//  CSSRendering.swift
//  MyListUI
//
//  Bildet die CSS-Primitive aus dem Canvas-Design 1:1 in SwiftUI nach:
//  Farben/Farbmathematik, linear-/radial-gradient, box-shadow (inkl. spread,
//  inset, Mehrfach-Schatten), border (border-box) und line-height.
//
//  Umrechnungsregeln (gelten für ALLE Screens):
//  • 1 CSS-px  = 1 pt.
//  • box-shadow blur B  → Gauß-Radius B/2   (CSS: σ = B/2)
//  • filter: blur(X)    → .blur(radius: X)  (CSS: σ = X)
//  • text-shadow / drop-shadow blur B → .shadow(radius: B/2)
//  • border-radius ist kreisförmig → immer `style: .circular` (nie .continuous)
//  • Transparente Verlaufs-Stopps nutzen die RGB-Werte des Nachbarstopps mit α = 0
//    (entspricht der vormultiplizierten Interpolation von CSS).

import SwiftUI
import UIKit

// MARK: - Farbe

/// sRGB-Wert mit Kanälen 0…255 – identische Mathematik wie im Design (JS `Math.round`).
struct RGB: Hashable {
    let r: Double
    let g: Double
    let b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        let v = UInt32(s, radix: 16) ?? 0
        self.init(Double((v >> 16) & 0xFF), Double((v >> 8) & 0xFF), Double(v & 0xFF))
    }

    /// JS: `Math.round(v + (target - v) * amount)` pro Kanal.
    func mix(toward target: Double, _ amount: Double) -> RGB {
        func m(_ v: Double) -> Double { (v + (target - v) * amount).rounded(.toNearestOrAwayFromZero) }
        return RGB(m(r), m(g), m(b))
    }

    func color(_ alpha: Double = 1) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: alpha)
    }
}

extension Color {
    /// `#RRGGBB` mit optionalem Alpha.
    static func hex(_ hex: String, _ alpha: Double = 1) -> Color { RGB(hex: hex).color(alpha) }

    /// CSS `rgba(r, g, b, a)`.
    static func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }
}

/// Kurzform für einen Verlaufs-Stopp.
func stop(_ color: Color, _ location: CGFloat) -> Gradient.Stop {
    Gradient.Stop(color: color, location: location)
}

// MARK: - Formen

/// CSS `border-radius: r` (kreisförmige Ecken).
func RR(_ radius: CGFloat) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: radius, style: .circular)
}

/// CSS `border-radius: 999px` bzw. 50 % auf Pillen.
var Pill: Capsule { Capsule(style: .circular) }

// MARK: - Füllungen

/// Hintergrund einer CSS-Box.
enum Paint {
    case color(Color)
    /// `linear-gradient(<angle>deg, …)`
    case linear(Double, [Gradient.Stop])
    /// `radial-gradient(circle at x% y%, …)` – Größe `farthest-corner`
    case radialCircle(UnitPoint, [Gradient.Stop])

    @ViewBuilder var view: some View {
        switch self {
        case .color(let c):
            Rectangle().fill(c)
        case .linear(let angle, let stops):
            CSSLinearGradient(angle: angle, stops: stops)
        case .radialCircle(let center, let stops):
            CSSRadialGradient(center: center, extent: .circleFarthestCorner, stops: stops)
        }
    }
}

/// Exakte CSS-`linear-gradient`-Geometrie für beliebige Winkel und Seitenverhältnisse.
/// CSS: 0deg = nach oben, im Uhrzeigersinn; Länge der Verlaufslinie = |w·sinθ| + |h·cosθ|.
struct CSSLinearGradient: View {
    let angle: Double
    let stops: [Gradient.Stop]

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 0.0001)
            let h = max(geo.size.height, 0.0001)
            let rad = angle * .pi / 180
            let dx = CGFloat(sin(rad))
            let dy = CGFloat(-cos(rad))
            let len = abs(w * CGFloat(sin(rad))) + abs(h * CGFloat(cos(rad)))
            let cx = w / 2
            let cy = h / 2
            LinearGradient(
                stops: stops,
                startPoint: UnitPoint(x: (cx - dx * len / 2) / w, y: (cy - dy * len / 2) / h),
                endPoint: UnitPoint(x: (cx + dx * len / 2) / w, y: (cy + dy * len / 2) / h)
            )
        }
    }
}

/// Exakte CSS-`radial-gradient`-Geometrie.
struct CSSRadialGradient: View {
    enum Extent {
        /// `circle at …` (Standardgröße farthest-corner)
        case circleFarthestCorner
        /// `radial-gradient(closest-side, …)` – Ellipse bis zur nächsten Kante
        case ellipseClosestSide
        /// `radial-gradient(<rx%> <ry%> at …)` – Radien als Anteil von Breite/Höhe
        case ellipse(rx: CGFloat, ry: CGFloat)
    }

    let center: UnitPoint
    let extent: Extent
    let stops: [Gradient.Stop]

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width * center.x, y: size.height * center.y)
            var rx: CGFloat = 0
            var ry: CGFloat = 0
            switch extent {
            case .circleFarthestCorner:
                let corners = [CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0),
                               CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
                let r = corners.map { hypot($0.x - c.x, $0.y - c.y) }.max() ?? 0
                rx = r
                ry = r
            case .ellipseClosestSide:
                rx = min(c.x, size.width - c.x)
                ry = min(c.y, size.height - c.y)
            case .ellipse(let fx, let fy):
                rx = fx * size.width
                ry = fy * size.height
            }
            guard rx > 0, ry > 0 else { return }
            ctx.translateBy(x: c.x, y: c.y)
            ctx.scaleBy(x: rx, y: ry)
            let rect = CGRect(x: -c.x / rx, y: -c.y / ry, width: size.width / rx, height: size.height / ry)
            ctx.fill(Path(rect), with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: 1))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - box-shadow

/// Ein Eintrag einer CSS-`box-shadow`-Liste.
struct BoxShadow {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var blur: CGFloat = 0
    var spread: CGFloat = 0
    var color: Color
    var isInset = false

    /// `x y blur spread color`
    static func drop(_ x: CGFloat, _ y: CGFloat, _ blur: CGFloat, _ spread: CGFloat, _ color: Color) -> BoxShadow {
        BoxShadow(x: x, y: y, blur: blur, spread: spread, color: color, isInset: false)
    }

    /// `inset x y blur spread color`
    static func inner(_ x: CGFloat, _ y: CGFloat, _ blur: CGFloat, _ spread: CGFloat, _ color: Color) -> BoxShadow {
        BoxShadow(x: x, y: y, blur: blur, spread: spread, color: color, isInset: true)
    }
}

/// Eine vollständige CSS-Box (border-box) mit der CSS-Malreihenfolge:
/// äußere Schatten → Hintergrund → innere Schatten → Rahmen.
/// Der Inhalt liegt immer darüber (per `.background(CSSBox(...))` anhängen).
///
/// • Äußere Schatten werden – wie in CSS – unter der Box selbst ausgestanzt,
///   damit sie durch halbtransparente Flächen nicht durchscheinen.
/// • Innere Schatten werden auf die Padding-Box (innerhalb des Rahmens) begrenzt.
/// • Der Rahmen liegt innerhalb des Frames (box-sizing: border-box).
struct CSSBox<S: InsettableShape>: View {
    let shape: S
    var paint: Paint = .color(.clear)
    var border: CGFloat = 0
    var borderColor: Color = .clear
    var dash: [CGFloat] = []
    var shadows: [BoxShadow] = []

    var body: some View {
        let outer = shadows.filter { !$0.isInset }
        let inner = shadows.filter { $0.isInset }
        ZStack {
            // In CSS liegt der zuerst genannte Schatten oben → rückwärts zeichnen.
            ForEach(Array(outer.indices.reversed()), id: \.self) { i in
                DropShadowLayer(shape: shape, s: outer[i])
            }
            paint.view.clipShape(shape)
            ForEach(Array(inner.indices.reversed()), id: \.self) { i in
                InnerShadowLayer(shape: shape.inset(by: border), s: inner[i])
            }
            if border > 0 {
                shape.strokeBorder(borderColor, style: StrokeStyle(lineWidth: border, dash: dash))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct DropShadowLayer<S: InsettableShape>: View {
    let shape: S
    let s: BoxShadow

    var body: some View {
        ZStack {
            shape.inset(by: -s.spread)
                .fill(s.color)
                .offset(x: s.x, y: s.y)
                .blur(radius: s.blur / 2)
            shape.fill(Color.black).blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

private struct InnerShadowLayer<S: InsettableShape>: View {
    let shape: S
    let s: BoxShadow

    var body: some View {
        let pad = s.blur + abs(s.x) + abs(s.y) + abs(s.spread) + 2
        ZStack {
            Rectangle().fill(s.color).padding(-pad)
            shape.inset(by: s.spread)
                .fill(Color.black)
                .offset(x: s.x, y: s.y)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .blur(radius: s.blur / 2)
        .clipShape(shape)
    }
}

// MARK: - Hilfsflächen

/// Glanz-Ellipse: `border-radius: 50%; background: linear-gradient(180deg, rgba(255,255,255,a), rgba(255,255,255,0))`.
struct GlossEllipse: View {
    let opacity: Double

    var body: some View {
        Ellipse()
            .fill(LinearGradient(stops: [stop(.rgba(255, 255, 255, opacity), 0), stop(.rgba(255, 255, 255, 0), 1)],
                                 startPoint: .top, endPoint: .bottom))
            .allowsHitTesting(false)
    }
}

/// CSS `border-top: 1px solid c` auf einer Fläche mit oberen Radien:
/// die Linie läuft oben voll und verjüngt sich in den Ecken bis zur Höhe des Radius auf 0.
struct TopBorderHairline: View {
    let radius: CGFloat
    let color: Color

    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius, style: .circular)
            .strokeBorder(color, lineWidth: 1)
            .mask(alignment: .top) {
                LinearGradient(stops: [stop(.black, 0), stop(.black.opacity(0), 1)], startPoint: .top, endPoint: .bottom)
                    .frame(height: radius)
            }
            .allowsHitTesting(false)
    }
}

// MARK: - line-height

extension View {
    /// CSS `line-height: <lineHeight>px` – Zeilenabstand + halbes Leading oben/unten.
    func cssLineHeight(_ lineHeight: CGFloat, font: UIFont) -> some View {
        let extra = max(0, lineHeight - font.lineHeight)
        return self.lineSpacing(extra).padding(.vertical, extra / 2)
    }
}
