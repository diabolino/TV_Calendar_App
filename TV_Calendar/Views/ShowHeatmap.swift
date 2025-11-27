//
//  ShowHeatmap.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 27/11/2025.
//


import SwiftUI

struct ShowHeatmap: View {
    let show: TVShow
    let episodes: [Episode]
    
    // État pour le chargement manuel
    @State private var isLoadingBanner = false
    
    // Affiche uniquement la saison "active"
    var episodesToDisplay: [Episode] {
        let sortedAll = episodes.sorted {
            if $0.season == $1.season { return $0.number < $1.number }
            return $0.season < $1.season
        }
        
        if let firstUnwatched = sortedAll.first(where: { !$0.isWatched }) {
            return sortedAll.filter { $0.season == firstUnwatched.season }
        }
        
        if let lastEpisode = sortedAll.last {
            return sortedAll.filter { $0.season == lastEpisode.season }
        }
        return []
    }
    
    var currentSeasonNumber: Int {
        episodesToDisplay.first?.season ?? 1
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 24, maximum: 30), spacing: 4)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            
            // --- BANNIÈRE ---
            ZStack(alignment: .center) {
                if let banner = show.bannerUrl {
                    PosterImage(urlString: banner, width: nil, height: 70)
                        .overlay(Color.black.opacity(0.1))
                } else {
                    ZStack {
                        Color.accentPurple.opacity(0.3)
                        Text(show.name).font(.headline).bold().foregroundColor(.white)
                    }
                    .frame(height: 70)
                }
                
                // Badges (Overlay)
                VStack {
                    HStack {
                        Spacer()
                        // Badge Saison
                        Text("SAISON \(currentSeasonNumber)")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white.opacity(0.9))
                            .cornerRadius(3)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        // Badge Qualité
                        Text(show.quality.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(qualityColor(show.quality))
                            .foregroundColor(.white)
                            .cornerRadius(3)
                    }
                }
                .padding(6)
            }
            .clipped()
            
            // --- GRILLE ÉPISODES ---
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(episodesToDisplay) { ep in
                    HeatmapCell(episode: ep) {
                        handleTap(on: ep)
                    }
                }
            }
            .padding(8)
            .background(Color.cardBackground)
            
            // --- BOUTON DE CHECK BANNIÈRE (Version 1.0 Finale) ---
            if show.bannerUrl == nil {
                // Cas 1 : Pas de bannière -> Bouton bien visible
                Button(action: refreshBanner) {
                    HStack {
                        if isLoadingBanner {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Rechercher une bannière sur TVMaze")
                        }
                    }
                    .font(.caption).bold()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentPurple.opacity(0.3))
                }
            } else {
                // Cas 2 : Bannière existe -> Menu contextuel discret (Appui long pour refresh)
                // Ou petit bouton discret en bas si on veut le voir
                /* Si vous voulez un bouton discret même quand y'a une image, décommentez ceci :
                Button(action: refreshBanner) {
                    Text("Actualiser l'image")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.vertical, 4)
                }
                */
            }
        }
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        // Petit menu contextuel pour forcer le refresh même si l'image est là
        .contextMenu {
            Button {
                refreshBanner()
            } label: {
                Label("Forcer la mise à jour image", systemImage: "arrow.clockwise")
            }
        }
    }
    
    // --- ACTIONS ---
    
    func refreshBanner() {
        isLoadingBanner = true
        Task {
            // On appelle l'API pour récupérer les images fraiches
            if let details = try? await TVMazeService.shared.fetchShowWithImages(id: show.tvmazeId) {
                // On cherche la bannière
                if let newBanner = TVMazeService.shared.extractBanner(from: details) {
                    // On met à jour l'objet SwiftData (l'UI se mettra à jour toute seule)
                    show.bannerUrl = newBanner
                    print("✅ Bannière trouvée : \(newBanner)")
                } else {
                    print("⚠️ Toujours pas de bannière sur TVMaze")
                }
            }
            // Petite pause pour voir le chargement
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoadingBanner = false
        }
    }
    
    func handleTap(on targetEpisode: Episode) {
        withAnimation(.snappy) {
            if !targetEpisode.isWatched {
                for ep in episodesToDisplay {
                    if ep.number <= targetEpisode.number {
                        if !ep.isWatched {
                            ep.isWatched = true
                            ep.watchedDate = Date()
                        }
                    }
                }
            } else {
                targetEpisode.isWatched = false
                targetEpisode.watchedDate = nil
            }
        }
    }
    
    func qualityColor(_ q: VideoQuality) -> Color {
        switch q {
        case .sd: return .orange; case .hd720: return .blue; case .hd1080: return .green; case .uhd4k: return .purple
        }
    }
}

struct HeatmapCell: View {
    let episode: Episode
    let action: () -> Void
    
    var statusColor: Color {
        if episode.isWatched { return .green }
        if let date = episode.airDate, date <= Date() { return .orange }
        return .gray.opacity(0.3)
    }
    
    var body: some View {
        Rectangle()
            .fill(statusColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Text("\(episode.number)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            )
            .cornerRadius(2)
            .onTapGesture {
                action()
            }
    }
}
