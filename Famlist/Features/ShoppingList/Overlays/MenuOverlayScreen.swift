/*
 MenuOverlayScreen.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kontext-Menü ☰ oben rechts: Kopf „Aktuelle Liste“ + Listenname, darunter die Menü-Gruppen.
   Der Menü-Knopf wird zum Schließen-Knopf (44, Rahmen 1,5 im Akzent).

 🔰 Notes for Beginners:
 - Vorlage: design-handoff/MyListUI/Screens/OverlayScreens.swift (MenuOverlay.dc.html).
   Werte 1:1: nav rechts 20 / oben 116 / Breite 286, Zeilen 48 hoch.
 - Abweichung (Roberts Entscheidung): zwei zusätzliche Zeilen „Kassenzettel scannen“ und
   „Import aus Zwischenablage“ in Gruppe 2, gleicher Zeilenstil. Siehe PLAN.md §5.
 - In der App zeichnet ShoppingListView Liste und Abdunkelung (hybridHosted).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct MenuOverlayScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var listTitle = "My List"
    /// Meta-Zahl rechts neben „Mitglieder & Teilen“ (Anzahl Mitglieder).
    var memberCount = 1
    var onClose: () -> Void = {}
    var onSelect: (ListMenuItem) -> Void = { _ in }

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
                    Text(listTitle)
                        .font(AppFont.outfit(18, 600))
                        .foregroundStyle(k.text)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(EdgeInsets(top: 10, leading: 12, bottom: 8, trailing: 12))
                .frame(maxWidth: .infinity, alignment: .leading)

                // Gruppe 1 (jede Gruppe beginnt mit einer Trennlinie)
                PopoverMenuDivider(k: k)
                row(k, .members, OverlayIcon.members, "Mitglieder & Teilen", meta: "\(memberCount)", highlight: true)
                // Gruppe 2
                PopoverMenuDivider(k: k)
                row(k, .manageItems, OverlayIcon.box, "Artikel verwalten")
                row(k, .manageCategories, OverlayIcon.tag, "Kategorien verwalten")
                row(k, .receipt, Icon.camera, "Kassenzettel scannen")
                row(k, .importClipboard, OverlayIcon.clipboard, "Import aus Zwischenablage")
                // Gruppe 3
                PopoverMenuDivider(k: k)
                row(k, .settings, OverlayIcon.settings, "Einstellungen")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Listen-Menü")
            .padding(.top, 116)
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    /// Zeile 48 hoch, Label 15/500, Meta 13/500 sub.
    private func row(_ k: OverlayTheme, _ item: ListMenuItem, _ icon: [SVGElement], _ title: String,
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
                              action: { onSelect(item) })
    }
}

#Preview("Kontext-Menü", traits: .fixedLayout(width: 390, height: 844)) { MenuOverlayScreen(appearance: .light) }
#Preview("Kontext-Menü – Dark", traits: .fixedLayout(width: 390, height: 844)) { MenuOverlayScreen(appearance: .dark) }
