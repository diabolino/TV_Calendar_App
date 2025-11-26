import Foundation

struct TMDBService {
    static let shared = TMDBService()
    private let baseURL = "https://api.themoviedb.org/3"
    
    // Structures pour décoder la réponse TMDB
    struct FindResult: Decodable {
        let tv_results: [TMDBShowDetails]
    }
    
    struct TMDBShowDetails: Decodable {
        let id: Int
        let name: String
        let overview: String // Le résumé en Français !
        let poster_path: String?
        let backdrop_path: String?
        let vote_average: Double?
    }
    
    // On cherche la série sur TMDB via son ID IMDB (fourni par TVMaze)
    // On demande explicitement la langue française (fr-FR)
    func fetchDetails(imdbId: String) async throws -> TMDBShowDetails? {
        let urlString = "\(baseURL)/find/\(imdbId)?api_key=\(Secrets.tmdbApiKey)&external_source=imdb_id&language=fr-FR"
        
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(FindResult.self, from: data)
        
        return result.tv_results.first
    }
    
    // Helper pour construire l'URL complète de l'image TMDB
    static func imageURL(path: String?, width: String = "w500") -> String? {
        guard let path = path else { return nil }
        return "https://image.tmdb.org/t/p/\(width)\(path)"
    }
}