//
//  MoviesView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 22/12/2025.
//


//
//  MoviesView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 22/12/2025.
//

import SwiftUI
import SwiftData

struct MoviesView: View {
    let profileId: String?
    @Query private var allMovies: [Movie]
    
    // Filtrage manuel car @Query dynamique est complexe
    var myMovies: [Movie] {
        guard let pid = profileId, let uuid = UUID(uuidString: pid) else { return [] }
        return allMovies.filter { $0.profileId == uuid }
    }
    
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    if myMovies.isEmpty {
                        ContentUnavailableView("Aucun film", systemImage: "popcorn", description: Text("Recherchez des films pour les ajouter à votre collection."))
                            .padding(.top, 50)
                    } else {
                        // Section: À voir
                        let toWatch = myMovies.filter { $0.status == .toWatch }
                        if !toWatch.isEmpty {
                            SectionHeader(title: "À voir")
                            MovieGrid(movies: toWatch)
                        }
                        
                        // Section: Vu
                        let watched = myMovies.filter { $0.status == .watched }
                        if !watched.isEmpty {
                            SectionHeader(title: "Vus récemment")
                            MovieGrid(movies: watched)
                        }
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Mes Films")
        }
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title2).bold()
            .foregroundColor(.white)
            .padding(.top)
    }
}

struct MovieGrid: View {
    let movies: [Movie]
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(movies) { movie in
                NavigationLink(destination: MovieDetailView(movie: movie)) {
                    VStack(alignment: .leading) {
                        PosterImage(urlString: movie.posterUrl, width: nil, height: 160)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                        
                        Text(movie.title)
                            .font(.caption).bold()
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}