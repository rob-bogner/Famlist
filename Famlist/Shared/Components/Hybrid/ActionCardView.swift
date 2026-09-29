/*
 ActionCardView.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Aktionskarte (Canvas: ItemSyncFailedDialog u. a.): Symbol-Kachel 48 + Titel/Text, Zusatzinhalt, Knöpfe.

 🔰 Notes for Beginners:
 - Karte: Padding 20 / 16 / 16, Radius 30, Fläche/Rand/Schatten aus ActionCardTokens.
 - Kopf: Kachel 48 (Radius 16, Ton-Hintergrund, Symbol 24 in Tonfarbe), 14 Abstand, Titel Outfit 19/600,
   Text DM Sans 14 sub (Zeilenhöhe 1,45). Abstände zwischen den Blöcken 16, zwischen Knöpfen 10.
 - Die Karte selbst positioniert sich nicht – das macht ActionCardHost (unten, links/rechts 12, unten 30).

 📝 Last Change:
 - Initial creation (Designsprache statt Systemdialoge).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Visual action card that replaces iOS confirmation dialogs and alerts.
struct ActionCardView: View {
    let content: ActionCardContent
    let k: SheetTheme
    let close: ActionCardContent.Close

    var body: some View {
        let d = ActionCardTokens(k)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                SVGIcon(content.icon, size: 24, color: d.color(content.tone), lineWidth: 2)
                    .frame(width: 48, height: 48)
                    .background(RR(16).fill(d.soft(content.tone)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(content.title)
                        .font(AppFont.outfit(19, 600))
                        .tracking(-0.19)                                      // -0.01em × 19
                        .foregroundStyle(d.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let message = content.message {
                        Text(message)
                            .font(AppFont.dm(14, 400))
                            .lineSpacing(6)                                   // line-height 1.45
                            .foregroundStyle(d.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let accessory = content.accessory {
                accessory(close)
            }
            VStack(spacing: 10) {
                ForEach(Array(content.buttons.enumerated()), id: \.offset) { _, button in
                    ActionCardButtonView(button: button, k: k, tokens: d) { close(button.action) }
                }
            }
            .padding(.top, 2)
        }
        .padding(.top, 21)                                                    // 20 + 1 Rahmen
        .padding(.horizontal, 17)                                             // 16 + 1 Rahmen
        .padding(.bottom, 17)
        .frame(maxWidth: .infinity)
        .background(CSSBox(shape: RR(30), paint: .color(d.background), border: 1, borderColor: d.border,
                           shadows: d.shadow))
        .accessibilityElement(children: .contain)
    }
}

#Preview("ActionCard") {
    let k = SheetTheme(.light)
    ActionCardView(content: ActionCardContent(icon: Icon.trash, tone: .danger, title: "„My List“ löschen?",
                                              message: "Die Liste und alle ihre Artikel werden für alle Mitglieder gelöscht.",
                                              buttons: [ActionCardButton(title: "Liste löschen", icon: Icon.trash, role: .destructive),
                                                        .cancel()]),
                   k: k, close: { _ in })
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color.gray.opacity(0.4))
}

#Preview("ActionCard – Dark") {
    let k = SheetTheme(.dark)
    ActionCardView(content: ActionCardContent(icon: Icon.sync, tone: .warn, title: "Sync fehlgeschlagen",
                                              message: "„Butter“ konnte nicht synchronisiert werden. Soll ein neuer Versuch gestartet werden?",
                                              buttons: [ActionCardButton(title: "Erneut synchronisieren", icon: Icon.sync, role: .primary),
                                                        .cancel()]),
                   k: k, close: { _ in })
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color.black)
}
