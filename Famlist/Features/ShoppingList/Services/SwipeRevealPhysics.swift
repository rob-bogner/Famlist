/*
 SwipeRevealPhysics.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Reine Rechenlogik der Wisch-Aktionen: Kartenversatz während des Ziehens und die Ruhelage
   beim Loslassen (zu / rechts offen / links offen / Abhaken auslösen).

 🔰 Notes for Beginners:
 - Drei Ruhelagen (Rest): zu (0), links offen (−revealWidth, Löschen/Bearbeiten/Nicht verfügbar
   bzw. „Zurück“), rechts offen (+leadingWidth, grüner Abhaken- bzw. gelber Zurück-Button).
 - Nach rechts gibt es zwei Stufen wie bei Apple: bis leadingWidth (96 pt) zeigt nur den Button,
   loslassen lässt die Karte offen. Erst ab fullSwipeDistance (180 pt) wird beim Loslassen ausgelöst.
 - Die Karte folgt dem Finger 1:1; über das Ziel hinaus (links > revealWidth, rechts > fullSwipeDistance)
   bremst ein Gummiband (höchstens 60 pt Überzug).
 - Zurückschnellen des Daumens (auf dem Gerät gemessen ≈ 90 … 280 ms) zählt nicht: Maßgeblich ist der
   weiteste Punkt. Ein bewusstes Zurückziehen (≥ 400 ms oder < 150 pt/s; gemessen 783 / 950 ms)
   entscheidet dagegen nach der Position beim Loslassen – so lässt sich ein Wisch abbrechen.
 - Abgehakte Artikel: auch nach links zweistufig (trailingFullSwipe) – „Zurück“ sichtbar lassen oder
   bis 180 pt durchwischen. Bei offenen Artikeln bewusst nicht (links liegt „Löschen“).
 - Keine UI, kein Zustand → vollständig per Unit-Test prüfbar (SwipeRevealPhysicsTests).

 📝 Last Change:
 - Rechts zweistufig (offen lassen / durchwischen), drei Ruhelagen.
 ------------------------------------------------------------------------
 */

import CoreGraphics

/// Offset and resting-state decision for a swipe-to-reveal row.
struct SwipeRevealPhysics {
    /// Resting position of a row.
    enum Rest: Equatable {
        case closed
        /// Right side revealed (card moved right): check / undo button.
        case leading
        /// Left side revealed (card moved left): delete / edit / unavailable (or undo).
        case trailing
    }

    /// Result of lifting the finger.
    enum Outcome: Equatable {
        case rest(Rest)
        /// Full swipe to the right: perform check / undo immediately.
        case triggerLeading
        /// Full swipe to the left (only if `trailingFullSwipe`): perform the trailing action (undo).
        case triggerTrailing
    }

    /// Movement facts of one drag, collected by the row.
    struct Drag {
        var translation: CGFloat
        var velocity: CGFloat
        /// Smallest / largest card offset reached during this drag.
        var minOffset: CGFloat
        var maxOffset: CGFloat
        /// Seconds from reaching minOffset / maxOffset until lift-off.
        var pullBackFromMin: Double = 0
        var pullBackFromMax: Double = 0
    }

    /// Width of the trailing action area (256 for open items, 86 for checked items).
    let revealWidth: CGFloat
    /// Resting width of the leading (check / undo) action. 0 disables the right swipe.
    var leadingWidth: CGFloat = 0
    /// Travel that performs the leading (and, if enabled, trailing) action on release (full swipe).
    var fullSwipeDistance: CGFloat = 180
    /// Left full swipe performs the trailing action (checked items: „Zurück“). Off for open items (delete).
    var trailingFullSwipe = false
    /// Swipes faster than this decide by direction (points per second).
    var flingVelocity: CGFloat = 350
    /// Maximum rubber-band overshoot in points.
    var maxOvershoot: CGFloat = 60
    /// From closed, the trailing side opens once this fraction of revealWidth is shown (0.35 × 256 ≈ 90 pt).
    var openFraction: CGFloat = 0.35
    /// Below this speed (pt/s) a pull-back counts as deliberate.
    var deliberatePullBackVelocity: CGFloat = 150
    /// A pull-back lasting at least this long counts as deliberate (seconds).
    var deliberatePullBackDuration: Double = 0.4

    // MARK: - Offset

    func baseOffset(_ rest: Rest) -> CGFloat {
        switch rest {
        case .closed: return 0
        case .leading: return leadingWidth
        case .trailing: return -revealWidth
        }
    }

    /// Card offset for a drag that started in `rest` and has moved by `translation`.
    func offset(rest: Rest, translation: CGFloat) -> CGFloat {
        let raw = baseOffset(rest) + translation
        if raw > 0 {
            guard leadingWidth > 0, rest != .trailing else { return rubberBand(raw) }
            return raw <= fullSwipeDistance ? raw : fullSwipeDistance + rubberBand(raw - fullSwipeDistance)
        }
        let leftLimit = trailingFullSwipe && rest != .leading ? fullSwipeDistance : revealWidth
        if raw < -leftLimit {
            return -leftLimit - rubberBand(-leftLimit - raw)
        }
        return raw
    }

    // MARK: - Release

    /// Where the row goes when the finger lifts.
    func release(from rest: Rest, _ drag: Drag) -> Outcome {
        let final = offset(rest: rest, translation: drag.translation)

        // 1. Full swipe to the right (not from the trailing side).
        if leadingWidth > 0, rest != .trailing, drag.maxOffset >= fullSwipeDistance {
            let cancelled = isDeliberate(drag.velocity, drag.pullBackFromMax) && final < fullSwipeDistance
            if !cancelled { return .triggerLeading }
        }

        // 2. Full swipe to the left (checked items only, not from the leading side).
        if trailingFullSwipe, rest != .leading, drag.minOffset <= -fullSwipeDistance {
            let cancelled = isDeliberate(drag.velocity, drag.pullBackFromMin) && final > -fullSwipeDistance
            if !cancelled { return .triggerTrailing }
        }

        switch rest {
        case .trailing:
            if drag.velocity <= -flingVelocity { return .rest(.trailing) }
            if drag.velocity >= flingVelocity { return .rest(.closed) }
            return .rest(final < -revealWidth * 0.5 ? .trailing : .closed)
        case .leading:
            if drag.velocity <= -flingVelocity { return .rest(.closed) }
            if drag.velocity >= flingVelocity { return .rest(.leading) }
            return .rest(final >= leadingWidth * 0.5 ? .leading : .closed)
        case .closed:
            return releaseFromClosed(final: final, drag)
        }
    }

    private func releaseFromClosed(final: CGFloat, _ drag: Drag) -> Outcome {
        let trailingThreshold = -revealWidth * openFraction
        let leadingThreshold = leadingWidth * 0.5
        // Reached the trailing threshold → stays open unless deliberately pulled back.
        if drag.minOffset <= trailingThreshold {
            let cancelled = isDeliberate(drag.velocity, drag.pullBackFromMin) && final > trailingThreshold
            // A deliberately cancelled left swipe always closes – its rightward pull-back is no right swipe.
            return .rest(cancelled ? .closed : .trailing)
        }
        // Reached the leading threshold → stays open unless deliberately pulled back.
        if leadingWidth > 0, drag.maxOffset >= leadingThreshold, drag.minOffset > trailingThreshold {
            let cancelled = isDeliberate(drag.velocity, drag.pullBackFromMax) && final < leadingThreshold
            if !cancelled { return .rest(.leading) }
        }
        if drag.velocity <= -flingVelocity && final < 0 { return .rest(.trailing) }
        if leadingWidth > 0 && drag.velocity >= flingVelocity && final > 0 { return .rest(.leading) }
        if final <= trailingThreshold { return .rest(.trailing) }
        if leadingWidth > 0 && final >= leadingThreshold { return .rest(.leading) }
        return .rest(.closed)
    }

    private func isDeliberate(_ velocity: CGFloat, _ pullBackDuration: Double) -> Bool {
        abs(velocity) < deliberatePullBackVelocity || pullBackDuration >= deliberatePullBackDuration
    }

    // MARK: - Progress

    /// Fraction 0 … 1 of how far the trailing actions are revealed.
    func revealProgress(offset: CGFloat) -> CGFloat {
        min(1, max(0, -offset / revealWidth))
    }

    /// Fraction 0 … 1 of how far the leading action is revealed (1 at leadingWidth).
    func leadingProgress(offset: CGFloat) -> CGFloat {
        guard leadingWidth > 0 else { return 0 }
        return min(1, max(0, offset / leadingWidth))
    }

    /// iOS-like resistance: grows quickly at first, then asymptotically towards maxOvershoot.
    private func rubberBand(_ distance: CGFloat) -> CGFloat {
        maxOvershoot * (1 - 1 / (distance / (maxOvershoot * 1.8) + 1))
    }
}
