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
                                // UTILISATION DE LA LISTE TRIÉE
                                ForEach(sortedLibraryShows) { show in
                                    NavigationLink(destination: ShowDetailView(show: show)) {
                                        ShowGridItem(
                                            title: show.name,
                                            imageUrl: show.imageUrl,
                                            quality: show.quality, // DIRECTEMENT L'ENUM
                                            isAdded: true,
                                            progress: calculateProgress(for: show),
                                            nextEpisodeCode: getNextEpisodeCode(for: show),
                                            action: nil
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
                            ContentUnavailableView("Bibliothèque vide", systemImage: "tv", description: Text("Recherchez une série."))
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
                                    action: { isSearchFocused = false; selectedShowToAdd = show; showQualitySelection = true }
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
                            Task { await addShowToLibrary(show, quality: quality) }
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
        withAnimation { modelContext.delete(show) }
    }
    
    func addShowToLibrary(_ dto: TVMazeService.ShowDTO, quality: VideoQuality) async {
        // CORRECTION : Comparaison Enum vs Enum (Simple)
        if libraryShows.contains(where: { $0.tvmazeId == dto.id && $0.quality == quality }) { return }
        
        // 2. Infos Fraiches
        var finalBannerUrl: String? = nil
        var finalNetwork = dto.network?.name ?? dto.webChannel?.name
        var finalStatus = dto.status
        var imdbIdForSearch: String? = dto.externals?.imdb
        
        if let details = try? await TVMazeService.shared.fetchShowWithImages(id: dto.id) {
            finalBannerUrl = TVMazeService.shared.extractBanner(from: details)
            finalNetwork = details.network?.name ?? details.webChannel?.name
            finalStatus = details.status
            imdbIdForSearch = details.externals?.imdb
        }
        
        // 3. TMDB
        var finalOverview = dto.summary?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) ?? ""
        var finalImage = dto.image?.original ?? dto.image?.medium
        var tmdbId: Int? = nil
        
        if let imdb = imdbIdForSearch, let tmdbResult = try? await TMDBService.shared.findShowByExternalId(imdbId: imdb) {
            tmdbId = tmdbResult.id
            if let fr = tmdbResult.overview, !fr.isEmpty { finalOverview = fr }
            if let img = tmdbResult.poster_path { finalImage = TMDBService.imageURL(path: img) }
        } else if let tmdbResult = try? await TMDBService.shared.searchShowByName(query: dto.name) {
            tmdbId = tmdbResult.id
            if let fr = tmdbResult.overview, !fr.isEmpty { finalOverview = fr }
            if let img = tmdbResult.poster_path { finalImage = TMDBService.imageURL(path: img) }
        }

        let newShow = TVShow(
            tvmazeId: dto.id, name: dto.name, overview: finalOverview, imageUrl: finalImage,
            bannerUrl: finalBannerUrl, network: finalNetwork, status: finalStatus,
            quality: quality // PAS DE CONVERSION ICI, quality est bien un Enum
        )
        modelContext.insert(newShow)
        
        // 5. Episodes
        if let episodes = try? await TVMazeService.shared.fetchEpisodes(showId: dto.id) {
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
            let episodesBySeason = Dictionary(grouping: episodes, by: { $0.season })
            
            for (seasonNum, seasonEpisodes) in episodesBySeason {
                var frenchOverviews: [Int: String] = [:]
                var englishOverviews: [Int: String] = [:]
                
                if let tId = tmdbId {
                    if let frSeason = try? await TMDBService.shared.fetchSeasonDetails(tmdbShowId: tId, seasonNumber: seasonNum, language: "fr-FR") {
                        for ep in frSeason.episodes { if let ov = ep.overview, !ov.isEmpty { frenchOverviews[ep.episode_number] = ov } }
                    }
                    if seasonEpisodes.count > frenchOverviews.count {
                        if let enSeason = try? await TMDBService.shared.fetchSeasonDetails(tmdbShowId: tId, seasonNumber: seasonNum, language: "en-US") {
                            for ep in enSeason.episodes { if let ov = ep.overview, !ov.isEmpty { englishOverviews[ep.episode_number] = ov } }
                        }
                    }
                }
                
                for ep in seasonEpisodes {
                    let date = ep.airdate != nil ? formatter.date(from: ep.airdate!) : nil
                    var epOverview = ""
                    var isTranslated = false
                    
                    if let fr = frenchOverviews[ep.number] {
                        epOverview = fr
                        isTranslated = false
                    } else {
                        let sourceText = englishOverviews[ep.number] ?? ep.summary?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) ?? ""
                        if !sourceText.isEmpty {
                            if let translatedText = await TranslationService.shared.translate(text: sourceText) {
                                epOverview = translatedText; isTranslated = true
                            } else {
                                epOverview = sourceText; isTranslated = true
                            }
                        }
                    }
                    
                    let newEp = Episode(
                        tvmazeId: ep.id, title: ep.name, season: ep.season, number: ep.number,
                        airDate: date, runtime: ep.runtime, overview: epOverview
                    )
                    newEp.isAutoTranslated = isTranslated
                    newEp.id = "\(newShow.uuid)-\(ep.id)"
                    newEp.show = newShow
                    modelContext.insert(newEp)
                    
                    if let validDate = newEp.airDate, validDate > Date() {
                        NotificationManager.shared.scheduleNotification(for: newEp)
                    }
                }
            }
        }
        
        // 6. Casting
        if let cast = try? await TVMazeService.shared.fetchCast(showId: dto.id) {
            for c in cast.prefix(10) {
                let actor = CastMember(personId: c.person.id, name: c.person.name, characterName: c.character.name, imageUrl: c.person.image?.medium)
                actor.show = newShow
                modelContext.insert(actor)
            }
        }
    }
    
    struct ShowGridItem: View {
        let title: String
        let imageUrl: String?
        let quality: VideoQuality?
        let isAdded: Bool
        let progress: Double?
        let nextEpisodeCode: String?
        let action: (() -> Void)?
        
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
                        if let action = action {
                            Button(action: action) {
                                Text("AJOUTER").font(.system(size: 10, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 6).background(Color.accentPurple).foregroundColor(.white).cornerRadius(4)
                            }
                        } else {
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
