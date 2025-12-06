//
//  TVCalendarWidget.swift
//  TVCalendarWidget
//
//  Created by Gouard matthieu on 06/12/2025.
//

import WidgetKit
import SwiftUI
import SwiftData
import ImageIO

// 1. Structure d'un élément
struct WidgetShowItem: Identifiable {
    let id: UUID
    let showName: String
    let episodeCode: String
    let imageData: Data?
    let date: Date // On garde la date pour le tri
}

// 2. L'Entrée
struct SimpleEntry: TimelineEntry {
    let date: Date
    let items: [WidgetShowItem]
}

// 3. Le Moteur
struct Provider: TimelineProvider {
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), items: [
            WidgetShowItem(id: UUID(), showName: "Série A", episodeCode: "S01E01", imageData: nil, date: Date()),
            WidgetShowItem(id: UUID(), showName: "Série B", episodeCode: "S02E05", imageData: nil, date: Date()),
            WidgetShowItem(id: UUID(), showName: "Série C", episodeCode: "S04E09", imageData: nil, date: Date())
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        
        Task { @MainActor in
            let currentDate = Date()
            let modelContext = SharedPersistence.sharedModelContainer.mainContext
            
            var widgetItems: [WidgetShowItem] = []
            
            // 🚀 CHANGEMENT MAJEUR : On récupère les SÉRIES, pas les ÉPISODES
            // Cela garantit qu'une série avec 100 épisodes de retard ne bloque pas les autres
            let descriptor = FetchDescriptor<TVShow>()
            
            do {
                let allShows = try modelContext.fetch(descriptor)
                
                // Pour chaque série, on cherche le PREMIER épisode à voir
                for show in allShows {
                    // On récupère les épisodes de la série (sécurisé)
                    let episodes = show.episodes ?? []
                    
                    // On cherche le premier épisode : Non Vu + Date Connue
                    // On trie par saison/épisode pour avoir le chronologique
                    let nextEpisode = episodes
                        .filter { !$0.isWatched && $0.airDate != nil }
                        .sorted {
                            if $0.season == $1.season { return $0.number < $1.number }
                            return $0.season < $1.season
                        }
                        .first
                    
                    // Si on a trouvé un candidat
                    if let ep = nextEpisode, let airDate = ep.airDate {
                        
                        // Téléchargement et Resize Image
                        var finalData: Data? = nil
                        if let urlStr = show.imageUrl, let url = URL(string: urlStr) {
                            // Petit hack synchrone propre dans une Task
                            if let data = try? Data(contentsOf: url) {
                                finalData = resizeImage(data: data, maxPixelSize: 300)
                            }
                        }
                        
                        let item = WidgetShowItem(
                            id: show.uuid,
                            showName: show.name,
                            episodeCode: "S\(ep.season)E\(ep.number)",
                            imageData: finalData,
                            date: airDate
                        )
                        widgetItems.append(item)
                    }
                }
                
                // MAINTENANT on trie les séries par la date de l'épisode (le plus vieux/urgent en premier)
                widgetItems.sort { $0.date < $1.date }
                
            } catch {
                print("❌ Erreur Fetch Widget: \(error)")
            }
            
            // On ne garde que les 3 premiers pour le widget
            let finalItems = Array(widgetItems.prefix(3))
            
            let entry = SimpleEntry(date: currentDate, items: finalItems)
            let refreshDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            
            completion(timeline)
        }
    }
    
    private func resizeImage(data: Data, maxPixelSize: Int) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let imageReference = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: imageReference).jpegData(compressionQuality: 0.7)
    }
}

// 4. La Vue (Avec correctif d'alignement)
struct TVCalendarWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if entry.items.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("Tout est vu !")
                        .font(.caption).bold().foregroundStyle(.white)
                }
            } else {
                switch family {
                case .systemSmall:
                    // Petit : Affiche le 1er
                    if let first = entry.items.first {
                        SinglePosterItem(item: first, isSmall: true)
                    }
                case .systemMedium:
                    // Moyen : Affiche 3 colonnes STRICTES
                    HStack(spacing: 12) {
                        // On boucle de 0 à 2 pour forcer 3 emplacements
                        ForEach(0..<3) { index in
                            if index < entry.items.count {
                                // Cas : Série existante
                                let item = entry.items[index]
                                Link(destination: URL(string: "tvcalendar://show/\(item.id)")!) {
                                    SinglePosterItem(item: item, isSmall: false)
                                }
                            } else {
                                // Cas : Emplacement vide (Invisible mais prend de la place)
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                default:
                    Text("Taille non gérée")
                }
            }
        }
        .containerBackground(for: .widget) { Color.appBackground }
    }
}

// Sous-vue Affiche (Sans GeometryReader pour éviter l'étirement bizarre)
struct SinglePosterItem: View {
    let item: WidgetShowItem
    let isSmall: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // IMAGE
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill) // Remplit le cadre verticalement
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay(LinearGradient(colors: [.black, .transparent], startPoint: .bottom, endPoint: .center))
            } else {
                Color.cardBackground
                Image(systemName: "tv")
                    .foregroundStyle(.white.opacity(0.2))
            }
            
            // TEXTE
            VStack(alignment: .center, spacing: 2) {
                Text(item.showName)
                    .font(.system(size: isSmall ? 12 : 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                
                Text(item.episodeCode)
                    .font(.system(size: isSmall ? 10 : 9, weight: .heavy))
                    .foregroundStyle(Color.accentPurple)
            }
            .padding(.bottom, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension Color {
    static let transparent = Color.black.opacity(0)
}

@main
struct TVCalendarWidget: Widget {
    let kind: String = "TVCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TVCalendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Ma Galerie")
        .description("Vos prochaines séries à regarder.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
