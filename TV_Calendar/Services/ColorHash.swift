import SwiftUI

// --- EXTENSIONS POUR LES DATES ---
extension Date {
    // Début du mois
    func startOfMonth() -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }
    
    // Nombre de jours dans le mois
    func daysInMonth() -> Int {
        Calendar.current.range(of: .day, in: .month, for: self)?.count ?? 0
    }
    
    // Jour de la semaine (1 = Dimanche, 2 = Lundi...)
    // On veut souvent commencer par Lundi, donc on ajustera dans la vue
    func dayOfWeek() -> Int {
        Calendar.current.component(.weekday, from: self)
    }
    
    // Obtenir tous les jours du mois actuel (avec le padding des jours vides avant)
    func calendarDisplayDays() -> [Date?] {
        let start = startOfMonth()
        let daysInMonth = daysInMonth()
        let firstDayWeekday = start.dayOfWeek() // 1 = Dimanche, 2 = Lundi...
        
        // Ajustement pour commencer le Lundi (Europe)
        // Si Dimanche (1) -> devient 7. Si Lundi (2) -> devient 1.
        let offset = (firstDayWeekday + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        for i in 0..<daysInMonth {
            if let date = Calendar.current.date(byAdding: .day, value: i, to: start) {
                days.append(date)
            }
        }
        return days
    }
    
    // Obtenir les 7 jours de la semaine autour de la date
    func weekDays() -> [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self))!
        // startOfWeek est souvent Dimanche aux USA, on ajoute 1 jour pour Lundi si besoin, ou on configure le calendrier.
        // Ici on suppose le calendrier par défaut (souvent Lundi en France).
        
        var days: [Date] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i + 1, to: startOfWeek) { // +1 pour caler Lundi
                days.append(date)
            }
        }
        return days
    }
    
    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }
}

// --- GÉNÉRATEUR DE COULEUR PAR SÉRIE ---
struct ColorHash {
    static func color(for string: String) -> Color {
        let hash = string.hashValue
        // On génère des couleurs pastel/sombres agréables
        let hue = Double(abs(hash) % 1000) / 1000.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
}