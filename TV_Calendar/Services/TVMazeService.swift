//
//  APIService.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import Foundation

struct APIService {
    static let shared = APIService()
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
        let externals: ExternalsDTO? // <--- AJOUT
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
}
