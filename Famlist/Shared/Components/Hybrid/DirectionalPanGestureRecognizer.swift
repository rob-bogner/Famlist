/*
 DirectionalPanGestureRecognizer.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - UIKit-Gestenerkenner für waagerechtes Wischen mit toleranter Richtungsentscheidung.

 🔰 Notes for Beginners:
 - Problem des Standard-UIPanGestureRecognizer: Er entscheidet nach ca. 10 pt anhand der
   momentanen Geschwindigkeit. Ein echter Daumen wackelt beim Aufsetzen senkrecht → „senkrecht“
   gewinnt, das Scrollen übernimmt, der Wisch ist verloren.
 - Dieser Erkenner entscheidet anhand der AUFSUMMIERTEN Bewegung seit dem Aufsetzen:
   • unter `decisionDistance` (8 pt): noch keine Entscheidung (Scrollen wartet),
   • waagerecht genug (|dx| ≥ |dy| · 0,8, also bis ca. 51°): Wisch beginnt,
   • erst wenn |dy| `verticalFailDistance` (16 pt) erreicht und es nicht waagerecht genug ist:
     Erkenner scheitert, das Scrollen übernimmt.
 - Geschwindigkeit = Mittel über die letzten ~80 ms (glättet das Rauschen einzelner Touch-Samples).
 - translation / velocity liefern Punkte bzw. Punkte pro Sekunde im Fenster-Koordinatensystem.

 📝 Last Change:
 - Initial creation (mehr Toleranz beim Wischen, Rückmeldung aus dem Praxistest).
 ------------------------------------------------------------------------
 */

import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Horizontal pan recognizer that tolerates vertical wobble at touch-down.
final class DirectionalPanGestureRecognizer: UIGestureRecognizer {
    enum Decision { case undecided, horizontal, vertical }

    static let decisionDistance: CGFloat = 8
    static let verticalFailDistance: CGFloat = 16
    /// Horizontal wins while |dx| ≥ |dy| · horizontalRatio (0.8 ≈ 51° from horizontal).
    static let horizontalRatio: CGFloat = 0.8

    /// Pure direction decision on the cumulative movement since touch-down (unit-tested).
    static func decide(dx: CGFloat, dy: CGFloat) -> Decision {
        if hypot(dx, dy) >= decisionDistance && abs(dx) >= abs(dy) * horizontalRatio { return .horizontal }
        if abs(dy) >= verticalFailDistance { return .vertical }
        return .undecided
    }

    private(set) var translation: CGFloat = 0
    private var start: CGPoint = .zero
    private var samples: [(x: CGFloat, time: TimeInterval)] = []

    /// Horizontal velocity averaged over the last ~80 ms.
    var velocity: CGFloat {
        guard let last = samples.last,
              let first = samples.first(where: { last.time - $0.time <= 0.08 }),
              last.time - first.time > 0.001 else { return 0 }
        return (last.x - first.x) / CGFloat(last.time - first.time)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.count == 1, let touch = touches.first, numberOfTouches(event) == 1 else {
            state = .failed
            return
        }
        start = touch.location(in: nil)
        translation = 0
        samples = [(start.x, touch.timestamp)]
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: nil)
        record(point, time: touch.timestamp)
        let dx = point.x - start.x
        let dy = point.y - start.y
        translation = dx

        switch state {
        case .possible:
            switch Self.decide(dx: dx, dy: dy) {
            case .horizontal: state = .began
            case .vertical: state = .failed
            case .undecided: break
            }
        case .began, .changed:
            state = .changed
        default:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first {
            // Kein neues Geschwindigkeits-Sample: Der End-Touch liegt meist auf dem letzten Punkt,
            // nur später – das würde die Wisch-Geschwindigkeit künstlich senken.
            translation = touch.location(in: nil).x - start.x
        }
        state = (state == .began || state == .changed) ? .ended : .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = (state == .began || state == .changed) ? .cancelled : .failed
    }

    override func reset() {
        super.reset()
        translation = 0
        samples.removeAll()
    }

    private func record(_ point: CGPoint, time: TimeInterval) {
        samples.append((point.x, time))
        if samples.count > 12 { samples.removeFirst(samples.count - 12) }
    }

    private func numberOfTouches(_ event: UIEvent) -> Int {
        event.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled }.count ?? 1
    }
}
