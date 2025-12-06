//
//  SharedPersistence.swift
//  TV_Calendar
//
//  Created by Gemini.
//

import SwiftData
import Foundation

struct SharedPersistence {
    static let appGroupIdentifier = "group.com.votreNom.TVCalendar" // ⚠️ REMPLACEZ PAR VOTRE VRAI ID APP GROUP

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TVShow.self,
            Episode.self,
            CastMember.self,
        ])
        
        let modelConfiguration: ModelConfiguration
        
        // On cherche le dossier partagé par l'App Group
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            let storeURL = containerURL.appending(path: "TVCalendar.store")
            modelConfiguration = ModelConfiguration(url: storeURL, allowsSave: true)
        } else {
            // Fallback si l'App Group est mal configuré (ne devrait pas arriver en prod)
            print("⚠️ Erreur: Impossible de trouver l'App Group Container. Utilisation du stockage standard.")
            modelConfiguration = ModelConfiguration()
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}