//
//  TVModels.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftData
import Foundation

// Enum pour la qualité
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

@Model
class TVShow {
    // SUPPRESSION DE @Attribute(.unique)
    // AJOUT DE VALEUR PAR DÉFAUT
    var uuid: UUID = UUID()
    
    var tvmazeId: Int = 0
    var name: String = ""
    var overview: String = ""
    var imageUrl: String? = nil
    var bannerUrl: String? = nil
    var network: String? = nil
    var status: String? = nil
    
    // Valeur par défaut obligatoire
    var quality: VideoQuality = VideoQuality.hd1080
    
    var lastUpdatedTimestamp: Int = 0
    
    // Relations optionnelles
    @Relationship(deleteRule: .cascade) var episodes: [Episode]? = []
    @Relationship(deleteRule: .cascade) var cast: [CastMember]? = []
    
    init(tvmazeId: Int, name: String, overview: String, imageUrl: String?, bannerUrl: String? = nil, network: String? = nil, status: String? = nil, quality: VideoQuality = .hd1080, lastUpdatedTimestamp: Int = 0) {
        self.tvmazeId = tvmazeId
        self.name = name
        self.overview = overview
        self.imageUrl = imageUrl
        self.bannerUrl = bannerUrl
        self.network = network
        self.status = status
        self.quality = quality
        self.lastUpdatedTimestamp = lastUpdatedTimestamp
    }
}

@Model
class Episode {
    // PAS de @Attribute(.unique)
    var id: String = UUID().uuidString
    
    var tvmazeId: Int = 0
    var title: String = ""
    var season: Int = 0
    var number: Int = 0
    var airDate: Date? = nil
    
    var isWatched: Bool = false
    // NOUVEAU : Date de visionnage (Optionnelle)
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

@Model
class CastMember {
    // SUPPRESSION DE @Attribute(.unique)
    var id: UUID = UUID()
    
    var personId: Int = 0
    var name: String = ""
    var characterName: String = ""
    var imageUrl: String? = nil
    
    var show: TVShow?
    
    init(personId: Int, name: String, characterName: String, imageUrl: String?) {
        self.personId = personId
        self.name = name
        self.characterName = characterName
        self.imageUrl = imageUrl
    }
}

// --- EXTENSION POUR GÉRER LA DATE AUTOMATIQUEMENT ---
extension Episode {
    func toggleWatched() {
        if isWatched {
            isWatched = false
            watchedDate = nil
        } else {
            isWatched = true
            // On définit la date de visionnage à "Maintenant"
            watchedDate = Date()
        }
    }
}
