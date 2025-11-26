import SwiftUI
import SDWebImageSwiftUI // <--- La librairie magique

struct PosterImage: View {
    let urlString: String?
    let width: CGFloat?
    let height: CGFloat?
    
    var body: some View {
        if let str = urlString, let url = URL(string: str) {
            WebImage(url: url) { image in
                image.resizable() // Affiche l'image une fois chargée
            } placeholder: {
                // Pendant le chargement ou si erreur
                ZStack {
                    Color.cardBackground // Fond gris
                    ProgressView() // Petite roue qui tourne
                }
            }
            // Options magiques :
            .onSuccess { image, data, cacheType in
                // Optionnel : pour debug, savoir si ça vient du Web ou du Cache
            }
            .resizable()
            .indicator(.activity) // Affiche le chargement
            .transition(.fade(duration: 0.5)) // Apparition en fondu
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipped() // Coupe ce qui dépasse
            
        } else {
            // Si pas d'URL
            ZStack {
                Color.gray.opacity(0.3)
                Image(systemName: "photo.slash")
                    .foregroundColor(.white.opacity(0.3))
            }
            .frame(width: width, height: height)
        }
    }
}