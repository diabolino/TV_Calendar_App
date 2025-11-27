import SwiftUI

struct ShowHeatmap: View {
    let show: TVShow
    let episodes: [Episode]
    
    // On filtre pour n'avoir que la saison en cours ou pertinente
    var currentSeasonEpisodes: [Episode] {
        // On cherche la première saison qui a des épisodes non vus
        let firstUnwatched = episodes.first(where: { !$0.isWatched })
        let seasonToShow = firstUnwatched?.season ?? (episodes.last?.season ?? 1)
        return episodes.filter { $0.season == seasonToShow }.sorted { $0.number < $1.number }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Image Série (Format Bannière)
            ZStack(alignment: .bottomLeading) {
                PosterImage(urlString: show.imageUrl, width: 100, height: 50)
                    .overlay(Color.black.opacity(0.3))
                    .cornerRadius(4)
                
                Text(show.name)
                    .font(.caption2).bold().foregroundColor(.white)
                    .padding(4)
                    .lineLimit(1)
            }
            
            // Badges Qualité / Saison
            VStack(alignment: .leading, spacing: 4) {
                // Qualité
                Text(show.quality.rawValue)
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(qualityColor(show.quality).opacity(0.2))
                    .foregroundColor(qualityColor(show.quality))
                    .cornerRadius(2)
                
                // Saison actuelle
                if let first = currentSeasonEpisodes.first {
                    Text("S\(first.season)")
                        .font(.caption2).bold().foregroundColor(.gray)
                }
            }
            
            // La Grille Heatmap (Scrollable horizontalement)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(currentSeasonEpisodes) { ep in
                        EpisodeHeatmapCell(episode: ep)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(8)
        .background(Color.cardBackground)
        .cornerRadius(8)
        
        // Barre de progression globale en bas
        .overlay(
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geo.size.width * progress(for: show), height: 2)
            },
            alignment: .bottomLeading
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    func progress(for show: TVShow) -> Double {
        let total = Double(show.episodes.count); guard total > 0 else { return 0 }
        let watched = Double(show.episodes.filter { $0.isWatched }.count)
        return watched / total
    }
    
    func qualityColor(_ q: VideoQuality) -> Color {
        switch q {
        case .sd: return .orange; case .hd720: return .blue; case .hd1080: return .green; case .uhd4k: return .purple
        }
    }
}

struct EpisodeHeatmapCell: View {
    let episode: Episode
    
    var color: Color {
        if episode.isWatched { return .green } // Vu
        if let airDate = episode.airDate, airDate <= Date() { return .orange } // Sorti mais pas vu
        return .gray.opacity(0.3) // Futur
    }
    
    var body: some View {
        Text("\(episode.number)")
            .font(.system(size: 9, weight: .bold))
            .frame(width: 20, height: 20)
            .background(color)
            .foregroundColor(.white) // Texte blanc pour lisibilité
            .cornerRadius(2)
    }
}