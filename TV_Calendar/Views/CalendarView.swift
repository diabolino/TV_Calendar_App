//
//  CalendarView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    let profileId: String? // NOUVEAU
    
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var sizeClass
    #endif

    @Query(sort: \Episode.airDate, order: .forward) var allEpisodes: [Episode]
    
    // FILTRE
    var myEpisodes: [Episode] {
        guard let pid = profileId, let uuid = UUID(uuidString: pid) else { return [] }
        return allEpisodes.filter { $0.show?.profileId == uuid }
    }
    
    @State private var viewMode: CalendarMode = .week // Par défaut semaine
    @State private var selectedDate = Date()
    
    enum CalendarMode: String, CaseIterable {
        case list = "list.bullet"
        case month = "calendar"
        case week = "list.bullet.below.rectangle"
    }
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        
        NavigationStack {
            VStack(spacing: 0) {
                
                // --- BARRE DE NAVIGATION BLINDÉE ---
                HStack(spacing: 0) {
                    
                    // Partie Gauche : Navigation
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
                            .minimumScaleFactor(0.8)
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
                    
                    Spacer()
                    
                    // Partie Droite : Sélecteur
                    Picker("Vue", selection: $viewMode) {
                        Image(systemName: "list.bullet").tag(CalendarMode.list)
                        Image(systemName: "calendar").tag(CalendarMode.month)
                        Image(systemName: "rectangle.split.3x1").tag(CalendarMode.week)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }
                .padding(.horizontal, 16)
                .frame(width: screenWidth)
                .frame(height: 60)
                .background(Color.cardBackground)
                .clipped()
                
                // --- CONTENU ---
                Group {
                    switch viewMode {
                    case .month:
                        MonthCalendarView(selectedDate: $selectedDate, episodes: myEpisodes)
                    case .week:
                        WeekCalendarView(selectedDate: $selectedDate, episodes: myEpisodes)
                    case .list:
                        EpisodeListView(episodes: myEpisodes.filter { $0.airDate != nil && $0.airDate! >= Date() })
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

struct EpisodeListView: View {
    let episodes: [Episode]
    
    var body: some View {
        if episodes.isEmpty {
            ContentUnavailableView("Aucun épisode", systemImage: "calendar.badge.exclamationmark", description: Text("Rien de prévu pour le moment."))
                .padding(.top, 50)
        } else {
            List(episodes) { episode in
                HStack(spacing: 12) {
                    PosterImage(urlString: episode.show?.imageUrl, width: 60, height: 90)
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(episode.show?.name ?? "Série Inconnue")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("\(episode.season)x\(String(format: "%02d", episode.number)) - \(episode.title)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        if let date = episode.airDate {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.accentPurple)
                        }
                    }
                }
                .listRowBackground(Color.appBackground)
                .listRowSeparatorTint(Color.white.opacity(0.1))
            }
            .listStyle(.plain)
            .background(Color.appBackground)
        }
    }
}
