//
//  TV_CalendarApp.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct TV_CalendarApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TVShow.self,
            Episode.self,
            CastMember.self,
        ])
        
        // Configuration STANDARD pour CloudKit
        // On laisse SwiftData gérer tout automatiquement
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
            // Pas de cloudKitDatabase: .none -> On veut la synchro !
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Si ça plante ici, c'est souvent un "Schema Mismatch"
            // L'astuce radicale pour les développeurs : supprimer les fichiers locaux
            // ATTENTION : À ne faire qu'en phase de développement
            print("❌ Erreur critique au chargement : \(error)")
            
            // On tente de nettoyer le dossier Application Support (là où SwiftData stocke par défaut)
            let defaultURL = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: defaultURL)
            try? FileManager.default.removeItem(at: defaultURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: defaultURL.appendingPathExtension("wal"))
            
            print("⚠️ Base de données locale supprimée pour tenter de réparer. Relancez l'app.")
            fatalError("Crash volontaire pour reset : \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NotificationManager.shared.requestPermission()
                }
                .task {
                    // Petite pause pour laisser l'UI charger
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    // Lancement de la synchro intelligente
                    await SyncManager.shared.synchronizeLibrary(modelContext: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
