/*
 MemberDeletedToast.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hinweis für den Listenbesitzer: „Sofie hat das Konto gelöscht“ – nicht mehr Mitglied, kommt beim
   Wiederherstellen automatisch zurück.

 🔰 Notes for Beginners:
 - Vorlage: MemberDeletedToast.dc.html – links/rechts 20, unten 114, padding 12 16, Radius 20, gap 12,
   Kreis 36 mit Icon 19, Restzeit-Balken unten (wie UndoToast).
 - Wortlaut ohne „ihr/sein“: Die App kennt das Geschlecht der Person nicht.
 - ShoppingListView zeigt den Hinweis in der betroffenen Liste und markiert ihn danach als gesehen.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 4).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct MemberDeletedToast: View {
    let k: OverlayTheme
    let name: String
    /// Restzeit-Balken, Anteil der Padding-Box (0…1).
    var remaining: CGFloat = 0.62

    var body: some View {
        GlassToast(k: k, height: 0, radius: 20, leading: 16, trailing: 16, vertical: 13) {   // 12 + 1 Rahmen
            SVGIcon(RestoreAccountIcon.memberLeft, size: 19, color: k.toastAccent, lineWidth: 1.9)
                .frame(width: 36, height: 36)
                .background(Circle().fill(k.undoBg))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name) hat das Konto gelöscht")
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(k.toastText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(name) ist nicht mehr Mitglied dieser Liste. Wird das Konto wiederhergestellt, ist \(name) automatisch wieder dabei.")
                    .font(AppFont.dm(13, 400))
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.72))
                    .cssLineHeight(17.55, font: AppFont.ui(.dmSans, 13, 400))  // line-height 1.35
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay {
            // Restzeit: links 0 / unten 0 der Padding-Box, Höhe 3, an der inneren Rundung (20 − 1) abgeschnitten.
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
        .accessibilityElement(children: .combine)
    }
}

#Preview("Mitglied hat Konto gelöscht", traits: .fixedLayout(width: 390, height: 844)) {
    OverlayStage(appearance: .light, accentHex: nil, listState: .empty, showsScrim: false) {
        MemberDeletedToast(k: OverlayTheme(.light, accentHex: nil), name: "Sofie")
            .overlayToastPosition(bottom: 114)
    }
}

#Preview("Mitglied hat Konto gelöscht – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    OverlayStage(appearance: .dark, accentHex: nil, listState: .empty, showsScrim: false) {
        MemberDeletedToast(k: OverlayTheme(.dark, accentHex: nil), name: "Sofie")
            .overlayToastPosition(bottom: 114)
    }
}
