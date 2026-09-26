/*
 RemoteSyncHighlightModifier.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kurzes Aufleuchten einer Artikelkarte, wenn ein anderes Mitglied sie geändert hat.

 📝 Last Change:
 - Aus ViewModifiers.swift ausgelagert; die übrigen Alt-Bausteine dort waren ungenutzt (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Transient gradient-glow overlay that plays once when an item arrives from a remote sync.
///
/// The glow runs from top-leading to bottom-trailing in the accent colour.
/// It fades to zero within ~1 second and never replays until the `isActive` flag cycles
/// false → true again (controlled by ListViewModel.recentlySyncedItemIDs).
struct RemoteSyncHighlightModifier: ViewModifier {
    let isActive: Bool
    /// Corner radius of the highlighted card (legacy rows 10, Hybrid ItemCard 24).
    var cornerRadius: CGFloat = 10
    @State private var glowOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            // Subtle gradient fill
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.25),
                                Color.accentColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(glowOpacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            )
            // Gradient border stroke
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.65),
                                Color.accentColor.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .opacity(glowOpacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            )
            .task(id: isActive) {
                guard isActive else { return }
                glowOpacity = 1.0
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s pre-glow hold
                withAnimation(.easeOut(duration: 2.0)) {
                    glowOpacity = 0
                }
            }
    }
}

extension View {
    func remoteSyncHighlight(isActive: Bool, cornerRadius: CGFloat = 10) -> some View {
        modifier(RemoteSyncHighlightModifier(isActive: isActive, cornerRadius: cornerRadius))
    }
}
