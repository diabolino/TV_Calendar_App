//
//  CalendarView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var sizeClass
    #endif

    @Query(sort: \Episode.airDate, order: .forward) var allEpisodes: [Episode]
    
    @State private var viewMode: CalendarMode = .week // Par défaut semaine
    @State private var selectedDate = Date()
    
    enum CalendarMode: String, CaseIterable {
        case list = "list.bullet"
        case month = "calendar"
        case week = "list.bullet.below.rectangle"
    }
    
    var body: some View {
        // CALCUL DE LA LARGEUR DISPONIBLE
        let screenWidth = UIScreen.main.bounds.width
        
        NavigationStack {
            VStack(spacing: 0) {
                
                // --- BARRE DE NAVIGATION BLINDÉE ---
                HStack(spacing: 0) { // Spacing 0 pour gérer nous-mêmes
                    
                    // Partie Gauche : Navigation (Prend toute la place dispo à gauche)
                    HStack(spacing: 8) {
                        Button(action: { moveDate(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .fontWeight(.bold)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        
                        Text(headerTitle)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8) // Rétrécit si trop long
                            .id(headerTitle)
                            .contentTransition(.numericText())
                        
                        Button(action: { moveDate(by: 1) }) {
                            Image(systemName: "chevron.right")
                                .fontWeight(.bold)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        
                        Button("Auj.") {
                            withAnimation { selectedDate = Date() }
                        }
                        .font(.caption).fontWeight(.medium)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .fixedSize()
                        .tint(.accentPurple)
                    }
                    
                    Spacer() // Pousse le Picker à droite
                    
                    // Partie Droite : Sélecteur
                    Picker("Vue", selection: $viewMode) {
                        Image(systemName: "list.bullet").tag(CalendarMode.list)
                        Image(systemName: "calendar").tag(CalendarMode.month)
                        Image(systemName: "rectangle.split.3x1").tag(CalendarMode.week)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110) // Largeur fixe raisonnable
                }
                .padding(.horizontal, 16)
                .frame(width: screenWidth) // FORCE LA LARGEUR ÉCRAN
                .frame(height: 60)
                .background(Color.cardBackground)
                .clipped() // Coupe tout ce qui dépasse au cas où
                
                // --- CONTENU ---
                Group {
                    switch viewMode {
                    case .month:
                        MonthCalendarView(selectedDate: $selectedDate, episodes: allEpisodes)
                    case .week:
                        WeekCalendarView(selectedDate: $selectedDate, episodes: allEpisodes)
                    case .list:
                        EpisodeListView(episodes: allEpisodes.filter { $0.airDate != nil && $0.airDate! >= Date() })
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.appBackground)
            .navigationTitle("")
            #if os(iOS)
            .toolbar(sizeClass == .compact ? .hidden : .visible, for: .navigationBar)
            #endif
        }
    }
    
    // (Helpers inchangés)
    var headerTitle: String {
        switch viewMode {
        case .month, .list:
            return selectedDate.formatted(.dateTime.month(.wide).year())
        case .week:
            let week = selectedDate.weekDays()
            if let start = week.first, let end = week.last {
                let fStart = start.formatted(.dateTime.day().month(.abbreviated))
                let fEnd = end.formatted(.dateTime.day().month(.abbreviated))
                return "\(fStart) - \(fEnd)"
            }
            return selectedDate.formatted(.dateTime.month(.wide).year())
        }
    }
    
    func moveDate(by value: Int) {
        let component: Calendar.Component = (viewMode == .week) ? .weekOfYear : .month
        if let newDate = Calendar.current.date(byAdding: component, value: value, to: selectedDate) {
            withAnimation { selectedDate = newDate }
        }
    }
}

// (EpisodeListView inchangé)
struct EpisodeListView: View {
    let episodes: [Episode]
    var body: some View {
        List(episodes) { episode in
            HStack {
                PosterImage(urlString: episode.show?.imageUrl, width: 50, height: 75).cornerRadius(4)
                VStack(alignment: .leading) {
                    Text(episode.show?.name ?? "").font(.headline)
                    Text(episode.title).font(.subheadline).foregroundColor(.gray)
                    Text(episode.airDate?.formatted(date: .abbreviated, time: .omitted) ?? "").font(.caption).foregroundColor(.blue)
                }
            }
            .listRowBackground(Color.appBackground)
        }
        .listStyle(.plain)
    }
}
