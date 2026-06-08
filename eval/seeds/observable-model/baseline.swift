import SwiftUI
import Combine

class Counter: ObservableObject {
    @Published var count = 0
}

struct CounterView: View {
    @StateObject private var model = Counter()
    var body: some View {
        Text("\(model.count)")
    }
}
