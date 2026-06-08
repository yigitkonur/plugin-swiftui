import SwiftUI
import Combine

// Deliberate violations for audit-swiftui-state-observation (lint self-test fixture).
class LegacyModel: ObservableObject {
    @Published var count = 0                              // state-03
}

struct CounterView: View {
    @ObservedObject var model = LegacyModel()             // state-01
    @StateObject private var other = LegacyModel()        // state-04
    @EnvironmentObject var shared: LegacyModel            // state-05
    var body: some View {
        Text("\(model.count)")
    }
}
