import SwiftUI

// Deliberate violations for audit-swiftui-drawing-canvas (lint self-test fixture).
// Guards the draw-05 / draw-12 rules whose grep-tells rows were previously malformed.
struct MeshView: View {
    var body: some View {
        GeometryReader { proxy in                         // draw-03
            MeshGradient(                                 // draw-05 (ungated, macOS 15.0+)
                width: 3, height: 3,
                points: [],
                colors: []
            )
        }
    }
}
