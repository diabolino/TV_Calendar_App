import SwiftUI

struct WelcomeView: View {
    // Callback pour rediriger l'utilisateur vers la recherche
    var onGoToSearch: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "tv.badge.wifi")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.accentPurple, .accentPink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .accentPurple.opacity(0.5), radius: 20)
            
            VStack(spacing: 12) {
                Text("Bienvenue sur TV Calendar")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                
                Text("Votre bibliothèque est vide pour le moment. Ajoutez vos séries préférées pour commencer le suivi.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 30)
            }
            
            Button(action: onGoToSearch) {
                Text("Ajouter une série")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentPurple)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .background(Color.appBackground)
    }
}