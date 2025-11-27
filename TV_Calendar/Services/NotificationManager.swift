//
//  NotificationManager.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//


import UserNotifications
import Foundation

class NotificationManager {
    static let shared = NotificationManager()
    
    // 1. Demander la permission (à lancer au premier démarrage)
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Permission notifications accordée !")
            } else if let error = error {
                print("Erreur permission: \(error.localizedDescription)")
            }
        }
    }
    
    // 2. Programmer une notif pour un épisode
    func scheduleNotification(for episode: Episode) {
        guard let airDate = episode.airDate, let showName = episode.show?.name else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Nouvel épisode ce soir !"
        content.body = "\(showName) - S\(episode.season)E\(episode.number) : \(episode.title)"
        content.sound = .default
        
        // On déclenche la notif à la date de sortie
        // Note: Si la date est passée, la notif s'affichera immédiatement (utile pour tester)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: airDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // ID unique pour ne pas le doubler
        let identifier = "episode-\(episode.id)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Erreur programmation notif: \(error)")
            } else {
                print("Notif programmée pour \(showName)")
            }
        }
    }
}
