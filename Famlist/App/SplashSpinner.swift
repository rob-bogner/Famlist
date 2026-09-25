/*
 SplashSpinner.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Weißer Ring-Spinner des Splash (32 × 32, 1 Umdrehung pro Sekunde).

 🔰 Notes for Beginners:
 - Design: SplashTomatoesBottom.dc.html („Splash G – Tomaten, Logo unten“).
 - Launch Screen (Info.plist → UILaunchScreen) zeigt dasselbe Bild `LaunchSplash` (440 × 956 pt,
   Foto + Verlauf + Logo) in natürlicher Größe mittig. Diese View zeigt es exakt gleich und ergänzt
   nur den Spinner → nahtloser Übergang ohne Sprung.

 📝 Last Change:
 - Initial creation (Splash-Variante G).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Spinner 32 × 32: Ring (Strich 3,5, Weiß 22 %) + weißer Viertelbogen mit runder Kappe.
struct SplashSpinner: View {
    @State private var spinning = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.rgba(255, 255, 255, 0.22), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 26, height: 26)                        // r 13 (Strich mittig auf dem Kreis wie im SVG)
        .frame(width: 32, height: 32)
        .rotationEffect(.degrees(spinning ? 360 : 0))
        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spinning)
        .onAppear { spinning = true }
        .accessibilityHidden(true)
    }
}

#Preview("Spinner") { SplashSpinner().padding().background(Color.black) }
