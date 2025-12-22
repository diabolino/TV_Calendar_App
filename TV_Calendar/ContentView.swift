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
                    SidebarView(profileId: currentProfileId) // <--- ICI
                #else
                    if sizeClass == .compact {
                        TabNavigationView(selectedTab: $selectedTab, profileId: currentProfileId)
                    } else {
                        SidebarView(profileId: currentProfileId) // <--- ET ICI
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
    let profileId: String?
    
    init(selectedTab: Binding<Int>, profileId: String?) {
        self._selectedTab = selectedTab
        self.profileId = profileId
        
        // Customisation TabBar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appBackground)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // Onglet 0 : À voir (Séries uniquement pour l'instant)
            ToWatchView(profileId: profileId)
                .tabItem { Label("À voir", systemImage: "play.tv") }
                .tag(0)
            
            // Onglet 1 : Calendrier
            CalendarView(profileId: profileId)
                .tabItem { Label("Calendrier", systemImage: "calendar") }
                .tag(1)
            
            // Onglet 2 : Explorer (Recherche + Bibliothèque Séries/Films)
            SearchView(profileId: profileId)
                .tabItem { Label("Explorer", systemImage: "magnifyingglass") }
                .tag(2)
            
            // --- ONGLET 3 SUPPRIMÉ ---
            
            // Onglet 4 -> Devient 3 : Dashboard (Stats)
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }
                .tag(3) // Changé de 4 à 3
            
            // Onglet 5 -> Devient 4 : Réglages
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gear") }
                .tag(4) // Changé de 5 à 4
        }
        .accentColor(Color.accentPurple)
    }
}
