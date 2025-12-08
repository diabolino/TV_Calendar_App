//
//  TraktImportManager.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 06/12/2025.
//

import Foundation
import SwiftData
import SwiftUI

// --- Modèles pour décoder le JSON de Trakt (Inchangés) ---
struct TraktShowEntry: Decodable {
    let show: TraktShowInfo
    let seasons: [TraktSeason]
}

struct TraktShowInfo: Decodable {
    let title: String
    let ids: TraktIds
}

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
    
    @MainActor
    func importTraktBackup(from url: URL, context: ModelContext, existingShows: [TVShow]) async -> String {
        
        // 1. Lecture du fichier
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
            
            // --- NOUVEAU : Liste pour stocker les noms des échecs ---
            var failedShows: [String] = []
            
            // --- TOAST DE DÉBUT ---
            print("📥 Trakt: \(traktEntries.count) séries trouvées.")
            ToastManager.shared.show("Import de \(traktEntries.count) séries en cours...", style: .info)
            
            // 2. Traitement série par série
            for (index, entry) in traktEntries.enumerated() {
                let traktTitle = entry.show.title
                
                // Indicateur de progression console
                print("--- Traitement \(index + 1)/\(traktEntries.count) : \(traktTitle) ---")
                
                // On essaie de trouver l'ID TVMaze
                guard let tvmazeShowDTO = try? await TVMazeService.shared.lookupShow(imdbId: entry.show.ids.imdb, tvdbId: entry.show.ids.tvdb) else {
                    print("⚠️ Trakt: \(traktTitle) introuvable sur TVMaze")
                    ToastManager.shared.show("Introuvable : \(traktTitle)", style: .error)
                    
                    // On enregistre l'erreur
                    errorCount += 1
                    failedShows.append("- \(traktTitle) (Introuvable)")
                    continue
                }
                
                var targetShow: TVShow
                
                if let existing = existingShows.first(where: { $0.tvmazeId == tvmazeShowDTO.id }) {
                    // La série existe déjà
                    print("♻️ Trakt: \(traktTitle) existe déjà. Mise à jour.")
                    ToastManager.shared.show("Mise à jour : \(traktTitle)", style: .info)
                    targetShow = existing
                    updateCount += 1
                } else {
                    // Nouvelle série
                    print("🆕 Trakt: Création de \(traktTitle)...")
                    ToastManager.shared.show("Ajout de : \(traktTitle)", style: .success)
                    
                    // Ajout via LibraryManager
                    await LibraryManager.shared.addShow(
                        dto: tvmazeShowDTO,
                        quality: .hd1080,
                        context: context,
                        existingShows: existingShows
                    )
                    
                    // Petit délai pour laisser SwiftData écrire
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    
                    // Récupération de l'objet créé (Correction du Predicate)
                    let searchId = tvmazeShowDTO.id
                    let descriptor = FetchDescriptor<TVShow>(predicate: #Predicate<TVShow> { $0.tvmazeId == searchId })
                    
                    if let freshShow = try? context.fetch(descriptor).first {
                        targetShow = freshShow
                        successCount += 1
                    } else {
                        // Erreur à la création
                        errorCount += 1
                        failedShows.append("- \(traktTitle) (Erreur création)")
                        continue
                    }
                }
                
                // 3. Marquage des épisodes
                markEpisodesAsWatched(traktEntry: entry, localShow: targetShow)
                
                // Pause anti-spam API
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }
            
            // --- CONSTRUCTION DU RAPPORT DÉTAILLÉ ---
            var finalMessage = "Terminé : \(successCount) ajouts, \(updateCount) MAJ, \(errorCount) erreurs."
            
            if !failedShows.isEmpty {
                finalMessage += "\n\nÉchecs :\n" + failedShows.joined(separator: "\n")
            }
            
            // --- TOAST DE FIN ---
            if errorCount > 0 {
                ToastManager.shared.show("Terminé avec \(errorCount) erreurs", style: .info)
            } else {
                ToastManager.shared.show("Importation réussie !", style: .success)
            }
            
            return finalMessage
            
        } catch {
            let errorMsg = "Erreur lecture JSON : \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            ToastManager.shared.show("Fichier invalide", style: .error)
            return errorMsg
        }
    }
    
    @MainActor
    private func markEpisodesAsWatched(traktEntry: TraktShowEntry, localShow: TVShow) {
        guard let localEpisodes = localShow.episodes else { return }
        
        // Dictionnaire rapide pour éviter de boucler 100 fois
        let episodeMap = Dictionary(grouping: localEpisodes, by: { "\($0.season)-\($0.number)" })
        
        var markedCount = 0
        
        for season in traktEntry.seasons {
            for traktEp in season.episodes {
                let key = "\(season.number)-\(traktEp.number)"
                
                if let match = episodeMap[key]?.first {
                    if !match.isWatched {
                        match.isWatched = true
                        
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        
                        if let date = formatter.date(from: traktEp.last_watched_at) {
                            match.watchedDate = date
                        } else {
                            match.watchedDate = Date()
                        }
                        markedCount += 1
                    }
                }
            }
        }
        
        if markedCount > 0 {
            print("   ✅ \(markedCount) épisodes marqués vus pour \(localShow.name)")
        }
    }
}
