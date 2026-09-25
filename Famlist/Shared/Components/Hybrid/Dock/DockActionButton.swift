/*
 DockActionButton.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einzelner Aktionsknopf im Dock; die gewählte Pille wandert per matchedGeometryEffect.

 📝 Last Change:
 - Aus DockView.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Aktionsknopf

struct DockActionButton: View {
    let item: DockItemModel
    let pillSpace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                SVGIcon(item.icon, size: item.selected ? 18 : 22, color: item.color,
                        lineWidth: item.selected ? 2.2 : 1.9)
                if item.selected {
                    Text(item.text)
                        .font(AppFont.dm(13, 600, scaled: false))   // Pille hat feste Breite, auch auf dem SE
                        .tracking(-0.065)                  // -0.005em × 13
                        .foregroundStyle(item.color)
                        .lineLimit(1)
                        .fixedSize()                       // white-space: nowrap
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
                }
            }
            .frame(width: item.selected ? item.pillWidth : 44, height: item.selected ? 54 : 44)
            .background {
                // Nur die gewählte Pille hat eine Fläche; sie wandert per matchedGeometryEffect.
                if item.selected {
                    CSSBox(shape: Pill, paint: item.paint, border: 1, borderColor: item.border,
                           shadows: item.shadows)
                        .matchedGeometryEffect(id: "dockPill", in: pillSpace)
                }
            }
            .contentShape(Pill)
            .opacity(item.disabled ? (item.selected ? 0.4 : 0.35) : 1)
        }
        .buttonStyle(.plain)
        // aria-disabled: nur Treffer sperren – `.disabled` würde bei .plain zusätzlich abdunkeln
        .allowsHitTesting(!item.disabled)
        .accessibilityLabel(item.label)
        .accessibilityValue(item.disabled ? "Nicht verfügbar" : "")
        .accessibilityAddTraits(item.selected ? .isSelected : [])
        // Große iOS-Schrift: langer Druck zeigt Symbol und Beschriftung groß (wie bei Tab-Leisten).
        .accessibilityShowsLargeContentViewer {
            SVGIcon(item.icon, size: 22, color: .primary, lineWidth: 1.9)
            Text(item.label)
        }
    }
}

/// Vorschau-Hülle: `matchedGeometryEffect` braucht einen Namespace.
private struct DockActionButtonPreview: View {
    let appearance: Appearance
    let active: DockActive
    @Namespace private var space

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(DockItemModel.items(t: ListTheme(appearance), active: active, pill: .open).enumerated()),
                    id: \.offset) { _, item in
                DockActionButton(item: item, pillSpace: space, action: {})
            }
        }
        .padding(12)
        .background(Capsule().fill(Color.hex("#0F1B1D")))
        .padding(20)
    }
}

#Preview("Dock-Knöpfe") { DockActionButtonPreview(appearance: .light, active: .none) }

#Preview("Dock-Knöpfe – Dark") { DockActionButtonPreview(appearance: .dark, active: .delete) }
