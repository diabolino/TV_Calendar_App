//
//  TVMazeService.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import Foundation

struct TVMazeService {
    static let shared = TVMazeService()
    private let baseURL = "https://api.tvmaze.com"
    
    // Structures pour décoder le JSON (DTO)
    struct SearchResult: Decodable {
        let show: ShowDTO
    }
    
    struct ShowDTO: Decodable {
        let id: Int
        let name: String
        let summary: String?
        let image: ImageDTO?
        let status: String?
        let network: NetworkDTO?
        let webChannel: NetworkDTO?
        let externals: ExternalsDTO?
        let _embedded: EmbeddedImagesDTO?
    }
    
    struct ExternalsDTO: Decodable {
        let imdb: String? // C'est la clé de liaison !
    }
    
    struct NetworkDTO: Decodable {
        let name: String
    }
    
    struct ImageDTO: Decodable {
        let medium: String?
        let original: String?
    }
    
    struct EmbeddedImagesDTO: Decodable {
        let images: [ShowImageDTO]
    }
        
    // Structure Image CORRIGÉE
    struct ShowImageDTO: Decodable {
        let type: String? // <--- AJOUT DU ? ICI (Le type peut être null)
        let resolutions: ImageResolutionsDTO
    }
    
    struct ImageResolutionsDTO: Decodable {
        let original: ImageResolutionDetailsDTO
    }
    
    struct ImageResolutionDetailsDTO: Decodable {
        let url: String
        let width: Int
        let height: Int
    }
    
    struct EpisodeDTO: Decodable {
        let id: Int
        let name: String
        let season: Int
        let number: Int
        let airdate: String?
        let summary: String?
        let runtime: Int? // <--- AJOUTER CECI
        
    }
    
    struct CastCreditDTO: Decodable {
            let person: PersonDTO
            let character: CharacterDTO
    }
    
    struct PersonDTO: Decodable {
        let id: Int
        let name: String
        let image: ImageDTO?
    }
    
    struct CharacterDTO: Decodable {
        let name: String
    }

    // 1. Rechercher une série
    func searchShow(query: String) async throws -> [ShowDTO] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/shows?q=\(encodedQuery)") else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let results = try JSONDecoder().decode([SearchResult].self, from: data)
        return results.map { $0.show }
    }
    
    // 2. Récupérer les épisodes d'une série
    func fetchEpisodes(showId: Int) async throws -> [EpisodeDTO] {
        guard let url = URL(string: "\(baseURL)/shows/\(showId)/episodes") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([EpisodeDTO].self, from: data)
    }
    
    func fetchCast(showId: Int) async throws -> [CastCreditDTO] {
        guard let url = URL(string: "\(baseURL)/shows/\(showId)/cast") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([CastCreditDTO].self, from: data)
    }
    
    func fetchUpdates() async throws -> [Int: Int] {
        guard let url = URL(string: "\(baseURL)/updates/shows") else { return [:] }
        let (data, _) = try await URLSession.shared.data(from: url)
        // L'API renvoie un objet JSON simple : { "1": 1732123, "2": 1543212 ... }
        return try JSONDecoder().decode([String: Int].self, from: data).reduce(into: [Int: Int]()) { (result, pair) in
            if let id = Int(pair.key) {
                result[id] = pair.value
            }
        }
    }
    
    func fetchShow(id: Int) async throws -> ShowDTO {
        guard let url = URL(string: "\(baseURL)/shows/\(id)") else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ShowDTO.self, from: data)
    }
    
    // Récupère la série avec les images incluses
    func fetchShowWithImages(id: Int) async throws -> ShowDTO {
        guard let url = URL(string: "\(baseURL)/shows/\(id)?embed=images") else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ShowDTO.self, from: data)
    }
    
    // Helper pour extraire la bannière
    func extractBanner(from dto: ShowDTO) -> String? {
        guard let images = dto._embedded?.images else {
            print("⚠️ Aucune image 'embedded' trouvée pour ID \(dto.id)")
            return nil
        }
        
        // DEBUG : Voir ce qu'on reçoit
        // print("🔎 Images trouvées pour \(dto.name): \(images.count)")
        // for img in images { print("   - Type: \(img.type) | Size: \(img.resolutions.original.width)x\(img.resolutions.original.height)") }
        
        // 1. PRIORITÉ : On cherche la bannière standard (758x140)
        if let perfectBanner = images.first(where: {
            $0.type == "banner" &&
            $0.resolutions.original.width == 758 &&
            $0.resolutions.original.height == 140
        }) {
            return perfectBanner.resolutions.original.url
        }
        
        // 2. PLAN B (Nouveau) : On cherche une bannière avec une largeur proche (entre 700 et 800)
        if let closeBanner = images.first(where: {
            $0.type == "banner" &&
            $0.resolutions.original.width > 700
        }) {
            print("⚠️ Bannière 'Plan B' utilisée (Taille non standard)")
            return closeBanner.resolutions.original.url
        }
        
        // 3. PLAN C : N'importe quelle image taguée "banner", peu importe la taille
        if let anyBanner = images.first(where: { $0.type == "banner" }) {
            print("⚠️ Bannière 'Plan C' utilisée (N'importe laquelle)")
            return anyBanner.resolutions.original.url
        }
        
        return nil
    }
        
    // --- NOUVEAU : Lookup pour l'import Trakt ---
    // Doc: https://www.tvmaze.com/api#show-lookup
    func lookupShow(imdbId: String?, tvdbId: Int?) async throws -> ShowDTO? {
        var urlString: String? = nil
        
        if let imdb = imdbId, !imdb.isEmpty {
            urlString = "\(baseURL)/lookup/shows?imdb=\(imdb)"
        } else if let tvdb = tvdbId {
            urlString = "\(baseURL)/lookup/shows?thetvdb=\(tvdb)"
        }
        
        guard let validUrlString = urlString, let url = URL(string: validUrlString) else { return nil }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            return nil // Pas trouvé
        }
        
        return try JSONDecoder().decode(ShowDTO.self, from: data)
    }
}
