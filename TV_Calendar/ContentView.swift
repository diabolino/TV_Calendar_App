//
//  ContentView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // NOUVEAU : Binding pour gérer la déconnexion
    @Binding var currentProfileId: String?
    
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var sizeClass
    #endif
    
    @State private var selectedTab: Int = 0
    @State private var toastManager = ToastManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            
            // --- CONTENU PRINCIPAL ---
            Group {
                #if os(macOS)
                    SidebarView() // Note: Il faudra adapter SidebarView plus tard si tu l'utilises sur Mac
                #else
                    if sizeClass == .compact {
                        // On passe l'ID du profil à la TabView
                        TabNavigationView(selectedTab: $selectedTab, profileId: currentProfileId)
                    } else {
                        SidebarView()
                    }
                #endif
            }
            
            // --- LA ZONE DE TOAST (Code Original restauré) ---
            if let toast = toastManager.currentToast {
                ToastView(toast: toast)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TabNavigationView: View {
    @Binding var selectedTab: Int
    let profileId: String? // NOUVEAU
    
    init(selectedTab: Binding<Int>, profileId: String?) {
        self._selectedTab = selectedTab
        self.profileId = profileId
        
        // Customisation TabBar (Code Original)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appBackground)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // Onglet 0 : À voir
            ToWatchView(profileId: profileId)
                .tabItem { Label("À voir", systemImage: "play.tv") }
                .tag(0)
            
            // Onglet 1 : Calendrier
            CalendarView(profileId: profileId)
                .tabItem { Label("Calendrier", systemImage: "calendar") }
                .tag(1)
            
            // Onglet 2 : Recherche (Séries & Films)
            SearchView(profileId: profileId)
                .tabItem { Label("Explorer", systemImage: "magnifyingglass") }
                .tag(2)
            
            // Onglet 3 : Mes Films (NOUVEAU)
            MoviesView(profileId: profileId)
                .tabItem { Label("Films", systemImage: "popcorn") }
                .tag(3)
            
            // Onglet 4 : Dashboard (Stats)
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }
                .tag(4)
            
            // Onglet 5 : Réglages (Déplacé ici pour accès facile au profil)
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gear") }
                .tag(5)
        }
        .accentColor(Color.accentPurple)
    }
}
