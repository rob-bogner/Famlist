/*
 SVGPathParser.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - SVG-Pfadparser (M L H V C S Q T A Z, absolut + relativ) → SwiftUI Path.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

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
