/*
 ActionCardHost.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bühne der Aktionskarte: Abdunkelung (ohne Blur) + Karte unten (links/rechts 12, unten 30), Ein-/Ausblenden.

 🔰 Notes for Beginners:
 - Läuft in einem durchsichtigen fullScreenCover (siehe View+ActionCard) – so liegt die Karte über allem,
   auch wenn sie aus einer kleinen Ansicht (z. B. einer Artikelkarte) heraus geöffnet wird.
 - Einblenden: Abdunkelung weich, Karte fährt von unten ein („Bewegung reduzieren“: nur einblenden).
 - Schließen (Knopf, Tipp auf die Abdunkelung, VoiceOver-Geste „Zurück“): erst ausblenden, dann `onClosed`
   mit der Folgeaktion aufrufen.
 - Tastatur: Die Karte bleibt über der Tastatur (nur der untere Container-Rand wird ignoriert).

 📝 Last Change:
 - Initial creation (Designsprache statt Systemdialoge).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Scrim and bottom-anchored action card with appear/disappear animation.
struct ActionCardHost: View {
    let k: SheetTheme
    /// nil, sobald der Aufrufer seinen Zustand zurückgesetzt hat – dann ist die Karte schon ausgeblendet.
    let content: ActionCardContent?
    let onClosed: (_ then: (() -> Void)?) -> Void

    @State private var visible = false
    @State private var closing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let d = ActionCardTokens(k)
        ZStack(alignment: .bottom) {
            d.scrim
                .opacity(visible ? 1 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if content?.closable ?? true { close(nil) } }
                .accessibilityHidden(true)
            if visible, let content {
                ActionCardView(content: content, k: k, close: close)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.isModal)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.88)) {
                visible = true
            }
        }
        .accessibilityAction(.escape) { if content?.closable ?? true { close(nil) } }
    }

    private func close(_ then: (() -> Void)?) {
        guard !closing else { return }
        closing = true
        withAnimation(.easeIn(duration: 0.18)) {
            visible = false
        } completion: {
            onClosed(then)
        }
    }
}
