import SwiftUI

// Deliberate violations for audit-swiftui-api-currency (lint self-test fixture).
struct LegacyView: View {
    @State private var name = ""
    var body: some View {
        NavigationView {                                  // curr-01
            Text(name)
                .foregroundColor(.red)                    // curr-02
                .cornerRadius(8)                          // curr-03
                .onChange(of: name) { newValue in }       // curr-04
                .glassBackground()                        // curr-13 (hallucinated)
        }
    }
}
