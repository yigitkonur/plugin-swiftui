import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Text("Home")
                .tabItem { Label("Home", systemImage: "house") }
            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
