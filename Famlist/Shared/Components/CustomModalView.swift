/*
 CustomModalView.swift

 GroceryGenius
 Created on: 30.05.2025 (est.)
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Generic modal container with a consistent accent-colored header bar and close action. Used across create/edit/image preview flows to ensure visual consistency.

 🛠 Includes:
 - Header with centered title + trailing close button
 - Accent background integration and safe-area handling
 - Generic Content slot exposed via @ViewBuilder

 🔰 Notes for Beginners:
 - Fixed header height (52pt) to align with design rhythm; body content is injected by caller.
 - GeometryReader is used only to size the accent header background.

 📝 Last Change:
 - Standardized header to required format; retained existing preview. No functional changes.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI to build the modal views.

/// Small header component for the modal with a centered title and a close button.
struct ModalHeader: View { // Declares a SwiftUI view used at the top of modals.
    let title: String // Title text shown in the header.
    let onClose: () -> Void // Action to execute when the close button is tapped.
    var body: some View { // Defines the header's layout.
        HStack { // Horizontal stack for spacing.
            Spacer(minLength: 0) // Pushes the title to center by taking up space on the leading side.
            Text(title) // The header title label.
                .font(.title2) // Uses a reasonably prominent title size.
                .fontWeight(.semibold) // Slightly bold for emphasis.
                .foregroundColor(Color.theme.background) // Title color contrasts with accent background.
                .frame(maxWidth: .infinity, alignment: .center) // Ensure the title is centered across full width.
            Button(action: onClose) { // Tap to trigger close action.
                Image(systemName: "xmark") // Cross icon indicating close.
                    .foregroundColor(Color.theme.background) // Icon color for contrast.
                    .padding(6) // Expand tap target slightly.
                    .background(Circle().fill(Color.theme.accent)) // Circle with accent color behind the icon.
            }
            .buttonStyle(.plain) // Plain style so background we set is visible.
        }
    }
}

/// Reusable modal shell with accent header & injected content.
struct CustomModalView<Content: View>: View { // Generic over content view type.
    let title: String // Title to display in the header.
    let onClose: () -> Void // Callback when user taps close.
    let content: Content // The injected body content.

    /// Initializes the modal with a title, close action, and a content builder.
    init(title: String, onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) { // Custom initializer to accept a builder.
        self.title = title // Store the provided title.
        self.onClose = onClose // Store the close handler.
        self.content = content() // Build and store the provided content.
    }

    var body: some View { // Declares the modal layout.
        VStack(spacing: 0) { // Vertical layout with no spacing between header and content.
            GeometryReader { geometry in // Provides size to draw the accent header background.
                ZStack(alignment: .top) { // Stack the colored bar and the header content.
                    Color.theme.accent // Accent color area behind the header.
                        .frame(width: geometry.size.width, height: 52) // Fixed 52pt tall header bar.
                        .ignoresSafeArea(.all, edges: .top) // Extend behind status bar if present.
                    ModalHeader(title: title, onClose: onClose) // Header with title and close button.
                        .frame(height: 52) // Match the bar height.
                        .padding(.horizontal, 16) // Horizontal padding for breathing room.
                }
            }
            .frame(height: 52) // Fix the container height for the header.
            content // Injected content from the caller.
        }
    }
}

#Preview { // Inline SwiftUI preview for development.
    CustomModalView(title: "Modal Title", onClose: {}) { // Create a modal with a sample title and empty close.
        VStack { Text("Modal Content").padding() } // Provide simple body content for the preview.
    }
}
