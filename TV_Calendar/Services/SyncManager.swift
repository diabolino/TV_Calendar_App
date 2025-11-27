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
        
        guard let episodesDTO = try? await TVMazeService.shared.fetchEpisodes(showId: show.tvmazeId) else { return }
        
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        
        var tmdbId: Int? = nil
        
        // --- LOGIQUE MISE À JOUR TBA & STATUS ---
        // CORRECTION : ?? []
        let safeEpisodes = show.episodes ?? []
        let existingEpisodesDict = Dictionary(grouping: safeEpisodes, by: { $0.tvmazeId })
        
        // On vérifie si on a besoin de récupérer les infos détaillées (pour l'IMDb ID ou update status)
        let needsDetailedInfo = episodesDTO.contains { dto in
            if existingEpisodesDict[dto.id] == nil { return true } // Nouvel épisode
            if let existing = existingEpisodesDict[dto.id]?.first, existing.title == "TBA" && dto.name != "TBA" { return true } // Update TBA
            return false
        }
        
        if needsDetailedInfo {
            // On récupère la fiche série à jour
            if let details = try? await TVMazeService.shared.fetchShow(id: show.tvmazeId) {
                
                // 1. CORRECTION DU WARNING : On utilise les données pour mettre à jour la série
                show.status = details.status
                show.network = details.network?.name ?? details.webChannel?.name
                // (Optionnel) show.imageUrl = details.image?.original ... si on voulait mettre à jour l'image
                
                // 2. On récupère l'IMDb ID pour la traduction
                if let imdb = details.externals?.imdb {
                    if let tmdbResult = try? await TMDBService.shared.findShowByExternalId(imdbId: imdb) {
                        tmdbId = tmdbResult.id
                    }
                }
            }
        }
        
        // --- SUITE DU CODE (Inchangé) ---
        let episodesBySeason = Dictionary(grouping: episodesDTO, by: { $0.season })
        
        for (seasonNum, seasonEpisodes) in episodesBySeason {
            
            var frenchOverviews: [Int: String] = [:]
            var englishOverviews: [Int: String] = [:]
            
            if let tId = tmdbId {
                if let frSeason = try? await TMDBService.shared.fetchSeasonDetails(tmdbShowId: tId, seasonNumber: seasonNum, language: "fr-FR") {
                    for ep in frSeason.episodes { if let ov = ep.overview, !ov.isEmpty { frenchOverviews[ep.episode_number] = ov } }
                }
                if seasonEpisodes.count > frenchOverviews.count {
                    if let enSeason = try? await TMDBService.shared.fetchSeasonDetails(tmdbShowId: tId, seasonNumber: seasonNum, language: "en-US") {
                        for ep in enSeason.episodes { if let ov = ep.overview, !ov.isEmpty { englishOverviews[ep.episode_number] = ov } }
                    }
                }
            }
            
            for epDTO in seasonEpisodes {
                let date = epDTO.airdate != nil ? formatter.date(from: epDTO.airdate!) : nil
                
                if let existingEp = existingEpisodesDict[epDTO.id]?.first {
                    // Update TBA
                    if existingEp.title == "TBA" && epDTO.name != "TBA" {
                        print("      ♻️ Update TBA : \(epDTO.name)")
                        existingEp.title = epDTO.name
                        existingEp.airDate = date
                        existingEp.runtime = epDTO.runtime
                        
                        let (overview, isTranslated) = await getSmartOverview(
                            epNumber: epDTO.number,
                            originalSummary: epDTO.summary,
                            frenchDict: frenchOverviews,
                            englishDict: englishOverviews
                        )
                        existingEp.overview = overview
                        existingEp.isAutoTranslated = isTranslated
                    }
                    // Update Date
                    else if existingEp.airDate != date {
                        existingEp.airDate = date
                        print("      🗓️ Date changée pour S\(epDTO.season)E\(epDTO.number)")
                    }
                } else {
                    // Nouvel épisode
                    print("      + Nouveau : S\(epDTO.season)E\(epDTO.number)")
                    
                    let (overview, isTranslated) = await getSmartOverview(
                        epNumber: epDTO.number,
                        originalSummary: epDTO.summary,
                        frenchDict: frenchOverviews,
                        englishDict: englishOverviews
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
    
    // Helper pour ne pas dupliquer la logique de traduction
    private func getSmartOverview(epNumber: Int, originalSummary: String?, frenchDict: [Int: String], englishDict: [Int: String]) async -> (String, Bool) {
        
        // 1. Priorité TMDB FR
        if let fr = frenchDict[epNumber] {
            return (fr, false)
        }
        
        // 2. Fallback Anglais (TMDB EN ou TVMaze) -> Traduction
        let sourceText = englishDict[epNumber] ?? originalSummary?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) ?? ""
        
        if !sourceText.isEmpty {
            if let translated = await TranslationService.shared.translate(text: sourceText) {
                return (translated, true) // Traduit !
            } else {
                return (sourceText, true) // Echec trad, on garde l'anglais avec le flag
            }
        }
        
        return ("", false)
    }
}
