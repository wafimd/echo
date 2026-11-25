import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
        .tint(Color(red: 0.98, green: 0.3, blue: 0.3))
        .preferredColorScheme(.dark)
    }
}
