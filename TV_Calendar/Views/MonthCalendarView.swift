//
//  MonthCalendarView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//


import SwiftUI
import SwiftData

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    let episodes: [Episode]
    
    let daysOfWeek = ["LUN", "MAR", "MER", "JEU", "VEN", "SAM", "DIM"]
    
    var body: some View {
        // 1. CALCULS DES DIMENSIONS BASÉS SUR L'ÉCRAN RÉEL
        let screenWidth = UIScreen.main.bounds.width
        let sidePadding: CGFloat = 16 // Marge gauche/droite
        
        // La place qu'il nous reste pour la grille
        let availableWidth = screenWidth - (sidePadding * 2)
        
        // Largeur exacte d'une case
        let cellWidth = availableWidth / 7
        // Hauteur (Ratio 1.3 pour être un peu rectangulaire)
        let cellHeight = cellWidth * 1.3
        
        // 2. DÉFINITION DES COLONNES
        // On utilise .fixed(cellWidth) pour forcer SwiftUI à respecter notre calcul
        let columns = Array(repeating: GridItem(.fixed(cellWidth), spacing: 0), count: 7)
        
        VStack(spacing: 0) {
            
            // --- EN-TÊTES JOURS ---
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.gray)
                        .frame(width: cellWidth) // On aligne parfaitement avec les colonnes
                        .padding(.vertical, 8)
                }
            }
            .background(Color.appBackground)
            
            // --- GRILLE MOIS ---
            ScrollView {
                LazyVGrid(columns: columns, spacing: 0) { // Spacing 0 car on gère les bordures nous-mêmes
                    ForEach(0..<selectedDate.calendarDisplayDays().count, id: \.self) { index in
                        let day = selectedDate.calendarDisplayDays()[index]
                        
                        if let date = day {
                            // CASE REMPLIE
                            MonthCell(date: date, episodes: episodesFor(date: date))
                                .frame(width: cellWidth, height: cellHeight) // TAILLE FORCÉE
                                .background(Color.cardBackground)
                                // Petite bordure fine pour séparer les cases
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                                )
                        } else {
                            // CASE VIDE (Mois précédent/suivant)
                            Rectangle()
                                .fill(Color.appBackground.opacity(0.5))
                                .frame(width: cellWidth, height: cellHeight)
                        }
                    }
                }
                .background(Color.gray.opacity(0.1))
                .padding(.bottom, 20)
            }
        }
        // Application des marges sur le conteneur global
        .padding(.horizontal, sidePadding)
    }
    
    func episodesFor(date: Date) -> [Episode] {
        episodes.filter { $0.airDate != nil && date.isSameDay(as: $0.airDate!) }
    }
}

// --- CELLULE DU JOUR (Design Compact) ---
struct MonthCell: View {
    let date: Date
    let episodes: [Episode]
    
    var isToday: Bool { date.isSameDay(as: Date()) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Numéro du jour
            HStack {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 20, height: 20)
                    .background(isToday ? Circle().fill(Color.accentPurple) : nil)
                    .foregroundColor(isToday ? .white : .gray)
                Spacer()
            }
            .padding([.top, .leading], 4)
            
            // Liste des épisodes (Max 4)
            VStack(spacing: 1) {
                ForEach(episodes.prefix(4)) { episode in
                    HStack(spacing: 0) {
                        // Barre couleur série
                        Rectangle()
                            .fill(ColorHash.color(for: episode.show?.name ?? ""))
                            .frame(width: 3)
                        
                        // Nom série tronqué
                        Text(episode.show?.name ?? "")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.leading, 2)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .frame(height: 14)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(2)
                }
                
                // "+2" si trop d'épisodes
                if episodes.count > 4 {
                    Text("+\(episodes.count - 4)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 2)
            
            Spacer()
        }
    }
}
