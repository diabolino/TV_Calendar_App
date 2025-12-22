//
//  ProfileSelectionView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 22/12/2025.
//


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
    
    // Binding pour dire à l'App qu'on a choisi quelqu'un
    @Binding var selectedProfileId: String?
    
    @State private var showAddProfile = false
    @State private var newProfileName = ""
    @State private var newProfileIcon = "person.circle"
    
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
        }
        .background(Color.appBackground)
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
        // On sauvegarde l'ID en String dans AppStorage (via le binding)
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
        showAddProfile = false
        newProfileName = ""
    }
}

// Helper couleur Hex
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