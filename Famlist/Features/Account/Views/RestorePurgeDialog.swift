/*
 RestorePurgeDialog.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bestätigung „Jetzt endgültig löschen?“ auf dem Screen „Konto wiederherstellen“.

 🔰 Notes for Beginners:
 - Vorlage: RestoreAccount.dc.html, Zustand confirm (RestorePurgeDialog): links/rechts 24, oben 236, Radius 28.
 - Hintergrund (Abdunkelung + Weichzeichner) legt RestoreAccountView darunter.
 - „Endgültig löschen“ löscht sofort alles (Edge Function purge-my-account). Solange das läuft, zeigt der
   Knopf einen Ladekreis und beide Knöpfe sind gesperrt.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 3).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct RestorePurgeDialog: View {
    let appearance: Appearance
    var isWorking = false
    var onConfirm: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        let t = ListAccountTokens(appearance)
        let k = t.k

        VStack(spacing: 10) {
            SVGIcon(ListAccountIcon.warning, size: 26, color: t.danger, lineWidth: 2)
                .frame(width: 56, height: 56)
                .background(Circle().fill(t.dangerSoft))
                .accessibilityHidden(true)

            Text("Jetzt endgültig löschen?")
                .font(AppFont.outfit(21, 600))
                .foregroundStyle(k.text)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)

            Text("Alle deine Daten werden sofort und unwiderruflich gelöscht: Listen, Artikel, Fotos und Kassenzettel. Geteilte Listen verschwinden für alle Mitglieder. Das lässt sich nicht rückgängig machen.")
                .font(AppFont.dm(14, 400))
                .foregroundStyle(k.sub)
                .multilineTextAlignment(.center)
                .cssLineHeight(21, font: AppFont.ui(.dmSans, 14, 400))       // line-height 1.5
                .fixedSize(horizontal: false, vertical: true)

            // Schieben zum Löschen statt Knopf (29.09.2026)
            SlideToConfirm(title: "Endgültig löschen", k: k, isWorking: isWorking, action: onConfirm)
                .padding(.top, 8)

        }
        .allowsHitTesting(!isWorking)
        .padding(.top, 25)                                                   // 24 + 1 Rahmen
        .padding(.horizontal, 21)                                            // 20 + 1 Rahmen
        .padding(.bottom, 19)                                                // 18 + 1 Rahmen
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
        .padding(.top, 236)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

#Preview("Jetzt endgültig löschen", traits: .fixedLayout(width: 390, height: 844)) {
    ZStack { Color.white; ListAccountTokens(.light).scrimDialog; RestorePurgeDialog(appearance: .light) }
}

#Preview("Jetzt endgültig löschen – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ZStack { Color.hex("#071012"); ListAccountTokens(.dark).scrimDialog; RestorePurgeDialog(appearance: .dark) }
}
