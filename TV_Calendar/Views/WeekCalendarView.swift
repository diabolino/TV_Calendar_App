//
//  WeekCalendarView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//


import SwiftUI
import SwiftData

struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    let episodes: [Episode]
    
    var weekDays: [Date] { selectedDate.weekDays() }
    
    var body: some View {
        // CALCUL DES TAILLES FIXES
        let screenWidth = UIScreen.main.bounds.width
        let padding: CGFloat = 16
        // La largeur que DOIT faire une carte pour tenir
        let cardWidth = screenWidth - (padding * 2)
        
        ScrollView {
            VStack(spacing: 24) {
                ForEach(weekDays, id: \.self) { date in
                    VStack(alignment: .leading, spacing: 12) {
                        
                        // En-tête jour
                        HStack {
                            Text(date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "fr_FR"))).capitalized)
                                .font(.headline)
                                .foregroundColor(date.isSameDay(as: Date()) ? .accentPurple : .white)
                            Text(date.formatted(.dateTime.day()))
                                .font(.headline).foregroundColor(.gray)
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        }
                        
                        let daysEpisodes = episodes.filter { $0.airDate != nil && date.isSameDay(as: $0.airDate!) }
                        
                        if daysEpisodes.isEmpty {
                            Text("Aucun épisode").font(.caption).italic().foregroundColor(.gray.opacity(0.3)).padding(.leading, 8)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(daysEpisodes) { episode in
                                    // ON FORCE LA LARGEUR DE LA CARTE ICI
                                    WeekAgendaCard(episode: episode)
                                        .frame(width: cardWidth)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, padding) // On applique le padding externe
            .padding(.bottom, 50)
        }
    }
}

struct WeekAgendaCard: View {
    let episode: Episode
    
    var body: some View {
        HStack(spacing: 12) {
            PosterImage(urlString: episode.show?.imageUrl, width: 60, height: 90)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.show?.name ?? "")
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1) // TRÈS IMPORTANT : Coupe le texte si trop long
                
                HStack {
                    Text("S\(episode.season)E\(String(format: "%02d", episode.number))")
                        .font(.caption).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.white.opacity(0.1)).foregroundColor(.white).cornerRadius(4)
                    
                    if let q = episode.show?.quality {
                        Text(q.rawValue).font(.caption2).bold().foregroundColor(qualityColor(q))
                    }
                }
                
                Text(episode.title)
                    .font(.subheadline).foregroundColor(.gray)
                    .lineLimit(1) // IMPORTANT
            }
            
            Spacer() // Pousse le contenu vers la gauche
            
            Button(action: { withAnimation { episode.toggleWatched() } }) {
                Image(systemName: episode.isWatched ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(episode.isWatched ? .green : .gray.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            Rectangle()
                .fill(ColorHash.color(for: episode.show?.name ?? ""))
                .frame(width: 4)
                .cornerRadius(2, corners: [.topLeft, .bottomLeft]),
            alignment: .leading
        )
    }
    
    func qualityColor(_ q: VideoQuality) -> Color {
        switch q {
        case .sd: return .orange; case .hd720: return .blue; case .hd1080: return .green; case .uhd4k: return .purple
        }
    }
}

// (Laissez vos extensions RoundedCorner en bas du fichier)

// Extension pour arrondir seulement certains coins (utilisé pour la barre de couleur)
// --- CORRECTION CROSS-PLATFORM ---

// Extension pour arrondir seulement certains coins (Compatible iOS & Mac)
extension View {
    // CORRECTION : On accepte maintenant un tableau [RectCorner] au lieu d'un seul élément
    func cornerRadius(_ radius: CGFloat, corners: [RectCorner]) -> some View {
        #if os(iOS)
        clipShape(RoundedCorner(radius: radius, corners: corners))
        #else
        // Sur Mac, on simplifie et on arrondit tout (le rendu est très proche)
        cornerRadius(radius)
        #endif
    }
}

// Notre Enum personnalisé (pour remplacer UIRectCorner qui n'existe pas sur Mac)
enum RectCorner {
    case allCorners
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

#if os(iOS)
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    // CORRECTION : On stocke un tableau de coins
    var corners: [RectCorner]

    func path(in rect: CGRect) -> Path {
        // On convertit notre tableau en "OptionSet" iOS
        var uiCorners: UIRectCorner = []
        
        for corner in corners {
            switch corner {
            case .allCorners: uiCorners = .allCorners
            case .topLeft: uiCorners.insert(.topLeft)
            case .topRight: uiCorners.insert(.topRight)
            case .bottomLeft: uiCorners.insert(.bottomLeft)
            case .bottomRight: uiCorners.insert(.bottomRight)
            }
        }
        
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: uiCorners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
#endif
