//
//  ToWatchView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData

// --- VIEW MODEL ---
@Observable
class ToWatchViewModel {
    // États de l'interface
    // MODIFICATION ICI : .heatmap par défaut au lieu de .list
    var displayMode: ToWatchMode = .heatmap
    var sortOption: ToWatchSortOption = .dateAsc
    
    enum ToWatchMode: String, CaseIterable {
        case list = "Liste"
        case heatmap = "Heatmap"
    }
    
    // Logique de Filtrage et Tri
    func getSortedShows(from shows: [TVShow]) -> [TVShow] {
        
        // 1. Filtrer (Garder uniquement ce qui est à voir et sorti)
        let activeShows = shows.filter { hasReleasedUnwatchedEpisodes($0) }
        
        // 2. Trier
        switch sortOption {
        case .nameAZ:
            return activeShows.sorted { $0.name < $1.name }
            
        case .dateAsc:
            return activeShows.sorted {
                let date1 = nextEpisode(for: $0)?.airDate ?? Date.distantFuture
                let date2 = nextEpisode(for: $1)?.airDate ?? Date.distantFuture
                return date1 < date2
            }
            
        case .dateDesc:
            return activeShows.sorted {
                let date1 = nextEpisode(for: $0)?.airDate ?? Date.distantPast
                let date2 = nextEpisode(for: $1)?.airDate ?? Date.distantPast
                return date1 > date2
            }
            
        case .progress:
            return activeShows.sorted { progress(for: $0) > progress(for: $1) }
        }
    }
    
    // --- HELPERS MÉTIER ---
    
    func hasReleasedUnwatchedEpisodes(_ show: TVShow) -> Bool {
        let safeEpisodes = show.episodes ?? []
        let now = Date()
        return safeEpisodes.contains { episode in
            !episode.isWatched && (episode.airDate ?? Date.distantFuture) <= now
        }
    }
    
    func nextEpisode(for show: TVShow) -> Episode? {
        let safeEpisodes = show.episodes ?? []
        return safeEpisodes.sorted {
            $0.season == $1.season ? $0.number < $1.number : $0.season < $1.season
        }
        .first(where: { !$0.isWatched && ($0.airDate ?? Date.distantFuture) <= Date() })
    }
    
    func progress(for show: TVShow) -> Double {
        let safeEpisodes = show.episodes ?? []
        let releasedEpisodes = safeEpisodes.filter { ($0.airDate ?? Date.distantFuture) <= Date() }
        let total = Double(releasedEpisodes.count)
        guard total > 0 else { return 0 }
        let watched = Double(releasedEpisodes.filter { $0.isWatched }.count)
        return watched / total
    }
}

// Enum pour les options de tri
enum ToWatchSortOption: String, CaseIterable {
    case dateAsc = "Date (Urgent)"
    case dateDesc = "Date (Récent)"
    case nameAZ = "Nom (A-Z)"
    case progress = "Progression"
}

// --- VUE PRINCIPALE ---
struct ToWatchView: View {
    let profileId: String?
    
    @Query var allShows: [TVShow]
    @State private var viewModel = ToWatchViewModel()
    
    // FILTRAGE DYNAMIQUE
    var myShows: [TVShow] {
        guard let pid = profileId, let uuid = UUID(uuidString: pid) else { return [] }
        return allShows.filter { $0.profileId == uuid }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // --- HEADER ---
                HStack {
                    Text("À regarder")
                        .font(.largeTitle).bold()
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // CONTROLES
                    HStack(spacing: 12) {
                        Menu {
                            Picker("Tri", selection: $viewModel.sortOption) {
                                ForEach(ToWatchSortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentPurple)
                        }
                        
                        HStack(spacing: 0) {
                            ForEach(ToWatchViewModel.ToWatchMode.allCases, id: \.self) { mode in
                                Button(action: { withAnimation { viewModel.displayMode = mode } }) {
                                    Text(mode.rawValue)
                                        .font(.caption).bold()
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(viewModel.displayMode == mode ? Color.accentPurple : Color.clear)
                                        .foregroundColor(viewModel.displayMode == mode ? .white : .gray)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(2)
                        .background(Color.cardBackground)
                        .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color.appBackground)
                
                // --- CONTENU ---
                ScrollView {
                    let displayShows = viewModel.getSortedShows(from: myShows)
                    
                    if myShows.isEmpty {
                        // CAS 1 : Zéro série
                        ContentUnavailableView("Bibliothèque vide", systemImage: "plus.circle", description: Text("Ajoutez des séries pour voir votre progression ici."))
                            .padding(.top, 50)
                        
                    } else if displayShows.isEmpty {
                        // CAS 2 : Des séries, mais tout est vu
                        ContentUnavailableView("Vous êtes à jour !", systemImage: "checkmark.circle", description: Text("Aucun épisode en retard.\nLes futurs épisodes apparaîtront ici le jour de leur sortie."))
                            .padding(.top, 50)
                        
                    } else {
                        // CAS 3 : LISTE DES ÉPISODES
                        LazyVStack(spacing: 16) {
                            ForEach(displayShows) { show in
                                
                                // === LOGIQUE DE SÉPARATION POSTER / BANNIERE ===
                                
                                if viewModel.displayMode == .list {
                                    // MODE LISTE : On utilise ToWatchCard
                                    if let nextEp = viewModel.nextEpisode(for: show) {
                                        NavigationLink(destination: ShowDetailView(show: show)) {
                                            ToWatchCard(
                                                showName: show.name,
                                                imageUrl: show.imageUrl, // <--- POSTER (Vertical)
                                                episode: nextEp,
                                                progress: viewModel.progress(for: show)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } else {
                                    // MODE HEATMAP : On utilise ShowHeatmap
                                    NavigationLink(destination: ShowDetailView(show: show)) {
                                        ShowHeatmap(show: show, episodes: show.episodes ?? [])
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("")
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
    }
}

// --- CARTE DÉTAILLÉE (Mode Liste uniquement) ---
struct ToWatchCard: View {
    let showName: String
    let imageUrl: String?
    let episode: Episode
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Poster Image (Format Portrait 2:3)
                PosterImage(urlString: imageUrl, width: 80, height: 120)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(showName).font(.title3).bold().foregroundColor(.white).lineLimit(1)
                        Spacer()
                    }
                    Text("Prochain épisode").font(.caption).foregroundColor(.orange)
                    Text("\(episode.season)x\(String(format: "%02d", episode.number)) - \(episode.title)")
                        .font(.headline).foregroundColor(.white).lineLimit(2)
                    if let date = episode.airDate {
                        Text("Sortie : \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundColor(.gray)
                    }
                }
            }
            .padding(16)
            
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.1))
                        Rectangle().fill(LinearGradient(colors: [Color.accentPurple, Color.accentPink], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * progress)
                    }
                }.frame(height: 4)
                
                Button(action: {
                    HapticManager.shared.trigger(.medium)
                    
                    // 1. Action Locale
                    withAnimation { episode.toggleWatched() }
                    
                    // 2. Action Trakt
                    if episode.isWatched {
                        print("🚀 ToWatchView: Envoi Trakt pour \(episode.title)")
                        Task {
                            await TraktService.shared.markEpisodeWatched(
                                imdbId: episode.show?.imdbId,
                                tmdbId: episode.show?.tmdbId,
                                title: episode.show?.name,
                                season: episode.season,
                                number: episode.number
                            )
                        }
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
