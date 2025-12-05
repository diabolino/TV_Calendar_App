//
//  ShowHeatmap.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 27/11/2025.
//


import SwiftUI

struct ShowHeatmap: View {
    let show: TVShow
    let episodes: [Episode]
    
    // État pour le chargement manuel
    @State private var isLoadingBanner = false
    
    // Affiche uniquement la saison "active"
    var episodesToDisplay: [Episode] {
        let sortedAll = episodes.sorted {
            if $0.season == $1.season { return $0.number < $1.number }
            return $0.season < $1.season
        }
        
        if let firstUnwatched = sortedAll.first(where: { !$0.isWatched }) {
            return sortedAll.filter { $0.season == firstUnwatched.season }
        }
        
        if let lastEpisode = sortedAll.last {
            return sortedAll.filter { $0.season == lastEpisode.season }
        }
        return []
    }
    
    var currentSeasonNumber: Int {
        episodesToDisplay.first?.season ?? 1
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 24, maximum: 30), spacing: 4)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            
            // --- BANNIÈRE ---
            ZStack(alignment: .center) {
                if let banner = show.bannerUrl {
                    PosterImage(urlString: banner, width: nil, height: 70)
                        .overlay(Color.black.opacity(0.1))
                } else {
                    ZStack {
                        Color.accentPurple.opacity(0.3)
                        Text(show.name).font(.headline).bold().foregroundColor(.white)
                    }
                    .frame(height: 70)
                }
                
                // Badges (Overlay)
                VStack {
                    HStack {
                        Spacer()
                        // Badge Saison
                        Text("SAISON \(currentSeasonNumber)")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white.opacity(0.9))
                            .cornerRadius(3)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        // Badge Qualité
                        Text(show.quality.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(qualityColor(show.quality))
                            .foregroundColor(.white)
                            .cornerRadius(3)
                    }
                }
                .padding(6)
            }
            .clipped()
            
            // --- GRILLE ÉPISODES ---
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(episodesToDisplay) { ep in
                    HeatmapCell(episode: ep) {
                        handleTap(on: ep)
                    }
                }
            }
            .padding(8)
            .background(Color.cardBackground)
            
            // --- BOUTON DE CHECK BANNIÈRE (Version 1.0 Finale) ---
            if show.bannerUrl == nil {
                // Cas 1 : Pas de bannière -> Bouton bien visible
                Button(action: refreshBanner) {
                    HStack {
                        if isLoadingBanner {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Rechercher une bannière sur TVMaze")
                        }
                    }
                    .font(.caption).bold()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentPurple.opacity(0.3))
                }
            } else {
                // Cas 2 : Bannière existe -> Menu contextuel discret (Appui long pour refresh)
                // Ou petit bouton discret en bas si on veut le voir
                /* Si vous voulez un bouton discret même quand y'a une image, décommentez ceci :
                Button(action: refreshBanner) {
                    Text("Actualiser l'image")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.vertical, 4)
                }
                */
            }
        }
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        // Petit menu contextuel pour forcer le refresh même si l'image est là
        .contextMenu {
            Button {
                refreshBanner()
            } label: {
                Label("Forcer la mise à jour image", systemImage: "arrow.clockwise")
            }
        }
    }
    
    // --- ACTIONS ---
    
    // --- ACTIONS ---
        
    func refreshBanner() {
        print("🔄 Début du refresh manuel pour la série ID: \(show.tvmazeId)")
        isLoadingBanner = true
        
        Task {
            do {
                // 1. On essaie de récupérer les détails SANS le '?' pour attraper l'erreur
                let details = try await TVMazeService.shared.fetchShowWithImages(id: show.tvmazeId)
                print("✅ JSON décodé avec succès. Analyse des images...")
                
                // 2. On cherche la bannière
                if let newBanner = TVMazeService.shared.extractBanner(from: details) {
                    // On met à jour l'objet SwiftData
                    show.bannerUrl = newBanner
                    print("🎉 Bannière trouvée et appliquée : \(newBanner)")
                } else {
                    print("⚠️ L'API a répondu, mais 'extractBanner' n'a rien trouvé d'intéressant.")
                    // Optionnel : Afficher les images trouvées pour comprendre
                    if let images = details._embedded?.images {
                        print("   Images disponibles : \(images.count)")
                        for img in images {
                            // CORRECTION ICI : Ajout de ?? "nil"
                            print("   - Type: \(img.type ?? "nil") | Size: \(img.resolutions.original.width)x\(img.resolutions.original.height)")
                        }
                    } else {
                        print("   Aucune image dans le champ _embedded.")
                    }
                }
                
            } catch {
                // 3. C'est ICI que l'erreur va s'afficher
                print("❌ ERREUR CRITIQUE API : \(error)")
                
                // Astuce : Si c'est une erreur de décodage, Swift vous dira quel champ pose problème
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let key, let context):
                        print("   Type incorrect pour la clé : \(key), contexte: \(context.debugDescription)")
                    case .valueNotFound(let key, let context):
                        print("   Valeur manquante pour la clé : \(key), contexte: \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("   Clé introuvable : \(key), contexte: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("   Données corrompues : \(context.debugDescription)")
                    @unknown default:
                        print("   Erreur de décodage inconnue")
                    }
                }
            }
            
            // Fin du chargement
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoadingBanner = false
        }
    }
    
    func handleTap(on targetEpisode: Episode) {
        withAnimation(.snappy) {
            if !targetEpisode.isWatched {
                for ep in episodesToDisplay {
                    if ep.number <= targetEpisode.number {
                        if !ep.isWatched {
                            ep.isWatched = true
                            ep.watchedDate = Date()
                        }
                    }
                }
            } else {
                targetEpisode.isWatched = false
                targetEpisode.watchedDate = nil
            }
        }
    }
    
    func qualityColor(_ q: VideoQuality) -> Color {
        switch q {
        case .sd: return .orange; case .hd720: return .blue; case .hd1080: return .green; case .uhd4k: return .purple
        }
    }
}

struct HeatmapCell: View {
    let episode: Episode
    let action: () -> Void
    
    var statusColor: Color {
        if episode.isWatched { return .green }
        if let date = episode.airDate, date <= Date() { return .orange }
        return .gray.opacity(0.3)
    }
    
    var body: some View {
        Rectangle()
            .fill(statusColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Text("\(episode.number)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            )
            .cornerRadius(2)
            .onTapGesture {
                action()
            }
    }
}
