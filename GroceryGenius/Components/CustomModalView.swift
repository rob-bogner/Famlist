// MARK: - CustomModalView.swift

/*
 File: CustomModalView.swift
 Project: GroceryGenius
 Created: 30.05.2025 (est.)
 Last Updated: 17.08.2025

 Overview:
 Generic modal container with a consistent accent-colored header bar and close action. Used across create / edit / image preview flows to ensure visual consistency.

 Responsibilities / Includes:
 - Header with centered title + trailing close button
 - Accent background integration
 - Safe-area handling for top inset
 - Generic Content slot via @ViewBuilder

 Design Notes:
 - Fixed header height (52pt) to align with design system rhythm
 - Internally uses GeometryReader only for full-width accent background; avoids layout side-effects
 - Keep logic minimal; state management lives in parent views

 Possible Enhancements:
 - Add optional leading accessory (e.g. back button)
 - Support ScrollView offset-based shadow/elevation
 - Provide standardized padding tokens for body content
*/

import SwiftUI

struct ModalHeader: View {
    let title: String
    let onClose: () -> Void
    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.theme.background)
                .frame(maxWidth: .infinity, alignment: .center)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(Color.theme.background)
                    .padding(6)
                    .background(Circle().fill(Color.theme.accent))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Reusable modal shell with accent header & injected content.
struct CustomModalView<Content: View>: View {
    let title: String
    let onClose: () -> Void
    let content: Content

    init(title: String, onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    Color.theme.accent
                        .frame(width: geometry.size.width, height: 52)
                        .ignoresSafeArea(.all, edges: .top)
                    ModalHeader(title: title, onClose: onClose)
                        .frame(height: 52)
                        .padding(.horizontal, 16)
                }
            }
            .frame(height: 52)
            content
        }
    }
}

#Preview {
    CustomModalView(title: "Modal Title", onClose: {}) {
        VStack { Text("Modal Content").padding() }
    }
}
