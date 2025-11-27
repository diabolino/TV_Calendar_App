//
//  Theme.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
//

import SwiftUI

extension Color {
    // Le fond bleu nuit profond de votre app
    static let appBackground = Color(red: 0.07, green: 0.08, blue: 0.12) // #11141F
    
    // La couleur des cartes (un peu plus clair)
    static let cardBackground = Color(red: 0.11, green: 0.13, blue: 0.18) // #1C212E
    
    // Vos accents
    static let accentPurple = Color(red: 0.56, green: 0.27, blue: 0.93) // Le violet du bouton
    static let accentPink = Color(red: 0.95, green: 0.24, blue: 0.63) // Le rose de la barre
    static let textPrimary = Color.white
    static let textSecondary = Color.gray
}

// Un modifieur pour appliquer le fond partout facilement
struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            content
        }
    }
}

extension View {
    func withAppBackground() -> some View {
        modifier(AppBackground())
    }
}
