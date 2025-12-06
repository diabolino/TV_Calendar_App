//
//  SharedPersistence.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 06/12/2025.
//

import SwiftData
import Foundation

struct SharedPersistence {
    static let appGroupIdentifier = "group.net.darkdiablo.TVCalendar" // ⚠️ REMPLACEZ PAR VOTRE VRAI ID APP GROUP

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([TVShow.self, Episode.self, CastMember.self])
        let modelConfiguration: ModelConfiguration
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            print("✅ APP GROUP TROUVÉ : \(containerURL.path)") // <--- Regardez la console
            let storeURL = containerURL.appending(path: "TVCalendar.store")
            modelConfiguration = ModelConfiguration(url: storeURL, allowsSave: true)
        } else {
            print("❌ APP GROUP INTROUVABLE. Fallback sur le stockage privé.") // <--- Si vous voyez ça, l'ID est faux
            modelConfiguration = ModelConfiguration()
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
