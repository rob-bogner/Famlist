/*
 ReceiptCropLoupe.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lupe in „Ecken anpassen“: zeigt beim Ziehen eines Griffs die Umgebung der Ecke 2,5-fach vergrößert.

 🔰 Notes for Beginners:
 - Vorlage: ReceiptCropEdit.dc.html, Zustand „dragging“. Kreis 104, Rand Weiß 3, Schatten 0/8/16 Schwarz 60 %,
   Fadenkreuz Akzent hell 1,5, Kante des Vierecks 1 × 2,5.
 - Die Mitte der Lupe (52 | 52) zeigt genau den Punkt unter dem Finger. Ein Punkt r der Fotofläche liegt in der
   Lupe bei 52 + (r − Mitte) · 2,5.

 📝 Last Change:
 - Initial creation (Kassenzettel wie ein Dokumentenscanner).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptCropLoupe: View {
    let image: UIImage
    /// Wo das Foto in der Fotofläche liegt (Punkte).
    let imageRect: CGRect
    /// Ecken in Punkten der Fotofläche.
    let corners: [CGPoint]
    /// Mitte der Lupe: der gezogene Punkt.
    let focus: CGPoint
    let accent: Color

    static let size: CGFloat = 104
    static let zoom: CGFloat = 2.5

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.hex("#0A0F10")
            Image(uiImage: image)
                .resizable()
                .frame(width: imageRect.width * Self.zoom, height: imageRect.height * Self.zoom)
                .offset(x: local(imageRect.origin).x, y: local(imageRect.origin).y)
            Path { path in
                path.addLines(corners.map(local))
                path.closeSubpath()
            }
            .stroke(accent, lineWidth: Self.zoom)
            crosshair
        }
        .frame(width: Self.size, height: Self.size)
        .clipShape(Circle())
        .overlay(Circle().inset(by: 1.5).stroke(Color.white, lineWidth: 3))
        .background(Circle().fill(Color.hex("#0A0F10")).shadow(color: .rgba(0, 0, 0, 0.6), radius: 8, y: 8))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Punkt der Fotofläche → Punkt in der Lupe.
    private func local(_ point: CGPoint) -> CGPoint {
        CGPoint(x: Self.size / 2 + (point.x - focus.x) * Self.zoom,
                y: Self.size / 2 + (point.y - focus.y) * Self.zoom)
    }

    /// Fadenkreuz mit Lücke in der Mitte: M52 36V46 M52 58V68 M36 52H46 M58 52H68.
    private var crosshair: some View {
        Path { path in
            path.move(to: CGPoint(x: 52, y: 36)); path.addLine(to: CGPoint(x: 52, y: 46))
            path.move(to: CGPoint(x: 52, y: 58)); path.addLine(to: CGPoint(x: 52, y: 68))
            path.move(to: CGPoint(x: 36, y: 52)); path.addLine(to: CGPoint(x: 46, y: 52))
            path.move(to: CGPoint(x: 58, y: 52)); path.addLine(to: CGPoint(x: 68, y: 52))
        }
        .stroke(accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }
}

#Preview("Lupe", traits: .fixedLayout(width: 200, height: 200)) {
    ReceiptCropLoupe(image: ReceiptSampleBon.image(), imageRect: CGRect(x: 0, y: 0, width: 300, height: 400),
                     corners: [CGPoint(x: 40, y: 40), CGPoint(x: 260, y: 40), CGPoint(x: 260, y: 360), CGPoint(x: 40, y: 360)],
                     focus: CGPoint(x: 40, y: 40), accent: AccentScale(Appearance.light.defaultAccent, .light).light.color())
        .padding(48)
}

#Preview("Lupe – Dark", traits: .fixedLayout(width: 200, height: 200)) {
    ReceiptCropLoupe(image: ReceiptSampleBon.image(), imageRect: CGRect(x: 0, y: 0, width: 300, height: 400),
                     corners: [CGPoint(x: 40, y: 40), CGPoint(x: 260, y: 40), CGPoint(x: 260, y: 360), CGPoint(x: 40, y: 360)],
                     focus: CGPoint(x: 260, y: 360), accent: AccentScale(Appearance.dark.defaultAccent, .dark).light.color())
        .padding(48)
        .preferredColorScheme(.dark)
}
