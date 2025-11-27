//
//  TV_CalendarApp.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData

@main
struct TV_CalendarApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TVShow.self,
            Episode.self,
            CastMember.self,
        ])
        
        // Configuration avec CloudKit activé et URL personnalisée
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: URL.documentsDirectory.appending(path: "TVCalendar.sqlite"),
            allowsSave: true,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ ModelContainer créé avec succès (CloudKit activé)")
            return container
        } catch {
            // ⚠️ Si CloudKit échoue, on tente un fallback en mode local
            print("❌ Erreur CloudKit : \(error.localizedDescription)")
            print("🔄 Tentative de création en mode local uniquement...")
            
            // En cas d'erreur, on supprime la base et on recommence en local
            let dbURL = URL.documentsDirectory.appending(path: "TVCalendar.sqlite")
            try? FileManager.default.removeItem(at: dbURL)
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("wal"))
            print("🗑️ Ancienne base de données supprimée")
            
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                url: dbURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            
            do {
                let container = try ModelContainer(for: schema, configurations: [fallbackConfig])
                print("✅ ModelContainer créé en mode local")
                return container
            } catch {
                // Si même le mode local échoue, c'est critique
                print("❌ Erreur fatale : \(error)")
                fatalError("Impossible de créer le conteneur de données : \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NotificationManager.shared.requestPermission()
                }
                .task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    // Attention : Accéder à sharedModelContainer ici est risqué si l'init a échoué,
                    // mais avec la correction ci-dessus, ça devrait passer.
                    await SyncManager.shared.synchronizeLibrary(modelContext: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
