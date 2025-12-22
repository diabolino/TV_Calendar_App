//
//  MovieDetailView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//  Updated for Trakt Sync & Full UI
//

import SwiftUI
import SwiftData

struct MovieDetailView: View {
    @Bindable var movie: Movie
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // État pour la confirmation de suppression
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // --- HEADER (BACKDROP + POSTER) ---
                ZStack(alignment: .bottomLeading) {
                    // Image de fond (Backdrop)
                    if let backdrop = movie.backdropUrl {
                        PosterImage(urlString: TMDBService.imageURL(path: backdrop, width: "w1280"), width: nil, height: 250)
                            .overlay(
                                LinearGradient(colors: [.clear, Color.appBackground], startPoint: .center, endPoint: .bottom)
                            )
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 250)
                    }
                    
                    // Poster et Titre
                    HStack(alignment: .bottom, spacing: 16) {
                        PosterImage(urlString: TMDBService.imageURL(path: movie.posterUrl, width: "w342"), width: 100, height: 150)
                            .cornerRadius(8)
                            .shadow(radius: 8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(movie.title)
                                .font(.title2).bold()
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2, x: 0, y: 1)
                            
                            if let date = movie.releaseDate {
                                Text(date.formatted(date: .long, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            if let runtime = movie.runtime, runtime > 0 {
                                Text("\(runtime / 60)h \(runtime % 60)min")
                                    .font(.caption)
                                    .bold()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(4)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
                VStack(alignment: .leading, spacing: 24) {
                    
                    // --- ACTIONS (BOUTON VU) ---
                    if movie.status == .watched {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Film vu le \(movie.watchedDate?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                                .foregroundColor(.green)
                                .bold()
                            Spacer()
                            
                            // Bouton pour annuler (optionnel, local seulement pour l'instant)
                            Button("Non vu") {
                                withAnimation {
                                    movie.status = .toWatch
                                    movie.watchedDate = nil
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        
                    } else {
                        // LE BOUTON PRINCIPAL AVEC SYNC TRAKT
                        Button(action: {
                            HapticManager.shared.trigger(.medium)
                            
                            // 1. Mise à jour Locale
                            withAnimation {
                                movie.status = .watched
                                movie.watchedDate = Date()
                            }
                            
                            // 2. Envoi vers Trakt
                            Task {
                                await TraktService.shared.markMovieWatched(
                                    tmdbId: movie.tmdbId,
                                    title: movie.title
                                )
                            }
                        }) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Marquer comme vu")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentPurple)
                            .cornerRadius(12)
                            .shadow(color: .accentPurple.opacity(0.4), radius: 5, x: 0, y: 3)
                        }
                    }
                    
                    // --- SYNOPSIS ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Synopsis")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(movie.overview.isEmpty ? "Aucune description disponible." : movie.overview)
                            .font(.body)
                            .foregroundColor(.gray)
                            .lineSpacing(4)
                    }
                    
                    // --- CASTING ---
                    if let cast = movie.cast, !cast.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Casting")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(cast) { member in
                                        VStack {
                                            PosterImage(urlString: member.imageUrl, width: 80, height: 80)
                                                .clipShape(Circle())
                                            
                                            Text(member.name)
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            
                                            Text(member.characterName)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 80)
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
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Supprimer de la bibliothèque", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Supprimer le film ?", isPresented: $showDeleteConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                LibraryManager.shared.deleteMovie(movie, context: modelContext)
                dismiss()
            }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer '\(movie.title)' de votre bibliothèque ?")
        }
    }
}
