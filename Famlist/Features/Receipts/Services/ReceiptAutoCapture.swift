/*
 ReceiptAutoCapture.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Entscheidet bei „Auto“, wann die Kamera selbst auslöst: sobald der erkannte Bon 1 Sekunde ruhig liegt.
   Liefert außerdem den Fortschritt (0…1) für den Ring am Auslöser.

 🔰 Notes for Beginners:
 - „Ruhig“ heißt: Keine Ecke hat sich seit Beginn der Ruhephase um mehr als 3 % der Bildbreite bewegt.
   Verglichen wird mit dem Anfang der Ruhephase, nicht mit dem letzten Bild – sonst würde langsames
   Wegdriften nie bemerkt.
 - Kurze Aussetzer der Erkennung (bis 0,3 s) werden überbrückt; die Erkennung verliert den Bon manchmal
   für ein einzelnes Bild.
 - Nach einer Aufnahme ist die Auto-Auslösung gesperrt, bis der Bon verschwindet oder sich deutlich bewegt
   (15 %). So entsteht nicht zweimal dasselbe Foto; bei langen Bons schiebt man das iPhone zum nächsten Teil.
 - Reine Logik ohne Kamera: Zeit und Ecken kommen von außen, damit sie testbar ist.

 📝 Last Change:
 - Initial creation (Kassenzettel wie ein Dokumentenscanner).
 ------------------------------------------------------------------------
 */

import CoreGraphics
import Foundation

struct ReceiptAutoCapture {
    static let holdDuration: TimeInterval = 1.0
    static let stillTolerance: CGFloat = 0.03
    static let dropoutTolerance: TimeInterval = 0.3
    static let rearmDistance: CGFloat = 0.15

    /// Fortschritt der Ruhephase (0…1) für den Ring am Auslöser.
    private(set) var progress: Double = 0

    /// Ecken zu Beginn der Ruhephase und deren Zeitpunkt.
    private var anchor: (quad: ReceiptQuad, time: TimeInterval)?
    private var lastSeen: TimeInterval?
    /// Ecken der letzten Auto-Aufnahme; solange gesetzt, löst Auto nicht erneut aus.
    private var capturedQuad: ReceiptQuad?

    /// Neues Analyse-Ergebnis. Gibt true zurück, wenn jetzt ausgelöst werden soll.
    mutating func update(quad: ReceiptQuad?, at time: TimeInterval) -> Bool {
        guard let quad else {
            handleDropout(at: time)
            return false
        }
        lastSeen = time
        if let captured = capturedQuad {
            guard quad.maxCornerDistance(to: captured) > Self.rearmDistance else { return false }
            capturedQuad = nil
        }
        if let anchor, quad.maxCornerDistance(to: anchor.quad) <= Self.stillTolerance {
            progress = min(1, (time - anchor.time) / Self.holdDuration)
        } else {
            anchor = (quad, time)
            progress = 0
        }
        guard progress >= 1 else { return false }
        capturedQuad = quad
        restart()
        return true
    }

    /// Nach einer Aufnahme per Knopf: gleiche Sperre wie nach einer Auto-Aufnahme.
    mutating func didCaptureManually(quad: ReceiptQuad?) {
        capturedQuad = quad
        restart()
    }

    /// Kein Bon im Bild: kurze Aussetzer überbrücken, danach alles zurücksetzen und die Sperre aufheben.
    private mutating func handleDropout(at time: TimeInterval) {
        guard let lastSeen else { return }
        if time - lastSeen > Self.dropoutTolerance {
            restart()
            capturedQuad = nil
            self.lastSeen = nil
        }
    }

    private mutating func restart() {
        anchor = nil
        progress = 0
    }
}
