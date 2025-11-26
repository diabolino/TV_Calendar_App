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
            let updatesMap = try await APIService.shared.fetchUpdates()
            
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
    
    // Met à jour une seule série (Récupère les nouveaux épisodes)
    @MainActor
    private func updateShowSchedule(show: TVShow, context: ModelContext) async {
        print("   -> Mise à jour de : \(show.name)")
        
        // 1. On récupère les épisodes à jour
        if let episodes = try? await APIService.shared.fetchEpisodes(showId: show.tvmazeId) {
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
            
            // On récupère les IDs des épisodes déjà existants pour ne pas faire de doublons
            let existingEpisodeIDs = Set(show.episodes.map { $0.tvmazeId })
            
            for epDTO in episodes {
                // Si l'épisode n'existe pas encore, on le crée
                if !existingEpisodeIDs.contains(epDTO.id) {
                    let date = epDTO.airdate != nil ? formatter.date(from: epDTO.airdate!) : nil
                    
                    // Note: Ici on pourrait remettre la logique de traduction intelligente
                    // Pour simplifier l'exemple, je mets le basique
                    let newEp = Episode(
                        tvmazeId: epDTO.id,
                        title: epDTO.name,
                        season: epDTO.season,
                        number: epDTO.number,
                        airDate: date,
                        runtime: epDTO.runtime,
                        overview: epDTO.summary // Ou logique de trad...
                    )
                    
                    newEp.id = "\(show.uuid)-\(epDTO.id)"
                    newEp.show = show
                    context.insert(newEp)
                    
                    // Notif si futur
                    if let d = newEp.airDate, d > Date() {
                        NotificationManager.shared.scheduleNotification(for: newEp)
                    }
                    print("      + Nouvel épisode : S\(epDTO.season)E\(epDTO.number)")
                } else {
                    // Optionnel : Mettre à jour la date de diffusion si elle a changé
                    if let existingEp = show.episodes.first(where: { $0.tvmazeId == epDTO.id }) {
                        let newDate = epDTO.airdate != nil ? formatter.date(from: epDTO.airdate!) : nil
                        if existingEp.airDate != newDate {
                            existingEp.airDate = newDate
                            print("      ~ Date modifiée pour S\(epDTO.season)E\(epDTO.number)")
                        }
                    }
                }
            }
        }
    }
}