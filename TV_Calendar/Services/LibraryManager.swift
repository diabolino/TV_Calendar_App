//
//  LibraryManager.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//  Updated for Movies, Profiles & TheTVDB Fallback
//

import Foundation
import SwiftData
import SwiftUI

class LibraryManager {
    static let shared = LibraryManager()
    
    // --- AJOUT D'UNE SÉRIE ---
    @MainActor
    func addShow(dto: TVMazeService.ShowDTO, quality: VideoQuality, profileId: String?, context: ModelContext, existingShows: [TVShow]) async {
        
        let profileUUID = profileId != nil ? UUID(uuidString: profileId!) : nil
        
        // 1. Vérification doublons (pour CE profil)
        if existingShows.contains(where: { $0.tvmazeId == dto.id && $0.profileId == profileUUID }) {
            ToastManager.shared.show("Cette série est déjà dans ce profil", style: .error)
            return
        }
        
        ToastManager.shared.show("Ajout de \(dto.name)...", style: .info)
        
        // 2. Récupération détails TVMaze (Mise à jour IDs)
        var finalBannerUrl: String? = nil
        var finalNetwork = dto.network?.name ?? dto.webChannel?.name
        var finalStatus = dto.status
        var imdbIdForSearch: String? = dto.externals?.imdb
        var thetvdbId: Int? = dto.externals?.thetvdb
        
        if let details = try? await TVMazeService.shared.fetchShowWithImages(id: dto.id) {
            finalBannerUrl = TVMazeService.shared.extractBanner(from: details)
            finalNetwork = details.network?.name ?? details.webChannel?.name
            finalStatus = details.status
            imdbIdForSearch = details.externals?.imdb
            thetvdbId = details.externals?.thetvdb
        }
        
        // --- LOGIQUE FALLBACK BANNIÈRE TheTVDB ---
        if finalBannerUrl == nil, let tvdbId = thetvdbId {
            print("⚠️ Pas de bannière TVMaze. Tentative via TheTVDB...")
            if let tvdbBanner = await TheTVDBService.shared.fetchBanner(thetvdbId: tvdbId) {
                finalBannerUrl = tvdbBanner
                print("✅ Bannière trouvée sur TheTVDB !")
            }
        }
        // -----------------------------------------
        
        // 3. Enrichissement TMDB (Description FR + Poster HQ)
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
            quality: quality,
            profileId: profileUUID
        )
        newShow.tmdbId = tmdbId
        newShow.imdbId = imdbIdForSearch
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
        
        ToastManager.shared.show("\(dto.name) ajoutée !", style: .success)
    }
    
    // --- AJOUT D'UN FILM ---
    @MainActor
    func addMovie(tmdbId: Int, profileId: String?, context: ModelContext, existingMovies: [Movie]) async {
        let profileUUID = profileId != nil ? UUID(uuidString: profileId!) : nil
        
        if existingMovies.contains(where: { $0.tmdbId == tmdbId && $0.profileId == profileUUID }) {
            ToastManager.shared.show("Ce film est déjà dans votre liste", style: .error)
            return
        }
        
        ToastManager.shared.show("Récupération du film...", style: .info)
        
        guard let details = try? await TMDBService.shared.fetchMovieDetails(id: tmdbId) else {
            ToastManager.shared.show("Erreur récupération film", style: .error)
            return
        }
        
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let releaseDate = details.release_date != nil ? formatter.date(from: details.release_date!) : nil
        
        let newMovie = Movie(
            tmdbId: details.id,
            title: details.title,
            overview: details.overview ?? "",
            posterUrl: TMDBService.imageURL(path: details.poster_path),
            releaseDate: releaseDate,
            profileId: profileUUID
        )
        newMovie.originalTitle = details.original_title
        newMovie.backdropUrl = TMDBService.imageURL(path: details.backdrop_path, width: "original")
        newMovie.runtime = details.runtime
        newMovie.rating = details.vote_average
        
        context.insert(newMovie)
        
        // Casting Film
        if let cast = try? await TMDBService.shared.fetchMovieCast(id: tmdbId) {
            for c in cast.prefix(8) {
                let actor = CastMember(personId: c.id, name: c.name, characterName: c.character ?? "Inconnu", imageUrl: TMDBService.imageURL(path: c.profile_path, width: "w185"))
                actor.movie = newMovie
                context.insert(actor)
            }
        }
        
        ToastManager.shared.show("\(details.title) ajouté !", style: .success)
    }
    
    // --- SUPPRESSION ---
    @MainActor
    func deleteShow(_ show: TVShow, context: ModelContext) {
        let name = show.name
        context.delete(show)
        ToastManager.shared.show("\(name) supprimée", style: .error)
    }
    
    @MainActor
    func deleteMovie(_ movie: Movie, context: ModelContext) {
        let title = movie.title
        context.delete(movie)
        ToastManager.shared.show("\(title) supprimé", style: .error)
    }
}
