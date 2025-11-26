import Foundation

struct TranslationService {
    static let shared = TranslationService()
    
    // On utilise une instance publique de LibreTranslate (Attention aux limites)
    // Idéalement, remplacez par votre propre serveur si vous en avez un (comme sur le repo original)
    private let baseURL = "https://translate.argosopentech.com/translate" 
    
    struct TranslationResponse: Decodable {
        let translatedText: String
    }
    
    func translate(text: String, from source: String = "en", to target: String = "fr") async -> String? {
        guard let url = URL(string: baseURL) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "q": text,
            "source": source,
            "target": target,
            "format": "text"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Vérification simple du statut HTTP
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("⚠️ Erreur Traduction API: \(httpResponse.statusCode)")
                return nil
            }
            
            let result = try JSONDecoder().decode(TranslationResponse.self, from: data)
            return result.translatedText
            
        } catch {
            print("❌ Erreur Traduction: \(error)")
            return nil
        }
    }
}