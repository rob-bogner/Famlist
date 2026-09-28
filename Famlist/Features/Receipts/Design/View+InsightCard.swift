/*
 View+InsightCard.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Karten-Hintergrund der Auswertung und des Bon-Details: Radius 20, card, 1 pt cardBorder, cardShadow.

 🔰 Notes for Beginners:
 - Der Rahmen liegt im Board außen (CSS content-box); deshalb 1 pt Innenabstand zusätzlich.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

extension View {
    /// Innenabstand laut Board + 1 pt Rahmen, dann der Kartenhintergrund.
    func insightCard(_ t: ListAccountTokens, top: CGFloat, horizontal: CGFloat, bottom: CGFloat) -> some View {
        padding(.top, top + 1)
            .padding(.horizontal, horizontal + 1)
            .padding(.bottom, bottom + 1)
            .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
    }
}
