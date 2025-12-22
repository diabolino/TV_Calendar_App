//
//  TVModels.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//  Updated for Movies & Multi-User (Fixed for SwiftData Macro)
//

import SwiftData
import Foundation

// --- ENUMS ---
enum VideoQuality: String, Codable, CaseIterable {
    case sd = "SD"
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4k = "4K"
    
    var color: String {
        switch self {
        case .sd: return "orange"
        case .hd720: return "blue"
        case .hd1080: return "green"
        case .uhd4k: return "purple"
        }
    }
}

enum WatchStatus: String, Codable, CaseIterable {
    case toWatch = "À voir"
    case watched = "Vu"
    case abandoned = "Abandonné" // Utile pour les films ou séries lâchées
}

// --- MODÈLE UTILISATEUR (Pour le Multi-User) ---
@Model
class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var avatarSymbol: String = "person.circle"
    var colorHex: String = "007AFF"
    var isDefault: Bool = false
    
    init(name: String, avatarSymbol: String = "person.circle", isDefault: Bool = false) {
        self.name = name
        self.avatarSymbol = avatarSymbol
        self.isDefault = isDefault
    }
}

// --- MODÈLE SÉRIE (TVShow) ---
@Model
class TVShow {
    var uuid: UUID = UUID()
    // Lien vers le profil utilisateur (Filtrage)
    var profileId: UUID? = nil
    
    var tvmazeId: Int = 0
    var tmdbId: Int? = nil // Ajouté pour faciliter la synchro Trakt/TMDB
    var imdbId: String? = nil // Ajouté pour TheTVDB lookup
    
    var name: String = ""
    var overview: String = ""
    var imageUrl: String? = nil
    var bannerUrl: String? = nil
    var network: String? = nil
    var status: String? = nil
    
    // CORRECTION ICI : Utilisation du type complet VideoQuality.hd1080
    var quality: VideoQuality = VideoQuality.hd1080
    var lastUpdatedTimestamp: Int = 0
    
    // Trakt Sync Info
    var traktId: Int? = nil
    var lastTraktSync: Date? = nil
    
    @Relationship(deleteRule: .cascade) var episodes: [Episode]? = []
    @Relationship(deleteRule: .cascade) var cast: [CastMember]? = []
    
    init(tvmazeId: Int, name: String, overview: String, imageUrl: String?, bannerUrl: String? = nil, network: String? = nil, status: String? = nil, quality: VideoQuality = .hd1080, profileId: UUID? = nil) {
        self.tvmazeId = tvmazeId
        self.name = name
        self.overview = overview
        self.imageUrl = imageUrl
        self.bannerUrl = bannerUrl
        self.network = network
        self.status = status
        self.quality = quality
        self.profileId = profileId
    }
}

// --- MODÈLE ÉPISODE ---
@Model
class Episode {
    var id: String = UUID().uuidString
    
    var tvmazeId: Int = 0
    var title: String = ""
    var season: Int = 0
    var number: Int = 0
    var airDate: Date? = nil
    
    var isWatched: Bool = false
    var watchedDate: Date? = nil
    
    var runtime: Int? = nil
    var overview: String? = nil
    var isAutoTranslated: Bool = false
    
    var show: TVShow?
    
    init(tvmazeId: Int, title: String, season: Int, number: Int, airDate: Date?, runtime: Int? = nil, overview: String? = nil) {
        self.id = UUID().uuidString
        self.tvmazeId = tvmazeId
        self.title = title
        self.season = season
        self.number = number
        self.airDate = airDate
        self.runtime = runtime
        self.overview = overview
    }
}

// --- NOUVEAU : MODÈLE FILM (Movie) ---
@Model
class Movie {
    var uuid: UUID = UUID()
    var profileId: UUID? = nil // Pour le multi-user
    
    var tmdbId: Int = 0
    var imdbId: String? = nil
    var title: String = ""
    var originalTitle: String? = nil
    var overview: String = ""
    
    var posterUrl: String? = nil
    var backdropUrl: String? = nil
    
    var releaseDate: Date? = nil
    var runtime: Int? = 0 // minutes
    
    // CORRECTION ICI : Utilisation du type complet WatchStatus.toWatch
    var status: WatchStatus = WatchStatus.toWatch
    var watchedDate: Date? = nil
    var rating: Double? = nil // Votre note persos ou TMDB
    
    // CORRECTION ICI : Utilisation du type complet VideoQuality.hd1080
    var quality: VideoQuality = VideoQuality.hd1080
    
    @Relationship(deleteRule: .cascade) var cast: [CastMember]? = []
    
    init(tmdbId: Int, title: String, overview: String, posterUrl: String?, releaseDate: Date?, profileId: UUID? = nil) {
        self.tmdbId = tmdbId
        self.title = title
        self.overview = overview
        self.posterUrl = posterUrl
        self.releaseDate = releaseDate
        self.profileId = profileId
    }
}

// --- MODÈLE CASTING (Partagé Séries/Films) ---
@Model
class CastMember {
    var id: UUID = UUID()
    
    var personId: Int = 0 // TMDB Person ID ou TVMaze ID selon la source
    var name: String = ""
    var characterName: String = ""
    var imageUrl: String? = nil
    
    var show: TVShow?
    var movie: Movie? // Nouveau lien optionnel
    
    init(personId: Int, name: String, characterName: String, imageUrl: String?) {
        self.personId = personId
        self.name = name
        self.characterName = characterName
        self.imageUrl = imageUrl
    }
}

extension Episode {
    func toggleWatched() {
        if isWatched {
            isWatched = false
            watchedDate = nil
        } else {
            isWatched = true
            watchedDate = Date()
        }
    }
}
