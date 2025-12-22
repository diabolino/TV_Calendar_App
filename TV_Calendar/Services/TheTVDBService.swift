//
//  TheTVDBService.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 22/12/2025.
//


//
//  TheTVDBService.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 22/12/2025.
//

import Foundation

class TheTVDBService {
    static let shared = TheTVDBService()
    private let baseURL = "https://api4.thetvdb.com/v4"
    private var token: String? = nil
    
    // Structure Auth
    struct AuthResponse: Decodable {
        let data: AuthData
    }
    struct AuthData: Decodable {
        let token: String
    }
    
    // Structure Recherche
    struct ArtworkResponse: Decodable {
        let data: ArtworkData?
    }
    struct ArtworkData: Decodable {
        let artworks: [Artwork]?
    }
    struct Artwork: Decodable {
        let image: String // URL de l'image
        let type: Int // 1 = Banner, 2 = Poster, 3 = Background, etc.
        let language: String?
    }
    
    // 1. Authentification (Récupérer le Token JWT)
    private func authenticate() async throws {
        // Si on a déjà un token valide (implémentation simplifiée sans check d'expiration pour l'instant)
        if token != nil { return }
        
        let url = URL(string: "\(baseURL)/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["apikey": Secrets.tvdbApiKey]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.token = auth.data.token
    }
    
    // 2. Récupérer la bannière via l'ID TVDB (ou recherche par IMDb via un autre endpoint si nécessaire)
    // Note: TVMaze nous donne souvent l'ID TheTVDB dans "externals".
    func fetchBanner(thetvdbId: Int) async -> String? {
        do {
            try await authenticate()
            guard let token = token else { return nil }
            
            // Endpoint pour récupérer les artworks d'une série
            let url = URL(string: "\(baseURL)/series/\(thetvdbId)/artworks?type=1")! // Type 1 = Bannières (Wide)
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let result = try JSONDecoder().decode(ArtworkResponse.self, from: data)
            
            // On cherche la meilleure bannière (priorité français, sinon anglais, sinon la première)
            if let artworks = result.data?.artworks {
                if let frBanner = artworks.first(where: { $0.language == "fra" }) {
                    return frBanner.image
                }
                if let enBanner = artworks.first(where: { $0.language == "eng" }) {
                    return enBanner.image
                }
                return artworks.first?.image
            }
            
        } catch {
            print("❌ TheTVDB Error: \(error)")
        }
        return nil
    }
}