import Foundation
import SwiftData
import SwiftUI

// Ce singleton gère toute la logique de modification de la base de données
class LibraryManager {
    static let shared = LibraryManager()
    
    // --- AJOUT D'UNE SÉRIE ---
    @MainActor
    func addShow(dto: TVMazeService.ShowDTO, quality: VideoQuality, context: ModelContext, existingShows: [TVShow]) async {
        
        // 1. Vérification doublons (CORRIGÉE)
        // On compare directement l'Enum ($0.quality) avec l'Enum (quality)
        // On a retiré .rawValue qui causait l'erreur
        if existingShows.contains(where: { $0.tvmazeId == dto.id && $0.quality == quality }) {
            print("⚠️ Cette version existe déjà.")
            // AJOUT :
            ToastManager.shared.show("Cette série est déjà dans votre bibliothèque", style: .error)
            return
        }
        
        print("📥 Début de l'ajout : \(dto.name)")
        // AJOUT :
        ToastManager.shared.show("Ajout de \(dto.name) en cours...", style: .info)
        
        // 2. Infos Fraiches (TVMaze Update)
        var finalBannerUrl: String? = nil
        var finalNetwork = dto.network?.name ?? dto.webChannel?.name
        var finalStatus = dto.status
        var imdbIdForSearch: String? = dto.externals?.imdb
        
        if let details = try? await TVMazeService.shared.fetchShowWithImages(id: dto.id) {
            finalBannerUrl = TVMazeService.shared.extractBanner(from: details)
            finalNetwork = details.network?.name ?? details.webChannel?.name
            finalStatus = details.status
            imdbIdForSearch = details.externals?.imdb
        }
        
        // 3. Enrichissement TMDB
        var finalOverview = dto.summary?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) ?? ""
        var finalImage = dto.image?.original ?? dto.image?.medium
        var tmdbId: Int? = nil
        
        if let imdb = imdbIdForSearch, let tmdbResult = try? await TMDBService.shared.findShowByExternalId(imdbId: imdb) {
            tmdbId = tmdbResult.id
            if let fr = tmdbResult.overview, !fr.isEmpty { finalOverview = fr }
            if let img = tmdbResult.poster_path { finalImage = TMDBService.imageURL(path: img) }
        } else if let tmdbResult = try? await TMDBService.shared.searchShowByName(query: dto.name) {
            tmdbId = tmdbResult.id
            if let fr = tmdbResult.overview, !fr.isEmpty { finalOverview = fr }
            if let img = tmdbResult.poster_path { finalImage = TMDBService.imageURL(path: img) }
        }

        // 4. Création Show
        let newShow = TVShow(
            tvmazeId: dto.id,
            name: dto.name,
            overview: finalOverview,
            imageUrl: finalImage,
            bannerUrl: finalBannerUrl,
            network: finalNetwork,
            status: finalStatus,
            quality: quality // Ici c'est bon, l'init attend bien un VideoQuality
        )
        context.insert(newShow)
        
        // 5. Episodes
        if let episodes = try? await TVMazeService.shared.fetchEpisodes(showId: dto.id) {
            let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
            let episodesBySeason = Dictionary(grouping: episodes, by: { $0.season })
            
            for (seasonNum, seasonEpisodes) in episodesBySeason {
                var frenchOverviews: [Int: String] = [:]
                var englishOverviews: [Int: String] = [:]
                
                if let tId = tmdbId {
                    if let frSeason = try? await TMDBService.shared.fetchSeasonDetails(tmdbShowId: tId, seasonNumber: seasonNum, language: "fr-FR") {
                        for ep in frSeason.episodes { if let ov = ep.overview, !ov.isEmpty { frenchOverviews[ep.episode_number] = ov } }
                    }
                    if seasonEpisodes.count > frenchOverviews.count {
                        if let enSeason = try? await TMDBService.shared.fetchSeasonDetails(tmdbShowId: tId, seasonNumber: seasonNum, language: "en-US") {
                            for ep in enSeason.episodes { if let ov = ep.overview, !ov.isEmpty { englishOverviews[ep.episode_number] = ov } }
                        }
                    }
                }
                
                for ep in seasonEpisodes {
                    let date = ep.airdate != nil ? formatter.date(from: ep.airdate!) : nil
                    var epOverview = ""
                    var isTranslated = false
                    
                    if let fr = frenchOverviews[ep.number] {
                        epOverview = fr
                        isTranslated = false
                    } else {
                        let sourceText = englishOverviews[ep.number] ?? ep.summary?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) ?? ""
                        if !sourceText.isEmpty {
                            if let translatedText = await TranslationService.shared.translate(text: sourceText) {
                                epOverview = translatedText; isTranslated = true
                            } else {
                                epOverview = sourceText; isTranslated = true
                            }
                        }
                    }
                    
                    let newEp = Episode(
                        tvmazeId: ep.id, title: ep.name, season: ep.season, number: ep.number,
                        airDate: date, runtime: ep.runtime, overview: epOverview
                    )
                    newEp.isAutoTranslated = isTranslated
                    newEp.id = "\(newShow.uuid)-\(ep.id)"
                    newEp.show = newShow
                    context.insert(newEp)
                    
                    if let validDate = newEp.airDate, validDate > Date() {
                        NotificationManager.shared.scheduleNotification(for: newEp)
                    }
                }
            }
        }
        
        // 6. Casting
        if let cast = try? await TVMazeService.shared.fetchCast(showId: dto.id) {
            for c in cast.prefix(10) {
                let actor = CastMember(personId: c.person.id, name: c.person.name, characterName: c.character.name, imageUrl: c.person.image?.medium)
                actor.show = newShow
                context.insert(actor)
            }
        }
        
        print("✅ Série ajoutée avec succès : \(dto.name)")
        // AJOUT :
        ToastManager.shared.show("\(dto.name) ajoutée avec succès !", style: .success)

    }
    
    // --- SUPPRESSION ---
    @MainActor
    func deleteShow(_ show: TVShow, context: ModelContext) {
        let name = show.name // On garde le nom avant de supprimer
        context.delete(show)
        ToastManager.shared.show("\(name) supprimée", style: .error)
    }
}
