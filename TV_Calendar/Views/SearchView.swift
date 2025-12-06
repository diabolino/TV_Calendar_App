//
//  SearchView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI
import SwiftData

// Enum pour les options de tri
enum SortOption: String, CaseIterable {
    case nameAZ = "Nom (A-Z)"
    case nameZA = "Nom (Z-A)"
    case status = "Par Statut"
}

struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [TVMazeService.ShowDTO] = []
    
    // État du tri
    @State private var sortOption: SortOption = .nameAZ
    
    // Réglage par défaut (stocké)
    @AppStorage("defaultQuality") private var defaultQuality: VideoQuality = .hd1080
    
    @FocusState private var isSearchFocused: Bool
    
    @State private var selectedShowToAdd: TVMazeService.ShowDTO?
    @State private var showQualitySelection = false
    
    @Environment(\.modelContext) private var modelContext
    @Query var libraryShows: [TVShow]
    
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
    
    // LOGIQUE DE TRI DYNAMIQUE
    var sortedLibraryShows: [TVShow] {
        switch sortOption {
        case .nameAZ:
            return libraryShows.sorted { $0.name < $1.name }
        case .nameZA:
            return libraryShows.sorted { $0.name > $1.name }
        case .status:
            return libraryShows.sorted {
                if ($0.status ?? "") == ($1.status ?? "") {
                    return $0.name < $1.name
                }
                return ($0.status ?? "") > ($1.status ?? "")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // --- BARRE DE RECHERCHE + TRI ---
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.gray)
                            TextField("Rechercher...", text: $searchText)
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .focused($isSearchFocused)
                                .submitLabel(.search)
                                .onSubmit { performSearch(query: searchText); isSearchFocused = false }
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = ""; isSearchFocused = false }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                        }
                        .padding().background(Color.cardBackground).cornerRadius(12)
                        
                        // BOUTON DE TRI
                        if searchText.isEmpty {
                            Menu {
                                Picker("Tri", selection: $sortOption) {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.accentPurple)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // --- CONTENU ---
                    if searchText.isEmpty {
                        // VUE BIBLIOTHÈQUE
                        if !libraryShows.isEmpty {
                            HStack {
                                Text("Ma Bibliothèque (\(libraryShows.count))")
                                    .font(.title2).bold().foregroundColor(.white)
                                Spacer()
                                Text(sortOption.rawValue).font(.caption).foregroundColor(.gray)
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
                            ContentUnavailableView("Bibliothèque vide", systemImage: "tv", description: Text("Recherchez une série ci-dessus pour commencer."))
                                .padding(.top, 50)
                        }
                    } else {
                        // VUE RÉSULTATS
                        Text("Résultats").font(.title2).bold().foregroundColor(.white).padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(searchResults, id: \.id) { show in
                                let existingQualities = getQualitiesFor(showId: show.id)
                                ShowGridItem(
                                    title: show.name,
                                    imageUrl: show.image?.medium,
                                    quality: nil,
                                    isAdded: !existingQualities.isEmpty,
                                    progress: nil,
                                    nextEpisodeCode: nil,
                                    onQuickAdd: {
                                        // CLIC SIMPLE : Ajout avec qualité par défaut
                                        isSearchFocused = false
                                        Task {
                                            await LibraryManager.shared.addShow(
                                                dto: show,
                                                quality: defaultQuality, // Utilise le réglage
                                                context: modelContext,
                                                existingShows: libraryShows
                                            )
                                        }
                                    },
                                    onManualAdd: {
                                        // APPUI LONG : Choix manuel
                                        isSearchFocused = false
                                        selectedShowToAdd = show
                                        showQualitySelection = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
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
                            Task { await LibraryManager.shared.addShow(
                                dto: show,
                                quality: quality,
                                context: modelContext,
                                existingShows: libraryShows
                            )}
                        }
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: { Text("Dans quelle qualité voulez-vous ajouter cette série ?") }
        }
        .onChange(of: searchText) { oldValue, newValue in
            if newValue.isEmpty { searchResults = [] } else { performSearch(query: newValue) }
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
        libraryShows.filter { $0.tvmazeId == showId }.map { $0.quality }
    }
    
    func performSearch(query: String) {
        guard !query.isEmpty else { searchResults = []; return }
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if let results = try? await TVMazeService.shared.searchShow(query: query) { searchResults = results }
        }
    }
    
    func deleteShow(_ show: TVShow) {
        withAnimation { LibraryManager.shared.deleteShow(show, context: modelContext) }
    }
    
    // --- CARTE AVEC DOUBLE ACTION (RETROUVÉE !) ---
    struct ShowGridItem: View {
        let title: String
        let imageUrl: String?
        let quality: VideoQuality?
        let isAdded: Bool
        let progress: Double?
        let nextEpisodeCode: String?
        
        // On accepte deux actions distinctes
        let onQuickAdd: (() -> Void)?
        let onManualAdd: (() -> Void)?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    PosterImage(urlString: imageUrl, width: nil, height: nil)
                        .aspectRatio(2/3, contentMode: .fill)
                        .frame(maxWidth: .infinity).clipped()
                    if let code = nextEpisodeCode {
                        Text(code)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .background(Color.cyan).foregroundColor(.white).cornerRadius(4)
                            .padding(6)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption).bold().foregroundColor(.white).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let prog = progress {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.2))
                                Capsule().fill(LinearGradient(colors: [Color.accentPurple, Color.accentPink], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * prog)
                            }
                        }.frame(height: 4)
                    }
                    
                    HStack {
                        // SI MODE AJOUT (RECHERCHE)
                        if let onQuick = onQuickAdd, let onManual = onManualAdd {
                            Text("AJOUTER")
                                .font(.system(size: 10, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.accentPurple)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                // GESTE 1 : Tap Simple -> Quick Add
                                .onTapGesture {
                                    HapticManager.shared.trigger(.light)
                                    onQuick()
                                }
                                // GESTE 2 : Long Press -> Manual Add
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    HapticManager.shared.trigger(.heavy)
                                    onManual()
                                }
                        }
                        // SI MODE BIBLIOTHÈQUE
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
