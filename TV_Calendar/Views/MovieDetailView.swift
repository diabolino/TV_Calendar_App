//
//  MovieDetailView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 22/12/2025.
//


//
//  MovieDetailView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 22/12/2025.
//

import SwiftUI
import SwiftData

struct MovieDetailView: View {
    let movie: Movie
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header Image
                PosterImage(urlString: movie.backdropUrl ?? movie.posterUrl, width: nil, height: 250)
                    .overlay(Color.black.opacity(0.3))
                    .mask(LinearGradient(gradient: Gradient(colors: [.black, .black, .clear]), startPoint: .top, endPoint: .bottom))
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(movie.title)
                        .font(.largeTitle).bold()
                        .foregroundColor(.white)
                    
                    HStack {
                        if let date = movie.releaseDate {
                            Text(date.formatted(date: .numeric, time: .omitted))
                                .font(.subheadline).foregroundColor(.gray)
                        }
                        if let runtime = movie.runtime {
                            Text("• \(runtime) min")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                    }
                    
                    // STATUS SELECTOR
                    Picker("Statut", selection: Binding(get: { movie.status }, set: { movie.status = $0 })) {
                        ForEach(WatchStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Synopsis")
                        .font(.headline).foregroundColor(.white).padding(.top)
                    
                    Text(movie.overview)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                    
                    if let cast = movie.cast, !cast.isEmpty {
                        Text("Casting").font(.headline).foregroundColor(.white).padding(.top)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(cast) { actor in
                                    VStack {
                                        PosterImage(urlString: actor.imageUrl, width: 60, height: 60)
                                            .clipShape(Circle())
                                        Text(actor.name).font(.caption).foregroundColor(.white).lineLimit(1).frame(width: 70)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.appBackground)
        .ignoresSafeArea(edges: .top)
        .toolbar {
            Button(role: .destructive) {
                LibraryManager.shared.deleteMovie(movie, context: modelContext)
                dismiss()
            } label: {
                Image(systemName: "trash").foregroundColor(.red)
            }
        }
    }
}