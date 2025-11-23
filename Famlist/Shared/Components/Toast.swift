/*
 Toast.swift

 Famlist
 Created on: 20.07.2025 (est.)
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lightweight toast overlay shown at the top of the screen to surface brief status messages.

 🛠 Includes:
 - ToastManager (ObservableObject) and a ViewModifier to overlay the toast on any view.

 🔰 Notes for Beginners:
 - Call manager.show("Message") to display a toast for a few seconds.
 - The overlay uses SwiftUI animations for smooth in/out transitions.

 📝 Last Change:
 - Standardized header and added clarifying comments; no behavior changes.
 ------------------------------------------------------------------------
 */

import SwiftUI // SwiftUI provides View, modifiers, and animations used here.

/// Observable object that controls when a toast is visible and what text it shows.
final class ToastManager: ObservableObject { // Publishes changes so UI updates.
    @Published var isShowing: Bool = false // Whether the toast is currently visible.
    @Published var message: String = "" // The text displayed inside the toast.

    /// Shows a toast with the given message, then hides it after `duration` seconds.
    /// - Parameters:
    ///   - message: The message to display.
    ///   - duration: How long the toast remains visible (in seconds).
    func show(_ message: String, duration: TimeInterval = 3.0) { // Public API to present a toast.
        Task { @MainActor in // Ensure UI updates are on the main thread.
            self.message = message // Set the displayed text.
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.isShowing = true } // Animate the toast in.
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) // Wait for the desired duration.
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.isShowing = false } // Animate the toast out.
        }
    }
}

/// Visual appearance of the toast pill.
private struct ToastView: View { // Private to this file.
    let text: String // The message to display.
    var body: some View { // Compose the toast UI.
        HStack(spacing: 10) { // Horizontal pill with icon and label.
            Image(systemName: "checkmark.circle.fill").foregroundColor(.white) // Success-looking icon.
            Text(text).foregroundColor(.white).font(.subheadline.weight(.semibold)) // Toast text label.
        }
        .padding(.horizontal, 14).padding(.vertical, 10) // Adds left/right and top/bottom spacing inside the pill.
        .background(.ultraThinMaterial) // Slight blur material for depth.
        .background(Color.black.opacity(0.75)) // Dark backdrop color.
        .clipShape(Capsule()) // Rounds to a pill shape.
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 8) // Soft drop shadow.
        .padding(.top, 12) // Separate from the top edge.
    }
}

/// Modifier that overlays the toast at the top of any content.
struct ToastOverlay: ViewModifier { // Makes it easy to attach to any view.
    @ObservedObject var manager: ToastManager // Reads toast state changes.
    func body(content: Content) -> some View { // Required ViewModifier method.
        ZStack(alignment: .top) { // Stack toast above the underlying content.
            content // Base content.
            if manager.isShowing { // Only show when visible.
                ToastView(text: manager.message)
                    .transition(.move(edge: .top).combined(with: .opacity)) // Animate in/out.
                    .zIndex(5) // Keep above most content.
            }
        }
    }
}

extension View { // Convenience extension to attach the overlay.
    /// Convenience wrapper to attach a toast overlay to any view.
    /// - Parameter manager: The ToastManager responsible for showing/hiding.
    /// - Returns: A view with the toast overlay applied.
    func toast(using manager: ToastManager) -> some View { self.modifier(ToastOverlay(manager: manager)) } // Chainable modifier.
}

#Preview { // Demonstrates the toast overlay in isolation.
    struct Demo: View { // Local demo view used by the preview.
        @StateObject var tm = ToastManager() // StateObject so the manager lives for preview lifetime.
        var body: some View { // Compose a simple demo screen.
            VStack(spacing: 12) { // Stack a button with instructions.
                Text("Toast Demo") // Title label.
                Button("Show Toast") { tm.show("Saved!") } // Tapping shows a toast.
            }
            .padding() // Add some padding.
            .toast(using: tm) // Attach toast overlay using the manager.
        }
    }
    return Demo() // Render the demo view.
} // end #Preview
