/*
 ViewfinderCorner.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sucher-Ecke der Bon-Kamera (34 × 34, Rahmen 4 oben + links, Radius 18).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ReceiptScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Sucher-Ecke oben links: 34 × 34, Rahmen 4 oben + links, äußerer Radius 18 (innen 14).
/// Umsetzung: Rahmen einer 38 × 38-Box (rechte/untere Kante liegen außerhalb) auf 34 × 34 beschnitten.
struct ViewfinderCorner: View {
    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: 18, style: .circular)
            .strokeBorder(Color.white, lineWidth: 4)
            .frame(width: 38, height: 38)
            .frame(width: 34, height: 34, alignment: .topLeading)
            .clipped()
    }
}
