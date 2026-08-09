import SwiftUI
import UIKit

/// Thin wrapper around `UIActivityViewController` so a generated file (e.g. the
/// CSV export) can be shared via the system share sheet from SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
