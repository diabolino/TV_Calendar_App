//
//  TMDBService.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//


import Foundation

struct TMDBService {
    static let shared = TMDBService()
    private let baseURL = "https://api.themoviedb.org/3"
    
    // --- Structures de réponse TMDB ---
    struct FindResult: Decodable {
        let tv_results: [TMDBShowDetails]
    }
    
    struct SearchResult: Decodable {
        let results: [TMDBShowDetails]
    }
    
    struct TMDBShowDetails: Decodable {
        let id: Int           // ID TMDB (ex: 1396)
        let name: String
        let overview: String? // Résumé en Français
        let poster_path: String?
        let backdrop_path: String?
        let vote_average: Double?
    }
    
    struct SeasonDetailsDTO: Decodable {
            let episodes: [TMDBEpisodeDTO]
        }
        
    struct TMDBEpisodeDTO: Decodable {
        let episode_number: Int
        let name: String
        let overview: String?
        let still_path: String? // Image de l'épisode (bonus !)
    }
    
    // --- GESTION DES POSTERS ---
    struct ImagesResponse: Decodable {
        let posters: [TMDBImageInfo]
    }
    
    struct TMDBImageInfo: Decodable, Identifiable {
        let file_path: String
        let vote_average: Double? // Utile pour trier par popularité
        let height: Int
        let width: Int
        
        // Identifiant calculé pour SwiftUI
        var id: String { file_path }
    }
    
    // Récupérer tous les posters d'une série
    func fetchPosters(tmdbId: Int) async throws -> [TMDBImageInfo] {
        // On demande les langues fr, en et null (sans texte)
        let urlString = "\(baseURL)/tv/\(tmdbId)/images?api_key=\(Secrets.tmdbApiKey)&include_image_language=fr,en,null"
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(ImagesResponse.self, from: data)
        
        // On renvoie les posters triés par note (les plus beaux en premier)
        return result.posters.sorted { ($0.vote_average ?? 0) > ($1.vote_average ?? 0) }
    }
    
    // Récupérer les détails d'une saison spécifique dans une langue donnée
    func fetchSeasonDetails(tmdbShowId: Int, seasonNumber: Int, language: String) async throws -> SeasonDetailsDTO {
        let urlString = "\(baseURL)/tv/\(tmdbShowId)/season/\(seasonNumber)?api_key=\(Secrets.tmdbApiKey)&language=\(language)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SeasonDetailsDTO.self, from: data)
    }
    
    // 1. Méthode PRÉCISE : On utilise l'ID IMDb fourni par TVMaze pour trouver la série sur TMDB
    // Endpoint: /find/{external_id}
    func findShowByExternalId(imdbId: String) async throws -> TMDBShowDetails? {
        let urlString = "\(baseURL)/find/\(imdbId)?api_key=\(Secrets.tmdbApiKey)&external_source=imdb_id&language=fr-FR"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(FindResult.self, from: data)
        
        return result.tv_results.first
    }
    
    // 2. Méthode DE SECOURS : On cherche par le nom si TVMaze n'a pas donné d'ID IMDb
    // Endpoint: /search/tv
    func searchShowByName(query: String) async throws -> TMDBShowDetails? {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlString = "\(baseURL)/search/tv?api_key=\(Secrets.tmdbApiKey)&query=\(encodedQuery)&language=fr-FR"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(SearchResult.self, from: data)
        
        // On prend le premier résultat qui correspond
        return result.results.first
    }
    
    // Helper pour l'image
    static func imageURL(path: String?, width: String = "original") -> String? {
        guard let path = path else { return nil }
        return "https://image.tmdb.org/t/p/\(width)\(path)"
    }
}
