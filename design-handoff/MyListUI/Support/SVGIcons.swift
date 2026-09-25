//  SVGIcons.swift
//  MyListUI
//
//  Alle Icons des Designs als exakte Vektorpfade (24×24-viewBox, Kontur, keine Füllung).
//  Die Pfaddaten sind 1:1 aus dem Design übernommen und werden von einem
//  SVG-Pfadparser (M L H V C S Q T A Z, absolut + relativ) in SwiftUI-Pfade übersetzt.
//  Kein SF Symbol ersetzt ein Icon.
//
//  Strichstärke: angegeben in viewBox-Einheiten und – wie im Browser –
//  proportional zur Icon-Größe skaliert (lineWidth · size / 24).
//  stroke-linecap: round, stroke-linejoin: round.

import SwiftUI

enum SVGElement {
    case path(String)
    /// `<circle cx cy r>`
    case circle(CGFloat, CGFloat, CGFloat)
    /// `<rect x y width height rx>`
    case rect(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
}

struct SVGIconShape: Shape {
    let elements: [SVGElement]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        for e in elements {
            switch e {
            case .path(let d):
                p.addPath(SVGPathParser.parse(d))
            case .circle(let cx, let cy, let r):
                p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            case .rect(let x, let y, let w, let h, let rx):
                p.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h),
                                 cornerSize: CGSize(width: rx, height: rx), style: .circular)
            }
        }
        let s = min(rect.width, rect.height) / 24
        return p.applying(CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: rect.minX, ty: rect.minY))
    }
}

/// Ein Kontur-Icon wie `<svg width=size height=size viewBox="0 0 24 24" stroke=color stroke-width=lineWidth>`.
struct SVGIcon: View {
    let elements: [SVGElement]
    let size: CGFloat
    let color: Color
    let lineWidth: CGFloat

    init(_ elements: [SVGElement], size: CGFloat, color: Color, lineWidth: CGFloat) {
        self.elements = elements
        self.size = size
        self.color = color
        self.lineWidth = lineWidth
    }

    var body: some View {
        SVGIconShape(elements: elements)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

/// Gefülltes Icon mit gleichfarbiger Kontur (`fill=c stroke=c stroke-linejoin=round`), z. B. Favoriten-Stern.
struct SVGFilledIcon: View {
    let elements: [SVGElement]
    let size: CGFloat
    let color: Color
    let lineWidth: CGFloat

    init(_ elements: [SVGElement], size: CGFloat, color: Color, lineWidth: CGFloat) {
        self.elements = elements
        self.size = size
        self.color = color
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            SVGIconShape(elements: elements).fill(color)
            SVGIconShape(elements: elements)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth * size / 24, lineCap: .butt, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Icon-Katalog (Pfade exakt aus dem Design)

enum Icon {
    static let chevronDown: [SVGElement] = [.path("M6 9l6 6 6-6")]
    static let chevronRight: [SVGElement] = [.path("M9 6l6 6-6 6")]
    static let chevronsUpDown: [SVGElement] = [.path("M8 9l4-4 4 4M8 15l4 4 4-4")]
    static let viewToggle: [SVGElement] = [.rect(3.5, 4, 17, 7, 2), .path("M4 15.5h16M4 19.5h16")]
    static let menu: [SVGElement] = [.path("M5 8h14M5 12h14M5 16h14")]
    static let search: [SVGElement] = [.circle(11, 11, 6.5), .path("M16 16l4 4")]
    static let scan: [SVGElement] = [.path("M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M8 9v6M11 9v6M14 9v6M17 9v6")]
    static let basket: [SVGElement] = [.path("M3 10h18l-1.6 8.2a2 2 0 0 1-2 1.8H6.6a2 2 0 0 1-2-1.8L3 10z"),
                                       .path("M8 10l3-6M16 10l-3-6M9 14v3M12 14v3M15 14v3")]
    static let check: [SVGElement] = [.path("M5 12.5l4.5 4.5L19 7.5")]
    static let tag: [SVGElement] = [.path("M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8z"),
                                    .circle(8, 8, 1.4)]
    static let cameraOff: [SVGElement] = [.path("M3 3l18 18"),
                                          .path("M9.5 5h5l1.5 2H19a2 2 0 0 1 2 2v8.5M17 19H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h2"),
                                          .path("M9.9 10.2a3 3 0 0 0 4 4")]
    static let camera: [SVGElement] = [.path("M4 8a2 2 0 0 1 2-2h2l1.5-2h5L16 6h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8z"),
                                       .circle(12, 12.5, 3.5)]
    static let undo: [SVGElement] = [.path("M9 14L4 9l5-5"), .path("M4 9h10.5a5.5 5.5 0 0 1 0 11H11")]
    static let trashAction: [SVGElement] = [.path("M4 7h16M9.5 7V4.8h5V7M6.5 7l.9 11.2a2 2 0 0 0 2 1.8h5.2a2 2 0 0 0 2-1.8L17.5 7")]
    static let pencil: [SVGElement] = [.path("M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16v4zM13.5 6.5l4 4")]
    static let unavailable: [SVGElement] = [.path("M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8 12h8")]
    static let listCheck: [SVGElement] = [.path("M9 6h11M9 12h11M9 18h11"), .path("M4 6l1 1 1.8-2M4 12l1 1 1.8-2"),
                                          .circle(5, 18, 1)]
    static let sort: [SVGElement] = [.path("M8 19V5M4.5 8.5 8 5l3.5 3.5M16 5v14M12.5 15.5 16 19l3.5-3.5")]
    static let duplicate: [SVGElement] = [.rect(8, 8, 12, 12, 3),
                                          .path("M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2")]
    static let trash: [SVGElement] = [.path("M4 7h16M9.5 7V4.8h5V7M6.5 7l.9 11.2a2 2 0 0 0 2 1.8h5.2a2 2 0 0 0 2-1.8L17.5 7M10 11v5M14 11v5")]
    static let plus: [SVGElement] = [.path("M12 5v14M5 12h14")]
    static let minus: [SVGElement] = [.path("M5 12h14")]
    static let close: [SVGElement] = [.path("M6 6l12 12M18 6L6 18")]
    static let cart: [SVGElement] = [.path("M3 4h2.5l2 11h10.5l2-8H7"), .circle(9.5, 19, 1.2), .circle(16.5, 19, 1.2)]
    static let leaf: [SVGElement] = [.path("M5 19c0-8 5-14 14-14 0 9-6 14-14 14zM5 19l8-8")]
    static let drop: [SVGElement] = [.path("M12 3.5s-6 6.6-6 10.5a6 6 0 0 0 12 0c0-3.9-6-10.5-6-10.5z")]
    static let listBullets: [SVGElement] = [.path("M9 7h11M9 12h11M9 17h11"),
                                            .circle(5, 7, 1), .circle(5, 12, 1), .circle(5, 17, 1)]
    static let star: [SVGElement] = [.path("M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9L12 3.5z")]
    static let cutlery: [SVGElement] = [.path("M7 3v8M5 3v5a2 2 0 0 0 4 0V3M7 11v10M16 21V3c-2 1.5-3 4-3 7h3")]
}

// MARK: - SVG-Pfadparser

enum SVGPathParser {
    private enum Token {
        case command(Character)
        case number(CGFloat)
    }

    static func parse(_ d: String) -> Path {
        let tokens = tokenize(d)
        var path = Path()
        var i = 0
        var command: Character = "M"
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCubicControl: CGPoint?
        var lastQuadControl: CGPoint?

        func isNumber(_ index: Int) -> Bool {
            guard index < tokens.count else { return false }
            if case .number = tokens[index] { return true }
            return false
        }
        func num() -> CGFloat {
            guard i < tokens.count, case .number(let v) = tokens[i] else { i += 1; return 0 }
            i += 1
            return v
        }
        func point(_ relative: Bool) -> CGPoint {
            let x = num()
            let y = num()
            return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }

        while i < tokens.count {
            if case .command(let c) = tokens[i] {
                command = c
                i += 1
            } else if !isNumber(i) {
                i += 1
                continue
            }
            let relative = command.isLowercase
            switch Character(command.uppercased()) {
            case "M":
                let p = point(relative)
                path.move(to: p)
                current = p
                subpathStart = p
                command = relative ? "l" : "L" // weitere Koordinatenpaare = lineto
                lastCubicControl = nil
                lastQuadControl = nil
            case "L":
                let p = point(relative)
                path.addLine(to: p)
                current = p
                lastCubicControl = nil
                lastQuadControl = nil
            case "H":
                let x = num()
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil
            case "V":
                let y = num()
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                path.addLine(to: current)
                lastCubicControl = nil
                lastQuadControl = nil
            case "C":
                let c1 = point(relative)
                let c2 = point(relative)
                let p = point(relative)
                path.addCurve(to: p, control1: c1, control2: c2)
                lastCubicControl = c2
                lastQuadControl = nil
                current = p
            case "S":
                let c2 = point(relative)
                let p = point(relative)
                let c1 = lastCubicControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                path.addCurve(to: p, control1: c1, control2: c2)
                lastCubicControl = c2
                lastQuadControl = nil
                current = p
            case "Q":
                let c = point(relative)
                let p = point(relative)
                path.addQuadCurve(to: p, control: c)
                lastQuadControl = c
                lastCubicControl = nil
                current = p
            case "T":
                let p = point(relative)
                let c = lastQuadControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                path.addQuadCurve(to: p, control: c)
                lastQuadControl = c
                lastCubicControl = nil
                current = p
            case "A":
                let rx = num()
                let ry = num()
                let rotation = num()
                let largeArc = num() != 0
                let sweep = num() != 0
                let p = point(relative)
                addArc(&path, from: current, rx: rx, ry: ry, rotationDegrees: rotation,
                       largeArc: largeArc, sweep: sweep, to: p)
                current = p
                lastCubicControl = nil
                lastQuadControl = nil
            case "Z":
                path.closeSubpath()
                current = subpathStart
                lastCubicControl = nil
                lastQuadControl = nil
                if isNumber(i) { i += 1 } // Z hat keine Argumente
            default:
                i += 1
            }
        }
        return path
    }

    private static func tokenize(_ d: String) -> [Token] {
        var out: [Token] = []
        let chars = Array(d)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isLetter && c != "e" && c != "E" {
                out.append(.command(c))
                i += 1
                continue
            }
            if c == "-" || c == "+" || c == "." || c.isNumber {
                var s = ""
                var j = i
                if chars[j] == "-" || chars[j] == "+" {
                    s.append(chars[j])
                    j += 1
                }
                var seenDot = false
                var seenExp = false
                while j < chars.count {
                    let ch = chars[j]
                    if ch.isNumber {
                        s.append(ch)
                        j += 1
                    } else if ch == "." && !seenDot && !seenExp {
                        seenDot = true
                        s.append(ch)
                        j += 1
                    } else if (ch == "e" || ch == "E") && !seenExp {
                        seenExp = true
                        s.append(ch)
                        j += 1
                        if j < chars.count, chars[j] == "-" || chars[j] == "+" {
                            s.append(chars[j])
                            j += 1
                        }
                    } else {
                        break
                    }
                }
                out.append(.number(CGFloat(Double(s) ?? 0)))
                i = j
                continue
            }
            i += 1 // Leerzeichen / Komma
        }
        return out
    }

    /// SVG-Elliptischer Bogen (Endpunkt-Parametrisierung, SVG 1.1 F.6.5) → kubische Béziers.
    private static func addArc(_ path: inout Path, from p0: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat,
                               rotationDegrees: CGFloat, largeArc: Bool, sweep: Bool, to p: CGPoint) {
        if p0 == p { return }
        var rx = abs(rxIn)
        var ry = abs(ryIn)
        if rx == 0 || ry == 0 {
            path.addLine(to: p)
            return
        }
        let phi = rotationDegrees * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let dx2 = (p0.x - p.x) / 2
        let dy2 = (p0.y - p.y) / 2
        let x1p = cosPhi * dx2 + sinPhi * dy2
        let y1p = -sinPhi * dx2 + cosPhi * dy2

        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            rx *= sqrt(lambda)
            ry *= sqrt(lambda)
        }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        let coef = (largeArc != sweep ? 1 : -1) * sqrt(max(0, num / den))
        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * (-ry * x1p / rx)
        let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let ux = (x1p - cxp) / rx
        let uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx
        let vy = (-y1p - cyp) / ry
        let theta1 = angle(1, 0, ux, uy)
        var delta = angle(ux, uy, vx, vy)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let step = delta / CGFloat(segments)
        let t = 4 / 3 * tan(step / 4)

        func map(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cosPhi * u - ry * sinPhi * v,
                    y: cy + rx * sinPhi * u + ry * cosPhi * v)
        }
        for k in 0..<segments {
            let a1 = theta1 + CGFloat(k) * step
            let a2 = a1 + step
            let c1 = map(cos(a1) - t * sin(a1), sin(a1) + t * cos(a1))
            let c2 = map(cos(a2) + t * sin(a2), sin(a2) - t * cos(a2))
            path.addCurve(to: map(cos(a2), sin(a2)), control1: c1, control2: c2)
        }
    }
}
