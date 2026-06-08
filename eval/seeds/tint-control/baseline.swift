import SwiftUI

struct ToggleView: View {
    @State private var on = false
    var body: some View {
        Toggle("Enabled", isOn: $on)
            .accentColor(.purple)
    }
}
