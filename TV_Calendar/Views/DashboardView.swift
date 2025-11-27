//
//  DashboardView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//


import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query var episodes: [Episode]
    @Query var shows: [TVShow]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // --- GRILLE DES STATS (4 cartes) ---
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
                            value: "\(shows.count)",
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
                    
                    // --- HEATMAP (Activité réelle) ---
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activité récente (7 jours)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            // On génère les 7 derniers jours
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
                    
                    // --- PROCHAINEMENT ---
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
                        } else {
                            ForEach(upcomingEpisodes.prefix(3)) { ep in
                                HStack {
                                    // --- CORRECTION ICI : PosterImage avec Cache ---
                                    PosterImage(urlString: ep.show?.imageUrl, width: 50, height: 70)
                                        .cornerRadius(6)
                                    // -----------------------------------------------
                                    
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
    
    // --- LOGIQUE DES CALCULS ---
    
    var watchedEpisodes: [Episode] { episodes.filter { $0.isWatched } }
    var watchedCount: Int { watchedEpisodes.count }
    
    var totalEpisodesCount: Int { episodes.count }
    
    var percentageSeen: Double {
        guard totalEpisodesCount > 0 else { return 0 }
        return Double(watchedCount) / Double(totalEpisodesCount) * 100
    }
    
    var toWatchCount: Int {
        // Episodes sortis (date passée) mais pas vus
        episodes.filter { !$0.isWatched && ($0.airDate ?? Date.distantFuture) < Date() }.count
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
    
    var upcomingEpisodes: [Episode] {
        episodes
            .filter { ($0.airDate ?? Date.distantPast) >= Date() }
            .sorted { ($0.airDate ?? Date.distantFuture) < ($1.airDate ?? Date.distantFuture) }
    }
    
    // --- LOGIQUE HEATMAP ---
        
    // Récupère les 7 derniers jours (d'hier à il y a 6 jours + Aujourd'hui)
    func getLast7Days() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        // On crée un tableau de 0 à 6, et on recule d'autant de jours
        return (0...6).map { i in
            calendar.date(byAdding: .day, value: -i, to: today)!
        }.reversed() // Pour avoir l'ordre chronologique (Il y a 7 jours -> Aujourd'hui)
    }
    
    // Compte les épisodes vus à cette date précise
    func getCountFor(date: Date) -> Int {
        episodes.filter { episode in
            guard let wDate = episode.watchedDate else { return false }
            return Calendar.current.isDate(wDate, inSameDayAs: date)
        }.count
    }
    
    // Génère la couleur (Plus c'est vu, plus c'est violet brillant)
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

// --- SOUS-VUE : CARTE STATISTIQUE ---
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

