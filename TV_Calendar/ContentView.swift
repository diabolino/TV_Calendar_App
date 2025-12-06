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
    
    @State private var selectedTab: Int = 0
    
    // NOUVEAU : On observe le manager
    @State private var toastManager = ToastManager.shared

    var body: some View {
        ZStack(alignment: .bottom) { // ZStack pour superposer le Toast
            
            // --- VOTRE CONTENU PRINCIPAL ---
            Group {
                #if os(macOS)
                    SidebarView()
                #else
                    if sizeClass == .compact {
                        TabNavigationView(selectedTab: $selectedTab)
                    } else {
                        SidebarView()
                    }
                #endif
            }
            
            // --- LA ZONE DE TOAST ---
            if let toast = toastManager.currentToast {
                ToastView(toast: toast)
                    .padding(.bottom, 60) // Un peu au-dessus de la TabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100) // Toujours au-dessus
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TabNavigationView: View {
    // On récupère le binding ici
    @Binding var selectedTab: Int
    
    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab // Initialisation du binding
        
        // Customisation TabBar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appBackground)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        // Ajout de la sélection
        TabView(selection: $selectedTab) {
            
            // Onglet 0
            ToWatchView(selectedTab: $selectedTab) // On passe le relais
                .tabItem { Label("À voir", systemImage: "play.tv") }
                .tag(0) // <--- TAG 0
            
            // Onglet 1
            CalendarView()
                .tabItem { Label("Calendrier", systemImage: "calendar") }
                .tag(1) // <--- TAG 1
            
            // Onglet 2
            SearchView()
                .tabItem { Label("Séries", systemImage: "square.grid.2x2") }
                .tag(2) // <--- TAG 2 (C'est lui qu'on veut viser)
            
            // Onglet 3
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }
                .tag(3) // <--- TAG 3
            
            // Onglet 4
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gear") }
                .tag(4) // <--- TAG 4
        }
        .accentColor(Color.accentPurple)
    }
}
