/*
 SortMenuScreen.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Dock-Menü „Sortieren“: Nach Kategorie, Alphabetisch, Zuletzt hinzugefügt, Manuell
   und der Schalter „Erledigte nach unten“.

 🔰 Notes for Beginners:
 - Vorlage: design-handoff/MyListUI/Screens/OverlayScreens.swift (SortMenu.dc.html), Werte 1:1.
   Popover 270 breit, links 20, unten 108; Zeiger links 104,33 (Mitte der Pille „Sortieren“).
 - Die gewählte Zeile trägt Häkchen, Titel 600 und Hervorhebung (wie „Nach Kategorie“ im Design).
 - Die Einstellung gilt pro Liste (ListSortSettings).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct SortMenuScreen: View {
    /// Bildschirmbreite: Der Zeiger folgt der Pille, auch wenn das Dock breiter als im Design ist.
    @Environment(\.hybridScreenWidth) var screenWidth
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var settings: ListSortSettings = .default
    var onSelect: (SortOrder) -> Void = { _ in }
    var onToggleDoneAtBottom: (Bool) -> Void = { _ in }
    var onDismiss: () -> Void = {}

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        return OverlayStage(appearance: appearance, accentHex: accentHex, dock: .sort, onDismiss: onDismiss) {
            PopoverMenu(k: k, width: 270, pointerLeft: DockGeometry.pointerLeft(for: .sort, screenWidth: screenWidth)) {
                PopoverMenuHeading(text: "Sortieren", k: k)
                row(k, .category, OverlayIcon.sortCategory, "Nach Kategorie", "Reihenfolge wie im Laden")
                row(k, .alphabetical, OverlayIcon.alphabetical, "Alphabetisch", "A bis Z")
                row(k, .dateAdded, OverlayIcon.clock, "Zuletzt hinzugefügt", "Neueste zuerst")
                row(k, .manual, OverlayIcon.grip, "Manuell", "Per Ziehen anordnen")
                PopoverMenuDivider(k: k)

                // Schalter-Zeile: min-height 52, padding 6 12, gap 12
                Button(action: { onToggleDoneAtBottom(!settings.doneAtBottom) }) {
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
                        OverlaySwitch(k: k, isOn: settings.doneAtBottom)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isToggle)
                .accessibilityValue(settings.doneAtBottom ? "An" : "Aus")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Sortieren")
            .overlayDockMenuPosition()
        }
    }

    private func row(_ k: OverlayTheme, _ order: SortOrder, _ icon: [SVGElement],
                     _ title: String, _ subtitle: String) -> some View {
        let selected = settings.order == order
        return PopoverMenuRow(k: k, icon: icon, title: title, subtitle: subtitle,
                              trailing: selected ? .check : .empty,
                              titleWeight: selected ? 600 : 500,
                              background: selected ? k.hi : .clear,
                              isSelected: selected,
                              action: { onSelect(order) })
    }
}

#Preview("Sortieren", traits: .fixedLayout(width: 390, height: 844)) { SortMenuScreen(appearance: .light) }
#Preview("Sortieren – Dark", traits: .fixedLayout(width: 390, height: 844)) { SortMenuScreen(appearance: .dark) }
