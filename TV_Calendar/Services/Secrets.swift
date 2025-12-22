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
    static let tvdbApiKey = "b764b6be-6b8f-4651-aaf9-f58e891dcce5"
    
    // NOUVEAU : Trakt (Client ID pour la synchro)
    // Obtenez une clé ici : https://trakt.tv/oauth/applications
    static let traktClientId = "bf02515b75340b1248ba4641bf675bd7a354609754f15c9c7f1e7ecb4376c8f6"
    static let traktClientSecret = "18d6917c1dea0a4fa7167540ddc56f2d2d400dcde4f1e6fcc3ad3cba1944c529"
}
