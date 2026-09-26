/*
 FamlistWatchApp.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einstiegspunkt der Watch-App (watchOS 10+), Companion der iOS-App.

 🔰 Notes for Beginners:
 - Beim Start: Verbindung zum iPhone aktivieren, eigene Sitzung wiederherstellen oder anfragen.
 - Sichtbar: Abfrage aller Listen alle 10 s und Senden; nicht sichtbar: angehalten (Watch-Plan §2).
 - Deep Links der Komplikationen: famlist://watch/list und famlist://watch/add.
 - DEBUG: `-watchDesignScreen <name>` zeigt einen Screen mit Beispieldaten (Pixelvergleich).

 📝 Last Change:
 - Widgets (App Group), Hintergrund-Aktualisierung (Watch-Plan Phase 6).
 ------------------------------------------------------------------------
 */

import SwiftUI

@main
struct FamlistWatchApp: App {
    @StateObject private var environment: WatchAppEnvironment
    @StateObject private var model: WatchListViewModel
    @State private var path: [WatchRoute] = [.list]
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let environment = WatchAppEnvironment()
        _environment = StateObject(wrappedValue: environment)
        _model = StateObject(wrappedValue: WatchListViewModel(sync: environment.sync, widgets: WatchWidgetPublisher()))
    }

    var body: some Scene {
        WindowGroup {
            content
                .task { await environment.start() }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    environment.sync.setActive(phase == .active)
                    if phase == .background { environment.scheduleBackgroundRefresh() }
                }
                .onOpenURL(perform: open)
                #if DEBUG
                // `-watchOpenURL famlist://watch/add`: wie ein Tipp auf die Komplikation (Simulator kann es nicht).
                .task {
                    if let link = UserDefaults.standard.string(forKey: "watchOpenURL"), let url = URL(string: link) { open(url) }
                }
                #endif
        }
        .backgroundTask(.appRefresh) { _ in
            await WatchAppEnvironment.performBackgroundRefresh()
        }
    }

    /// Deep Link der Komplikationen: Navigationsstapel setzen.
    private func open(_ url: URL) {
        if let route = WatchRoute.path(for: url) { path = route }
    }

    @ViewBuilder private var content: some View {
        #if DEBUG
        if let screen = WatchDesignGallery.requestedScreen {
            WatchDesignGallery(screen: screen)
        } else {
            WatchRootView(session: environment.session, model: model, path: $path)
                .modifier(WatchE2EHook(model: model))
        }
        #else
        WatchRootView(session: environment.session, model: model, path: $path)
        #endif
    }
}
