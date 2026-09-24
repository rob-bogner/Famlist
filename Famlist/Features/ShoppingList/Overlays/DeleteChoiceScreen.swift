/*
 DeleteChoiceScreen.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Dock-Menü „Artikel löschen“: Nur abgehakte / Alle Artikel, dazu „Abbrechen“.
   Kein Bestätigungsdialog: danach erscheint der Toast mit „Rückgängig“.

 🔰 Notes for Beginners:
 - Vorlage: design-handoff/MyListUI/Screens/OverlayScreens.swift (DeleteChoice.dc.html), Werte 1:1.
   Zeiger links 211 (Mitte der roten Pille „Löschen“).
 - Das Design zeigt nur den Zustand „nichts abgehakt“ (Zeile gedimmt, „Noch nichts abgehakt“).
   Mit abgehakten Artikeln lautet der Untertitel „Offene Artikel bleiben“ (eigener Text, PLAN.md §9).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct DeleteChoiceScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var checkedCount = 0
    var allCount = 1
    var onDeleteChecked: () -> Void = {}
    var onDeleteAll: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        return OverlayStage(appearance: appearance, accentHex: accentHex, dock: .delete, onDismiss: onDismiss) {
            PopoverMenu(k: k, width: 270, pointerLeft: 211) {
                PopoverMenuHeading(text: "Artikel löschen", k: k)
                PopoverMenuRow(k: k, icon: OverlayIcon.checkAll, title: "Nur abgehakte",
                               subtitle: checkedCount == 0 ? "Noch nichts abgehakt" : "Offene Artikel bleiben",
                               trailing: .text("\(checkedCount)"), isDisabled: checkedCount == 0,
                               action: onDeleteChecked)
                PopoverMenuRow(k: k, icon: Icon.trash, title: "Alle Artikel",
                               subtitle: "Liste wird geleert", trailing: .text("\(allCount)", color: k.danger),
                               titleWeight: 600, tint: k.danger, background: k.dangerSoft,
                               isDisabled: allCount == 0,
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

#Preview("Artikel löschen", traits: .fixedLayout(width: 390, height: 844)) { DeleteChoiceScreen(appearance: .light) }
#Preview("Artikel löschen – Dark", traits: .fixedLayout(width: 390, height: 844)) { DeleteChoiceScreen(appearance: .dark) }
