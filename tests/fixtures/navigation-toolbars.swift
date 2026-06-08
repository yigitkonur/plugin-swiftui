import SwiftUI

// Deliberate violations for audit-swiftui-navigation-toolbars (lint self-test fixture).
struct OldNav: View {
    var body: some View {
        NavigationView {                                  // nav-01
            Text("detail")
                .navigationBarTitle("Title")              // nav-07
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { EmptyView() }   // nav-05
                }
        }
    }
}
