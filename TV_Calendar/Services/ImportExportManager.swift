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
    let version: Int
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
    let quality: String // On stocke en String dans le fichier JSON
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
                    // CORRECTION ICI : On convertit l'Enum en String
                    quality: show.quality.rawValue,
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
            // Conversion du String JSON vers l'Enum
            let importedQuality = VideoQuality(rawValue: backupShow.quality) ?? .hd1080
            
            // Vérification doublon (Même ID + Même Qualité)
            if let _ = existingShows.first(where: { $0.tvmazeId == backupShow.tvmazeId && $0.quality == importedQuality }) {
                print("♻️ Mise à jour de l'existant : \(backupShow.name)")
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
                quality: importedQuality // Utilisation de l'Enum converti
            )
            context.insert(newShow)
            
            // Création des épisodes
            for backupEp in backupShow.episodes {
                let newEp = Episode(
                    tvmazeId: backupEp.tvmazeId,
                    title: backupEp.title,
                    season: backupEp.season,
                    number: backupEp.number,
                    airDate: nil,
                    runtime: nil,
                    overview: backupEp.overview
                )
                
                newEp.isWatched = backupEp.isWatched
                newEp.watchedDate = backupEp.watchedDate
                
                newEp.id = "\(newShow.uuid)-\(backupEp.tvmazeId)"
                newEp.show = newShow
                context.insert(newEp)
            }
            
            importedCount += 1
        }
        
        // On force une synchro API pour récupérer les dates de sortie manquantes
        if importedCount > 0 {
            Task {
                await SyncManager.shared.synchronizeLibrary(modelContext: context)
            }
        }
        
        return importedCount
    }
}
