//
//  BackupData.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 06/12/2025.
//


import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// --- STRUCTURES DE SAUVEGARDE (JSON) ---
struct BackupData: Codable {
    let version: Int // Pour gérer les futures évolutions
    let date: Date
    let shows: [BackupShow]
}

struct BackupShow: Codable {
    let tvmazeId: Int
    let name: String
    let overview: String
    let imageUrl: String?
    let bannerUrl: String?
    let network: String?
    let status: String?
    let quality: String
    let episodes: [BackupEpisode]
}

struct BackupEpisode: Codable {
    let tvmazeId: Int
    let title: String
    let season: Int
    let number: Int
    let isWatched: Bool
    let watchedDate: Date?
    let overview: String?
}

// --- MANAGER ---
class ImportExportManager {
    static let shared = ImportExportManager()
    
    // 1. EXPORT : De SwiftData vers un fichier JSON temporaire
    @MainActor
    func generateBackupFile(context: ModelContext) -> URL? {
        do {
            // A. Récupérer toutes les données
            let descriptor = FetchDescriptor<TVShow>()
            let shows = try context.fetch(descriptor)
            
            // B. Convertir en objets simples (Structs)
            let backupShows = shows.map { show in
                BackupShow(
                    tvmazeId: show.tvmazeId,
                    name: show.name,
                    overview: show.overview,
                    imageUrl: show.imageUrl,
                    bannerUrl: show.bannerUrl,
                    network: show.network,
                    status: show.status,
                    quality: show.quality,
                    episodes: (show.episodes ?? []).map { ep in
                        BackupEpisode(
                            tvmazeId: ep.tvmazeId,
                            title: ep.title,
                            season: ep.season,
                            number: ep.number,
                            isWatched: ep.isWatched,
                            watchedDate: ep.watchedDate,
                            overview: ep.overview
                        )
                    }
                )
            }
            
            let backup = BackupData(version: 1, date: Date(), shows: backupShows)
            
            // C. Encoder en JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(backup)
            
            // D. Écrire dans un fichier temporaire
            let fileName = "TVCalendar_Backup_\(Int(Date().timeIntervalSince1970)).json"
            let tempURL = FileManager.default.temporaryDirectory.appending(path: fileName)
            try data.write(to: tempURL)
            
            return tempURL
            
        } catch {
            print("❌ Erreur Export : \(error)")
            return nil
        }
    }
    
    // 2. IMPORT : Du fichier JSON vers SwiftData
    @MainActor
    func restoreBackup(from url: URL, context: ModelContext) async throws -> Int {
        // A. Lire et décoder le fichier
        // Note: startAccessingSecurityScopedResource est crucial pour lire les fichiers sélectionnés
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupData.self, from: data)
        
        var importedCount = 0
        
        // B. Récupérer l'existant pour éviter les doublons
        let descriptor = FetchDescriptor<TVShow>()
        let existingShows = try context.fetch(descriptor)
        
        // C. Insérer les données
        for backupShow in backup.shows {
            // Vérification doublon (Même ID + Même Qualité)
            if let existing = existingShows.first(where: { $0.tvmazeId == backupShow.tvmazeId && $0.quality == backupShow.quality }) {
                print("♻️ Mise à jour de l'existant : \(backupShow.name)")
                // On pourrait mettre à jour le statut des épisodes ici si on veut fusionner
                // Pour l'instant, on ignore si ça existe déjà pour ne pas écraser
                continue
            }
            
            // Création de la série
            let newShow = TVShow(
                tvmazeId: backupShow.tvmazeId,
                name: backupShow.name,
                overview: backupShow.overview,
                imageUrl: backupShow.imageUrl,
                bannerUrl: backupShow.bannerUrl,
                network: backupShow.network,
                status: backupShow.status,
                quality: VideoQuality(rawValue: backupShow.quality) ?? .hd1080 // Conversion String -> Enum
            )
            context.insert(newShow)
            
            // Création des épisodes
            for backupEp in backupShow.episodes {
                let newEp = Episode(
                    tvmazeId: backupEp.tvmazeId,
                    title: backupEp.title,
                    season: backupEp.season,
                    number: backupEp.number,
                    airDate: nil, // On ne stocke pas la date de sortie dans le backup pour gagner de la place, elle se mettra à jour via l'API plus tard
                    runtime: nil,
                    overview: backupEp.overview
                )
                
                // Restauration de l'état "Vu"
                newEp.isWatched = backupEp.isWatched
                newEp.watchedDate = backupEp.watchedDate
                
                newEp.id = "\(newShow.uuid)-\(backupEp.tvmazeId)"
                newEp.show = newShow
                context.insert(newEp)
            }
            
            importedCount += 1
        }
        
        // On force une synchro API pour récupérer les dates de sortie manquantes et les castings
        // C'est plus propre que de tout stocker dans le JSON
        if importedCount > 0 {
            Task {
                // On lance la synchro en tâche de fond
                await SyncManager.shared.synchronizeLibrary(modelContext: context)
            }
        }
        
        return importedCount
    }
}