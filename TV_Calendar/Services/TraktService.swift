//
//  TraktService.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 22/12/2025.
//  Updated for Full Sync (Movies + Episodes + Mark Watched)
//

import Foundation
import AuthenticationServices
import SwiftUI

@Observable
class TraktService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = TraktService()
    
    // --- CONFIGURATION ---
    // Assurez-vous que Secrets.swift contient bien vos clés
    private let clientID = Secrets.traktClientId
    private let clientSecret = Secrets.traktClientSecret
    private let redirectURI = "tvcalendar://auth"
    private let baseURL = "https://api.trakt.tv"
    
    var isAuthenticated = false
    private var currentProfileId: String?
    
    override init() { super.init() }
    
    func configure(for profileId: String?) {
        self.currentProfileId = profileId
        checkAuthentication()
    }
    
    private func getTokenKey() -> String {
        guard let pid = currentProfileId else { return "trakt_token_global" }
        return "trakt_token_\(pid)"
    }
    
    func checkAuthentication() {
        if let token = UserDefaults.standard.string(forKey: getTokenKey()), !token.isEmpty {
            self.isAuthenticated = true
        } else {
            self.isAuthenticated = false
        }
    }
    
    // ====================================================
    // MARK: - 1. AUTHENTIFICATION
    // ====================================================
    
    @MainActor
    func signIn() async {
        guard let authURL = URL(string: "https://trakt.tv/oauth/authorize?response_type=code&client_id=\(clientID)&redirect_uri=\(redirectURI)") else { return }
        do {
            let callbackURL = try await ASWebAuthenticationSession.perform(url: authURL, callbackURLScheme: "tvcalendar")
            guard let code = URLComponents(string: callbackURL.absoluteString)?.queryItems?.first(where: { $0.name == "code" })?.value else { return }
            await exchangeCodeForToken(code: code)
        } catch { print("❌ Trakt Auth: \(error)") }
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: getTokenKey())
        self.isAuthenticated = false
        ToastManager.shared.show("Déconnecté", style: .info)
    }
    
    private func exchangeCodeForToken(code: String) async {
        guard let url = URL(string: "\(baseURL)/oauth/token") else { return }
        let body = ["code": code, "client_id": clientID, "client_secret": clientSecret, "redirect_uri": redirectURI, "grant_type": "authorization_code"]
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let response = try JSONDecoder().decode(TraktTokenResponse.self, from: data)
            UserDefaults.standard.set(response.access_token, forKey: getTokenKey())
            await MainActor.run {
                self.isAuthenticated = true
                ToastManager.shared.show("Connecté à Trakt !", style: .success)
            }
        } catch {
            print("❌ Trakt Token Error: \(error)")
        }
    }
    
    // ====================================================
    // MARK: - 2. RÉCUPÉRATION (SYNC DOWN)
    // ====================================================
    
    func fetchWatchedShows() async throws -> [TraktWatchedShow] {
        return try await fetch(endpoint: "/sync/watched/shows?extended=full")
    }
    
    func fetchWatchedMovies() async throws -> [TraktWatchedMovie] {
        return try await fetch(endpoint: "/sync/watched/movies?extended=full")
    }
    
    private func fetch<T: Decodable>(endpoint: String) async throws -> T {
        guard let token = UserDefaults.standard.string(forKey: getTokenKey()) else { throw URLError(.userAuthenticationRequired) }
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("2", forHTTPHeaderField: "trakt-api-version")
        req.setValue(clientID, forHTTPHeaderField: "trakt-api-key")
        
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // ====================================================
    // MARK: - 3. ENVOI (SYNC UP)
    // ====================================================
    
    /// Marquer un ÉPISODE comme vu
    func markEpisodeWatched(imdbId: String?, tmdbId: Int? = nil, title: String?, season: Int, number: Int) async {
        guard isAuthenticated, let token = UserDefaults.standard.string(forKey: getTokenKey()) else { return }
        
        print("📤 Envoi Episode vers Trakt : \(title ?? "?") S\(season)E\(number)")
        
        // Construction IDs
        var ids: [String: Any] = [:]
        if let imdb = imdbId { ids["imdb"] = imdb }
        if let tmdb = tmdbId { ids["tmdb"] = tmdb }
        
        var showObj: [String: Any] = [:]
        if !ids.isEmpty { showObj["ids"] = ids }
        else if let t = title { showObj["title"] = t }
        else { return }
        
        let body: [String: Any] = [
            "shows": [[
                "ids": showObj["ids"] ?? [:],
                "title": showObj["title"] ?? "",
                "seasons": [[ "number": season, "episodes": [[ "number": number ]] ]]
            ]]
        ]
        
        await sendSyncRequest(body: body)
    }
    
    /// Marquer un FILM comme vu
    func markMovieWatched(tmdbId: Int, title: String) async {
        guard isAuthenticated, let token = UserDefaults.standard.string(forKey: getTokenKey()) else {
            print("⚠️ Trakt: Non connecté, envoi film annulé.")
            return
        }
        
        print("🍿 Envoi Film vers Trakt : \(title) (TMDB: \(tmdbId))")
        
        if tmdbId == 0 {
            print("⚠️ Erreur : ID TMDB est 0. Impossible d'envoyer à Trakt.")
            return
        }
        
        let body: [String: Any] = [
            "movies": [[
                "ids": ["tmdb": tmdbId],
                "title": title
            ]]
        ]
        
        await sendSyncRequest(body: body)
    }
    
    /// Helper générique d'envoi
    private func sendSyncRequest(body: [String: Any]) async {
        guard let token = UserDefaults.standard.string(forKey: getTokenKey()) else { return }
        let url = URL(string: "\(baseURL)/sync/history")!
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("2", forHTTPHeaderField: "trakt-api-version")
        req.setValue(clientID, forHTTPHeaderField: "trakt-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    print("✅ Trakt Sync: Succès !")
                } else {
                    print("❌ Trakt Sync: Erreur \(httpResponse.statusCode)")
                    if let str = String(data: data, encoding: .utf8) { print("   Réponse: \(str)") }
                }
            }
        } catch {
            print("❌ Erreur réseau Trakt: \(error)")
        }
    }
    
    // --- UTILS ASWEB ---
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { ASPresentationAnchor() }
}

// ====================================================
// MARK: - MODELS DECODABLE
// ====================================================

struct TraktTokenResponse: Decodable { let access_token: String }

struct TraktWatchedShow: Decodable {
    let plays: Int
    let last_watched_at: String?
    let show: TraktShow
    let seasons: [TraktWatchedSeason]?
}
struct TraktWatchedSeason: Decodable { let number: Int; let episodes: [TraktWatchedEpisode] }
struct TraktWatchedEpisode: Decodable { let number: Int; let plays: Int; let last_watched_at: String? }

struct TraktWatchedMovie: Decodable {
    let plays: Int
    let last_watched_at: String?
    let movie: TraktMovie
}

struct TraktShow: Decodable { let title: String; let ids: TraktIds }
struct TraktMovie: Decodable { let title: String; let ids: TraktIds }

// Note: TraktIds est défini dans TraktImportManager.swift
// Extension ASWebAuthenticationSession identique...
extension ASWebAuthenticationSession {
    static func perform(url: URL, callbackURLScheme: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { callbackURL, error in
                if let error = error { continuation.resume(throwing: error) }
                else if let callbackURL = callbackURL { continuation.resume(returning: callbackURL) }
                else { continuation.resume(throwing: URLError(.unknown)) }
            }
            session.presentationContextProvider = TraktService.shared
            session.start()
        }
    }
}
