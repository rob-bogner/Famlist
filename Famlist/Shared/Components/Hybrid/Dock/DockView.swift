/*
 DockView.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Untere Leiste (Dock): dunkle Glas-Leiste 276 × 64 mit vier Aktionen + Plus-Knopf 64. Genau ein Knopf ist als Pille gewählt; die Pille wandert animiert (matchedGeometryEffect).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/Dock.swift (Dock.dc.html / DockStates.png; ergänzt um Aktionen und Pillen-Animation).
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 - DockGeometry, DockItemModel, DockActionButton und DockFAB in eigene Dateien ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct DockView: View {
    let appearance: Appearance
    var accentHex: String? = nil
    var active: DockActive = .none
    var pill: DockPill = .open
    /// Optional: echter `backdrop-filter` (blur 24) über `.ultraThinMaterial`. Im Standbild aus.
    var liveBlur: Bool = false
    /// Aktionen der vier Knöpfe und des Plus-Knopfs (Vorschau: leer).
    var onCheck: () -> Void = {}
    var onSort: () -> Void = {}
    var onCopy: () -> Void = {}
    var onDelete: () -> Void = {}
    var onAdd: () -> Void = {}

    /// Gemeinsamer Namensraum, damit die gewählte Pille zum angetippten Knopf wandert.
    @Namespace private var pillSpace

    init(appearance: Appearance, accentHex: String? = nil, active: DockActive = .none,
         pill: DockPill = .open, liveBlur: Bool = false,
         onCheck: @escaping () -> Void = {}, onSort: @escaping () -> Void = {},
         onCopy: @escaping () -> Void = {}, onDelete: @escaping () -> Void = {},
         onAdd: @escaping () -> Void = {}) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.active = active
        self.pill = pill
        self.liveBlur = liveBlur
        self.onCheck = onCheck
        self.onSort = onSort
        self.onCopy = onCopy
        self.onDelete = onDelete
        self.onAdd = onAdd
    }

    private func action(for key: DockKey) -> () -> Void {
        switch key {
        case .check: onCheck
        case .sort: onSort
        case .copy: onCopy
        case .delete: onDelete
        }
    }

    var body: some View {
        let t = ListTheme(appearance, accentHex: accentHex)
        let k = DockTokens(appearance)
        let items = DockItemModel.items(t: t, active: active, pill: pill)

        HStack(spacing: 10) {
            // Leiste
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Spacer(minLength: 0) }
                    DockActionButton(item: item, pillSpace: pillSpace, action: action(for: item.key))
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity)            // Leiste wächst mit der Bildschirmbreite (Design 390 → 276)
            .frame(height: 62)
            .clipShape(Pill)                       // overflow: hidden (Padding-Box, Radius 31)
            .padding(1)                            // border 1
            .frame(height: 64)
            .background(CSSBox(shape: Pill, paint: .color(k.nav), border: 1, borderColor: k.navBorder, shadows: k.navShadow))
            .background {
                if liveBlur { Pill.fill(.ultraThinMaterial) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Listen-Aktionen")

            DockFAB(t: t, action: onAdd)
        }
        .frame(height: 64)                         // Breite = Bildschirm − 2 × 20 (Design 390 → 350)
    }
}

// MARK: - Tokens

/// Leisten-Tokens aus Dock.dc.html (in beiden Modi dunkles Glas).
private struct DockTokens {
    let nav: Color
    let navBorder: Color
    let navShadow: [BoxShadow]

    init(_ appearance: Appearance) {
        if appearance == .dark {
            nav = .rgba(22, 36, 39, 0.78)
            navBorder = .rgba(255, 255, 255, 0.1)
            navShadow = [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.1)),
                         .drop(0, 24, 44, -12, .rgba(0, 0, 0, 0.85))]
        } else {
            nav = .rgba(15, 27, 29, 0.84)
            navBorder = .rgba(255, 255, 255, 0.1)
            navShadow = [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.12)),
                         .drop(0, 20, 36, -12, .rgba(12, 30, 33, 0.5))]
        }
    }
}

#Preview("DockView") {
    DockView(appearance: .light)
        .padding(20)
        .background(Color.hex("#F4F7F7"))
}

#Preview("DockView – Dark") {
    DockView(appearance: .dark)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
