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
    
    // --- LE CHANGEMENT EST ICI ---
    // On remplace tout le gros bloc par cette simple ligne qui va chercher
    // la config partagée dans l'autre fichier :
    var sharedModelContainer: ModelContainer = SharedPersistence.sharedModelContainer

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
