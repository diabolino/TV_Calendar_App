//
//  PosterSelectionView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 27/11/2025.
//


import SwiftUI

struct PosterSelectionView: View {
    @Environment(\.dismiss) var dismiss
    let show: TVShow
    
    @State private var posters: [TMDBService.TMDBImageInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // 3 colonnes pour la grille
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Recherche des posters...")
                        .padding(.top, 50)
                } else if let error = errorMessage {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if posters.isEmpty {
                    ContentUnavailableView("Aucun poster", systemImage: "photo.on.rectangle.angled", description: Text("Aucun autre poster trouvé sur TMDB."))
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(posters) { poster in
                            Button(action: { selectPoster(poster) }) {
                                PosterImage(urlString: TMDBService.imageURL(path: poster.file_path, width: "w500"), width: nil, height: 160)
                                    .aspectRatio(2/3, contentMode: .fill)
                                    .cornerRadius(8)
                                    .overlay(
                                        // Bordure si c'est l'image actuelle (comparaison basique d'URL)
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentPurple, lineWidth: isCurrentPoster(poster) ? 4 : 0)
                                    )
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Choisir une affiche")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task {
                await loadPosters()
            }
        }
    }
    
    // --- LOGIQUE ---
    
    func isCurrentPoster(_ poster: TMDBService.TMDBImageInfo) -> Bool {
        guard let currentUrl = show.imageUrl else { return false }
        return currentUrl.contains(poster.file_path)
    }
    
    func selectPoster(_ poster: TMDBService.TMDBImageInfo) {
        // On construit l'URL haute qualité
        if let newUrl = TMDBService.imageURL(path: poster.file_path, width: "original") {
            // Mise à jour de SwiftData
            show.imageUrl = newUrl
            print("🖼️ Affiche mise à jour : \(newUrl)")
            dismiss()
        }
    }
    
    func loadPosters() async {
        isLoading = true
        do {
            // 1. On a besoin de l'ID IMDb ou TMDB.
            // On refait un appel léger à TVMaze pour être sûr d'avoir les IDs externes
            let details = try await TVMazeService.shared.fetchShowWithImages(id: show.tvmazeId)
            
            var tmdbId: Int? = nil
            
            // 2. On cherche l'ID TMDB via IMDb
            if let imdb = details.externals?.imdb {
                if let tmdbResult = try? await TMDBService.shared.findShowByExternalId(imdbId: imdb) {
                    tmdbId = tmdbResult.id
                }
            } 
            // Fallback : Recherche par nom
            else if let tmdbResult = try? await TMDBService.shared.searchShowByName(query: show.name) {
                tmdbId = tmdbResult.id
            }
            
            // 3. Si on a l'ID, on charge les images
            if let tId = tmdbId {
                posters = try await TMDBService.shared.fetchPosters(tmdbId: tId)
            } else {
                errorMessage = "Série introuvable sur TMDB"
            }
            
        } catch {
            errorMessage = "Erreur réseau : \(error.localizedDescription)"
        }
        isLoading = false
    }
}