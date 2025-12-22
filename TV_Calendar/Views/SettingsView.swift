//
//  SettingsView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 27/11/2025.
//  Updated for Trakt OAuth
//

import SwiftUI
import SwiftData
import SDWebImage
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Gestion Profil
    @AppStorage("currentProfileId") private var currentProfileId: String?
    @Query private var userProfiles: [UserProfile]
    
    // Préférences
    @AppStorage("defaultQuality") private var defaultQuality: VideoQuality = .hd1080
    
    // Service Trakt
    @State private var traktService = TraktService.shared
    @State private var isSyncingTrakt = false
    
    // États techniques
    @State private var cacheSize: String = "Calcul..."
    @State private var isSyncing = false
    
    // Import/Export
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var showFileImporter = false
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false
    
    var currentProfileName: String {
        if let id = currentProfileId, let profile = userProfiles.first(where: { $0.id.uuidString == id }) {
            return profile.name
        }
        return "Inconnu"
    }
    
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (Build \(build))"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // --- SECTION PROFIL ---
                Section("Profil Actuel") {
                    HStack {
                        Text("Connecté en tant que :")
                        Spacer()
                        Text(currentProfileName).bold().foregroundColor(.accentPurple)
                    }
                    Button(role: .destructive) {
                        currentProfileId = nil
                    } label: {
                        Label("Changer de profil", systemImage: "person.2.circle")
                    }
                }
                
                // --- SECTION TRAKT (FACULTATIF) ---
                Section("Trakt.tv (Optionnel)") {
                    if traktService.isAuthenticated {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Connecté")
                            Spacer()
                            Button("Déconnexion") {
                                traktService.signOut()
                            }
                            .font(.caption).buttonStyle(.bordered)
                        }
                        
                        Button(action: syncTrakt) {
                            HStack {
                                Label("Synchroniser maintenant", systemImage: "arrow.triangle.2.circlepath")
                                if isSyncingTrakt { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(isSyncingTrakt)
                    } else {
                        Button(action: {
                            Task { await traktService.signIn() }
                        }) {
                            Label("Se connecter avec Trakt", systemImage: "link")
                                .foregroundColor(.accentPurple)
                        }
                        Text("Synchronisez votre historique automatiquement.")
                            .font(.caption).foregroundColor(.gray)
                    }
                }
                
                // --- SECTION PRÉFÉRENCES ---
                Section("Préférences") {
                    Picker("Qualité par défaut", selection: $defaultQuality) {
                        ForEach(VideoQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // --- SECTION SAUVEGARDE ---
                Section("Sauvegarde Locale") {
                    Button(action: exportData) {
                        Label("Exporter une sauvegarde", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showFileImporter = true }) {
                        Label("Importer une sauvegarde", systemImage: "square.and.arrow.down")
                    }
                }
                
                // --- SECTION STOCKAGE ---
                Section("Stockage") {
                    HStack {
                        Text("Cache Images")
                        Spacer()
                        Text(cacheSize).foregroundStyle(.secondary)
                    }
                    Button("Vider le cache") { clearCache() }.foregroundStyle(.red)
                }
                
                // --- SECTION AIDE ---
                Section("Aide") {
                    Link(destination: URL(string: "https://diabolino.github.io/TV_Calendar_contact/#support")!) {
                        Label("Support / FAQ", systemImage: "questionmark.circle")
                    }
                }
                
                // --- ABOUT ---
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("TV Calendar").font(.headline)
                            Text(appVersion).font(.caption).foregroundStyle(.gray)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Réglages")
            .onAppear {
                calculateCacheSize()
                traktService.configure(for: currentProfileId)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL { ShareSheet(activityItems: [url]) }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                handleImport(result: result)
            }
            .alert("Importation", isPresented: $showImportAlert) {
                Button("OK", role: .cancel) { }
            } message: { Text(importAlertMessage) }
        }
    }
    
    // --- LOGIQUE SYNC TRAKT ---
    
    // --- LOGIQUE SYNC TRAKT ---
        
    func syncTrakt() {
        isSyncingTrakt = true
        Task {
            do {
                // 1. SÉRIES
                let watchedShows = try await traktService.fetchWatchedShows()
                await MainActor.run { ToastManager.shared.show("Sync Séries (\(watchedShows.count))...", style: .info) }
                
                let descShows = FetchDescriptor<TVShow>()
                let existingShows = (try? modelContext.fetch(descShows)) ?? []
                
                let msgShows = await TraktImportManager.shared.processApiSyncShows(
                    items: watchedShows,
                    profileId: currentProfileId,
                    context: modelContext,
                    existingShows: existingShows
                )
                
                // 2. FILMS
                let watchedMovies = try await traktService.fetchWatchedMovies()
                await MainActor.run { ToastManager.shared.show("Sync Films (\(watchedMovies.count))...", style: .info) }
                
                let descMovies = FetchDescriptor<Movie>()
                let existingMovies = (try? modelContext.fetch(descMovies)) ?? []
                
                let msgMovies = await TraktImportManager.shared.processApiSyncMovies(
                    items: watchedMovies,
                    profileId: currentProfileId,
                    context: modelContext,
                    existingMovies: existingMovies
                )
                
                await MainActor.run {
                    importAlertMessage = "\(msgShows)\n\(msgMovies)"
                    showImportAlert = true
                    isSyncingTrakt = false
                }
                
            } catch {
                await MainActor.run {
                    ToastManager.shared.show("Erreur Sync: \(error.localizedDescription)", style: .error)
                    isSyncingTrakt = false
                }
            }
        }
    }
    
    // --- LOGIQUE STANDARD (Inchangée) ---
    
    func exportData() {
        if let url = ImportExportManager.shared.generateBackupFile(context: modelContext) {
            exportURL = url
            showShareSheet = true
        }
    }
    
    func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    let count = try await ImportExportManager.shared.restoreBackup(from: url, context: modelContext)
                    await MainActor.run {
                        importAlertMessage = "Succès ! \(count) éléments importés."
                        showImportAlert = true
                    }
                } catch {
                    await MainActor.run {
                        importAlertMessage = "Erreur : \(error.localizedDescription)"
                        showImportAlert = true
                    }
                }
            }
        case .failure(let error):
            importAlertMessage = "Erreur : \(error.localizedDescription)"
            showImportAlert = true
        }
    }
    
    func calculateCacheSize() {
        Task {
            let size = await Task.detached { return SDImageCache.shared.totalDiskSize() }.value
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            await MainActor.run { self.cacheSize = formatted }
        }
    }
    
    func clearCache() {
        SDImageCache.shared.clearMemory()
        SDImageCache.shared.clearDisk { calculateCacheSize() }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
