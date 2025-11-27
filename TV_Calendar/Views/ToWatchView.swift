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
                    
                    // Sélecteur Custom
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
                        
                        // 1. ON FILTRE LES SÉRIES ICI
                        let activeShows = shows.filter { hasReleasedUnwatchedEpisodes($0) }
                        
                        if activeShows.isEmpty {
                            ContentUnavailableView("Vous êtes à jour !", systemImage: "checkmark.circle", description: Text("Aucun épisode en retard. Les futurs épisodes apparaîtront ici le jour de leur sortie."))
                                .padding(.top, 50)
                        } else {
                            
                            ForEach(activeShows) { show in
                                if displayMode == .list {
                                    // VUE LISTE
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
                                    // VUE HEATMAP
                                    NavigationLink(destination: ShowDetailView(show: show)) {
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
            .navigationTitle("")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
    }
    
    // --- HELPER DE FILTRAGE AMÉLIORÉ ---
    func hasReleasedUnwatchedEpisodes(_ show: TVShow) -> Bool {
        let safeEpisodes = show.episodes ?? []
        let now = Date()
        
        // On garde la série SI il existe au moins un épisode qui :
        // 1. N'est pas vu (!isWatched)
        // 2. A une date de sortie (airDate != nil)
        // 3. Est déjà sorti ou sort aujourd'hui (airDate <= now)
        return safeEpisodes.contains { episode in
            !episode.isWatched &&
            (episode.airDate ?? Date.distantFuture) <= now
        }
    }
    
    func nextEpisode(for show: TVShow) -> Episode? {
        let safeEpisodes = show.episodes ?? []
        // On cherche le prochain épisode À VOIR et DÉJÀ SORTI
        return safeEpisodes.sorted {
            $0.season == $1.season ? $0.number < $1.number : $0.season < $1.season
        }
        .first(where: { !$0.isWatched && ($0.airDate ?? Date.distantFuture) <= Date() })
    }
    
    func progress(for show: TVShow) -> Double {
        let safeEpisodes = show.episodes ?? []
        // Pour la barre de progression, on ne compte que les épisodes DÉJÀ SORTIS
        // Sinon une série avec 20 épisodes futurs donnerait l'impression d'être à 0% alors qu'on est à jour
        let releasedEpisodes = safeEpisodes.filter { ($0.airDate ?? Date.distantFuture) <= Date() }
        
        let total = Double(releasedEpisodes.count)
        guard total > 0 else { return 0 }
        
        let watched = Double(releasedEpisodes.filter { $0.isWatched }.count)
        return watched / total
    }
}

// (La struct ToWatchCard reste inchangée en bas)


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
