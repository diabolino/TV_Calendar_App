//
//  SyncManager.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//


import Foundation
import SwiftData

class SyncManager {
    static let shared = SyncManager()
    
    // Fonction principale à appeler au lancement de l'app ou via "Pull to Refresh"
    @MainActor
    func synchronizeLibrary(modelContext: ModelContext) async {
        print("🔄 Début de la synchronisation intelligente...")
        
        do {
            // 1. Récupérer toutes nos séries locales
            let descriptor = FetchDescriptor<TVShow>()
            let localShows = try modelContext.fetch(descriptor)
            
            if localShows.isEmpty { return }
            
            // 2. Récupérer la liste des mises à jour globales depuis TVMaze (1 seul appel)
            let updatesMap = try await TVMazeService.shared.fetchUpdates()
            
            var showsToUpdate: [TVShow] = []
            
            // 3. Comparer : Qui a besoin d'une mise à jour ?
            for show in localShows {
                // Si le timestamp de l'API est plus grand que le nôtre, il y a du nouveau !
                if let apiTimestamp = updatesMap[show.tvmazeId], apiTimestamp > show.lastUpdatedTimestamp {
                    showsToUpdate.append(show)
                    // On met à jour le timestamp local tout de suite pour éviter de re-sync en boucle
                    show.lastUpdatedTimestamp = apiTimestamp
                }
            }
            
            print("📊 Bilan : \(localShows.count) séries en tout. \(showsToUpdate.count) à mettre à jour.")
            
            // 4. Mettre à jour uniquement les séries nécessaires
            // On le fait série par série pour ne pas surcharger
            for show in showsToUpdate {
                await updateShowSchedule(show: show, context: modelContext)
                // Petite pause pour être gentil avec l'API (Rate Limiting)
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec entre chaque appel
            }
            
            print("✅ Synchronisation terminée !")
            
        } catch {
            print("❌ Erreur Sync: \(error)")
        }
    }
    
    @MainActor
        private func updateShowSchedule(show: TVShow, context: ModelContext) async {
            print("   -> Mise à jour de : \(show.name)")
            
            // 1. Récupération des données brutes TVMaze (Rapide)
            guard let episodesDTO = try? await TVMazeService.shared.fetchEpisodes(showId: show.tvmazeId) else { return }
            
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
            var tmdbId: Int? = show.tmdbId // On utilise l'ID déjà stocké si possible
            
            // --- RECUPERATION ID TMDB SI MANQUANT ---
            // (Optimisation: on ne le fait que si on ne l'a pas déjà)
            if tmdbId == nil {
                 if let details = try? await TVMazeService.shared.fetchShow(id: show.tvmazeId) {
                     // Mise à jour infos série au passage
                     show.status = details.status
                     show.network = details.network?.name ?? details.webChannel?.name
                     
                     if let imdb = details.externals?.imdb,
                        let tmdbResult = try? await TMDBService.shared.findShowByExternalId(imdbId: imdb) {
                         tmdbId = tmdbResult.id
                         show.tmdbId = tmdbResult.id // Sauvegarde pour la prochaine fois
                     }
                 }
            }
            
            // Préparation des données locales pour comparaison rapide
            let safeEpisodes = show.episodes ?? []
            let existingEpisodesDict = Dictionary(grouping: safeEpisodes, by: { $0.tvmazeId })
            
            // Groupement par saison pour l'itération
            let episodesBySeason = Dictionary(grouping: episodesDTO, by: { $0.season })
            
            for (seasonNum, seasonEpisodes) in episodesBySeason {
                
                // --- LE COEUR DE L'OPTIMISATION EST ICI ---
                // On vérifie si CETTE saison a besoin d'une mise à jour TMDB
                let needsTMDBUpdate = seasonEpisodes.contains { dto in
                    // Cas A: C'est un nouvel épisode (pas dans le dict local)
                    guard let existingEp = existingEpisodesDict[dto.id]?.first else { return true }
                    
                    // Cas B: C'est un épisode "TBA" qui vient d'avoir un titre
                    if existingEp.title == "TBA" && dto.name != "TBA" { return true }
                    
                    // Cas C: L'épisode est marqué comme "Traduit Auto" (On veut la version officielle si dispo)
                    if existingEp.isAutoTranslated { return true }
                    
                    // Cas D: Le résumé est vide
                    if (existingEp.overview?.isEmpty ?? true) { return true }
                    
                    // Sinon, pas besoin de TMDB pour cet épisode
                    return false
                }
                
                var frenchOverviews: [Int: String] = [:]
                var englishOverviews: [Int: String] = [:]
                
                // ON NE LANCE LES REQUÊTES TMDB QUE SI NÉCESSAIRE
                if needsTMDBUpdate, let tId = tmdbId {
                    // print("      Fetch TMDB pour Saison \(seasonNum)...") // Décommenter pour debug
                    
                    if let frSeason = try? await TMDBService.shared.fetchSeasonDetails(tmdbShowId: tId, seasonNumber: seasonNum, language: "fr-FR") {
                        for ep in frSeason.episodes { if let ov = ep.overview, !ov.isEmpty { frenchOverviews[ep.episode_number] = ov } }
                    }
                    // Si on n'a pas tout en FR, on tente l'anglais
                    if seasonEpisodes.count > frenchOverviews.count {
                        if let enSeason = try? await TMDBService.shared.fetchSeasonDetails(tmdbShowId: tId, seasonNumber: seasonNum, language: "en-US") {
                            for ep in enSeason.episodes { if let ov = ep.overview, !ov.isEmpty { englishOverviews[ep.episode_number] = ov } }
                        }
                    }
                } else {
                    // Si pas de mise à jour nécessaire, on ne fait RIEN (gain de temps énorme)
                    // print("      Saison \(seasonNum) à jour, skip TMDB.")
                }
                
                // Mise à jour des épisodes (Dates, Runtime, et Synopsis si récupérés)
                for epDTO in seasonEpisodes {
                    let date = epDTO.airdate != nil ? formatter.date(from: epDTO.airdate!) : nil
                    
                    if let existingEp = existingEpisodesDict[epDTO.id]?.first {
                        // Update simple (Date/Runtime) - Toujours fait car très rapide
                        if existingEp.airDate != date { existingEp.airDate = date }
                        if existingEp.runtime != epDTO.runtime { existingEp.runtime = epDTO.runtime }
                        
                        // Update Complexe (Titre / Synopsis)
                        // On ne touche au synopsis QUE si on a récupéré des données TMDB (donc si needsTMDBUpdate était true)
                        if needsTMDBUpdate || (existingEp.title == "TBA" && epDTO.name != "TBA") {
                            
                            if existingEp.title == "TBA" && epDTO.name != "TBA" { existingEp.title = epDTO.name }
                            
                            // On tente de mettre à jour le résumé seulement si on a de nouvelles données
                            // ou si l'actuel est une traduction auto
                            if !frenchOverviews.isEmpty || !englishOverviews.isEmpty || existingEp.isAutoTranslated {
                                let (overview, isTranslated) = await getSmartOverview(
                                    epNumber: epDTO.number,
                                    originalSummary: epDTO.summary,
                                    frenchDict: frenchOverviews,
                                    englishDict: englishOverviews,
                                    currentOverview: existingEp.overview,      // Passer l'actuel
                                    currentIsAuto: existingEp.isAutoTranslated // Passer l'état actuel
                                )
                                
                                // On n'écrase que si on a trouvé quelque chose de pertinent
                                if !overview.isEmpty {
                                    existingEp.overview = overview
                                    existingEp.isAutoTranslated = isTranslated
                                }
                            }
                        }
                        
                    } else {
                        // Nouvel épisode (Création)
                        let (overview, isTranslated) = await getSmartOverview(
                            epNumber: epDTO.number,
                            originalSummary: epDTO.summary,
                            frenchDict: frenchOverviews,
                            englishDict: englishOverviews,
                            currentOverview: nil,
                            currentIsAuto: false
                        )
                        
                        let newEp = Episode(
                            tvmazeId: epDTO.id,
                            title: epDTO.name,
                            season: epDTO.season,
                            number: epDTO.number,
                            airDate: date,
                            runtime: epDTO.runtime,
                            overview: overview
                        )
                        
                        newEp.isAutoTranslated = isTranslated
                        newEp.id = "\(show.uuid)-\(epDTO.id)"
                        newEp.show = show
                        context.insert(newEp)
                        
                        if let d = newEp.airDate, d > Date() {
                            NotificationManager.shared.scheduleNotification(for: newEp)
                        }
                    }
                }
            }
        }
        
        // Helper mis à jour pour prendre en compte l'état actuel
        private func getSmartOverview(
            epNumber: Int,
            originalSummary: String?,
            frenchDict: [Int: String],
            englishDict: [Int: String],
            currentOverview: String?,
            currentIsAuto: Bool
        ) async -> (String, Bool) {
            
            // 1. Si on a une VF officielle via TMDB, c'est le Graal, on prend tout de suite.
            if let fr = frenchDict[epNumber], !fr.isEmpty {
                return (fr, false)
            }
            
            // 2. Si on a déjà un résumé local qui N'EST PAS une traduction auto, on le garde !
            // (C'est ce qui évite de refaire des traductions inutiles ou d'écraser du contenu manuel)
            if let current = currentOverview, !current.isEmpty, !currentIsAuto {
                return (current, false)
            }
            
            // 3. Sinon, on cherche la source anglaise (TMDB EN ou TVMaze)
            let sourceText = englishDict[epNumber] ?? originalSummary?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) ?? ""
            
            if !sourceText.isEmpty {
                // Si on a du texte, on traduit
                if let translated = await TranslationService.shared.translate(text: sourceText) {
                    return (translated, true) // Marqué comme Auto-Traduit
                } else {
                    return (sourceText, true) // Echec trad, on garde l'anglais mais on marque comme "à revoir"
                }
            }
            
            return ("", false)
        }
}
