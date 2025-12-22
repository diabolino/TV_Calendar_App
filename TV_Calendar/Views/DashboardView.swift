//
//  DashboardView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @AppStorage("currentProfileId") private var currentProfileId: String?
    
    @Query var allEpisodes: [Episode]
    @Query var allShows: [TVShow]
    
    // FILTRAGE PAR PROFIL
    var myShows: [TVShow] {
        guard let pid = currentProfileId, let uuid = UUID(uuidString: pid) else { return [] }
        return allShows.filter { $0.profileId == uuid }
    }
    
    var myEpisodes: [Episode] {
        guard let pid = currentProfileId, let uuid = UUID(uuidString: pid) else { return [] }
        return allEpisodes.filter { $0.show?.profileId == uuid }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // --- 1. GRILLE DES STATS (4 cartes) ---
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Épisodes vus",
                            value: "\(watchedCount)",
                            subtitle: "\(Int(percentageSeen))% du total",
                            icon: "eye.fill",
                            color: Color.green
                        )
                        
                        StatCard(
                            title: "À regarder",
                            value: "\(toWatchCount)",
                            subtitle: "Épisodes passés",
                            icon: "clock.fill",
                            color: Color.orange
                        )
                        
                        StatCard(
                            title: "Séries",
                            value: "\(myShows.count)",
                            subtitle: "Dans la bibliothèque",
                            icon: "tv.fill",
                            color: Color.blue
                        )
                        
                        StatCard(
                            title: "Temps passé",
                            value: timeSpentFormatted,
                            subtitle: "Devant l'écran",
                            icon: "chart.bar.fill",
                            color: Color.accentPurple
                        )
                    }
                    
                    // --- 2. GRAPHIQUES (Si données dispos) ---
                    if !myShows.isEmpty {
                        VStack(spacing: 16) {
                            HistoryChart(episodes: myEpisodes)
                            StatusDistributionChart(shows: myShows)
                        }
                    }
                    
                    // --- 3. HEATMAP (Activité 7 jours) ---
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activité récente (7 jours)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            ForEach(getLast7Days(), id: \.self) { date in
                                VStack {
                                    // Le bloc de couleur
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(getColorForActivity(date: date))
                                        .frame(height: 40)
                                        .overlay(
                                            // Affiche le nombre si > 0
                                            Text(getCountFor(date: date) > 0 ? "\(getCountFor(date: date))" : "")
                                                .font(.caption2).bold()
                                                .foregroundColor(.white.opacity(0.8))
                                        )
                                    
                                    // Le jour (Lun, Mar...)
                                    Text(date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "fr_FR"))))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .textCase(.uppercase)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(12)
                    
                    // --- 4. PROCHAINEMENT (C'EST CE BLOC QUI MANQUAIT) ---
                    VStack(alignment: .leading) {
                        Text("Cette semaine")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        if upcomingEpisodes.isEmpty {
                            Text("Aucun épisode prévu cette semaine")
                                .font(.caption)
                                .italic()
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(8)
                        } else {
                            ForEach(upcomingEpisodes.prefix(3)) { ep in
                                HStack {
                                    PosterImage(urlString: ep.show?.imageUrl, width: 50, height: 70)
                                        .cornerRadius(6)
                                    
                                    VStack(alignment: .leading) {
                                        Text(ep.show?.name ?? "")
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.secondary)
                                        
                                        Text(ep.title)
                                            .font(.body)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Text(ep.airDate?.formatted(date: .abbreviated, time: .omitted) ?? "")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(Color.cardBackground)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Tableau de bord")
            #if os(iOS)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
        }
    }
    
    // --- LOGIQUE CALCULS ---
    
    var watchedEpisodes: [Episode] { myEpisodes.filter { $0.isWatched } }
    var watchedCount: Int { watchedEpisodes.count }
    
    var totalEpisodesCount: Int { myEpisodes.count }
    
    var percentageSeen: Double {
        guard totalEpisodesCount > 0 else { return 0 }
        return Double(watchedCount) / Double(totalEpisodesCount) * 100
    }
    
    var toWatchCount: Int {
        myEpisodes.filter { !$0.isWatched && ($0.airDate ?? Date.distantFuture) < Date() }.count
    }
    
    // NOUVEAU : Calcul des épisodes à venir (cette semaine)
    var upcomingEpisodes: [Episode] {
        myEpisodes
            .filter { ($0.airDate ?? Date.distantPast) >= Date() }
            .sorted { ($0.airDate ?? Date.distantFuture) < ($1.airDate ?? Date.distantFuture) }
    }
    
    var timeSpentFormatted: String {
        let totalMinutes = watchedEpisodes.reduce(0) { $0 + ($1.runtime ?? 0) }
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        
        if days > 0 {
            return "\(days)j \(hours)h"
        } else {
            return "\(hours)h \((totalMinutes % 1440) % 60)m"
        }
    }
    
    // --- LOGIQUE HEATMAP ---
        
    func getLast7Days() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        return (0...6).map { i in
            calendar.date(byAdding: .day, value: -i, to: today)!
        }.reversed()
    }
    
    func getCountFor(date: Date) -> Int {
        myEpisodes.filter { episode in
            guard let wDate = episode.watchedDate else { return false }
            return Calendar.current.isDate(wDate, inSameDayAs: date)
        }.count
    }
    
    func getColorForActivity(date: Date) -> Color {
        let count = getCountFor(date: date)
        
        if count == 0 {
            return Color.white.opacity(0.05) // Gris très sombre (vide)
        } else if count <= 2 {
            return Color.accentPurple.opacity(0.4) // Un peu vu
        } else if count <= 5 {
            return Color.accentPurple.opacity(0.7) // Bien vu
        } else {
            return Color.accentPurple // Binge watching !
        }
    }
}

// --- SOUS-VUE : CARTE STATISTIQUE (Restaurée) ---
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .padding(8)
                    .background(color.opacity(0.2))
                    .clipShape(Circle())
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption).bold()
                    .foregroundColor(.gray)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 4)
    }
}
