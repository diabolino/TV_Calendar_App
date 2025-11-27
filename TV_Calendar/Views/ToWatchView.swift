//
//  ToWatchView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData

struct ToWatchView: View {
    @Query var shows: [TVShow]
    
    // État pour le mode d'affichage (Liste ou Heatmap)
    @State private var displayMode: ToWatchMode = .list
    
    enum ToWatchMode: String, CaseIterable {
        case list = "Liste"
        case heatmap = "Heatmap"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // --- HEADER AVEC SÉLECTEUR ---
                HStack {
                    Text("À regarder")
                        .font(.largeTitle).bold()
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Sélecteur Custom (Style bouton)
                    HStack(spacing: 0) {
                        ForEach(ToWatchMode.allCases, id: \.self) { mode in
                            Button(action: { withAnimation { displayMode = mode } }) {
                                Text(mode.rawValue)
                                    .font(.caption).bold()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(displayMode == mode ? Color.accentPurple : Color.clear)
                                    .foregroundColor(displayMode == mode ? .white : .gray)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(2)
                    .background(Color.cardBackground)
                    .cornerRadius(6)
                }
                .padding()
                .background(Color.appBackground)
                
                // --- CONTENU ---
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if shows.isEmpty {
                            ContentUnavailableView("Aucune série", systemImage: "tv.slash", description: Text("Ajoutez des séries pour voir votre progression."))
                                .padding(.top, 50)
                        } else {
                            // On filtre les séries actives
                            let activeShows = shows.filter { hasNextEpisode($0) }
                            
                            ForEach(activeShows) { show in
                                if displayMode == .list {
                                    // VUE LISTE (Votre carte détaillée actuelle)
                                    if let nextEp = nextEpisode(for: show) {
                                        NavigationLink(destination: ShowDetailView(show: show)) {
                                            ToWatchCard(
                                                showName: show.name,
                                                imageUrl: show.imageUrl,
                                                episode: nextEp,
                                                progress: progress(for: show)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } else {
                                    // VUE HEATMAP (La nouvelle vue compacte)
                                    NavigationLink(destination: ShowDetailView(show: show)) {
                                        // CORRECTION : show.episodes ?? []
                                        ShowHeatmap(show: show, episodes: show.episodes ?? [])
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color.appBackground)
            .navigationTitle("") // On cache le titre natif car on a fait le nôtre
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
    }
    
    // Helpers
    func hasNextEpisode(_ show: TVShow) -> Bool {
            // CORRECTION : ?? []
            (show.episodes ?? []).contains(where: { !$0.isWatched && $0.airDate != nil })
    }
    
    func nextEpisode(for show: TVShow) -> Episode? {
        // CORRECTION : ?? []
        (show.episodes ?? []).sorted { $0.season == $1.season ? $0.number < $1.number : $0.season < $1.season }
            .first(where: { !$0.isWatched && $0.airDate != nil })
    }
    
    func progress(for show: TVShow) -> Double {
        let safeEpisodes = show.episodes ?? [] // CORRECTION
        let total = Double(safeEpisodes.count)
        guard total > 0 else { return 0 }
        let watched = Double(safeEpisodes.filter { $0.isWatched }.count)
        return watched / total
    }
}


// --- CARTE CORRIGÉE (SIMPLIFIÉE) ---
struct ToWatchCard: View {
    let showName: String
    let imageUrl: String? // On passe juste le String, c'est plus stable
    let episode: Episode
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                
                PosterImage(urlString: imageUrl, width: 80, height: 120)
                .cornerRadius(8)
                
                // INFOS
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(showName)
                            .font(.title3).bold()
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                    }
                    
                    Text("Prochain épisode")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("\(episode.season)x\(String(format: "%02d", episode.number)) - \(episode.title)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    if let date = episode.airDate {
                        Text("Sortie : \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(16)
            
            // BARRE DE PROGRESSION
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.1))
                        Rectangle()
                            .fill(LinearGradient(colors: [Color.accentPurple, Color.accentPink], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 4)
                
                // Bouton Marquer Vu
                Button(action: {
                    withAnimation {
                        // REMPLACER : episode.isWatched = true
                        // PAR :
                        episode.isWatched = true
                        episode.watchedDate = Date() // <--- AJOUT DATE
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Marquer comme vu")
                    }
                    .font(.caption).bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentPurple.opacity(0.2))
                    .foregroundColor(Color.accentPurple)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
