/*
 HorizontalPanGesture.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Waagerechte Wischgeste für Zeilen innerhalb eines ScrollView: `.onHorizontalPan(...)`.

 🔰 Notes for Beginners:
 - iOS 18+: DirectionalPanGestureRecognizer (UIGestureRecognizerRepresentable).
   • Er entscheidet tolerant anhand der aufsummierten Bewegung (Details dort), nicht nach der
     verrauschten Anfangsgeschwindigkeit. Wackeln beim Aufsetzen kippt die Entscheidung nicht.
   • Der Scroll-Pan des ScrollView wartet auf ihn (shouldBeRequiredToFailBy). Senkrechtes Wischen
     scrollt also wie gewohnt, waagerechtes bewegt nur die Karte – kein Gerangel beider Gesten.
   • Loslassen, Abbrechen und Fehlschlag melden immer onEnded → keine hängenbleibende Karte.
 - iOS 17: SwiftUI-DragGesture als Rückfallweg (simultaneous + Richtungssperre).
 - Werte in Punkten; Geschwindigkeit in Punkten pro Sekunde (negativ = nach links).

 📝 Last Change:
 - Initial creation (ersetzt die reine DragGesture der Wisch-Zeile).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

extension View {
    /// Horizontal pan that cooperates with vertical scrolling.
    func onHorizontalPan(onChanged: @escaping (CGFloat) -> Void,
                         onEnded: @escaping (_ translation: CGFloat, _ velocity: CGFloat) -> Void) -> some View {
        modifier(HorizontalPanModifier(onChanged: onChanged, onEnded: onEnded))
    }
}

/// Chooses the UIKit recognizer on iOS 18+ and a DragGesture fallback on iOS 17.
private struct HorizontalPanModifier: ViewModifier {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void

    @State private var isHorizontal: Bool?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.gesture(HorizontalPanRecognizer(onChanged: onChanged, onEnded: onEnded))
        } else {
            content.simultaneousGesture(fallbackDrag)
        }
    }

    private var fallbackDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if isHorizontal == nil {
                    isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                }
                if isHorizontal == true { onChanged(value.translation.width) }
            }
            .onEnded { value in
                if isHorizontal == true { onEnded(value.translation.width, value.velocity.width) }
                isHorizontal = nil
            }
    }
}

/// Wraps DirectionalPanGestureRecognizer (tolerant horizontal decision) for SwiftUI.
@available(iOS 18.0, *)
private struct HorizontalPanRecognizer: UIGestureRecognizerRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> DirectionalPanGestureRecognizer {
        let pan = DirectionalPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func handleUIGestureRecognizerAction(_ recognizer: DirectionalPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            onChanged(recognizer.translation)
        case .ended, .cancelled, .failed:
            onEnded(recognizer.translation, recognizer.velocity)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// The scroll view's pan waits until this recognizer has decided (fails for vertical movement).
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other is UIPanGestureRecognizer && other.view is UIScrollView
        }
    }
}
