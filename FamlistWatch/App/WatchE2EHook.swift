/*
 WatchE2EHook.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nur DEBUG: Startargument `-watchE2ECheck <Artikelname>` schaltet diesen Artikel der aktiven Liste
   einmal um (abhaken bzw. wieder öffnen), sobald er geladen ist. Für den Gerätepaar-Test im Simulator (Uhr → iPhone), in dem sich die
   Uhr nicht antippen lässt. Wie `-watchDesignScreen` ohne Wirkung in Release-Builds.
 ------------------------------------------------------------------------
 */

#if DEBUG
import SwiftUI

struct WatchE2EHook: ViewModifier {
    @ObservedObject var model: WatchListViewModel
    @State private var done = false

    func body(content: Content) -> some View {
        content.onReceive(model.$sections) { sections in
            guard !done, let name = UserDefaults.standard.string(forKey: "watchE2ECheck"),
                  let item = sections.flatMap(\.items).first(where: { $0.name == name }) else { return }
            done = true
            Task {
                // Erst abhaken, wenn das iPhone erreichbar ist (sonst prüft der Test nur Supabase).
                for _ in 0..<20 where model.sync.transport?.isReachable != true {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
                logVoid(params: (action: "watchE2E.check", name: name, reachable: model.sync.transport?.isReachable ?? false))
                model.toggle(item.id)
            }
        }
    }
}
#endif
