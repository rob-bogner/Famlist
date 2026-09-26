/*
 WatchStatusScreen.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zustand ohne Listen: Verbinden mit dem iPhone, „Öffne Famlist auf dem iPhone“, Laden.
   Nicht gestaltet (Watch-Plan §5) – schlicht im vorhandenen Stil, eingetragen in PLAN.md §9.

 🔰 Notes for Beginners:
 - Nur Anzeige und ein Rückruf; welcher Text erscheint, entscheidet WatchRootView.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchStatusScreen: View {
    var w = WatchTheme()
    let message: String
    var showsProgress = false
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            if showsProgress { ProgressView().tint(w.accentText) }
            Text(message)
                .font(WatchFont.dm(14)).foregroundStyle(w.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let onRetry {
                Button(action: onRetry) {
                    Text("Erneut versuchen").font(WatchFont.dm(14, 600)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(CSSBox(shape: Capsule(), paint: w.glassButton, border: 1, borderColor: w.glassBorder))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .watchScreen("Famlist", contentTop: 38, w: w)
    }
}

#Preview("iPhone öffnen") {
    WatchStatusScreen(message: "Öffne Famlist auf dem iPhone, um die Uhr anzumelden.", onRetry: {})
}

#Preview("Verbinden") {
    WatchStatusScreen(message: "Verbinde mit dem iPhone …", showsProgress: true)
}
