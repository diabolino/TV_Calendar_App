import SwiftUI
import SwiftData

struct MonthCalendarView: View {
    @Binding var selectedDate: Date // La date sélectionnée (pour naviguer)
    let episodes: [Episode]
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
    let daysOfWeek = ["LUN", "MAR", "MER", "JEU", "VEN", "SAM", "DIM"]
    
    var body: some View {
        VStack(spacing: 0) {
            // En-têtes jours
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                }
            }
            .background(Color.appBackground)
            
            // Grille
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(0..<selectedDate.calendarDisplayDays().count, id: \.self) { index in
                    let day = selectedDate.calendarDisplayDays()[index]
                    
                    if let date = day {
                        MonthCell(date: date, episodes: episodesFor(date: date))
                            .frame(minHeight: 100, alignment: .top) // Hauteur min des cases
                            .background(Color.cardBackground)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.black.opacity(0.5), lineWidth: 0.5)
                            )
                    } else {
                        // Case vide (mois précédent/suivant)
                        Rectangle()
                            .fill(Color.appBackground)
                            .frame(minHeight: 100)
                    }
                }
            }
        }
        .background(Color.black) // Couleur des bordures de grille
    }
    
    func episodesFor(date: Date) -> [Episode] {
        episodes.filter { $0.airDate != nil && date.isSameDay(as: $0.airDate!) }
    }
}

struct MonthCell: View {
    let date: Date
    let episodes: [Episode]
    
    var isToday: Bool { date.isSameDay(as: Date()) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Numéro du jour
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption2)
                .padding(4)
                .foregroundColor(isToday ? .white : .gray)
                .background(isToday ? Circle().fill(Color.accentPurple) : nil)
            
            // Liste des épisodes (Max 3 affichés)
            ForEach(episodes.prefix(3)) { episode in
                HStack(spacing: 4) {
                    // Petite pastille couleur série
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorHash.color(for: episode.show?.name ?? ""))
                        .frame(width: 3)
                    
                    Text(episode.show?.name ?? "")
                        .font(.system(size: 8, weight: .bold))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("S\(episode.season)E\(episode.number)")
                        .font(.system(size: 7))
                        .opacity(0.7)
                }
                .padding(3)
                .background(ColorHash.color(for: episode.show?.name ?? "").opacity(0.2))
                .cornerRadius(3)
            }
            
            if episodes.count > 3 {
                Text("+\(episodes.count - 3) plus")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
            }
            
            Spacer(minLength: 0)
        }
        .padding(2)
    }
}