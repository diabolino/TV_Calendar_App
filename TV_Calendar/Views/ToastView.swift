//
//  ToastView.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 06/12/2025.
//


import SwiftUI

struct ToastView: View {
    let toast: Toast
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.style.icon)
                .font(.title3)
            
            Text(toast.message)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(toast.style.color.opacity(0.9)) // Fond coloré semi-transparent
        .foregroundColor(.white)
        .cornerRadius(25) // Forme de pilule
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }
}

#Preview {
    VStack {
        ToastView(toast: Toast(message: "Série ajoutée avec succès !", style: .success))
        ToastView(toast: Toast(message: "Erreur de connexion", style: .error))
    }
    .padding()
    .background(Color.black)
}