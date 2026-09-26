/*
 DockItemModel.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Modell der vier Dock-Knöpfe (Text, Icon, Pillenbreite, Farben) samt Dock-Icons, entspricht renderVals() in Dock.dc.html.

 📝 Last Change:
 - Aus DockView.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Icons des Docks (Pfade exakt aus Dock.dc.html).
private enum DockIcon {
    static let checks: [SVGElement] = [.path("M18 6 7 17l-5-5M22 10l-7.5 7.5L13 16")]
    static let reset: [SVGElement] = [.path("M3 12a9 9 0 1 0 3-6.7L3 8M3 3v5h5")]
    static let clipboard: [SVGElement] = [.path("M9 3.5h6a1 1 0 0 1 1 1V6a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V4.5a1 1 0 0 1 1-1zM16 5h1.5A1.5 1.5 0 0 1 19 6.5v13a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 19.5v-13A1.5 1.5 0 0 1 6.5 5H8M9 12h6M9 16h4")]
}

// MARK: - Modell (entspricht renderVals() → items)

enum DockKey { case check, sort, copy, delete }

/// Eintrag aus `defs` in renderVals().
private struct DockDef {
    let key: DockKey
    let text: String
    let label: String
    let icon: [SVGElement]
    let w: CGFloat
}

struct DockItemModel {
    typealias Key = DockKey

    let key: Key
    let text: String
    let label: String
    let icon: [SVGElement]
    let pillWidth: CGFloat
    let selected: Bool
    let disabled: Bool
    let paint: Paint
    let border: Color
    let shadows: [BoxShadow]
    let color: Color

    static func items(t: ListTheme, active: DockActive, pill: DockPill) -> [DockItemModel] {
        let empty = pill == .empty
        let sel: Key
        switch active {
        case .none: sel = .check
        case .sort: sel = .sort
        case .copy, .copied: sel = .copy
        case .delete: sel = .delete
        }

        let check = pill == .allDone
            ? DockDef(key: .check, text: "Zurücksetzen", label: "Alle Artikel wieder öffnen", icon: DockIcon.reset, w: 124)
            : DockDef(key: .check, text: "Alle abhaken", label: "Alle Artikel abhaken", icon: DockIcon.checks, w: 124)
        let copy = active == .copied
            ? DockDef(key: .copy, text: "Kopiert", label: "Kopiert", icon: Icon.check, w: 112)
            : DockDef(key: .copy, text: "Kopieren", label: "In Zwischenablage kopieren", icon: DockIcon.clipboard, w: 112)
        let defs: [DockDef] = [
            check,
            DockDef(key: .sort, text: "Sortieren", label: "Sortieren", icon: Icon.sort, w: 112),
            copy,
            DockDef(key: .delete, text: "Löschen", label: "Artikel löschen", icon: Icon.trash, w: 104)
        ]

        let base = t.a.base
        return defs.map { (d: DockDef) -> DockItemModel in
            let on = d.key == sel
            let dis = empty && d.key != .sort
            var paint: Paint = .color(.clear)
            var border: Color = .clear
            var shadows: [BoxShadow] = []
            var color: Color = .hex("#D3E6E8")
            if on {
                border = .rgba(255, 255, 255, 0.22)
                color = .white
                if d.key == .delete {
                    // hiDanger
                    paint = .linear(180, [stop(.rgba(229, 72, 77, 0.6), 0), stop(.rgba(229, 72, 77, 0.24), 1)])
                    shadows = [.inner(0, -1, 0, 0, .rgba(0, 0, 0, 0.2)), .drop(0, 0, 16, 0, .rgba(229, 72, 77, 0.3))]
                } else {
                    // hiAccent
                    paint = .linear(180, [stop(base.color(0.55), 0), stop(base.color(0.22), 1)])
                    shadows = [.inner(0, -1, 0, 0, .rgba(0, 0, 0, 0.2)), .drop(0, 0, 16, 0, base.color(0.3))]
                }
            }
            // Leere Liste: ausgewählte (erste) Pille ohne Glow
            if empty && d.key == .check { shadows = [] }
            return DockItemModel(key: d.key, text: d.text, label: d.label, icon: d.icon, pillWidth: d.w,
                                 selected: on, disabled: dis, paint: paint, border: border,
                                 shadows: shadows, color: color)
        }
    }
}
