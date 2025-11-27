//
//  TranslationService.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//


import Foundation

struct TranslationService {
    static let shared = TranslationService()
    
    // Votre instance privée LibreTranslate
    private let baseURL = "https://darkdiablo.net/translate"
    
    struct TranslationResponse: Decodable {
        let translatedText: String
    }
    
    func translate(text: String, from source: String = "en", to target: String = "fr") async -> String? {
        guard let url = URL(string: baseURL) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Si jamais vous ajoutez une API Key sur votre serveur plus tard, décommentez ceci :
        // request.setValue("VOTRE_API_KEY", forHTTPHeaderField: "X-API-Key")
        
        let body: [String: Any] = [
            "q": text,
            "source": source,
            "target": target,
            "format": "text"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Vérification du statut HTTP
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("⚠️ Erreur Traduction (Status \(httpResponse.statusCode)) sur \(baseURL)")
                return nil
            }
            
            let result = try JSONDecoder().decode(TranslationResponse.self, from: data)
            return result.translatedText
            
        } catch {
            print("❌ Erreur connexion Traduction: \(error)")
            return nil
        }
    }
}
