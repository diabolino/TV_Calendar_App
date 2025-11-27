//
//  ContentView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var sizeClass
    #endif
    
    // On force le mode sombre pour toute l'app
    var body: some View {
        Group {
            #if os(macOS)
                SidebarView()
            #else
                if sizeClass == .compact {
                    TabNavigationView()
                } else {
                    SidebarView()
                }
            #endif
        }
        .preferredColorScheme(.dark) // FORCE LE DARK MODE
    }
}

struct TabNavigationView: View {
    
    // Customisation de la TabBar pour qu'elle soit sombre
    #if os(iOS)
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        // On utilise UIColor que sur iOS. Sur Mac ce code sera ignoré.
        appearance.backgroundColor = UIColor(Color.appBackground)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    #endif
    
    var body: some View {
        TabView {
            // Onglet 1 : À Voir (Nouveau !)
            ToWatchView()
                .tabItem { Label("À voir", systemImage: "play.tv") }
            
            // Onglet 2 : Calendrier
            CalendarView()
                .tabItem { Label("Calendrier", systemImage: "calendar") }
            
            // Onglet 3 : Séries (Recherche/Bibliothèque)
            SearchView()
                .tabItem { Label("Séries", systemImage: "square.grid.2x2") }
            
            // Onglet 4 : Dashboard
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }
        }
        .accentColor(Color.accentPurple) // Couleur des icones actives
    }
}
