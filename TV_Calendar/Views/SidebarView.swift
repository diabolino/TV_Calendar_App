//
//  SidebarView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI

struct SidebarView: View {
    var body: some View {
        NavigationSplitView {
            List {
                // Section 1 : Votre activité
                Section("Mon Suivi") {
                    NavigationLink(destination: ToWatchView(selectedTab: nil)) {
                        Label("À voir", systemImage: "play.tv")
                    }
                    
                    NavigationLink(destination: CalendarView()) {
                        Label("Calendrier", systemImage: "calendar")
                    }
                    
                    NavigationLink(destination: DashboardView()) {
                        Label("Dashboard", systemImage: "chart.bar")
                    }
                }
                
                // Section 2 : Bibliothèque & Recherche
                Section("Collection") {
                    NavigationLink(destination: SearchView()) {
                        Label("Séries", systemImage: "square.grid.2x2")
                    }
                }
            }
            .listStyle(.sidebar) // Style natif macOS (translucide)
            .navigationTitle("TV Tracker")
            
        } detail: {
            // Vue par défaut au lancement sur Mac
            ToWatchView(selectedTab: nil)
        }
    }
}
