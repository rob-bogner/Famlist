/*
 WatchWidgetPublisher.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Schreibt den Widget-Stand in die App Group und lädt die Widgets neu – nur wenn er sich geändert hat
   (watchOS begrenzt, wie oft Komplikationen neu gezeichnet werden).

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 6).
 ------------------------------------------------------------------------
 */

import Foundation
import WidgetKit

@MainActor
final class WatchWidgetPublisher {
    private let defaults: UserDefaults?
    private let reload: @MainActor () -> Void

    init(defaults: UserDefaults? = WatchWidgetState.sharedDefaults,
         reload: @escaping @MainActor () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.defaults = defaults
        self.reload = reload
    }

    func publish(_ state: WatchWidgetState) {
        guard WatchWidgetState.load(from: defaults) != state else { return }
        state.save(to: defaults)
        reload()
    }
}
