//
//  SharedPersistence.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 06/12/2025.
//  Updated for CloudKit Sync Fix (Correction .private)
//

import SwiftData
import Foundation

struct SharedPersistence {
    // ⚠️ ID APP GROUP
    static let appGroupIdentifier = "group.net.darkdiablo.TVCalendar"
    // ⚠️ ID ICLOUD (Doit correspondre exactement à vos Entitlements)
    static let iCloudContainerIdentifier = "iCloud.net.darkdiablo.TVCalendar.v2"

    static var sharedModelContainer: ModelContainer = {
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
            
            // CORRECTION : .private nécessite l'ID du container en paramètre
            modelConfiguration = ModelConfiguration(
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .private(iCloudContainerIdentifier)
            )
        } else {
            // Fallback (Stockage local par défaut si pas d'App Group trouvé)
            modelConfiguration = ModelConfiguration(
                cloudKitDatabase: .private(iCloudContainerIdentifier)
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
