//
//  SharedPersistence.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 06/12/2025.
//  Updated for Movies & Multi-User
//

import SwiftData
import Foundation

struct SharedPersistence {
    // ⚠️ REMPLACEZ PAR VOTRE VRAI ID APP GROUP SI VOUS L'UTILISEZ
    static let appGroupIdentifier = "group.net.darkdiablo.TVCalendar"

    static var sharedModelContainer: ModelContainer = {
        // AJOUT DES NOUVEAUX MODÈLES ICI 👇
        let schema = Schema([
            UserProfile.self,
            TVShow.self,
            Episode.self,
            Movie.self,
            CastMember.self
        ])
        
        let modelConfiguration: ModelConfiguration
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            let storeURL = containerURL.appending(path: "TVCalendar.store")
            modelConfiguration = ModelConfiguration(url: storeURL, allowsSave: true)
        } else {
            // Fallback (Stockage local standard)
            modelConfiguration = ModelConfiguration()
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
