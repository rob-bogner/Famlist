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

/// Sucher-Ecke oben links: Standard 34 × 34, Rahmen 4 oben + links, äußerer Radius 18.
/// Kassenzettel (ReceiptCapture.dc.html): 36 × 36, Radius 20.
/// Umsetzung: Rahmen einer um 4 größeren Box (rechte/untere Kante liegen außerhalb) auf size × size beschnitten.
struct ViewfinderCorner: View {
    var size: CGFloat = 34
    var radius: CGFloat = 18

    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: radius, style: .circular)
            .strokeBorder(Color.white, lineWidth: 4)
            .frame(width: size + 4, height: size + 4)
            .frame(width: size, height: size, alignment: .topLeading)
            .clipped()
    }
}

#Preview("ViewfinderCorner") {
    ViewfinderCorner()
        .padding(20)
        .background(Color.hex("#5A6B6E"))
}

#Preview("ViewfinderCorner – Dark") {
    ViewfinderCorner()
        .padding(20)
        .background(Color.hex("#0A1416"))
}
