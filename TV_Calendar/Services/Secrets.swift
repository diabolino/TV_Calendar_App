//
//  Secrets.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import Foundation

struct Secrets {
    // TMDB (Déjà présent)
    static let tmdbApiKey = "a3e2775c4d38fe179721bf2318760c9f"
    
    // NOUVEAU : TheTVDB (Nécessaire pour le fallback bannière)
    // Obtenez une clé ici : https://thetvdb.com/api-information
    static let tvdbApiKey = "3bd317ae-c2ed-410c-af87-87995d383b4b"
    
    // NOUVEAU : Trakt (Client ID pour la synchro)
    // Obtenez une clé ici : https://trakt.tv/oauth/applications
    static let traktClientId = "e12e9cf0e13c518960af73246b1934191335410a74887eca63d2bb7ca1a98d25"
    static let traktClientSecret = "a39a83144f83d424eaa272c54b92a9d3f77d0ec8e8bd31e8677c4a3959796542"
}
