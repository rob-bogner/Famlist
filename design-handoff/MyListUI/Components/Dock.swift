//  Dock.swift
//  MyListUI
//
//  Quelle: Design/html/Dock.dc.html (Kontrolle: DockStates.dc.html / png/DockStates.png)
//
//  Untere Leiste 350 × 64:
//    Leiste 276 × 64 (border-box, Rahmen 1 + Innenabstand 4, Radius 32, overflow: hidden)
//    · Abstand 10 · FAB 64.
//  Vier Aktionen, verteilt mit `justify-content: space-between`.
//  Genau EIN Knopf ist ausgewählt: Pille 54 hoch, Radius 27, Highlight + Beschriftung,
//  feste Breiten: Abhaken 124 · Sortieren 112 · Kopieren 112 · Löschen 104.
//  Alle anderen: 44 × 44, nur Icon (22), keine Fläche.
//  Ruhezustand (active = .none) = „Alle abhaken“ ausgewählt.
//  Leiste in Light UND Dark dunkles Glas (Tokens unten, weichen von ListTheme.nav ab).
//
//  Position im Screen: .frame(width: 350, height: 64), links 20, unten 34.
//
//  Animation (Vorschlag, im Standbild ohne Einfluss):
//  Das Wandern der Pille lässt sich mit `matchedGeometryEffect` umsetzen:
//    @Namespace var ns
//    … im ausgewählten Knopf: CSSBox(...).matchedGeometryEffect(id: "dockPill", in: ns)
//    … beim Antippen: withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { active = … }
//  Die Beschriftung per `.transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))`
//  ein-/ausblenden; die Breite (44 → 124/112/104) animiert dann automatisch mit.

import SwiftUI

/// Welcher Knopf aktiv ist (bzw. welches Menü offen ist).
enum DockActive {
    case none      // Ruhezustand → „Alle abhaken“ ausgewählt
    case sort
    case copy
    case copied    // Pille zeigt „Kopiert“ mit Haken
    case delete    // rotes Highlight
}

/// Zustand der Liste, steuert den ersten Knopf und das Dimmen.
enum DockPill {
    case open      // „Alle abhaken“
    case allDone   // „Zurücksetzen“
    case empty     // Abhaken / Kopieren / Löschen gedimmt, Sortieren bleibt aktiv
}

struct DockView: View {
    let appearance: Appearance
    var accentHex: String? = nil
    var active: DockActive = .none
    var pill: DockPill = .open
    /// Optional: echter `backdrop-filter` (blur 24) über `.ultraThinMaterial`. Im Standbild aus.
    var liveBlur: Bool = false

    init(appearance: Appearance, accentHex: String? = nil, active: DockActive = .none,
         pill: DockPill = .open, liveBlur: Bool = false) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.active = active
        self.pill = pill
        self.liveBlur = liveBlur
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
                    DockActionButton(item: item)
                }
            }
            .padding(4)
            .frame(width: 274, height: 62)
            .clipShape(Pill)                       // overflow: hidden (Padding-Box, Radius 31)
            .padding(1)                            // border 1
            .frame(width: 276, height: 64)
            .background(CSSBox(shape: Pill, paint: .color(k.nav), border: 1, borderColor: k.navBorder, shadows: k.navShadow))
            .background {
                if liveBlur { Pill.fill(.ultraThinMaterial) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Listen-Aktionen")

            DockFAB(t: t)
        }
        .frame(width: 350, height: 64)
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

/// Icons des Docks (Pfade exakt aus Dock.dc.html).
private enum DockIcon {
    static let checks: [SVGElement] = [.path("M18 6 7 17l-5-5M22 10l-7.5 7.5L13 16")]
    static let reset: [SVGElement] = [.path("M3 12a9 9 0 1 0 3-6.7L3 8M3 3v5h5")]
    static let clipboard: [SVGElement] = [.path("M9 3.5h6a1 1 0 0 1 1 1V6a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V4.5a1 1 0 0 1 1-1zM16 5h1.5A1.5 1.5 0 0 1 19 6.5v13a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 19.5v-13A1.5 1.5 0 0 1 6.5 5H8M9 12h6M9 16h4")]
}

// MARK: - Modell (entspricht renderVals() → items)

private enum DockKey { case check, sort, copy, delete }

/// Eintrag aus `defs` in renderVals().
private struct DockDef {
    let key: DockKey
    let text: String
    let label: String
    let icon: [SVGElement]
    let w: CGFloat
}

private struct DockItemModel {
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

// MARK: - Aktionsknopf

private struct DockActionButton: View {
    let item: DockItemModel

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                SVGIcon(item.icon, size: item.selected ? 18 : 22, color: item.color,
                        lineWidth: item.selected ? 2.2 : 1.9)
                if item.selected {
                    Text(item.text)
                        .font(AppFont.dm(13, 600))
                        .tracking(-0.065)                  // -0.005em × 13
                        .foregroundStyle(item.color)
                        .lineLimit(1)
                        .fixedSize()                       // white-space: nowrap
                }
            }
            .frame(width: item.selected ? item.pillWidth : 44, height: item.selected ? 54 : 44)
            .background(CSSBox(shape: Pill, paint: item.paint, border: 1, borderColor: item.border,
                               shadows: item.shadows))
            .contentShape(Pill)
            .opacity(item.disabled ? (item.selected ? 0.4 : 0.35) : 1)
        }
        .buttonStyle(.plain)
        // aria-disabled: nur Treffer sperren – `.disabled` würde bei .plain zusätzlich abdunkeln
        .allowsHitTesting(!item.disabled)
        .accessibilityLabel(item.label)
        .accessibilityValue(item.disabled ? "Nicht verfügbar" : "")
        .accessibilityAddTraits(item.selected ? .isSelected : [])
    }
}

// MARK: - FAB 64

private struct DockFAB: View {
    let t: ListTheme

    var body: some View {
        Button(action: {}) {
            SVGIcon(Icon.plus, size: 26, color: .white, lineWidth: 2.6)
                .shadow(color: .rgba(0, 40, 45, 0.35), radius: 1.5, x: 0, y: 2)   // drop-shadow(0 2px 3px)
                .frame(width: 64, height: 64)
                .background {
                    ZStack {
                        // left/right 11, top 4, Höhe 24
                        GlossEllipse(opacity: 0.6)
                            .frame(height: 24)
                            .padding(.horizontal, 11)
                            .padding(.top, 4)
                            .frame(maxHeight: .infinity, alignment: .top)
                        // left/right 17, bottom 4, Höhe 8, filter: blur(3px)
                        Ellipse()
                            .fill(Color.rgba(255, 255, 255, 0.22))
                            .frame(height: 8)
                            .blur(radius: 3)
                            .padding(.horizontal, 17)
                            .padding(.bottom, 4)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(Circle())                                          // overflow: hidden
                .background(CSSBox(shape: Circle(), paint: t.fabBg, shadows: t.fabShadow))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Neuer Artikel")
    }
}
