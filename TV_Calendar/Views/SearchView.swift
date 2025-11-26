struct SearchView: View {
    @State private var searchText = ""
    @State private var results: [APIService.ShowDTO] = []
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            List(results, id: \.id) { show in
                HStack {
                    Text(show.name)
                    Spacer()
                    Button("Suivre") {
                        Task { await addShowToLibrary(show) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .searchable(text: $searchText)
            .onChange(of: searchText) { oldValue, newValue in
                Task {
                    if !newValue.isEmpty {
                        results = try! await APIService.shared.searchShow(query: newValue)
                    }
                }
            }
            .navigationTitle("Ajouter une série")
        }
    }
    
    func addShowToLibrary(_ dto: APIService.ShowDTO) async {
        // 1. Créer la série locale
        let newShow = TVShow(
            id: dto.id,
            name: dto.name,
            overview: dto.summary ?? "",
            imageUrl: dto.image?.medium
        )
        modelContext.insert(newShow)
        
        // 2. Récupérer les épisodes
        do {
            let episodesDTO = try await APIService.shared.fetchEpisodes(showId: dto.id)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            for ep in episodesDTO {
                let date = ep.airdate != nil ? formatter.date(from: ep.airdate!) : nil
                let newEp = Episode(
                    id: ep.id,
                    title: ep.name,
                    season: ep.season,
                    number: ep.number,
                    airDate: date
                )
                newEp.show = newShow // Lier à la série
                modelContext.insert(newEp)
            }
            print("Série ajoutée avec succès !")
        } catch {
            print("Erreur lors de l'ajout : \(error)")
        }
    }
}