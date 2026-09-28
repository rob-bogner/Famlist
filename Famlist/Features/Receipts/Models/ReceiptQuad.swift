/*
 ReceiptQuad.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Die vier Ecken eines Kassenzettels in einem Foto. Aus ihnen entsteht der gerade gezogene Zuschnitt.

 🔰 Notes for Beginners:
 - Die Ecken sind relativ zum Bild angegeben: 0…1, Ursprung oben links (wie in UIKit).
   (0, 0) ist die linke obere Bildecke, (1, 1) die rechte untere – egal, wie groß das Foto ist.
 - `isPlausible` sortiert Fehltreffer aus: zu kleine Flächen (z. B. nur ein Preisschild im Bild)
   und verdrehte Vierecke, deren Ecken sich überkreuzen.

 📝 Last Change:
 - Initial creation (automatischer Bon-Zuschnitt).
 ------------------------------------------------------------------------
 */

import CoreGraphics

struct ReceiptQuad: Equatable, Sendable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    /// Kleinster Anteil am Bild, ab dem ein Treffer als Bon zählt (8 %).
    /// Ein Bon, der so klein im Bild liegt, wäre ohnehin kaum lesbar.
    static let minimumArea: CGFloat = 0.08

    /// Ecken im Uhrzeigersinn, beginnend oben links.
    var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    /// Ecke per Index (0 oben links … 3 unten links, im Uhrzeigersinn) – für die Griffe in „Ecken anpassen“.
    subscript(corner index: Int) -> CGPoint {
        get { corners[index] }
        set {
            switch index {
            case 0: topLeft = newValue
            case 1: topRight = newValue
            case 2: bottomRight = newValue
            default: bottomLeft = newValue
            }
        }
    }

    /// Rechteck mit Abstand `margin` zum Bildrand – Startwert, wenn kein Bon erkannt wurde.
    static func inset(by margin: CGFloat) -> ReceiptQuad {
        ReceiptQuad(topLeft: CGPoint(x: margin, y: margin), topRight: CGPoint(x: 1 - margin, y: margin),
                    bottomRight: CGPoint(x: 1 - margin, y: 1 - margin), bottomLeft: CGPoint(x: margin, y: 1 - margin))
    }

    /// Fläche relativ zum Bild (0…1), Gaußsche Trapezformel.
    var area: CGFloat {
        let c = corners
        var sum: CGFloat = 0
        for i in c.indices {
            let a = c[i], b = c[(i + 1) % c.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    /// Groß genug, konvex und nicht überkreuzt.
    var isPlausible: Bool { area >= Self.minimumArea && isConvex }

    /// Alle Kreuzprodukte aufeinanderfolgender Kanten haben dasselbe Vorzeichen.
    private var isConvex: Bool {
        let c = corners
        let signs = c.indices.map { i -> CGFloat in
            let a = c[i], b = c[(i + 1) % 4], d = c[(i + 2) % 4]
            return (b.x - a.x) * (d.y - b.y) - (b.y - a.y) * (d.x - b.x)
        }
        return signs.allSatisfy { $0 > 0 } || signs.allSatisfy { $0 < 0 }
    }

    /// Größte Verschiebung einer Ecke gegenüber `other` (relativ zum Bild). Maß für „Bon bewegt sich“.
    func maxCornerDistance(to other: ReceiptQuad) -> CGFloat {
        zip(corners, other.corners).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 0
    }

    /// Ecken in Pixeln eines Bildes mit Ursprung unten links (Core-Image-Koordinaten).
    func pixelCorners(in size: CGSize) -> (topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        func map(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height) }
        return (map(topLeft), map(topRight), map(bottomRight), map(bottomLeft))
    }
}
