//
//  ShowDetailView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//


import SwiftUI
import SwiftData

struct ShowDetailView: View {
    let show: TVShow
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss // Pour revenir en arrière après suppression
    @State private var showDeleteConfirmation = false // Pour afficher l'alerte
    @State private var showPosterPicker = false
    
    // Calcul des saisons
    var episodesBySeason: [Int: [Episode]] {
        // CORRECTION : On déballe les épisodes avec ?? []
        let safeEpisodes = show.episodes ?? []
        
        let sorted = safeEpisodes.sorted {
            $0.season == $1.season ? $0.number < $1.number : $0.season < $1.season
        }
        return Dictionary(grouping: sorted, by: { $0.season })
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // --- HEADER (Même code qu'avant) ---
                headerView
                
                // --- SYNOPSIS ---
                VStack(alignment: .leading, spacing: 16) {
                    Text("Synopsis")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(show.overview)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .padding()
                
                // --- CASTING ---
                if let cast = show.cast, !cast.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Distribution")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(cast) { actor in
                                    VStack {
                                        // --- CORRECTION : PosterImage Ronde ---
                                        PosterImage(urlString: actor.imageUrl, width: 70, height: 70)
                                            .clipShape(Circle()) // On force le rond
                                            .overlay(
                                                Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                        // --------------------------------------
                                        
                                        Text(actor.name)
                                            .font(.caption).bold()
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Text(actor.characterName)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 80)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 24)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // --- LISTE DES EPISODES ---
                LazyVStack(pinnedViews: [.sectionHeaders]) {
                    // 1. On récupère la liste des saisons triées (La plus récente en haut)
                    let sortedSeasons = episodesBySeason.keys.sorted(by: >)
                    // 2. On identifie le numéro de la dernière saison (ex: Saison 5)
                    let latestSeason = sortedSeasons.first ?? 0
                    
                    ForEach(sortedSeasons, id: \.self) { season in
                        Section(header: SeasonHeader(title: "Saison \(season)", onMarkWatched: {
                            markSeasonWatched(season: season)
                        })) {
                            // 3. LOGIQUE DE TRI INTELLIGENT
                            // On récupère les épisodes de cette saison (qui sont triés par défaut 1, 2, 3...)
                            let episodes = episodesBySeason[season] ?? []
                            
                            // Si c'est la dernière saison, on inverse (pour voir l'ep le plus récent en premier)
                            // Sinon (vieilles saisons), on garde l'ordre normal pour le binge-watching
                            let episodesDisplay = (season == latestSeason) ? episodes.reversed() : episodes
                            
                            // On doit convertir en Array explicitement pour que ForEach soit content
                            ForEach(Array(episodesDisplay)) { episode in
                                DetailEpisodeRow(episode: episode)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.appBackground)
        .ignoresSafeArea(edges: .top)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showPosterPicker) {
            PosterSelectionView(show: show)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        // ALERTE DE CONFIRMATION
        .alert("Supprimer cette série ?", isPresented: $showDeleteConfirmation) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                deleteShow()
            }
        } message: {
            Text("Cette action est irréversible. Tout l'historique de visionnage de cette série sera effacé.")
        }
    }
    
    // --- HEADER COMPLET (Avec PosterImage et Édition) ---
    var headerView: some View {
        ZStack(alignment: .bottom) {
            
            // 1. ARRIÈRE-PLAN (Backdrop flouté)
            // On utilise l'image de la série, on la laisse prendre toute la largeur
            PosterImage(urlString: show.imageUrl, width: nil, height: 350)
                .blur(radius: 40) // Effet de flou
                .overlay(Color.black.opacity(0.4)) // Assombrissement
            
            // Dégradé vers le bas pour fondre avec le reste de la page
            LinearGradient(colors: [.clear, Color.appBackground], startPoint: .center, endPoint: .bottom)
            
            // 2. CONTENU DE PREMIER PLAN
            HStack(alignment: .bottom, spacing: 16) {
                
                // A. LE POSTER (Avec le bouton modifier)
                ZStack(alignment: .bottomTrailing) {
                    // Image nette avec cache
                    PosterImage(urlString: show.imageUrl, width: 100, height: 150)
                        .cornerRadius(8)
                        .shadow(radius: 10)
                    
                    // Bouton "Crayon"
                    Button(action: { showPosterPicker = true }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(4) // Petit décalage du bord
                    .buttonStyle(.plain) // Important pour que ça ne clique pas toute la zone
                }
                
                // B. LES INFOS TEXTE
                VStack(alignment: .leading, spacing: 8) {
                    Text(show.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .lineLimit(2)
                    
                    // Badges
                    HStack(spacing: 8) {
                        
                        // 1. Badge Qualité (En premier)
                        Text(show.quality.rawValue)
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(qualityColor(show.quality))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        
                        // 2. Badge Statut
                        if let status = show.status {
                            StatusBadge(text: status, color: status == "Ended" ? .red : .green)
                        }
                        
                        // 3. Badge Network
                        if let network = show.network {
                            StatusBadge(text: network, color: .blue)
                        }
                        
                        // 4. Compteur d'épisodes (Sécurisé pour CloudKit)
                        Text("\((show.episodes ?? []).count) éps")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                Spacer()
            }
            .padding()
            .padding(.bottom, 20)
        }
    }

    // --- HELPER POUR LA COULEUR (À mettre à la fin de la struct ShowDetailView) ---
    func qualityColor(_ q: VideoQuality) -> Color {
        switch q {
        case .sd: return .orange
        case .hd720: return .blue
        case .hd1080: return .green
        case .uhd4k: return .purple
        }
    }
    
    struct StatusBadge: View {
        let text: String
        let color: Color
        
        var body: some View {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        }
    }
    
    // --- ACTION : TOUT MARQUER VU ---
    func markSeasonWatched(season: Int) {
        withAnimation {
            let episodes = episodesBySeason[season] ?? []
            for ep in episodes {
                ep.isWatched = true
            }
        }
    }
    
    func deleteShow() {
        // 1. On supprime l'objet
        modelContext.delete(show)
        // 2. On ferme la vue pour revenir à la liste
        dismiss()
    }
}

// --- NOUVEAU HEADER DE SECTION AVEC MENU ---
struct SeasonHeader: View {
    let title: String
    let onMarkWatched: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Menu {
                Button(action: onMarkWatched) {
                    Label("Marquer tout comme vu", systemImage: "checkmark.circle.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.accentPurple)
                    .font(.title3)
            }
        }
        .padding()
        .background(Color.appBackground.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.1)),
            alignment: .bottom
        )
    }
}

// --- LIGNE EPISODE (Mise à jour pour le design sombre) ---
// --- LIGNE EPISODE CORRIGÉE (Plus simple) ---
struct DetailEpisodeRow: View {
    let episode: Episode
    @State private var isExpanded = false // Pour dérouler le résumé au clic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Numéro
                Text("\(episode.number)")
                    .font(.monospacedDigit(.body)())
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                
                // Infos principales
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    HStack {
                        if let date = episode.airDate {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        
                        // --- INDICATEUR VISUEL TRADUCTION ---
                        if episode.isAutoTranslated {
                            HStack(spacing: 2) {
                                Image(systemName: "sparkles") // Icône magique
                                Text("AUTO")
                            }
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.accentPurple)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.accentPurple.opacity(0.15))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentPurple.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Bouton Vu
                Button(action: {
                    HapticManager.shared.trigger(.medium)
                    withAnimation { episode.toggleWatched() }
                }) {
                    Image(systemName: episode.isWatched ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(episode.isWatched ? Color.green : Color.gray.opacity(0.5))
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            // --- RESUME DÉROULANT ---
            // On affiche le résumé si disponible et si on a cliqué sur la ligne (hors bouton vu)
            if isExpanded, let overview = episode.overview, !overview.isEmpty {
                Text(overview)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 38) // Alignement sous le titre
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.appBackground)
        .contentShape(Rectangle()) // Rend toute la zone cliquable
        .onTapGesture {
            withAnimation(.snappy) {
                isExpanded.toggle()
            }
        }
    }
}
