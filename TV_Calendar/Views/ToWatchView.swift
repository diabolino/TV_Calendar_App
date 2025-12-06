//
//  ToWatchView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData

// Enum pour les options de tri spécifiques à cette vue
enum ToWatchSortOption: String, CaseIterable {
    case dateAsc = "Date (Urgent)" // Prochain épisode le plus vieux (retard) ou proche
    case dateDesc = "Date (Récent)"
    case nameAZ = "Nom (A-Z)"
    case progress = "Progression" // Ceux presque finis en premier
}

struct ToWatchView: View {
    @Query var shows: [TVShow]
    
    // État pour le mode d'affichage
    @State private var displayMode: ToWatchMode = .list
    
    // NOUVEAU : État pour le tri
    @State private var sortOption: ToWatchSortOption = .dateAsc
    
    enum ToWatchMode: String, CaseIterable {
        case list = "Liste"
        case heatmap = "Heatmap"
    }
    
    // LOGIQUE DE TRI ET FILTRAGE
    var sortedAndFilteredShows: [TVShow] {
        // 1. Filtrer (Garder uniquement ce qui est à voir et sorti)
        let activeShows = shows.filter { hasReleasedUnwatchedEpisodes($0) }
        
        // 2. Trier
        switch sortOption {
        case .nameAZ:
            return activeShows.sorted { $0.name < $1.name }
            
        case .dateAsc: // Du plus vieux retard au plus récent
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // --- HEADER ---
                HStack {
                    Text("À regarder")
                        .font(.largeTitle).bold()
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // GROUPE : BOUTON TRI + SÉLECTEUR
                    HStack(spacing: 12) {
                        
                        // 1. BOUTON TRI (Menu)
                        Menu {
                            Picker("Tri", selection: $sortOption) {
                                ForEach(ToWatchSortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentPurple)
                        }
                        
                        // 2. SÉLECTEUR VUE (Liste / Heatmap)
                        HStack(spacing: 0) {
                            ForEach(ToWatchMode.allCases, id: \.self) { mode in
                                Button(action: { withAnimation { displayMode = mode } }) {
                                    Text(mode.rawValue)
                                        .font(.caption).bold()
                                        .padding(.horizontal, 10)
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
                }
                .padding()
                .background(Color.appBackground)
                
                // --- CONTENU ---
                ScrollView {
                    LazyVStack(spacing: 16) {
                        
                        let displayShows = sortedAndFilteredShows
                        
                        if displayShows.isEmpty {
                            ContentUnavailableView("Vous êtes à jour !", systemImage: "checkmark.circle", description: Text("Aucun épisode en retard. Les futurs épisodes apparaîtront ici le jour de leur sortie."))
                                .padding(.top, 50)
                        } else {
                            
                            ForEach(displayShows) { show in
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
                                        // On passe la liste des épisodes (optionnels gérés)
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
    
    // --- HELPER FUNCTIONS ---
    
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

// (La struct ToWatchCard reste inchangée en bas du fichier)
struct ToWatchCard: View {
    let showName: String
    let imageUrl: String?
    let episode: Episode
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
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
                    withAnimation {
                        episode.isWatched = true
                        episode.watchedDate = Date()
                    }
                }) {
                    HStack { Image(systemName: "checkmark"); Text("Marquer comme vu") }
                        .font(.caption).bold().frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.accentPurple.opacity(0.2)).foregroundColor(Color.accentPurple)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
