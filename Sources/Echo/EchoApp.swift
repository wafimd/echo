import SwiftUI

@main
struct EchoApp: App {
    @StateObject private var player = PlayerManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
        }
    }
}
