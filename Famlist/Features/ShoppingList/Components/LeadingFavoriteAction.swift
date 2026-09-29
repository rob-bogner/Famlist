/*
 LeadingFavoriteAction.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Gelber Glas-Kreis „Favorit“ links hinter einer Listenkarte (Meine Listen, nach rechts wischen).
   Design: MyListsSwipeRight.

 🔰 Notes for Beginners:
 - Kreis 48 (Verlauf #FFE38A → #F5B521 → #C98A06), Stern weiß, Beschriftung 11/600 sub, Spalte 76.
 - Ist die Liste schon Favorit, heißt die Aktion „Kein Favorit“.
 - Wie LeadingCheckAction: wächst beim Wischen mit, ab der Durchwisch-Schwelle etwas größer (armed).

 📝 Last Change:
 - Initial creation (Wisch-Aktionen „Meine Listen“).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Yellow favourite action revealed by swiping a list card to the right.
struct LeadingFavoriteAction: View {
    let labelColor: Color
    let isFavorite: Bool
    let progress: CGFloat
    let isArmed: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            Button(action: action) {
                SVGIcon(Icon.star, size: 20, color: .white, lineWidth: 2.1)
                    .frame(width: 48, height: 48)
                    .background(alignment: .top) {
                        GlossEllipse(opacity: 0.65)
                            .frame(height: 17)
                            .padding(.horizontal, 8)
                            .padding(.top, 3)
                    }
                    .clipShape(Circle())
                    .background(CSSBox(
                        shape: Circle(),
                        paint: .radialCircle(UnitPoint(x: 0.32, y: 0.22),
                                             [stop(.hex("#FFE38A"), 0), stop(.hex("#F5B521"), 0.55), stop(.hex("#C98A06"), 1)]),
                        shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.5)),
                                  .inner(0, -3, 8, 0, .rgba(0, 0, 0, 0.18)),
                                  .drop(0, 10, 20, -8, .rgba(201, 138, 6, 0.7))]))
                    .scaleEffect(isArmed ? 1.12 : 0.7 + 0.3 * progress)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
            Text(isFavorite ? "Kein Favorit" : "Favorit")
                .font(AppFont.dm(11, 600))
                .foregroundStyle(labelColor)
                .fixedSize()
        }
        .frame(width: 76)
        .accessibilityHidden(true)
    }
}

#Preview {
    LeadingFavoriteAction(labelColor: SheetTheme(.light).sub, isFavorite: false, progress: 1, isArmed: false, action: {})
        .padding(20)
}

#Preview("Dark") {
    LeadingFavoriteAction(labelColor: SheetTheme(.dark).sub, isFavorite: true, progress: 1, isArmed: true, action: {})
        .padding(20)
        .background(Color.hex("#0A1416"))
}
