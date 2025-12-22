//
//  SearchView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData

// Enum pour les options de tri (Gardé au cas où)
enum SortOption: String, CaseIterable {
    case nameAZ = "Nom (A-Z)"
    case nameZA = "Nom (Z-A)"
    case status = "Par Statut"
}

// Enum pour le type de recherche (Nouveau)
enum SearchScope: String, CaseIterable {
    case shows = "Séries"
    case movies = "Films"
}

struct SearchView: View {
    // --- NOUVEAU : ID PROFIL ---
    let profileId: String?
    
    @State private var searchText = ""
    @State private var searchScope: SearchScope = .shows
    
    // Résultats
    @State private var showResults: [TVMazeService.ShowDTO] = []
    @State private var movieResults: [TMDBService.TMDBMovieDetails] = [] // Nouveau
    
    // État du tri (pour la vue locale si besoin)
    @State private var sortOption: SortOption = .nameAZ
    
    // Réglage par défaut (stocké)
    @AppStorage("defaultQuality") private var defaultQuality: VideoQuality = .hd1080
    
    @FocusState private var isSearchFocused: Bool
    
    @State private var selectedShowToAdd: TVMazeService.ShowDTO?
    @State private var showQualitySelection = false
    @State private var isSearching = false
    
    @Environment(\.modelContext) private var modelContext
    @Query var libraryShows: [TVShow]
    @Query var libraryMovies: [Movie] // Nouveau
    
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
    
    // LOGIQUE DE TRI DYNAMIQUE (Pour l'affichage bibliothèque si vide)
    var sortedLibraryShows: [TVShow] {
        // Filtre par profil d'abord
        guard let pid = profileId, let uuid = UUID(uuidString: pid) else { return [] }
        let myShows = libraryShows.filter { $0.profileId == uuid }
        
        switch sortOption {
        case .nameAZ: return myShows.sorted { $0.name < $1.name }
        case .nameZA: return myShows.sorted { $0.name > $1.name }
        case .status:
            return myShows.sorted {
                if ($0.status ?? "") == ($1.status ?? "") { return $0.name < $1.name }
                return ($0.status ?? "") > ($1.status ?? "")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // --- BARRE DE RECHERCHE + SCOPE ---
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.gray)
                            TextField("Rechercher...", text: $searchText)
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .focused($isSearchFocused)
                                .submitLabel(.search)
                                .onSubmit { performSearch(query: searchText); isSearchFocused = false }
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = ""; showResults = []; movieResults = []; isSearchFocused = false }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                        }
                        .padding().background(Color.cardBackground).cornerRadius(12)
                        
                        // SÉLECTEUR TYPE
                        Picker("Type", selection: $searchScope) {
                            ForEach(SearchScope.allCases, id: \.self) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: searchScope) { _, _ in
                            if !searchText.isEmpty { performSearch(query: searchText) }
                        }
                    }
                    .padding(.horizontal)
                    
                    // --- CONTENU ---
                    if searchText.isEmpty {
                        // VUE BIBLIOTHÈQUE (Vide ou liste rapide)
                        if !sortedLibraryShows.isEmpty && searchScope == .shows {
                            HStack {
                                Text("Ma Bibliothèque (\(sortedLibraryShows.count))")
                                    .font(.title2).bold().foregroundColor(.white)
                                Spacer()
                                // Menu de tri (Optionnel ici)
                                Menu {
                                    Picker("Tri", selection: $sortOption) {
                                        ForEach(SortOption.allCases, id: \.self) { option in
                                            Text(option.rawValue).tag(option)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                                        .foregroundColor(.accentPurple)
                                }
                            }
                            .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(sortedLibraryShows) { show in
                                    NavigationLink(destination: ShowDetailView(show: show)) {
                                        ShowGridItem(
                                            title: show.name,
                                            imageUrl: show.imageUrl,
                                            quality: show.quality,
                                            isAdded: true,
                                            progress: calculateProgress(for: show),
                                            nextEpisodeCode: getNextEpisodeCode(for: show),
                                            onQuickAdd: nil,
                                            onManualAdd: nil
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) { deleteShow(show) } label: { Label("Supprimer", systemImage: "trash") }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            ContentUnavailableView("Recherche", systemImage: "magnifyingglass", description: Text("Recherchez des séries ou des films pour les ajouter."))
                                .padding(.top, 50)
                        }
                    } else {
                        // VUE RÉSULTATS
                        if isSearching {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 50)
                        } else {
                            Text("Résultats").font(.title2).bold().foregroundColor(.white).padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                if searchScope == .shows {
                                    ForEach(showResults, id: \.id) { show in
                                        let qualities = getQualitiesFor(showId: show.id)
                                        let isAdded = !qualities.isEmpty
                                        
                                        ShowGridItem(
                                            title: show.name,
                                            imageUrl: show.image?.medium,
                                            quality: nil,
                                            isAdded: isAdded,
                                            progress: nil,
                                            nextEpisodeCode: nil,
                                            onQuickAdd: {
                                                isSearchFocused = false
                                                Task { await LibraryManager.shared.addShow(dto: show, quality: defaultQuality, profileId: profileId, context: modelContext, existingShows: libraryShows) }
                                            },
                                            onManualAdd: {
                                                isSearchFocused = false
                                                selectedShowToAdd = show
                                                showQualitySelection = true
                                            }
                                        )
                                    }
                                } else {
                                    // FILMS
                                    ForEach(movieResults, id: \.id) { movie in
                                        let isAdded = isMovieAdded(id: movie.id)
                                        ShowGridItem(
                                            title: movie.title,
                                            imageUrl: TMDBService.imageURL(path: movie.poster_path, width: "w342"),
                                            quality: nil,
                                            isAdded: isAdded,
                                            progress: nil,
                                            nextEpisodeCode: nil,
                                            onQuickAdd: {
                                                isSearchFocused = false
                                                Task { await LibraryManager.shared.addMovie(tmdbId: movie.id, profileId: profileId, context: modelContext, existingMovies: libraryMovies) }
                                            },
                                            onManualAdd: nil
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color.appBackground)
            .navigationTitle("")
            #if os(iOS)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            
            .confirmationDialog("Choisir la qualité", isPresented: $showQualitySelection, titleVisibility: .visible) {
                ForEach(VideoQuality.allCases, id: \.self) { quality in
                    Button(quality.rawValue) {
                        if let show = selectedShowToAdd {
                            Task { await LibraryManager.shared.addShow(dto: show, quality: quality, profileId: profileId, context: modelContext, existingShows: libraryShows) }
                        }
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: { Text("Dans quelle qualité voulez-vous ajouter cette série ?") }
        }
    }
    
    // --- FONCTIONS ---
    func calculateProgress(for show: TVShow) -> Double {
        let safeEpisodes = show.episodes ?? []
        let total = Double(safeEpisodes.count)
        guard total > 0 else { return 0 }
        let watched = Double(safeEpisodes.filter { $0.isWatched }.count)
        return watched / total
    }
    
    func getNextEpisodeCode(for show: TVShow) -> String? {
        let safeEpisodes = show.episodes ?? []
        let nextEp = safeEpisodes.sorted {
            $0.season == $1.season ? $0.number < $1.number : $0.season < $1.season
        }.first(where: { !$0.isWatched && $0.airDate != nil })
        if let ep = nextEp { return "S\(ep.season)E\(String(format: "%02d", ep.number))" }
        return nil
    }

    func getQualitiesFor(showId: Int) -> [VideoQuality] {
        guard let pid = profileId, let uuid = UUID(uuidString: pid) else { return [] }
        return libraryShows.filter { $0.tvmazeId == showId && $0.profileId == uuid }.map { $0.quality }
    }
    
    func isMovieAdded(id: Int) -> Bool {
        guard let pid = profileId, let uuid = UUID(uuidString: pid) else { return false }
        return libraryMovies.contains { $0.tmdbId == id && $0.profileId == uuid }
    }
    
    func performSearch(query: String) {
        guard !query.isEmpty else { showResults = []; movieResults = []; return }
        isSearching = true
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if searchScope == .shows {
                if let results = try? await TVMazeService.shared.searchShow(query: query) {
                    await MainActor.run { showResults = results; isSearching = false }
                }
            } else {
                if let results = try? await TMDBService.shared.searchMovie(query: query) {
                    await MainActor.run { movieResults = results; isSearching = false }
                }
            }
        }
    }
    
    func deleteShow(_ show: TVShow) {
        withAnimation { LibraryManager.shared.deleteShow(show, context: modelContext) }
    }
    
    // --- CARTE GRID ITEM (COMPLET) ---
    struct ShowGridItem: View {
        let title: String
        let imageUrl: String?
        let quality: VideoQuality?
        let isAdded: Bool
        let progress: Double?
        let nextEpisodeCode: String?
        
        let onQuickAdd: (() -> Void)?
        let onManualAdd: (() -> Void)?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    PosterImage(urlString: imageUrl, width: nil, height: nil)
                        .aspectRatio(2/3, contentMode: .fill)
                        .frame(maxWidth: .infinity).clipped()
                    
                    // Badge prochain épisode
                    if let code = nextEpisodeCode {
                        Text(code)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .background(Color.cyan).foregroundColor(.white).cornerRadius(4)
                            .padding(6)
                    }
                    
                    // Check si ajouté (dans la recherche)
                    if isAdded && onQuickAdd != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .frame(maxWidth: .infinity, alignment: .topTrailing)
                            .padding(4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption).bold().foregroundColor(.white).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Barre de progression (Bibliothèque)
                    if let prog = progress {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.2))
                                Capsule().fill(LinearGradient(colors: [Color.accentPurple, Color.accentPink], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * prog)
                            }
                        }.frame(height: 4)
                    }
                    
                    HStack {
                        // MODE RECHERCHE
                        if let onQuick = onQuickAdd {
                            if !isAdded {
                                Text("AJOUTER")
                                    .font(.system(size: 10, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color.accentPurple)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                    .onTapGesture {
                                        HapticManager.shared.trigger(.light)
                                        onQuick()
                                    }
                                    .onLongPressGesture(minimumDuration: 0.5) {
                                        if let onManual = onManualAdd {
                                            HapticManager.shared.trigger(.heavy)
                                            onManual()
                                        }
                                    }
                            }
                        }
                        // MODE BIBLIOTHEQUE
                        else {
                            if let q = quality {
                                Text(q.rawValue).font(.system(size: 9, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(qualityColor(q).opacity(0.2)).foregroundColor(qualityColor(q)).cornerRadius(3).overlay(RoundedRectangle(cornerRadius: 3).stroke(qualityColor(q), lineWidth: 1))
                            }
                            Spacer()
                            if progress == 1.0 { Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption) }
                        }
                    }
                }
                .padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Color.cardBackground)
            }
            .cornerRadius(8).shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        
        func qualityColor(_ q: VideoQuality) -> Color {
            switch q { case .sd: return .orange; case .hd720: return .blue; case .hd1080: return .green; case .uhd4k: return .purple }
        }
    }
}
