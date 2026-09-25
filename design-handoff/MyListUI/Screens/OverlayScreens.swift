//  OverlayScreens.swift
//  MyListUI
//
//  Overlays über der Liste (390 × 844, absolute Ebenen wie im Design):
//  • MenuOverlayScreen   – Kontext-Menü oben rechts (Menü-Knopf wird zum Schließen-Knopf)
//  • SortMenuScreen      – Dock „Sortieren“
//  • CopyChoiceScreen    – Dock „Kopieren“ (Auswahl + Vorschau)
//  • CopyDoneScreen      – Toast „Liste kopiert“ (ohne Scrim)
//  • DeleteChoiceScreen  – Dock „Löschen“
//  • UndoToastScreen     – Toast „1 Artikel gelöscht“ über der leeren Liste (ohne Scrim, ohne Extra-Dock)
//
//  Dock-Menüs: links 20, unten 108, Breite 270; Zeiger `bottom: -7px`, `left` je Screen.

import SwiftUI

// MARK: - Icons (Pfade exakt aus dem HTML, 24er-viewBox)

private enum OverlayIcon {
    static let members: [SVGElement] = [.path("M12.5 8a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0zM2.5 19c1-3 3.5-4.5 6.5-4.5s5.5 1.5 6.5 4.5M19.5 9a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0zM16 14.6c2.6.2 4.6 1.6 5.5 4.4")]
    static let box: [SVGElement] = [.path("M3.5 7.5 12 3l8.5 4.5v9L12 21l-8.5-4.5zM3.5 7.5 12 12l8.5-4.5M12 12v9")]
    static let tag: [SVGElement] = [.path("M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8zM8 7.2v1.6")]
    static let settings: [SVGElement] = [.path("M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0zM12 2.5v3M12 18.5v3M4.6 4.6l2.1 2.1M17.3 17.3l2.1 2.1M2.5 12h3M18.5 12h3M4.6 19.4l2.1-2.1M17.3 6.7l2.1-2.1")]
    static let sortCategory: [SVGElement] = [.path("M4 6h10M4 12h7M4 18h4M17 5v14M14 16l3 3 3-3")]
    static let alphabetical: [SVGElement] = [.path("M4 18l4-12 4 12M5.3 14h5.4M14 6h6l-6 12h6")]
    static let clock: [SVGElement] = [.path("M12 7v5l3 2M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z")]
    static let grip: [SVGElement] = [.path("M9 5h.01M15 5h.01M9 12h.01M15 12h.01M9 19h.01M15 19h.01")]
    static let moveDown: [SVGElement] = [.path("M12 4v12M7 11l5 5 5-5M5 20h14")]
    static let clipboard: [SVGElement] = [.path("M9 3.5h6a1 1 0 0 1 1 1V6a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V4.5a1 1 0 0 1 1-1zM16 5h1.5A1.5 1.5 0 0 1 19 6.5v13a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 19.5v-13A1.5 1.5 0 0 1 6.5 5H8")]
    static let checkAll: [SVGElement] = [.path("M18 6 7 17l-5-5M22 10l-7.5 7.5L13 16")]
}

/// Dock-Menü-Position: `left: 20px; bottom: 108px; width: 270px`.
private extension View {
    func overlayDockMenuPosition() -> some View {
        self
            .padding(.leading, 20)
            .padding(.bottom, 108)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    /// Toast: `left: 20px; right: 20px; bottom: <bottom>`.
    func overlayToastPosition(bottom: CGFloat) -> some View {
        self
            .padding(.horizontal, 20)
            .padding(.bottom, bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

// MARK: - Kontext-Menü

// Quelle: Design/html/MenuOverlay.dc.html (+ MenuOverlayDark.dc.html)
struct MenuOverlayScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var onClose: () -> Void = {}
    var onSelect: (String) -> Void = { _ in }

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex, variant: .listMenu)
        return OverlayStage(appearance: appearance, accentHex: accentHex, onDismiss: onClose) {
            // Aktiver Menü-Knopf bleibt über der Abdunkelung: rechts 20, oben 62, 44 (border-box), Rahmen 1,5
            Button(action: onClose) {
                SVGIcon(Icon.close, size: 20, color: k.accentText, lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .background(CSSBox(shape: Circle(), paint: .color(k.btn), border: 1.5, borderColor: k.btnRing))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menü schließen")
            .padding(.top, 62)
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // nav: rechts 20, oben 116, Breite 286
            PopoverMenu(k: k, width: 286) {
                // Kopf: padding 10 12 8 12, gap 2
                VStack(alignment: .leading, spacing: 2) {
                    OverlayCapsLabel(text: "Aktuelle Liste", size: 12, color: k.sub)
                    Text("My List")
                        .font(AppFont.outfit(18, 600))
                        .foregroundStyle(k.text)
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 12))
                .frame(maxWidth: .infinity, alignment: .leading)

                // Gruppe 1 (jede Gruppe beginnt mit einer Trennlinie)
                PopoverMenuDivider(k: k)
                row(k, OverlayIcon.members, "Mitglieder & Teilen", meta: "1", highlight: true)
                // Gruppe 2
                PopoverMenuDivider(k: k)
                row(k, OverlayIcon.box, "Artikel verwalten")
                row(k, OverlayIcon.tag, "Kategorien verwalten")
                // Gruppe 3
                PopoverMenuDivider(k: k)
                row(k, OverlayIcon.settings, "Einstellungen")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Listen-Menü")
            .padding(.top, 116)
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    /// Zeile 48 hoch, Label 15/500, Meta 13/500 sub.
    private func row(_ k: OverlayTheme, _ icon: [SVGElement], _ title: String,
                     meta: String? = nil, highlight: Bool = false) -> some View {
        let trailing: PopoverMenuTrailing
        if let meta {
            trailing = .text(meta, weight: 500)
        } else {
            trailing = .empty
        }
        return PopoverMenuRow(k: k, icon: icon, title: title,
                       trailing: trailing,
                       size: .compact,
                       background: highlight ? k.hi : .clear,
                       action: { onSelect(title) })
    }
}

// MARK: - Sortieren

// Quelle: Design/html/SortMenu.dc.html (+ SortMenuDark.dc.html)
struct SortMenuScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var onDismiss: () -> Void = {}

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        return OverlayStage(appearance: appearance, accentHex: accentHex, dock: .sort, onDismiss: onDismiss) {
            PopoverMenu(k: k, width: 270, pointerLeft: 104.33) {
                PopoverMenuHeading(text: "Sortieren", k: k)
                PopoverMenuRow(k: k, icon: OverlayIcon.sortCategory, title: "Nach Kategorie",
                               subtitle: "Reihenfolge wie im Laden", trailing: .check,
                               titleWeight: 600, background: k.hi, isSelected: true)
                PopoverMenuRow(k: k, icon: OverlayIcon.alphabetical, title: "Alphabetisch", subtitle: "A bis Z")
                PopoverMenuRow(k: k, icon: OverlayIcon.clock, title: "Zuletzt hinzugefügt", subtitle: "Neueste zuerst")
                PopoverMenuRow(k: k, icon: OverlayIcon.grip, title: "Manuell", subtitle: "Per Ziehen anordnen")
                PopoverMenuDivider(k: k)

                // Schalter-Zeile: min-height 52, padding 6 12, gap 12
                HStack(spacing: 12) {
                    // Der Text bricht um; per flex-shrink schrumpft das SVG im Browser auf ≈ 18,5 × 20
                    // (Icon skaliert, vertikal zentriert) – Text beginnt dadurch 1,5 pt weiter links.
                    SVGIcon(OverlayIcon.moveDown, size: 18.5, color: k.accentText, lineWidth: 1.9)
                        .frame(width: 18.5, height: 20)
                    Text("Erledigte nach unten")
                        .font(AppFont.dm(15, 500))
                        .foregroundStyle(k.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    OverlaySwitch(k: k)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .accessibilityElement(children: .combine)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Sortieren")
            .overlayDockMenuPosition()
        }
    }
}

// MARK: - Kopieren – Auswahl

// Quelle: Design/html/CopyChoice.dc.html (+ CopyChoiceDark.dc.html)
struct CopyChoiceScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var onDismiss: () -> Void = {}

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        return OverlayStage(appearance: appearance, accentHex: accentHex, dock: .copy, onDismiss: onDismiss) {
            PopoverMenu(k: k, width: 270, pointerLeft: 155.67) {
                PopoverMenuHeading(text: "In Zwischenablage kopieren", k: k)
                PopoverMenuRow(k: k, icon: OverlayIcon.clipboard, title: "Offene Artikel",
                               subtitle: "Was noch gekauft werden muss", trailing: .text("1"),
                               titleWeight: 600, background: k.hi)
                PopoverMenuRow(k: k, icon: OverlayIcon.checkAll, title: "Alle Artikel",
                               subtitle: "Inklusive abgehakter", trailing: .text("1"))
                PopoverMenuDivider(k: k)

                // Vorschau: margin 4 6 6 6, padding 10 12, Radius 14, Rahmen 1 (content-box), gap 4
                VStack(alignment: .leading, spacing: 4) {
                    OverlayCapsLabel(text: "Vorschau", size: 11, color: k.sub)
                    // font-size 14, line-height 1.45 (= 20,3), white-space: pre-line
                    Text("My List\n• Butter · 1 Packung")
                        .font(AppFont.dm(14, 400))
                        .foregroundStyle(k.text)
                        .cssLineHeight(14 * 1.45, font: AppFont.ui(.dmSans, 14, 400))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))   // 1 Rahmen + 10/12
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CSSBox(shape: RR(14), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                .padding(EdgeInsets(top: 4, leading: 6, bottom: 6, trailing: 6))
                .accessibilityElement(children: .combine)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("In Zwischenablage kopieren")
            .overlayDockMenuPosition()
        }
    }
}

// MARK: - Kopieren – Bestätigung

// Quelle: Design/html/CopyDone.dc.html (+ CopyDoneDark.dc.html)
// Kein Scrim: Dock (active: .copied) liegt direkt über dem Dock der Liste.
struct CopyDoneScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        return OverlayStage(appearance: appearance, accentHex: accentHex, showsScrim: false, dock: .copied) {
            // links/rechts 20, unten 112, Höhe 60, padding 0 16 0 10, Radius 22
            GlassToast(k: k, height: 60, radius: 22, leading: 10, trailing: 16) {
                SVGIcon(Icon.check, size: 20, color: k.toastAccent, lineWidth: 2.4)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(k.okBg))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Liste kopiert")
                        .font(AppFont.dm(15, 600))
                        .foregroundStyle(k.toastText)
                    Text("1 offener Artikel · bereit zum Einfügen")
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(k.toastSub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .overlayToastPosition(bottom: 112)
        }
    }
}

// MARK: - Löschen – Auswahl

// Quelle: Design/html/DeleteChoice.dc.html (+ DeleteChoiceDark.dc.html)
struct DeleteChoiceScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var onDismiss: () -> Void = {}
    var onDeleteAll: () -> Void = {}

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        return OverlayStage(appearance: appearance, accentHex: accentHex, dock: .delete, onDismiss: onDismiss) {
            PopoverMenu(k: k, width: 270, pointerLeft: 211) {
                PopoverMenuHeading(text: "Artikel löschen", k: k)
                PopoverMenuRow(k: k, icon: OverlayIcon.checkAll, title: "Nur abgehakte",
                               subtitle: "Noch nichts abgehakt", trailing: .text("0"), isDisabled: true)
                PopoverMenuRow(k: k, icon: Icon.trash, title: "Alle Artikel",
                               subtitle: "Liste wird geleert", trailing: .text("1", color: k.danger),
                               titleWeight: 600, tint: k.danger, background: k.dangerSoft,
                               action: onDeleteAll)
                PopoverMenuDivider(k: k)

                // „Abbrechen“: Höhe 48, Radius 16, 15/600 Akzent, zentriert
                Button(action: onDismiss) {
                    Text("Abbrechen")
                        .font(AppFont.dm(15, 600))
                        .foregroundStyle(k.accentText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .contentShape(RR(16))
                }
                .buttonStyle(.plain)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Artikel löschen")
            .overlayDockMenuPosition()
        }
    }
}

// MARK: - Rückgängig-Toast

// Quelle: Design/html/UndoToast.dc.html (+ UndoToastDark.dc.html)
// Liste im Zustand .empty, kein Scrim, kein zusätzliches Dock.
struct UndoToastScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    /// Restzeit-Balken (Design: 62 % der Padding-Box)
    var remaining: CGFloat = 0.62
    var onUndo: () -> Void = {}

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        return OverlayStage(appearance: appearance, accentHex: accentHex, listState: .empty, showsScrim: false) {
            // links/rechts 20, unten 114, Höhe 56, padding 0 8 0 16, Radius 20, overflow hidden
            GlassToast(k: k, height: 56, radius: 20, leading: 16, trailing: 8) {
                SVGIcon(Icon.trash, size: 20, color: k.toastIcon, lineWidth: 1.9)
                Text("1 Artikel gelöscht")
                    .font(AppFont.dm(15, 500))
                    .foregroundStyle(k.toastText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onUndo) {
                    HStack(spacing: 6) {
                        SVGIcon(Icon.undo, size: 16, color: k.toastAccent, lineWidth: 2.2)
                        Text("Rückgängig")
                            .font(AppFont.dm(15, 600))
                            .foregroundStyle(k.toastAccent)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(RR(14).fill(k.undoBg))
                    .contentShape(RR(14))
                }
                .buttonStyle(.plain)
            }
            .overlay {
                // Restzeit: absolute links 0 / unten 0 der Padding-Box, Höhe 3,
                // an der inneren Rundung (20 − 1 = 19) abgeschnitten.
                GeometryReader { g in
                    Rectangle()
                        .fill(k.timer)
                        .frame(width: g.size.width * remaining, height: 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .clipShape(RR(19))
                .padding(1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .contain)
            .overlayToastPosition(bottom: 114)
        }
    }
}
