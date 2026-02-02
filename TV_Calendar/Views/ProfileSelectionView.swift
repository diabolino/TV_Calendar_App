//
//  ProfileSelectionView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 22/12/2025.
//

import SwiftUI
import SwiftData

struct ProfileSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var profiles: [UserProfile]
    
    @Binding var selectedProfileId: String?
    
    @State private var showAddProfile = false
    @State private var newProfileName = ""
    @State private var newProfileIcon = "person.circle"
    
    // NOUVEAU : État pour gérer le délai d'attente iCloud
    @State private var isCheckingCloud = true
    
    let columns = [
        GridItem(.adaptive(minimum: 120))
    ]
    
    let icons = ["person.circle", "star.circle", "heart.circle", "bolt.circle", "face.smiling", "gamecontroller.circle"]
    
    var body: some View {
        VStack(spacing: 40) {
            
            Text("Qui regarde ?")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
                .padding(.top, 60)
            
            // --- LOGIQUE D'AFFICHAGE ---
            if profiles.isEmpty && isCheckingCloud {
                // CAS 1 : C'est vide, mais on attend encore iCloud (Chargement)
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    
                    Text("Recherche de vos profils iCloud...")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Cela peut prendre quelques secondes lors de la première installation.")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxHeight: .infinity)
                
            } else {
                // CAS 2 : On a des profils OU on a fini d'attendre
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 30) {
                        // 1. Liste des profils existants
                        ForEach(profiles) { profile in
                            Button {
                                selectProfile(profile)
                            } label: {
                                VStack {
                                    Image(systemName: profile.avatarSymbol)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 80, height: 80)
                                        .foregroundColor(Color(hex: profile.colorHex))
                                    
                                    Text(profile.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(12)
                            }
                        }
                        
                        // 2. Bouton Ajouter Profil
                        Button {
                            showAddProfile = true
                        } label: {
                            VStack {
                                Image(systemName: "plus.circle")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.gray)
                                
                                Text("Ajouter")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5]))
                            )
                        }
                    }
                    .padding()
                }
                
                // Si après le chargement c'est toujours vide, on met un petit message
                if profiles.isEmpty && !isCheckingCloud {
                    Text("Aucun profil trouvé.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 20)
                }
            }
        }
        .background(Color.appBackground)
        // Démarrage du timer de "patience"
        .onAppear {
            // On laisse 10 secondes à iCloud pour réagir avant de montrer l'interface vide
            // Si des profils arrivent avant, SwiftData mettra à jour la vue automatiquement
            if profiles.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    withAnimation {
                        isCheckingCloud = false
                    }
                }
            } else {
                isCheckingCloud = false
            }
        }
        // Mise à jour immédiate si des données arrivent via SwiftData
        .onChange(of: profiles.count) { oldCount, newCount in
            if newCount > 0 {
                withAnimation {
                    isCheckingCloud = false
                }
            }
        }
        .sheet(isPresented: $showAddProfile) {
            NavigationStack {
                Form {
                    Section("Nom") {
                        TextField("Prénom", text: $newProfileName)
                    }
                    
                    Section("Avatar") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 20) {
                            ForEach(icons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title)
                                    .foregroundColor(newProfileIcon == icon ? .accentPurple : .gray)
                                    .onTapGesture {
                                        newProfileIcon = icon
                                    }
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .navigationTitle("Nouveau profil")
                .toolbar {
                    Button("Créer") {
                        createProfile()
                    }
                    .disabled(newProfileName.isEmpty)
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // --- LOGIQUE ---
    
    func selectProfile(_ profile: UserProfile) {
        withAnimation {
            selectedProfileId = profile.id.uuidString
        }
    }
    
    func createProfile() {
        let colors = ["007AFF", "AF52DE", "FF2D55", "5856D6", "FF9500"]
        let randomColor = colors.randomElement() ?? "007AFF"
        
        let newProfile = UserProfile(name: newProfileName, avatarSymbol: newProfileIcon)
        newProfile.colorHex = randomColor
        
        modelContext.insert(newProfile)
        try? modelContext.save() // Force save pour déclencher le sync
        showAddProfile = false
        newProfileName = ""
    }
}

// Helper couleur Hex (Déjà présent dans votre code, je le remets pour compilation)
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = rgbValue & 0xff
        
        self.init(
            red: Double(r) / 0xff,
            green: Double(g) / 0xff,
            blue: Double(b) / 0xff
        )
    }
}
