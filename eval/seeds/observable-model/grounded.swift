import SwiftUI

@Observable
final class Counter {
    var count = 0
}

struct CounterView: View {
    @State private var model = Counter()
    var body: some View {
        Text("\(model.count)")
    }
}
