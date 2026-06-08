import SwiftUI

// Deliberate violations for audit-swiftui-liquid-glass (lint self-test fixture).
struct GlassView: View {
    var body: some View {
        Text("hi")
            .glassBackground()                            // glass-01 (hallucinated name)
            .glassBackgroundEffect()                      // glass-02 (visionOS-only on Mac)
            .glassEffect(.clear)                          // glass-03 / glass-08
    }
}
