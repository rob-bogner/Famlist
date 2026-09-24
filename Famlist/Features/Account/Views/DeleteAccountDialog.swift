/*
 DeleteAccountDialog.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bestätigungsdialog „Konto löschen?“ über den Einstellungen (App-Store-Pflicht).

 🔰 Notes for Beginners:
 - Vorlage: DeleteAccountScreen in design-handoff/MyListUI/Screens/AccountScreens.swift
   (DeleteAccount.dc.html): links/rechts 24, oben 250, Radius 28.
 - „Konto endgültig löschen“ ruft delete_my_account() auf. Solange das läuft, zeigt der Knopf einen
   Ladekreis und beide Knöpfe sind gesperrt.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 4).
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

                Text(errorText ?? "Deine eigenen Listen, Artikel und Fotos werden dauerhaft gelöscht. Aus geteilten Listen wirst du entfernt. Das lässt sich nicht rückgängig machen.")
                    .font(AppFont.dm(14, 400))
                    .foregroundStyle(errorText == nil ? k.sub : t.danger)
                    .multilineTextAlignment(.center)
                    .cssLineHeight(21, font: bodyFont)             // line-height 1.5
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onConfirm) {
                    ZStack {
                        Text("Konto endgültig löschen")
                            .font(AppFont.dm(16, 600))
                            .foregroundStyle(.white)
                            .opacity(isWorking ? 0 : 1)
                        if isWorking { ProgressView().tint(.white) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Pill.fill(t.danger))
                    .contentShape(Pill)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Button(action: onCancel) {
                    Text("Abbrechen")
                        .font(AppFont.dm(16, 600))
                        .foregroundStyle(t.accentText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .contentShape(Pill)
                }
                .buttonStyle(.plain)
            }
            .allowsHitTesting(!isWorking)
            .padding(.top, 25)                                   // 24 + 1 Rahmen
            .padding(.horizontal, 21)                            // 20 + 1 Rahmen
            .padding(.bottom, 19)                                // 18 + 1 Rahmen
            .frame(maxWidth: .infinity)
            .background(CSSBox(shape: RR(28), paint: .color(t.menu), border: 1, borderColor: t.menuBorder,
                               shadows: t.menuShadow))
            .padding(.horizontal, 24)
            .padding(.top, 250)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }
}

#Preview("Konto löschen", traits: .fixedLayout(width: 390, height: 844)) { DeleteAccountDialog(appearance: .light) }
#Preview("Konto löschen – Dark", traits: .fixedLayout(width: 390, height: 844)) { DeleteAccountDialog(appearance: .dark) }
