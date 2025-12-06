import Foundation
import SwiftUI
import SwiftData

@Observable // Nécessite iOS 17+, sinon utiliser ObservableObject + @Published
class SearchViewModel {
    // États de l'interface
    var searchText = ""
    var searchResults: [TVMazeService.ShowDTO] = []
    var isSearching = false
    
    // Actions
    func performSearch() async {
        guard !searchText.isEmpty else {
            self.searchResults = []
            return
        }
        
        self.isSearching = true
        
        // Petit délai pour éviter le spam (debounce)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        if let results = try? await TVMazeService.shared.searchShow(query: searchText) {
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        } else {
            await MainActor.run {
                self.isSearching = false
            }
        }
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
        isSearching = false
    }
}