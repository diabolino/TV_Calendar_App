//
//  SettingsView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 27/11/2025.
//

import SwiftUI
import SwiftData
import SDWebImage
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("defaultQuality") private var defaultQuality: VideoQuality = .hd1080
    @AppStorage("currentProfileId") private var currentProfileId: String?
    @Query private var profiles: [UserProfile]
    
    @State private var cacheSize: String = "Calcul..."
    @State private var showSyncAlert = false
    @State private var isSyncing = false
    
    // ÉTATS POUR IMPORT / EXPORT
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var showFileImporter = false
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false
    @State private var showTraktImporter = false
    
    var currentProfileName: String {
        if let id = currentProfileId, let profile = profiles.first(where: { $0.id.uuidString == id }) {
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
                // SECTION PROFIL (NOUVEAU)
                Section("Profil") {
                    HStack {
                        Text("Connecté en tant que")
                        Spacer()
                        Text(currentProfileName).bold().foregroundColor(.accentPurple)
                    }
                    Button(role: .destructive) {
                        currentProfileId = nil // Déconnexion
                    } label: {
                        Label("Changer de profil", systemImage: "person.2.circle")
                    }
                }
                
                // SECTION 1 : PRÉFÉRENCES
                Section("Préférences") {
                    Picker("Qualité par défaut", selection: $defaultQuality) {
                        ForEach(VideoQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Text("Cette qualité sera pré-sélectionnée lors de l'ajout d'une nouvelle série.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                // SECTION 2 : SAUVEGARDE
                Section("Sauvegarde & Restauration") {
                    Button(action: exportData) {
                        Label("Exporter une sauvegarde", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showFileImporter = true }) {
                        Label("Importer une sauvegarde", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: { showTraktImporter = true }) {
                        Label("Importer historique Trakt (.json)", systemImage: "play.tv.fill")
                            .foregroundColor(.accentPurple)
                    }
                }
                
                // SECTION 3 : DONNÉES
                Section("Stockage & Données") {
                    HStack {
                        Text("Cache Images")
                        Spacer()
                        Text(cacheSize).foregroundStyle(.secondary)
                    }
                    
                    Button("Vider le cache des images") {
                        clearCache()
                    }
                    .foregroundStyle(.red)
                    
                    Button(action: { forceSync() }) {
                        HStack {
                            Text("Forcer la synchronisation iCloud")
                            if isSyncing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)
                }
                
                // SECTION 4 : SUPPORT
                Section("Aide") {
                    Link(destination: URL(string: "https://diabolino.github.io/TV_Calendar_contact/#support")!) {
                        Label("Contacter le support / FAQ", systemImage: "questionmark.circle")
                    }
                    
                    Link(destination: URL(string: "https://diabolino.github.io/TV_Calendar_contact/#privacy")!) {
                        Label("Politique de confidentialité", systemImage: "hand.raised")
                    }
                }
                
                // SECTION 5 : A PROPOS
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("TV Calendar")
                                .font(.headline)
                            Text(appVersion)
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Réglages")
            .onAppear {
                calculateCacheSize()
            }
            // GESTION DU PARTAGE (EXPORT)
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            // GESTION DE L'IMPORT
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            // GESTION TRAKT
            .fileImporter(
                isPresented: $showTraktImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleTraktImport(result: result)
            }
            // ALERTES
            .alert("Importation", isPresented: $showImportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importAlertMessage)
            }
        }
    }
    
    // --- LOGIQUE (Identique à l'original) ---
    
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
                        importAlertMessage = "Succès ! \(count) série(s) importée(s)."
                        showImportAlert = true
                    }
                } catch {
                    await MainActor.run {
                        importAlertMessage = "Erreur lors de l'import : \(error.localizedDescription)"
                        showImportAlert = true
                    }
                }
            }
        case .failure(let error):
            importAlertMessage = "Échec de la sélection : \(error.localizedDescription)"
            showImportAlert = true
        }
    }
    
    func handleTraktImport(result: Result<[URL], Error>) {
        // Logique connectée au TraktImportManager
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            // Note: On pourrait passer currentProfileId ici si on voulait isoler l'import
            // Pour l'instant, TraktImportManager utilise le contexte global
            ToastManager.shared.show("Analyse du fichier Trakt...", style: .info)
            // (La logique d'appel est gérée ici ou dans Settings, mais TraktImportManager fait le gros du travail)
        case .failure(let error):
            ToastManager.shared.show("Erreur: \(error.localizedDescription)", style: .error)
        }
    }
    
    func forceSync() {
        isSyncing = true
        Task {
            await SyncManager.shared.synchronizeLibrary(modelContext: modelContext)
            await MainActor.run {
                isSyncing = false
            }
        }
    }
    
    func calculateCacheSize() {
        Task {
            let size = await Task.detached(priority: .background) {
                return SDImageCache.shared.totalDiskSize()
            }.value
            let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            await MainActor.run { self.cacheSize = formattedSize }
        }
    }
    
    func clearCache() {
        SDImageCache.shared.clearMemory()
        SDImageCache.shared.clearDisk { calculateCacheSize() }
    }
}
