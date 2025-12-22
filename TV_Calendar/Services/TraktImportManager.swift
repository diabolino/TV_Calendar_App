//
//  TraktImportManager.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 06/12/2025.
//  Updated for File Import (Legacy) AND API Sync (New)
//

import Foundation
import SwiftData
import SwiftUI

// --- Modèles pour décoder le JSON de Trakt (Fichiers Backup) ---
struct TraktShowEntry: Decodable {
    let show: TraktShowInfo
    let seasons: [TraktSeason]
}

struct TraktShowInfo: Decodable {
    let title: String
    let ids: TraktIds
}

// Cette structure est partagée
struct TraktIds: Decodable {
    let trakt: Int
    let imdb: String?
    let tvdb: Int?
    let tmdb: Int?
}

struct TraktSeason: Decodable {
    let number: Int
    let episodes: [TraktEpisode]
}

struct TraktEpisode: Decodable {
    let number: Int
    let plays: Int
    let last_watched_at: String
}

// --- Manager ---
class TraktImportManager {
    static let shared = TraktImportManager()
    
    // ====================================================
    // MARK: - 1. IMPORT VIA FICHIER JSON (BACKUP MANUEL)
    // ====================================================
    @MainActor
    func importTraktBackup(from url: URL, profileId: String?, context: ModelContext, existingShows: [TVShow]) async -> String {
        
        // Gestion des permissions de fichier
        guard url.startAccessingSecurityScopedResource() else {
            let errorMsg = "Permission refusée sur le fichier."
            ToastManager.shared.show(errorMsg, style: .error)
            return errorMsg
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let traktEntries = try JSONDecoder().decode([TraktShowEntry].self, from: data)
            
            var successCount = 0
            var updateCount = 0
            var errorCount = 0
            
            print("📥 Trakt (Fichier): \(traktEntries.count) séries trouvées.")
            ToastManager.shared.show("Import de \(traktEntries.count) séries en cours...", style: .info)
            
            let profileUUID = profileId != nil ? UUID(uuidString: profileId!) : nil
            
            // Traitement série par série
            for (index, entry) in traktEntries.enumerated() {
                let traktTitle = entry.show.title
                if index % 5 == 0 { print("--- Traitement Fichier \(index + 1)/\(traktEntries.count) ---") }
                
                // Recherche TVMaze via IDs
                guard let tvmazeShowDTO = try? await TVMazeService.shared.lookupShow(imdbId: entry.show.ids.imdb, tvdbId: entry.show.ids.tvdb) else {
                    print("⚠️ Introuvable : \(traktTitle)")
                    errorCount += 1
                    continue
                }
                
                var targetShow: TVShow
                
                // Vérification doublon DANS LE PROFIL ACTUEL
                if let existing = existingShows.first(where: { $0.tvmazeId == tvmazeShowDTO.id && $0.profileId == profileUUID }) {
                    targetShow = existing
                    updateCount += 1
                } else {
                    print("🆕 Création : \(traktTitle)")
                    
                    // Ajout
                    await LibraryManager.shared.addShow(
                        dto: tvmazeShowDTO,
                        quality: .hd1080,
                        profileId: profileId,
                        context: context,
                        existingShows: existingShows
                    )
                    
                    // Petit délai pour l'écriture SwiftData
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    
                    // Récupération de l'objet créé
                    let searchId = tvmazeShowDTO.id
                    let descriptor = FetchDescriptor<TVShow>(predicate: #Predicate<TVShow> {
                        $0.tvmazeId == searchId && $0.profileId == profileUUID
                    })
                    
                    if let freshShow = try? context.fetch(descriptor).first {
                        targetShow = freshShow
                        successCount += 1
                    } else {
                        errorCount += 1
                        continue
                    }
                }
                
                // Marquage des épisodes vus (Logique spécifique Fichier)
                markEpisodesAsWatchedFromFile(traktEntry: entry, localShow: targetShow)
                
                // Pause anti-spam API
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            
            let message = "Fichier : \(successCount) ajouts, \(updateCount) MAJ, \(errorCount) erreurs."
            ToastManager.shared.show("Import terminé", style: .success)
            return message
            
        } catch {
            return "Erreur lecture JSON : \(error.localizedDescription)"
        }
    }
    
    // Helper pour le fichier JSON
    @MainActor
    private func markEpisodesAsWatchedFromFile(traktEntry: TraktShowEntry, localShow: TVShow) {
        guard let localEpisodes = localShow.episodes else { return }
        let episodeMap = Dictionary(grouping: localEpisodes, by: { "\($0.season)-\($0.number)" })
        
        for season in traktEntry.seasons {
            for traktEp in season.episodes {
                let key = "\(season.number)-\(traktEp.number)"
                if let match = episodeMap[key]?.first {
                    if !match.isWatched {
                        match.isWatched = true
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        match.watchedDate = formatter.date(from: traktEp.last_watched_at) ?? Date()
                    }
                }
            }
        }
    }

    // ====================================================
    // MARK: - 2. TRAITEMENT DEPUIS L'API (OAUTH SYNC)
    // ====================================================
    
    // --- SÉRIES ---
    @MainActor
    func processApiSyncShows(items: [TraktWatchedShow], profileId: String?, context: ModelContext, existingShows: [TVShow]) async -> String {
        print("🔄 Sync Séries API : \(items.count) trouvées.")
        
        var added = 0
        var updated = 0
        let profileUUID = profileId != nil ? UUID(uuidString: profileId!) : nil
        
        for (index, item) in items.enumerated() {
            if index % 5 == 0 { print("   API Série \(index)/\(items.count)...") }
            
            // 1. Identification (TVMaze)
            guard let tvmazeShowDTO = try? await TVMazeService.shared.lookupShow(imdbId: item.show.ids.imdb, tvdbId: item.show.ids.tvdb) else {
                continue
            }
            
            var targetShow: TVShow?
            
            // 2. Récupération ou Création
            if let existing = existingShows.first(where: { $0.tvmazeId == tvmazeShowDTO.id && $0.profileId == profileUUID }) {
                targetShow = existing
            } else {
                // Ajout
                await LibraryManager.shared.addShow(dto: tvmazeShowDTO, quality: .hd1080, profileId: profileId, context: context, existingShows: existingShows)
                // Récupération immédiate
                let searchId = tvmazeShowDTO.id
                let descriptor = FetchDescriptor<TVShow>(predicate: #Predicate<TVShow> { $0.tvmazeId == searchId && $0.profileId == profileUUID })
                targetShow = try? context.fetch(descriptor).first
                added += 1
                try? await Task.sleep(nanoseconds: 250_000_000) // Pause API
            }
            
            // 3. Mise à jour des épisodes vus (Logique spécifique API)
            if let show = targetShow, let seasons = item.seasons {
                updateWatchedEpisodesFromApi(localShow: show, traktSeasons: seasons)
                updated += 1
            }
        }
        
        return "Séries : \(added) ajoutées, \(updated) à jour."
    }
    
    // Helper pour API
    @MainActor
    private func updateWatchedEpisodesFromApi(localShow: TVShow, traktSeasons: [TraktWatchedSeason]) {
        guard let localEpisodes = localShow.episodes else { return }
        let episodeMap = Dictionary(grouping: localEpisodes, by: { "\($0.season)-\($0.number)" })
        
        for season in traktSeasons {
            for ep in season.episodes {
                let key = "\(season.number)-\(ep.number)"
                if let match = episodeMap[key]?.first {
                    if !match.isWatched {
                        match.isWatched = true
                        // Le format de date de l'API est parfois standard ISO8601
                        match.watchedDate = ISO8601DateFormatter().date(from: ep.last_watched_at ?? "") ?? Date()
                    }
                }
            }
        }
    }
    
    // --- FILMS ---
    @MainActor
    func processApiSyncMovies(items: [TraktWatchedMovie], profileId: String?, context: ModelContext, existingMovies: [Movie]) async -> String {
        print("🔄 Sync Films API : \(items.count) trouvés.")
        var added = 0
        let profileUUID = profileId != nil ? UUID(uuidString: profileId!) : nil
        
        for item in items {
            // On a besoin de l'ID TMDB
            guard let tmdbId = item.movie.ids.tmdb else { continue }
            
            // Vérif doublon
            if existingMovies.contains(where: { $0.tmdbId == tmdbId && $0.profileId == profileUUID }) {
                continue
            }
            
            // Ajout
            await LibraryManager.shared.addMovie(tmdbId: tmdbId, profileId: profileId, context: context, existingMovies: existingMovies)
            
            // Marquage comme VU immédiatement
            let descriptor = FetchDescriptor<Movie>(predicate: #Predicate<Movie> { $0.tmdbId == tmdbId && $0.profileId == profileUUID })
            if let freshMovie = try? context.fetch(descriptor).first {
                freshMovie.status = .watched
                freshMovie.watchedDate = ISO8601DateFormatter().date(from: item.last_watched_at ?? "") ?? Date()
            }
            
            added += 1
            try? await Task.sleep(nanoseconds: 100_000_000) // Pause
        }
        
        return "Films : \(added) ajoutés."
    }
}
