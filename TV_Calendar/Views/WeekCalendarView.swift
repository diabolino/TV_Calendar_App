//
//  WeekCalendarView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//


import SwiftUI

struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    let episodes: [Episode]
    
    // On prend toute la semaine autour de la date sélectionnée
    var weekDays: [Date] { selectedDate.weekDays() }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 2) {
                ForEach(weekDays, id: \.self) { date in
                    VStack(spacing: 0) {
                        // En-tête Colonne (Lun 24)
                        VStack {
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption2).textCase(.uppercase)
                                .foregroundColor(.gray)
                            
                            Text(date.formatted(.dateTime.day()))
                                .font(.title3).bold()
                                .foregroundColor(date.isSameDay(as: Date()) ? .accentPurple : .white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(date.isSameDay(as: selectedDate) ? Color.accentPurple.opacity(0.1) : Color.appBackground)
                        
                        // Contenu de la journée
                        let daysEpisodes = episodes.filter { $0.airDate != nil && date.isSameDay(as: $0.airDate!) }
                        
                        if daysEpisodes.isEmpty {
                            Spacer()
                            Text("Aucun épisode")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.3))
                                .frame(height: 200)
                            Spacer()
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 8) {
                                    ForEach(daysEpisodes) { episode in
                                        WeekEpisodeCard(episode: episode)
                                    }
                                }
                                .padding(4)
                            }
                        }
                    }
                    .frame(width: 140) // Largeur fixe par colonne
                    .frame(maxHeight: .infinity) // Prend toute la hauteur
                    .background(Color.appBackground)
                    .overlay(
                        Rectangle().frame(width: 1, height: nil, alignment: .trailing)
                            .foregroundColor(Color.white.opacity(0.05)),
                        alignment: .trailing
                    )
                }
            }
        }
        .background(Color.black)
    }
}

struct WeekEpisodeCard: View {
    let episode: Episode
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Affiche
            PosterImage(urlString: episode.show?.imageUrl, width: nil, height: 200)
                .cornerRadius(8)
                .overlay(
                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                        .cornerRadius(8)
                )
            
            // Infos
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.show?.name ?? "")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack {
                    Text("S\(episode.season)E\(episode.number)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Badge Qualité Série
                    if let q = episode.show?.quality {
                        Text(q.rawValue)
                            .font(.system(size: 6, weight: .black))
                            .padding(2)
                            .background(Color.blue)
                            .cornerRadius(2)
                    }
                }
            }
            .padding(8)
        }
        .frame(height: 200)
        // Petit bordure colorée selon la série
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorHash.color(for: episode.show?.name ?? ""), lineWidth: 2)
        )
    }
}