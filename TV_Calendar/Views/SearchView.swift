//
//  SearchView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//  Updated for Unified Collection View
//

import SwiftUI
import SwiftData

// Enum pour le type de recherche
enum SearchScope: String, CaseIterable {
    case shows = "Séries"
    case movies = "Films"
}

// Enum pour les options de tri
enum SortOption: String, CaseIterable {
    case nameAZ = "Nom (A-Z)"
    case nameZA = "Nom (Z-A)"
    case status = "Par Statut"
}

struct SearchView: View {
    let profileId: String?
    
    @State private var searchText = ""
    @State private var searchScope: SearchScope = .shows
    @State private var sortOption: SortOption = .nameAZ
    
    // Résultats de recherche
    @State private var showResults: [TVMazeService.ShowDTO] = []
    @State private var movieResults: [TMDBService.TMDBMovieDetails] = []
    
    // Réglage par défaut
    @AppStorage("defaultQuality") private var defaultQuality: VideoQuality = .hd1080
    
    @FocusState private var isSearchFocused: Bool
    @State private var selectedShowToAdd: TVMazeService.ShowDTO?
    @State private var showQualitySelection = false
    @State private var isSearching = false
    
    @Environment(\.modelContext) private var modelContext
    @Query var libraryShows: [TVShow]
    @Query var libraryMovies: [Movie]
    
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
    
    // --- LOGIQUE DE TRI SÉRIES ---
    var sortedLibraryShows: [TVShow] {
        guard let pid = profileId, let uuid = UUID(uuidString: pid) else { return [] }
        let myShows = libraryShows.filter { $0.profileId == uuid }
        
        switch sortOption {
        case .nameAZ: return myShows.sorted { $0.name < $1.name }
        case .nameZA: return myShows.sorted { $0.name > $1.name }
        case .status: return myShows.sorted { ($0.status ?? "") > ($1.status ?? "") }
        }
    }
    
    // --- LOGIQUE DE TRI FILMS (NOUVEAU) ---
    var sortedLibraryMovies: [Movie] {
        guard let pid = profileId, let uuid = UUID(uuidString: pid) else { return [] }
        let myMovies = libraryMovies.filter { $0.profileId == uuid }
        
        switch sortOption {
        case .nameAZ: return myMovies.sorted { $0.title < $1.title }
        case .nameZA: return myMovies.sorted { $0.title > $1.title }
        case .status: return myMovies.sorted { $0.status.rawValue > $1.status.rawValue }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // --- ZONE DE RECHERCHE ---
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
                .padding(.bottom, 10)
                
                // --- CONTENU ---
                ScrollView {
                    // MODE 1 : AFFICHAGE BIBLIOTHÈQUE (Pas de recherche)
                    if searchText.isEmpty {
                        
                        // Header "Ma Bibliothèque"
                        HStack {
                            let count = (searchScope == .shows) ? sortedLibraryShows.count : sortedLibraryMovies.count
                            Text("Ma Bibliothèque (\(count))")
                                .font(.title2).bold().foregroundColor(.white)
                            Spacer()
                            
                            // Menu de tri
                            Menu {
                                Picker("Tri", selection: $sortOption) {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down.circle.fill")
                                    .foregroundColor(.accentPurple)
                                    .font(.title3)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            // --- CAS A : SÉRIES DANS LA LIBRAIRIE ---
                            if searchScope == .shows {
                                if sortedLibraryShows.isEmpty {
                                    ContentUnavailableView("Vide", systemImage: "tv", description: Text("Aucune série."))
                                } else {
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
                            }
                            // --- CAS B : FILMS DANS LA LIBRAIRIE (CE QUI MANQUAIT) ---
                            else {
                                if sortedLibraryMovies.isEmpty {
                                    ContentUnavailableView("Vide", systemImage: "popcorn", description: Text("Aucun film."))
                                } else {
                                    ForEach(sortedLibraryMovies) { movie in
                                        NavigationLink(destination: MovieDetailView(movie: movie)) {
                                            ShowGridItem(
                                                title: movie.title,
                                                imageUrl: movie.posterUrl,
                                                quality: movie.quality,
                                                isAdded: true,
                                                progress: movie.status == .watched ? 1.0 : 0.0,
                                                nextEpisodeCode: nil,
                                                onQuickAdd: nil,
                                                onManualAdd: nil
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive) { deleteMovie(movie) } label: { Label("Supprimer", systemImage: "trash") }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        
                    }
                    // MODE 2 : RÉSULTATS DE RECHERCHE
                    else {
                        if isSearching {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 50)
                        } else {
                            Text("Résultats").font(.title2).bold().foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                // RÉSULTATS SÉRIES
                                if searchScope == .shows {
                                    ForEach(showResults, id: \.id) { show in
                                        let isAdded = !getQualitiesFor(showId: show.id).isEmpty
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
                                }
                                // RÉSULTATS FILMS
                                else {
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
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color.appBackground)
            .navigationTitle("")
            #if os(iOS)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            
            // Dialogue Ajout Série
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
    
    // --- LOGIQUE METIER ---
    
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
    
    func deleteMovie(_ movie: Movie) {
        withAnimation { LibraryManager.shared.deleteMovie(movie, context: modelContext) }
    }
    
    // --- HELPERS ---
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
    
    // --- COMPOSANT VISUEL UNIQUE ---
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
                    
                    // Badge Prochain Épisode (Séries uniquement)
                    if let code = nextEpisodeCode {
                        Text(code)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .background(Color.cyan).foregroundColor(.white).cornerRadius(4)
                            .padding(6)
                    }
                    
                    // Badge "Ajouté" (Mode Recherche)
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
                    
                    // Barre de progression (Mode Bibliothèque)
                    if let prog = progress, onQuickAdd == nil {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.2))
                                Capsule().fill(LinearGradient(colors: [Color.accentPurple, Color.accentPink], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * prog)
                            }
                        }.frame(height: 4)
                    }
                    
                    HStack {
                        // MODE RECHERCHE : BOUTON AJOUTER
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
                        // MODE BIBLIOTHEQUE : BADGE QUALITÉ / CHECK
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
