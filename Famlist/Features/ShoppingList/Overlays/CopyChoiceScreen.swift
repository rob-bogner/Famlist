/*
 CopyChoiceScreen.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Dock-Menü „In Zwischenablage kopieren“: Offene Artikel / Alle Artikel mit Anzahl
   und einer Textvorschau.

 🔰 Notes for Beginners:
 - Vorlage: design-handoff/MyListUI/Screens/OverlayScreens.swift (CopyChoice.dc.html), Werte 1:1.
   Zeiger links 155,67 (Mitte der Pille „Kopieren“).
 - Die Vorschau zeigt den Text der Auswahl „Offene Artikel“. Bei langen Listen ist sie auf
   8 Zeilen begrenzt, damit das Popover auf dem Bildschirm bleibt (Design zeigt nur 2 Zeilen).
 - Ein Tipp auf eine Zeile kopiert sofort (ListClipboardFormatter).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct CopyChoiceScreen: View {
    /// Bildschirmbreite: Der Zeiger folgt der Pille, auch wenn das Dock breiter als im Design ist.
    @Environment(\.hybridScreenWidth) var screenWidth
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var openCount = 1
    var allCount = 1
    var previewText = "My List\n• Butter · 1 Packung"
    var onSelect: (ListClipboardFormatter.Scope) -> Void = { _ in }
    var onDismiss: () -> Void = {}

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        return OverlayStage(appearance: appearance, accentHex: accentHex, dock: .copy, onDismiss: onDismiss) {
            PopoverMenu(k: k, width: 270, pointerLeft: DockGeometry.pointerLeft(for: .copy, screenWidth: screenWidth)) {
                PopoverMenuHeading(text: "In Zwischenablage kopieren", k: k)
                PopoverMenuRow(k: k, icon: OverlayIcon.clipboard, title: "Offene Artikel",
                               subtitle: "Was noch gekauft werden muss", trailing: .text("\(openCount)"),
                               titleWeight: 600, background: k.hi, isDisabled: openCount == 0,
                               action: { onSelect(.open) })
                PopoverMenuRow(k: k, icon: OverlayIcon.checkAll, title: "Alle Artikel",
                               subtitle: "Inklusive abgehakter", trailing: .text("\(allCount)"),
                               isDisabled: allCount == 0,
                               action: { onSelect(.all) })
                PopoverMenuDivider(k: k)

                // Vorschau: margin 4 6 6 6, padding 10 12, Radius 14, Rahmen 1 (content-box), gap 4
                VStack(alignment: .leading, spacing: 4) {
                    OverlayCapsLabel(text: "Vorschau", size: 11, color: k.sub)
                    // font-size 14, line-height 1.45 (= 20,3), white-space: pre-line
                    Text(previewText)
                        .font(AppFont.dm(14, 400))
                        .foregroundStyle(k.text)
                        .cssLineHeight(14 * 1.45, font: AppFont.ui(.dmSans, 14, 400))
                        .lineLimit(8)
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

#Preview("Kopieren", traits: .fixedLayout(width: 390, height: 844)) { CopyChoiceScreen(appearance: .light) }
#Preview("Kopieren – Dark", traits: .fixedLayout(width: 390, height: 844)) { CopyChoiceScreen(appearance: .dark) }
