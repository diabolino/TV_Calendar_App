//
//  TV_CalendarApp.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//  Updated with Legacy Data Migration
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct TV_CalendarApp: App {
    
    // Config Persistence
    var sharedModelContainer: ModelContainer = SharedPersistence.sharedModelContainer
    
    // Stockage de l'ID utilisateur sélectionné
    @AppStorage("currentProfileId") private var currentProfileId: String?
    
    // Flag pour savoir si on a déjà fait la migration (Optionnel, mais plus sûr)
    @AppStorage("hasMigratedV2") private var hasMigratedV2: Bool = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let _ = currentProfileId {
                    // Si un utilisateur est connecté, on lance l'app
                    ContentView(currentProfileId: $currentProfileId)
                } else {
                    // Sinon, on lance la sélection de profil
                    ProfileSelectionView(selectedProfileId: $currentProfileId)
                }
            }
            .onAppear {
                NotificationManager.shared.requestPermission()
                // TENTATIVE DE MIGRATION AU LANCEMENT
                migrateLegacyData(context: sharedModelContainer.mainContext)
            }
            .task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await SyncManager.shared.synchronizeLibrary(modelContext: sharedModelContainer.mainContext)
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // --- FONCTION DE MIGRATION DES ANCIENNES DONNÉES ---
    @MainActor
    func migrateLegacyData(context: ModelContext) {
        // Si déjà fait, on arrête tout de suite
        if hasMigratedV2 { return }
        
        print("🛠️ Vérification de la migration des données v1 -> v2...")
        
        do {
            // 1. Chercher s'il y a des séries "orphelines" (sans profileId)
            // Note: En SwiftData, nil est parfois tricky à filtrer directement, on récupère tout et on trie.
            let descriptor = FetchDescriptor<TVShow>()
            let allShows = try context.fetch(descriptor)
            let orphans = allShows.filter { $0.profileId == nil }
            
            if orphans.isEmpty {
                print("✅ Aucune donnée orpheline trouvée. Tout est propre.")
                hasMigratedV2 = true
                return
            }
            
            print("⚠️ \(orphans.count) séries orphelines trouvées. Lancement de la migration...")
            
            // 2. Vérifier s'il existe déjà un profil, sinon en créer un par défaut
            let profileDescriptor = FetchDescriptor<UserProfile>()
            var defaultProfile: UserProfile
            
            let existingProfiles = try context.fetch(profileDescriptor)
            
            if let firstProfile = existingProfiles.first {
                defaultProfile = firstProfile
                print("👤 Utilisation du profil existant : \(defaultProfile.name)")
            } else {
                defaultProfile = UserProfile(name: "Principal", avatarSymbol: "star.circle", isDefault: true)
                defaultProfile.colorHex = "007AFF" // Bleu Apple
                context.insert(defaultProfile)
                try context.save() // Sauvegarde immédiate pour avoir un ID
                print("👤 Création d'un profil 'Principal' par défaut.")
            }
            
            // 3. Assigner les orphelins à ce profil
            for show in orphans {
                show.profileId = defaultProfile.id
            }
            
            // 4. Sauvegarder et marquer comme fait
            try context.save()
            hasMigratedV2 = true
            
            // 5. Connecter l'utilisateur automatiquement pour qu'il ne soit pas perdu
            currentProfileId = defaultProfile.id.uuidString
            
            print("🎉 Migration terminée avec succès ! Toutes les séries sont sur le profil '\(defaultProfile.name)'.")
            ToastManager.shared.show("Mise à jour des données terminée", style: .success)
            
        } catch {
            print("❌ Erreur critique lors de la migration : \(error)")
        }
    }
}
