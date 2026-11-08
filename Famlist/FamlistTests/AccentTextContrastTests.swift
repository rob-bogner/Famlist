/*
 AccentTextContrastTests.swift
 FamlistTests
 Created on: 08.11.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - T-011: Schrift auf Akzentflächen hält mindestens 4,5:1 (WCAG 1.4.3), in hell und dunkel, an jedem Stopp
   des Verlaufs: gewählte Pillen (GlassStyleTokens.selectedPillPaint / selectedPillText) und die Bon-Kopfkarte
   (EKKTokens.receiptHeroBg / receiptHeroText / receiptHeroSub, Unterzeile als Mischfarbe mit 92 %).

 🔰 Notes for Beginners:
 - Verläufe sind `Paint` und nicht auslesbar; ihre Stopps kommen aus `AccentScale` (light, base), genau wie
   `selectedPillPaint` sie baut. Geprüft wird jeder Stopp einzeln – der ungünstigste zählt.
 - Gegenprobe: die alte weiße Schrift muss an mindestens einem Stopp durchfallen, sonst prüft der Test nichts.

 📝 Last Change:
 - Initial creation (T-011).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit
import XCTest
@testable import Famlist

final class AccentTextContrastTests: XCTestCase {

    private typealias RGBA = (r: Double, g: Double, b: Double, a: Double)

    // MARK: - Gewählte Pillen

    func test_selectedPill_textReachesFourPointFiveOnEveryStop() {
        let text = rgba(GlassStyleTokens.selectedPillText)
        for appearance in [Appearance.light, .dark] {
            for (name, stop) in pillStops(appearance) {
                let ratio = contrast(text, stop)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(appearance) – Pille \(name): \(fmt(ratio)):1")
            }
        }
    }

    /// Gegenprobe: Weiß (vorher) fällt auf der Pillenfüllung durch – der Test erkennt den alten Fehler.
    func test_selectedPill_oldWhiteTextFailsOnSomeStop() {
        let white: RGBA = (255, 255, 255, 1)
        for appearance in [Appearance.light, .dark] {
            let worst = pillStops(appearance).map { contrast(white, $0.1) }.min() ?? 99
            XCTAssertLessThan(worst, 4.5, "\(appearance): Weiß sollte auf der hellen Füllung unter 4,5 liegen")
        }
    }

    // MARK: - Bon-Kopfkarte

    func test_receiptHeroCard_textAndSubReachFourPointFiveOnEveryStop() {
        let text = rgba(EKKTokens.receiptHeroText)
        let sub = rgba(EKKTokens.receiptHeroSub)
        for appearance in [Appearance.light, .dark] {
            for (name, stop) in pillStops(appearance) {          // receiptHeroBg hat dieselben Stopps light → base
                let rText = contrast(text, stop), rSub = contrast(sub, stop)
                XCTAssertGreaterThanOrEqual(rText, 4.5, "\(appearance) – Kopfkarte Text \(name): \(fmt(rText)):1")
                XCTAssertGreaterThanOrEqual(rSub, 4.5, "\(appearance) – Kopfkarte Unterzeile \(name): \(fmt(rSub)):1")
            }
        }
    }

    /// Gegenprobe: die alte Unterzeile (weiß 85 %) fällt auf denselben Stopps durch.
    func test_receiptHeroCard_oldWhiteSubFailsOnSomeStop() {
        let oldSub: RGBA = (255, 255, 255, 0.85)
        for appearance in [Appearance.light, .dark] {
            let worst = pillStops(appearance).map { contrast(oldSub, $0.1) }.min() ?? 99
            XCTAssertLessThan(worst, 4.5, "\(appearance): alte Unterzeile sollte unter 4,5 liegen")
        }
    }

    // MARK: - Stopps

    private func pillStops(_ appearance: Appearance) -> [(String, RGBA)] {
        let a = AccentScale(appearance.defaultAccent, appearance)
        return [("light", rgb(a.light)), ("base", rgb(a.base))]
    }

    // MARK: - Helpers

    private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }

    private func rgb(_ c: RGB) -> RGBA { (c.r, c.g, c.b, 1) }

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

    /// WCAG-2-Kontrast; halbtransparente Schrift wird vorher über den Grund gemischt.
    private func contrast(_ fg: RGBA, _ bg: RGBA) -> Double {
        let x = fg.a < 1 ? over(fg, bg) : fg
        let lx = luminance(x), ly = luminance(bg)
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
