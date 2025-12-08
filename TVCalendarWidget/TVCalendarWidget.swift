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
    let date: Date
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
            
            let descriptor = FetchDescriptor<TVShow>()
            
            do {
                let allShows = try modelContext.fetch(descriptor)
                
                for show in allShows {
                    let episodes = show.episodes ?? []
                    
                    let nextEpisode = episodes
                        .filter { !$0.isWatched && $0.airDate != nil }
                        .sorted {
                            if $0.season == $1.season { return $0.number < $1.number }
                            return $0.season < $1.season
                        }
                        .first
                    
                    if let ep = nextEpisode, let airDate = ep.airDate {
                        
                        var finalData: Data? = nil
                        if let urlStr = show.imageUrl, let url = URL(string: urlStr) {
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
                
                widgetItems.sort { $0.date < $1.date }
                
            } catch {
                print("❌ Erreur Fetch Widget: \(error)")
            }
            
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

// 4. La Vue (Correctif final "Transparent Mode")
struct TVCalendarWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    // INDISPENSABLE : Pour détecter si l'user est en mode "Transparent/Teinté"
    @Environment(\.widgetRenderingMode) var renderingMode

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
                    if let first = entry.items.first {
                        SinglePosterItem(item: first, isSmall: true)
                            .widgetURL(URL(string: "tvcalendar://show/\(first.id)"))
                    }
                case .systemMedium:
                    HStack(spacing: 12) {
                        ForEach(0..<3) { index in
                            if index < entry.items.count {
                                let item = entry.items[index]
                                Link(destination: URL(string: "tvcalendar://show/\(item.id)")!) {
                                    SinglePosterItem(item: item, isSmall: false)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear
                            }
                        }
                    }
                default:
                    Text("Taille non gérée")
                }
            }
        }
        // LE FIX EST ICI 👇
        .containerBackground(for: .widget) {
            // Si le mode est "Accented" (Transparent/Teinté), on ne veut AUCUN fond.
            if renderingMode == .accented {
                Color.clear
            } else {
                // Sinon (Mode Clair/Sombre classique), on met ton fond habituel
                Color.appBackground
            }
        }
    }
}

// Sous-vue Affiche (Patchée pour garder les couleurs)
struct SinglePosterItem: View {
    let item: WidgetShowItem
    let isSmall: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // IMAGE
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                posterImage(uiImage)
            } else {
                // Fallback si pas d'image
                Color.gray.opacity(0.3)
                Image(systemName: "tv")
                    .foregroundStyle(.white.opacity(0.5))
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
                    // On force une couleur visible même en mode teinté
                    .foregroundStyle(Color.purple)
            }
            .padding(.bottom, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        // LE DEUXIÈME FIX EST ICI 👇
        // Cela dit : "Ne touche pas aux couleurs de ce bloc, garde l'image originale !"
        .widgetAccentable(false)
    }
    
    // Helper pour l'image avec support iOS 18+
    @ViewBuilder
    private func posterImage(_ uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .widgetAccentedRenderingMode(.fullColor)  // DOIT être juste après .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(LinearGradient(colors: [.black, .transparent], startPoint: .bottom, endPoint: .center))
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
        // On assure que le content margin est respecté
        .contentMarginsDisabled()
    }
}
