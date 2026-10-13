/*
 PressGestureRecognizer.swift
 Famlist
 Created on: 14.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - UIKit-Gestenerkenner, der das Aufsetzen des Fingers sofort meldet (Drücken, Bewegen, Loslassen).

 🔰 Notes for Beginners:
 - Anlass: Seit iOS 27 erkennt `DragGesture(minimumDistance: 0)` das Aufsetzen spürbar verzögert, besonders im
   unteren Fünftel des Bildschirms (Apple Developer Forums, Thread 846105). Das Plus im Dock liegt genau dort.
 - Die Rückrufe laufen direkt aus `touchesBegan/Moved/Ended` und nicht über target-action. Die Zustellung per
   target-action kann das System nahe dem Home-Indikator zurückhalten; der Zustand selbst wechselt sofort.
 - Der Erkenner beobachtet nur: Er nimmt anderen Gesten nichts weg (`cancelsTouchesInView` aus, siehe PressGesture).
 - Ort im Fenster-Koordinatensystem, Bewegung in Punkten seit dem Aufsetzen. Verfolgt wird nur der erste Finger.

 📝 Last Change:
 - Initial creation (Plus gedrückt halten startete auf iOS 27 mal sofort, mal nach ca. 0,4 s).
 ------------------------------------------------------------------------
 */

import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Touch-down recognizer that reports from the touch callbacks without recognition delay.
final class PressGestureRecognizer: UIGestureRecognizer {
    /// Location in window coordinates and translation since touch-down.
    var onChanged: ((CGPoint, CGSize) -> Void)?
    /// Finger lifted or touch cancelled.
    var onEnded: (() -> Void)?

    private var start: CGPoint = .zero
    private weak var tracked: UITouch?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard tracked == nil, let touch = touches.first else { return }
        tracked = touch
        start = touch.location(in: nil)
        state = .began
        onChanged?(start, .zero)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        let point = touch.location(in: nil)
        state = .changed
        onChanged?(point, CGSize(width: point.x - start.x, height: point.y - start.y))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        finish(.ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        finish(.cancelled)
    }

    override func reset() {
        super.reset()
        // Vom System zurückgesetzt, ohne dass der Finger gemeldet wurde: trotzdem „losgelassen“ melden.
        if tracked != nil {
            tracked = nil
            onEnded?()
        }
    }

    private func finish(_ end: State) {
        tracked = nil
        state = end
        onEnded?()
    }
}
