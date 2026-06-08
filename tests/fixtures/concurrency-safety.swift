import SwiftUI

// Deliberate violations for audit-swiftui-concurrency-safety (lint self-test fixture).
@Observable
final class Loader {
    func load() {
        Task.detached {                                   // conc-01
            DispatchQueue.main.async {                    // conc-03
                print("done")
            }
        }
    }
    @Sendable func handler() {}                           // conc-02
}
