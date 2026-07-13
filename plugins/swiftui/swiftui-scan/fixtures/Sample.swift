import SwiftUI
import SwiftData
import AppKit

struct SettingsView: View {
    @State private var tab: Tab = .general
    @AppStorage("theme") var theme: String = "dark"
    @Environment(\.dismiss) private var dismiss
    @State private var a = 1, b = 2

    var body: some View {
        VStack {
            Text("Settings").font(.system(size: 14, weight: .semibold))
            Button("Done") { dismiss() }.buttonStyle(.bordered)
            List<Item>()
        }
        .frame(maxWidth: .infinity)
        .environment(\.locale, .current)
        .animation(.easeInOut, value: tab)
    }

    @ViewBuilder
    func header() -> some View { Text("Header") }
}

extension SettingsView: Equatable {}

struct GraphView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ v: NSView, context: Context) {}
}

extension Color {
    static var brand: Color { .blue }
}

@Observable final class Store {
    var count = 0
}

#Preview { SettingsView() }
