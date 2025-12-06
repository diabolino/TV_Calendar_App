//
//  ChartsViews.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 06/12/2025.
//


import SwiftUI
import Charts
import SwiftData

// --- GRAPHIQUE 1 : TEMPS DE VISIONNAGE (Barres) ---
struct HistoryChart: View {
    let episodes: [Episode]
    
    // Calcul des données pour le graphique
    var data: [(month: Date, hours: Double)] {
        let calendar = Calendar.current
        
        // On ne prend que les épisodes vus qui ont une date enregistrée
        let watched = episodes.filter { $0.isWatched && $0.watchedDate != nil }
        
        // On groupe par mois
        let grouped = Dictionary(grouping: watched) { ep -> Date in
            let components = calendar.dateComponents([.year, .month], from: ep.watchedDate!)
            return calendar.date(from: components)!
        }
        
        // On additionne les durées (runtime est en minutes -> conversion en heures)
        let results = grouped.map { (key, value) in
            let totalMinutes = value.reduce(0) { $0 + ($1.runtime ?? 0) }
            return (month: key, hours: Double(totalMinutes) / 60.0)
        }
        
        // On trie par date et on garde les 6 derniers mois
        return results.sorted { $0.month < $1.month }.suffix(6)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temps de visionnage")
                .font(.headline).foregroundColor(.white)
            Text("Heures par mois")
                .font(.caption).foregroundColor(.gray)
            
            if data.isEmpty {
                ContentUnavailableView("Pas assez de données", systemImage: "chart.bar.xaxis", description: Text("Regardez des épisodes pour remplir le graphique."))
                    .frame(height: 150)
            } else {
                Chart(data, id: \.month) { item in
                    BarMark(
                        x: .value("Mois", item.month, unit: .month),
                        y: .value("Heures", item.hours)
                    )
                    .foregroundStyle(LinearGradient(colors: [.accentPurple, .accentPink], startPoint: .bottom, endPoint: .top))
                    .cornerRadius(4)
                    // CORRECTION ICI : .annotation est un modificateur, pas une vue
                    .annotation(position: .top, alignment: .center) {
                        Text(String(format: "%.1fh", item.hours))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .frame(height: 180)
                // Personnalisation des axes pour le Dark Mode
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                            .foregroundStyle(.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5])).foregroundStyle(.gray.opacity(0.2))
                    }
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}

// --- GRAPHIQUE 2 : STATUT DES SÉRIES (Donut) ---
struct StatusDistributionChart: View {
    let shows: [TVShow]
    
    var data: [(status: String, count: Int)] {
        var counts: [String: Int] = [:]
        for show in shows {
            let status = show.status ?? "Inconnu"
            counts[status, default: 0] += 1
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("État de la bibliothèque")
                .font(.headline).foregroundColor(.white)
            
            if data.isEmpty {
                Text("Aucune donnée").font(.caption).foregroundColor(.gray).frame(height: 150)
            } else {
                HStack {
                    Chart(data, id: \.status) { item in
                        SectorMark(
                            angle: .value("Nombre", item.count),
                            innerRadius: .ratio(0.6), // Effet Donut
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Statut", item.status))
                        .cornerRadius(4)
                    }
                    .frame(height: 150)
                    
                    // Légende personnalisée à droite
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(data, id: \.status) { item in
                            HStack(spacing: 6) {
                                Circle().fill(colorForStatus(item.status)).frame(width: 8, height: 8)
                                Text(item.status).font(.caption).foregroundColor(.gray).lineLimit(1)
                                Spacer()
                                Text("\(item.count)").font(.caption).bold().foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 120)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
    
    // Couleurs automatiques pour le graphique
    func colorForStatus(_ status: String) -> Color {
        switch status {
        case "Running": return .green
        case "Ended": return .red
        case "To Be Announced": return .orange
        case "In Development": return .blue
        default: return .gray
        }
    }
}
