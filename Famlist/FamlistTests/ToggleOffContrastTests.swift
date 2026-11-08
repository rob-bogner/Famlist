/*
 ToggleOffContrastTests.swift
 FamlistTests
 Created on: 08.11.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - T-010: Die Spur eines ausgeschalteten Schalters hebt sich mit mindestens 3:1 vom Grund ab (WCAG 1.4.11),
   in hell und dunkel, gegen jeden Grund, auf dem ein Schalter in der App liegt.

 🔰 Notes for Beginners:
 - Spurfarbe aus der App: `ListAccountTokens.toggleOff` (dieselbe Quelle nutzen OverlaySwitch und PopoverMenuRow).
 - Gründe: Karte (Einstellungen), Feld (Neue Liste → „Als Favorit“), Menü (☰ „Artikelbilder“ = .listMenu,
   Sortieren „Erledigte unten“ = .dockMenu). Halbtransparente Farben werden über den ungünstigsten Untergrund
   gemischt (Menü über Schwarz/Weiß, Karte/Feld über beide Enden des Sheet-Verlaufs).
 - Kartenverläufe sind `Paint` und nicht auslesbar; ihre Stopps w(0,07)/w(0,03) stehen in ListAccountTokens.swift,
   der Sheet-Verlauf #102022 → #0A1416 in SheetTheme.swift:53.

 📝 Last Change:
 - Initial creation (T-010).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit
import XCTest
@testable import Famlist

final class ToggleOffContrastTests: XCTestCase {

    private typealias RGBA = (r: Double, g: Double, b: Double, a: Double)

    private let white: RGBA = (255, 255, 255, 1)
    private let black: RGBA = (0, 0, 0, 1)

    // MARK: - Hell

    func test_toggleOff_light_reachesThreeToOneOnEveryGround() {
        let track = rgba(ListAccountTokens(.light).toggleOff)
        let grounds: [(String, RGBA)] = [
            ("Karte (weiß)", white),
            ("Feld", over(rgba(SheetTheme(.light).field), white)),
            ("Menü .listMenu über Schwarz", over(rgba(OverlayTheme(.light, variant: .listMenu).menu), black)),
            ("Menü .listMenu über Weiß", over(rgba(OverlayTheme(.light, variant: .listMenu).menu), white)),
            ("Menü .dockMenu über Schwarz", over(rgba(OverlayTheme(.light, variant: .dockMenu).menu), black))
        ]
        assertThreeToOne(track: track, grounds: grounds, mode: "hell")
    }

    // MARK: - Dunkel

    func test_toggleOff_dark_reachesThreeToOneOnEveryGround() {
        let trackColor = rgba(ListAccountTokens(.dark).toggleOff)
        let sheets: [RGBA] = [hex(0x10, 0x20, 0x22), hex(0x0A, 0x14, 0x16)]
        var grounds: [(String, RGBA)] = []
        for sheet in sheets {
            grounds.append(("Karte w0.07", over((255, 255, 255, 0.07), sheet)))
            grounds.append(("Karte w0.03", over((255, 255, 255, 0.03), sheet)))
            grounds.append(("Feld", over(rgba(SheetTheme(.dark).field), sheet)))
        }
        for variant in [OverlayTheme.MenuVariant.listMenu, .dockMenu] {
            let menu = rgba(OverlayTheme(.dark, variant: variant).menu)
            grounds.append(("Menü \(variant) über Weiß", over(menu, white)))
            grounds.append(("Menü \(variant) über Schwarz", over(menu, black)))
        }
        for (name, ground) in grounds {
            let ratio = contrast(over(trackColor, ground), ground)
            XCTAssertGreaterThanOrEqual(ratio, 3.0, "dunkel – \(name): \(String(format: "%.2f", ratio)):1")
        }
    }

    // MARK: - Helpers

    private func assertThreeToOne(track: RGBA, grounds: [(String, RGBA)], mode: String) {
        for (name, ground) in grounds {
            let ratio = contrast(over(track, ground), ground)
            XCTAssertGreaterThanOrEqual(ratio, 3.0, "\(mode) – \(name): \(String(format: "%.2f", ratio)):1")
        }
    }

    private func hex(_ r: Double, _ g: Double, _ b: Double) -> RGBA { (r, g, b, 1) }

    /// sRGB-Komponenten 0…255 und Deckkraft einer SwiftUI-Farbe.
    private func rgba(_ color: Color) -> RGBA {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a), "Farbe nicht in sRGB auflösbar")
        return (Double(r) * 255, Double(g) * 255, Double(b) * 255, Double(a))
    }

    /// Mischfarbe von `top` (mit Deckkraft) über einem deckenden Grund.
    private func over(_ top: RGBA, _ base: RGBA) -> RGBA {
        let mix = { (t: Double, b: Double) in t * top.a + b * (1 - top.a) }
        return (mix(top.r, base.r), mix(top.g, base.g), mix(top.b, base.b), 1)
    }

    /// WCAG-2-Kontrast zweier deckender Farben.
    private func contrast(_ x: RGBA, _ y: RGBA) -> Double {
        let lx = luminance(x), ly = luminance(y)
        return (max(lx, ly) + 0.05) / (min(lx, ly) + 0.05)
    }

    private func luminance(_ c: RGBA) -> Double {
        func channel(_ v: Double) -> Double {
            let s = v / 255
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }
}
