import SwiftUI
import SwiftData

struct ShowDetailView: View {
    let show: TVShow
    
    // On calcule les épisodes triés par saison et numéro
    var sortedEpisodes: [Episode] {
        show.episodes.sorted {
            if $0.season == $1.season {
                return $0.number < $1.number
            }
            return $0.season < $1.season
        }
    }
    
    // On groupe les épisodes par saison pour l'affichage
    var episodesBySeason: [Int: [Episode]] {
        Dictionary(grouping: sortedEpisodes, by: { $0.season })
    }
    
    var body: some View {
        List {
            // --- EN-TÊTE : Image et Info ---
            Section {
                VStack(alignment: .center, spacing: 12) {
                    // Image Poster
                    AsyncImage(url: URL(string: show.imageUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(Text(show.name))
                    }
                    .frame(maxHeight: 300)
                    
                    // Titre et Synopsis
                    Text(show.name)
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)
                    
                    Text(show.overview)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(4) // On limite à 4 lignes (clic pour étendre possible plus tard)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear) // Rend le fond transparent pour cette section
            }
            
            // --- LISTE DES SAISONS ---
            // On parcourt les clés (saisons) triées (1, 2, 3...)
            ForEach(episodesBySeason.keys.sorted(), id: \.self) { seasonNumber in
                Section(header: Text("Saison \(seasonNumber)")) {
                    // Pour chaque saison, on affiche les épisodes
                    ForEach(episodesBySeason[seasonNumber] ?? []) { episode in
                        EpisodeRow(episode: episode)
                    }
                }
            }
        }
        .navigationTitle(show.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Une sous-vue pour afficher une ligne d'épisode proprement
struct EpisodeRow: View {
    let episode: Episode
    
    var body: some View {
        HStack {
            Text("\(episode.number).")
                .font(.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
            
            VStack(alignment: .leading) {
                Text(episode.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let date = episode.airDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Bouton Vu / Pas vu
            Button(action: {
                withAnimation {
                    episode.isWatched.toggle()
                }
            }) {
                Image(systemName: episode.isWatched ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(episode.isWatched ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(.plain) // Important pour ne pas cliquer toute la ligne
        }
        .padding(.vertical, 4)
    }
}