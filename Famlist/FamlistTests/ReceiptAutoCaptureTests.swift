/*
 ReceiptAutoCaptureTests.swift
 FamlistTests

 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für die Auto-Auslösung: 1 Sekunde Ruhe → Aufnahme, Bewegung setzt zurück, kurze Aussetzer
   werden überbrückt, nach einer Aufnahme erst wieder nach deutlicher Bewegung.

 📝 Last Change:
 - Initial creation (Kassenzettel wie ein Dokumentenscanner).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ReceiptAutoCaptureTests: XCTestCase {
    private func quad(dx: CGFloat = 0, dy: CGFloat = 0) -> ReceiptQuad {
        ReceiptQuad(topLeft: CGPoint(x: 0.3 + dx, y: 0.1 + dy), topRight: CGPoint(x: 0.7 + dx, y: 0.1 + dy),
                    bottomRight: CGPoint(x: 0.7 + dx, y: 0.9 + dy), bottomLeft: CGPoint(x: 0.3 + dx, y: 0.9 + dy))
    }

    /// Frames alle 0,125 s (im Binärsystem exakt, anders als 0,1); gibt die Zeitpunkte der Auslösungen zurück.
    private func feed(_ auto: inout ReceiptAutoCapture, from start: TimeInterval, to end: TimeInterval,
                      quad: (TimeInterval) -> ReceiptQuad?) -> [TimeInterval] {
        var fired: [TimeInterval] = []
        for frame in Int((start * 8).rounded(.up))...Int((end * 8).rounded(.down)) {
            let t = Double(frame) / 8
            if auto.update(quad: quad(t), at: t) { fired.append(t) }
        }
        return fired
    }

    func test_stillReceipt_firesAfterOneSecond() {
        var auto = ReceiptAutoCapture()
        let fired = feed(&auto, from: 0, to: 1.5) { _ in self.quad() }
        XCTAssertEqual(fired.count, 1)
        XCTAssertEqual(fired.first ?? 0, 1.0, accuracy: 0.001)
    }

    func test_progress_growsWhileStill() {
        var auto = ReceiptAutoCapture()
        _ = feed(&auto, from: 0, to: 0.5) { _ in self.quad() }
        XCTAssertEqual(auto.progress, 0.5, accuracy: 0.001)
    }

    /// Kleines Zittern (1 %) zählt als ruhig; ein Ruck (5 %) startet die Ruhephase neu.
    func test_movement_restartsHold() {
        var auto = ReceiptAutoCapture()
        let fired = feed(&auto, from: 0, to: 2.0) { t in
            let jitter: CGFloat = Int(t * 8) % 2 == 0 ? 0 : 0.01
            return self.quad(dx: t < 0.7 ? jitter : 0.05 + jitter)
        }
        XCTAssertEqual(fired.first ?? 0, 1.75, accuracy: 0.001, "Ruck bei 0,75 s → Aufnahme erst 1 s später")
    }

    /// Langsames Wegdriften (je Bild 0,6 %) ist keine Ruhe, auch wenn jeder einzelne Schritt klein ist.
    func test_slowDrift_isNotStill() {
        var auto = ReceiptAutoCapture()
        let fired = feed(&auto, from: 0, to: 2.0) { t in self.quad(dx: CGFloat(t) * 0.05) }
        XCTAssertTrue(fired.isEmpty)
    }

    /// Einzelne Bilder ohne Treffer (≤ 0,3 s) unterbrechen die Ruhephase nicht.
    func test_shortDropout_isBridged() {
        var auto = ReceiptAutoCapture()
        let fired = feed(&auto, from: 0, to: 1.5) { t in (0.45...0.55).contains(t) ? nil : self.quad() }
        XCTAssertEqual(fired.first ?? 0, 1.0, accuracy: 0.001)
    }

    func test_longDropout_resetsProgress() {
        var auto = ReceiptAutoCapture()
        _ = feed(&auto, from: 0, to: 0.5) { _ in self.quad() }
        _ = feed(&auto, from: 0.625, to: 1.25) { _ in nil }
        XCTAssertEqual(auto.progress, 0)
        let fired = feed(&auto, from: 1.375, to: 2.5) { _ in self.quad() }
        XCTAssertEqual(fired.first ?? 0, 2.375, accuracy: 0.001)
    }

    /// Nach der Aufnahme bleibt der Bon liegen → keine zweite Aufnahme.
    func test_afterCapture_doesNotFireAgainForSameReceipt() {
        var auto = ReceiptAutoCapture()
        let fired = feed(&auto, from: 0, to: 4.0) { _ in self.quad() }
        XCTAssertEqual(fired.count, 1)
    }

    /// Langer Bon: iPhone zum nächsten Teil geschoben (Ecken 20 % versetzt) → neue Aufnahme nach 1 s Ruhe.
    func test_afterCapture_firesAgainAfterMovingOn() {
        var auto = ReceiptAutoCapture()
        let fired = feed(&auto, from: 0, to: 3.0) { t in self.quad(dy: t < 1.45 ? 0 : 0.2) }
        XCTAssertEqual(fired.count, 2)
        XCTAssertEqual(fired.last ?? 0, 2.5, accuracy: 0.001)
    }

    /// Bon verschwindet nach der Aufnahme und kommt zurück → Sperre aufgehoben.
    func test_afterCapture_rearmsWhenReceiptLeaves() {
        var auto = ReceiptAutoCapture()
        let fired = feed(&auto, from: 0, to: 3.0) { t in (1.2...1.7).contains(t) ? nil : self.quad() }
        XCTAssertEqual(fired.count, 2)
    }

    /// Aufnahme per Knopf sperrt Auto für denselben Bon.
    func test_manualCapture_locksSameReceipt() {
        var auto = ReceiptAutoCapture()
        _ = feed(&auto, from: 0, to: 0.5) { _ in self.quad() }
        auto.didCaptureManually(quad: quad())
        let fired = feed(&auto, from: 0.625, to: 3.0) { _ in self.quad() }
        XCTAssertTrue(fired.isEmpty)
    }
}
