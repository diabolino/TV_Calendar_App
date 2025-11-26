import SwiftUI
import SwiftData

struct ToWatchView: View {
    @Query var shows: [TVShow]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(shows) { show in
                        if let nextEp = nextEpisode(for: show) {
                            ToWatchCard(show: show, episode: nextEp, progress: progress(for: show))
                        }
                    }
                }
                .padding()
            }
            .background(Color.appBackground) // Notre fond sombre
            .navigationTitle("À regarder")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    // Trouve le premier épisode non vu
    func nextEpisode(for show: TVShow) -> Episode? {
        show.episodes.sorted {
            $0.season == $1.season ? $0.number < $1.number : $0.season < $1.season
        }.first(where: { !$0.isWatched && $0.airDate != nil })
    }
    
    // Calcule le % de progression (Episodes vus / Total)
    func progress(for show: TVShow) -> Double {
        let total = Double(show.episodes.count)
        guard total > 0 else { return 0 }
        let watched = Double(show.episodes.filter { $0.isWatched }.count)
        return watched / total
    }
}

struct ToWatchCard: View {
    let show: TVShow
    let episode: Episode
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Haut de la carte
            HStack(alignment: .top, spacing: 12) {
                // Image Série
                AsyncImage(url: URL(string: show.imageUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: { Color.gray }
                .frame(width: 80, height: 120)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(show.name)
                            .font(.title3).bold()
                            .foregroundColor(.white)
                        Spacer()
                        // Badge qualité (Fake pour l'instant)
                        Text("1080p")
                            .font(.caption2).bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                    
                    Text("Prochain épisode non vu")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("\(episode.season)x\(String(format: "%02d", episode.number)) - \(episode.title)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let date = episode.airDate {
                        Text("Sortie : \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(16)
            
            // Barre de progression
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                        
                        Rectangle()
                            .fill(LinearGradient(colors: [Color.accentPurple, Color.accentPink], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 4)
                
                // Bouton "Marquer comme vu"
                Button(action: {
                    withAnimation { episode.isWatched = true }
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
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}