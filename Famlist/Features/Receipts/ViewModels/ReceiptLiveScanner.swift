/*
 ReceiptLiveScanner.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zustand der Live-Erkennung im Kamerabildschirm: erkannte Ecken für den Rahmen, Fortschritt für den
   Ring am Auslöser und die Auto-Auslösung.

 🔰 Notes for Beginners:
 - Die Kamera liefert bis zu 10 Ergebnisse pro Sekunde (ReceiptCamera.setDocumentHandler).
   `update` läuft auf dem Main Actor, weil die Oberfläche die Werte anzeigt.
 - Die Entscheidung „jetzt auslösen“ trifft ReceiptAutoCapture (1 s Ruhe, Sperre nach der Aufnahme).
 - `isPaused`: Während Vollbild oder „Ecken anpassen“ offen sind, darf die Kamera nicht heimlich auslösen.

 📝 Last Change:
 - Initial creation (Kassenzettel wie ein Dokumentenscanner).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class ReceiptLiveScanner: ObservableObject {
    /// Erkannte Ecken in Sensor-Koordinaten (für den Rahmen); nil = kein Bon im Bild.
    @Published private(set) var quad: ReceiptQuad?
    /// 0…1 für den Ring am Auslöser (nur bei Auto).
    @Published private(set) var progress: Double = 0

    var isAutoEnabled = true {
        didSet { if !isAutoEnabled { resetTracking() } }
    }
    var isPaused = false {
        didSet { if isPaused { quad = nil; resetTracking() } }
    }
    /// Wird gerufen, wenn Auto auslösen soll. Die Nummer des neuen Teils kommt vom Aufrufer.
    var onAutoCapture: () -> Void = {}

    private var auto = ReceiptAutoCapture()

    func update(quad newQuad: ReceiptQuad?, at time: TimeInterval) {
        guard !isPaused else { return }
        quad = newQuad
        guard isAutoEnabled else { return }
        let fire = auto.update(quad: newQuad, at: time)
        progress = auto.progress
        if fire { onAutoCapture() }
    }

    /// Aufnahme per Knopf: denselben Bon danach nicht noch einmal automatisch fotografieren.
    func didCaptureManually() {
        auto.didCaptureManually(quad: quad)
        progress = 0
    }

    private func resetTracking() {
        auto = ReceiptAutoCapture()
        progress = 0
    }
}
