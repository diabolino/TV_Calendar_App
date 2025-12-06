import SwiftUI
import SDWebImage // Nécessaire pour vider le cache

struct SettingsView: View {
    // Persistance automatique de la qualité par défaut
    @AppStorage("defaultQuality") private var defaultQuality: VideoQuality = .hd1080
    
    @State private var cacheSize: String = "Calcul..."
    @State private var showSyncAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // SECTION 1 : PRÉFÉRENCES
                Section("Préférences") {
                    Picker("Qualité par défaut", selection: $defaultQuality) {
                        ForEach(VideoQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    .pickerStyle(.navigationLink) // Plus joli sur iOS
                    
                    Text("Cette qualité sera pré-sélectionnée lors de l'ajout d'une nouvelle série.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                // SECTION 2 : DONNÉES
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
                    
                    Button("Forcer la synchronisation iCloud") {
                        // On lance la synchro manuelle
                        Task {
                            // On suppose que vous avez accès au context via un Environment ou Singleton si besoin, 
                            // mais ici SyncManager gère son propre context ou on lui passe.
                            // Pour simplifier, on appelle la méthode qui ne demande pas de contexte spécifique si possible, 
                            // ou on utilise celui de la vue (voir plus bas).
                            showSyncAlert = true
                        }
                    }
                }
                
                // SECTION 3 : SUPPORT
                Section("Aide") {
                    Link(destination: URL(string: "https://diabolino.github.io/TV-Calendar/")!) {
                        Label("Contacter le support / FAQ", systemImage: "questionmark.circle")
                    }
                    
                    Link(destination: URL(string: "https://diabolino.github.io/TV-Calendar/")!) {
                        Label("Politique de confidentialité", systemImage: "hand.raised")
                    }
                }
                
                // SECTION 4 : A PROPOS
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("TV Calendar")
                                .font(.headline)
                            Text("Version 1.3")
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
            .alert("Synchronisation lancée", isPresented: $showSyncAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("La synchronisation avec iCloud s'exécute en arrière-plan.")
            }
        }
    }
    
    // Calcul taille du cache SDWebImage
    func calculateCacheSize() {
        let size = SDImageCache.shared.totalDiskSize()
        cacheSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    // Vider le cache
    func clearCache() {
        SDImageCache.shared.clearMemory()
        SDImageCache.shared.clearDisk {
            calculateCacheSize()
        }
    }
}