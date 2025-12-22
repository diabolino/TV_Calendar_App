//
//  TMDBService.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//  Updated for Movies Support
//

import Foundation

struct TMDBService {
    static let shared = TMDBService()
    private let baseURL = "https://api.themoviedb.org/3"
    
    // --- Structures de réponse TMDB (Séries & Films) ---
    struct FindResult: Decodable {
        let tv_results: [TMDBShowDetails]?
        let movie_results: [TMDBMovieDetails]?
    }
    
    struct SearchResult: Decodable {
        let results: [TMDBShowDetails]
    }
    
    struct MovieSearchResult: Decodable {
        let results: [TMDBMovieDetails]
    }
    
    struct TMDBShowDetails: Decodable {
        let id: Int
        let name: String
        let overview: String?
        let poster_path: String?
        let backdrop_path: String?
        let vote_average: Double?
    }
    
    struct TMDBMovieDetails: Decodable {
        let id: Int
        let title: String
        let original_title: String?
        let overview: String?
        let poster_path: String?
        let backdrop_path: String?
        let release_date: String?
        let runtime: Int?
        let vote_average: Double?
    }
    
    struct SeasonDetailsDTO: Decodable {
        let episodes: [TMDBEpisodeDTO]
    }
        
    struct TMDBEpisodeDTO: Decodable {
        let episode_number: Int
        let name: String
        let overview: String?
        let still_path: String?
    }
    
    struct CreditsResponse: Decodable {
        let cast: [TMDBCastMember]
    }
    
    struct TMDBCastMember: Decodable {
        let id: Int
        let name: String
        let character: String?
        let profile_path: String?
    }
    
    // --- GESTION DES IMAGES ---
    struct ImagesResponse: Decodable {
        let posters: [TMDBImageInfo]?
        let backdrops: [TMDBImageInfo]?
    }
    
    struct TMDBImageInfo: Decodable, Identifiable {
        let file_path: String
        let vote_average: Double?
        let height: Int
        let width: Int
        var id: String { file_path }
    }
    
    // --- FONCTIONS FILMS ---
    
    // Rechercher un film
    func searchMovie(query: String) async throws -> [TMDBMovieDetails] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let urlString = "\(baseURL)/search/movie?api_key=\(Secrets.tmdbApiKey)&query=\(encodedQuery)&language=fr-FR"
        guard let url = URL(string: urlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(MovieSearchResult.self, from: data)
        return result.results
    }
    
    // Détails complets d'un film
    func fetchMovieDetails(id: Int) async throws -> TMDBMovieDetails {
        let urlString = "\(baseURL)/movie/\(id)?api_key=\(Secrets.tmdbApiKey)&language=fr-FR"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(TMDBMovieDetails.self, from: data)
    }
    
    // Casting d'un film
    func fetchMovieCast(id: Int) async throws -> [TMDBCastMember] {
        let urlString = "\(baseURL)/movie/\(id)/credits?api_key=\(Secrets.tmdbApiKey)&language=fr-FR"
        guard let url = URL(string: urlString) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(CreditsResponse.self, from: data).cast
    }

    // --- FONCTIONS SÉRIES (Existantes + Améliorations) ---
    
    func fetchPosters(tmdbId: Int) async throws -> [TMDBImageInfo] {
        let urlString = "\(baseURL)/tv/\(tmdbId)/images?api_key=\(Secrets.tmdbApiKey)&include_image_language=fr,en,null"
        guard let url = URL(string: urlString) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(ImagesResponse.self, from: data)
        return result.posters?.sorted { ($0.vote_average ?? 0) > ($1.vote_average ?? 0) } ?? []
    }
    
    func fetchSeasonDetails(tmdbShowId: Int, seasonNumber: Int, language: String) async throws -> SeasonDetailsDTO {
        let urlString = "\(baseURL)/tv/\(tmdbShowId)/season/\(seasonNumber)?api_key=\(Secrets.tmdbApiKey)&language=\(language)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SeasonDetailsDTO.self, from: data)
    }
    
    func findShowByExternalId(imdbId: String) async throws -> TMDBShowDetails? {
        let urlString = "\(baseURL)/find/\(imdbId)?api_key=\(Secrets.tmdbApiKey)&external_source=imdb_id&language=fr-FR"
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(FindResult.self, from: data)
        return result.tv_results?.first
    }
    
    func searchShowByName(query: String) async throws -> TMDBShowDetails? {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlString = "\(baseURL)/search/tv?api_key=\(Secrets.tmdbApiKey)&query=\(encodedQuery)&language=fr-FR"
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(SearchResult.self, from: data)
        return result.results.first
    }
    
    static func imageURL(path: String?, width: String = "original") -> String? {
        guard let path = path else { return nil }
        return "https://image.tmdb.org/t/p/\(width)\(path)"
    }
}
