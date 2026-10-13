/*
 ShoppingDoneMenuScreen.swift
 Famlist
 Created on: 13.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Einkauf erledigt“ als Dock-Popup über „Zurücksetzen“ (Design: ShoppingDonePopover / ShoppingDonePopoverSaved),
   statt des früheren Vollbilds (ShoppingDoneView).

 🔰 Notes for Beginners:
 - Noch kein Kassenzettel: „Kassenzettel scannen“ (hervorgehoben) · „Abgehakte löschen“ · „Liste behalten“.
 - Nach dem Kassenzettel (`savedPrices` gesetzt): „Abgehakte löschen & fertig“ (hervorgehoben) · „Liste behalten“.
 - Abdunkelung antippen = „Liste behalten“. Löschen läuft über das Löschen mit Rückgängig-Toast.

 📝 Last Change:
 - Initial creation (Wunsch Robert 13.10.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ShoppingDoneMenuScreen: View {
    @Environment(\.hybridScreenWidth) var screenWidth
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var listName = "My List"
    var checkedCount = 0
    /// Summe der Liste (nil oder 0 → nicht anzeigen).
    var total: Double? = nil
    /// nil = noch kein Kassenzettel; sonst Anzahl gespeicherter Preise.
    var savedPrices: Int? = nil
    var onScan: () -> Void = {}
    var onFinish: () -> Void = {}
    var onKeep: () -> Void = {}

    private var subtitle: String {
        var parts = [listName]
        if let savedPrices {
            if let total, total > 0 { parts.append(PriceDisplaySetting.euro(total)) }
            parts.append(savedPrices == 1 ? "1 Preis gespeichert" : "\(savedPrices) Preise gespeichert")
        } else {
            parts.append("alles abgehakt")
            if let total, total > 0 { parts.append(PriceDisplaySetting.euro(total)) }
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        return OverlayStage(appearance: appearance, accentHex: accentHex, dock: DockActive.none, dockPill: .allDone,
                            onDismiss: onKeep) {
            PopoverMenu(k: k, width: 300, pointerLeft: DockGeometry.pointerLeft(for: .none, screenWidth: screenWidth)) {
                header(k: k)
                PopoverMenuDivider(k: k)
                if savedPrices == nil {
                    PopoverMenuRow(k: k, icon: ShoppingDoneIcon.camera, title: "Kassenzettel scannen",
                                   subtitle: "Preise für den Preisverlauf erfassen", titleWeight: 600,
                                   background: k.hi, action: onScan)
                        .accessibilityLabel("Kassenzettel scannen")
                        .accessibilityHint("Preise für den Preisverlauf erfassen")
                    PopoverMenuRow(k: k, icon: Icon.trash, title: "Abgehakte löschen",
                                   subtitle: "Liste ist frei für den nächsten Einkauf",
                                   tint: k.danger, isDisabled: checkedCount == 0, action: onFinish)
                        .accessibilityLabel("Abgehakte löschen")
                        .accessibilityHint("Liste ist frei für den nächsten Einkauf")
                } else {
                    PopoverMenuRow(k: k, icon: Icon.trash, title: "Abgehakte löschen & fertig",
                                   subtitle: "Liste ist frei für den nächsten Einkauf", titleWeight: 600,
                                   tint: k.danger, background: k.dangerSoft,
                                   isDisabled: checkedCount == 0, action: onFinish)
                        .accessibilityLabel("Abgehakte löschen & fertig")
                        .accessibilityHint("Liste ist frei für den nächsten Einkauf")
                }
                PopoverMenuRow(k: k, icon: OverlayIcon.checkAll, title: "Liste behalten",
                               subtitle: "Alles bleibt abgehakt", action: onKeep)
                    .accessibilityLabel("Liste behalten")
                    .accessibilityHint("Alles bleibt abgehakt")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Einkauf erledigt")
            .overlayDockMenuPosition()
        }
    }

    /// Grüner Haken 40 · „Einkauf erledigt“ (Outfit 18/600) · Liste, Stand, Summe (12, sub).
    private func header(k: OverlayTheme) -> some View {
        HStack(spacing: 12) {
            SVGIcon(Icon.check, size: 20, color: .white, lineWidth: 2.6)
                .frame(width: 40, height: 40)
                .background(Circle().fill(RadialGradient(colors: [k.isDark ? .hex("#7FE3BD") : .hex("#5FD3A3"),
                                                                  k.isDark ? .hex("#2FB383") : .hex("#1F9A66")],
                                                         center: UnitPoint(x: 0.32, y: 0.22), startRadius: 0, endRadius: 34)))
                .shadow(color: Color.rgba(31, 138, 91, 0.45), radius: 7, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("Einkauf erledigt")
                    .font(AppFont.outfit(18, 600))
                    .foregroundStyle(k.text)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(k.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

enum ShoppingDoneIcon {
    /// Kamera (wie „Kassenzettel scannen“ im Menü ☰).
    static let camera: [SVGElement] = [
        .path("M4 8.5A1.5 1.5 0 0 1 5.5 7h2.3l1.4-2h5.6l1.4 2h2.3A1.5 1.5 0 0 1 20 8.5v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 17.5z"),
        .circle(12, 12.8, 3.2),
    ]
}

#Preview("Einkauf erledigt", traits: .fixedLayout(width: 390, height: 844)) {
    ShoppingDoneMenuScreen(appearance: .light, checkedCount: 6, total: 11.51)
}
#Preview("Nach dem Kassenzettel – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ShoppingDoneMenuScreen(appearance: .dark, checkedCount: 6, total: 11.51, savedPrices: 5)
}
