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
                    
                    // --- HEATMAP (Version simplifiée : Activité récente) ---
                    VStack(alignment: .leading) {
                        Text("Activité récente")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            ForEach(0..<7) { day in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentPurple.opacity(Double.random(in: 0.1...0.8))) // Fake data pour l'instant
                                    .frame(height: 30)
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
                        
                        ForEach(upcomingEpisodes.prefix(3)) { ep in
                            HStack {
                                AsyncImage(url: URL(string: ep.show?.imageUrl ?? "")) { img in
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: { Color.gray }
                                .frame(width: 50, height: 70)
                                .cornerRadius(6)
                                
                                VStack(alignment: .leading) {
                                    Text(ep.show?.name ?? "")
                                        .font(.caption).bold().foregroundColor(.secondary)
                                    Text(ep.title)
                                        .font(.body).foregroundColor(.white).lineLimit(1)
                                    Text(ep.airDate?.formatted(date: .abbreviated, time: .omitted) ?? "")
                                        .font(.caption).foregroundColor(.blue)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.cardBackground)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Tableau de bord")
            .toolbarColorScheme(.dark, for: .navigationBar)
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