import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                Text("Home")
            }
            Tab("Settings", systemImage: "gear") {
                Text("Settings")
            }
        }
    }
}
