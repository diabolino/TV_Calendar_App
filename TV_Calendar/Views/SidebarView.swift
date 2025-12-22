//
//  SidebarView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//  Updated for Multi-User & Movies
//

import SwiftUI

struct SidebarView: View {
    // On doit recevoir l'ID du profil pour le passer aux vues enfants
    let profileId: String?
    
    var body: some View {
        NavigationSplitView {
            List {
                // Section 1 : Votre activité
                Section("Mon Suivi") {
                    // CORRECTION : On passe profileId, et on retire selectedTab qui n'existe plus
                    NavigationLink(destination: ToWatchView(profileId: profileId)) {
                        Label("À voir", systemImage: "play.tv")
                    }
                    
                    NavigationLink(destination: CalendarView(profileId: profileId)) {
                        Label("Calendrier", systemImage: "calendar")
                    }
                    
                    NavigationLink(destination: DashboardView()) {
                        Label("Dashboard", systemImage: "chart.bar")
                    }
                }
                
                // Section 2 : Bibliothèque & Recherche
                Section("Collection") {
                    NavigationLink(destination: SearchView(profileId: profileId)) {
                        Label("Explorer", systemImage: "magnifyingglass")
                    }
                }
                
                // Section 3 : Paramètres
                Section("Système") {
                    NavigationLink(destination: SettingsView()) {
                        Label("Réglages", systemImage: "gear")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("TV Tracker")
            
        } detail: {
            // Vue par défaut au lancement sur Mac/iPad
            ToWatchView(profileId: profileId)
        }
    }
}
