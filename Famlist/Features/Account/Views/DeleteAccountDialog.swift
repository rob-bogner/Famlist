/*
 DeleteAccountDialog.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bestätigungsdialog „Konto löschen?“ über den Einstellungen (App-Store-Pflicht).

 🔰 Notes for Beginners:
 - Vorlage: DeleteAccountScreen in design-handoff/MyListUI/Screens/AccountScreens.swift
   (DeleteAccount.dc.html): links/rechts 24, oben 214, Radius 28.
 - „Konto löschen“ ruft delete_my_account() auf (archiviert 60 Tage, Migration 027). Solange das läuft, zeigt der Knopf einen
   Ladekreis und beide Knöpfe sind gesperrt.

 📝 Last Change:
 - Neuer Text und Hinweis auf 60 Tage Wiederherstellen (Konto-Archiv, 27.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct DeleteAccountDialog: View {
    let appearance: Appearance
    var isWorking = false
    var errorText: String?
    var onConfirm: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        let t = ListAccountTokens(appearance)
        let k = t.k
        let bodyFont = AppFont.ui(.dmSans, 14, 400)

        ListAccountBackdrop(scrim: t.scrimDialog, alignment: .top) {
            DesignListScreen(appearance: appearance)
        } content: {
            VStack(spacing: 10) {
                SVGIcon(ListAccountIcon.warning, size: 26, color: t.danger, lineWidth: 2)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(t.dangerSoft))
                    .accessibilityHidden(true)

                Text("Konto löschen?")
                    .font(AppFont.outfit(21, 600))
                    .foregroundStyle(k.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)

                Text(errorText ?? "Dein Konto wird sofort deaktiviert. Deine geteilten Listen verschwinden bei allen Mitgliedern, und aus Listen anderer wirst du entfernt.")
                    .font(AppFont.dm(14, 400))
                    .foregroundStyle(errorText == nil ? k.sub : t.danger)
                    .multilineTextAlignment(.center)
                    .cssLineHeight(21, font: bodyFont)             // line-height 1.5
                    .fixedSize(horizontal: false, vertical: true)

                restoreHint(k: k)

                // Schieben zum Löschen statt Knopf (29.09.2026)
                SlideToConfirm(title: "Konto löschen", k: k, isWorking: isWorking, action: onConfirm)
                    .padding(.top, 8)

            }
            .allowsHitTesting(!isWorking)
            .padding(.top, 25)                                   // 24 + 1 Rahmen
            .padding(.horizontal, 21)                            // 20 + 1 Rahmen
            .padding(.bottom, 19)                                // 18 + 1 Rahmen
            .frame(maxWidth: .infinity)
            .background(CSSBox(shape: RR(28), paint: .color(t.menu), border: 1, borderColor: t.menuBorder,
                               shadows: t.menuShadow))
            .overlay(alignment: .topTrailing) {
                // ✕ statt „Abbrechen“ (Canvas: Glas-Knopf 40, oben rechts 14 / 14)
                GlassCircleButton(style: .neutral, appearance: k.appearance, accent: k.a, icon: Icon.close,
                                  label: "Schließen", size: 40, iconSize: 16, action: onCancel)
                    .accessibilityIdentifier("actionCardClose")
                    .padding(.top, 14)
                    .padding(.trailing, 14)
                    .disabled(isWorking)
            }
            .padding(.horizontal, 24)
            .padding(.top, 214)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    /// Hinweisfeld: padding 10/12, Radius 14, 13 pt, line-height 1.45; „60 Tagen“ fett in Textfarbe.
    private func restoreHint(k: SheetTheme) -> some View {
        let strong = AttributedString("60 Tagen", attributes: AttributeContainer()
            .font(AppFont.dm(13, 600)).foregroundColor(k.text))
        let text = AttributedString("Meldest du dich innerhalb von ") + strong
            + AttributedString(" wieder an, kannst du alles wiederherstellen. Danach wird alles endgültig gelöscht.")
        return Text(text)
            .font(AppFont.dm(13, 400))
            .foregroundStyle(k.sub)
            .multilineTextAlignment(.center)
            .cssLineHeight(18.85, font: AppFont.ui(.dmSans, 13, 400))   // line-height 1.45
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(RR(14).fill(k.field))
    }
}

#Preview("Konto löschen", traits: .fixedLayout(width: 390, height: 844)) { DeleteAccountDialog(appearance: .light) }
#Preview("Konto löschen – Dark", traits: .fixedLayout(width: 390, height: 844)) { DeleteAccountDialog(appearance: .dark) }
