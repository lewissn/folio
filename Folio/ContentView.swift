import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "book.closed", value: 0) {
                HomeView()
            }
            Tab("Library", systemImage: "books.vertical", value: 1) {
                LibraryView()
            }
            Tab("Patterns", systemImage: "chart.xyaxis.line", value: 2) {
                PatternsView()
            }
        }
        .tint(Color.charcoal)
    }
}
