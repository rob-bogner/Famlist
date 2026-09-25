/*
 SplashView.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vollbild-Splash beim Wiederherstellen der Sitzung.

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

/// Vollbild-Splash: Launch-Bild unverändert + Spinner.
struct SplashView: View {
    /// Natürliche Größe des Launch-Bilds (größtes iPhone, 440 × 956 pt); kleinere Geräte schneiden mittig zu.
    static let imageSize = CGSize(width: 440, height: 956)
    /// Spinner-Mitte relativ zur Bildschirmmitte (Design 390 × 844: Unterkante 72 → Mitte 334 pt unter der Mitte).
    static let spinnerOffset: CGFloat = 334

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color("LaunchBackground")
                Image("LaunchSplash")                               // nicht resizable → natürliche Größe wie im Launch Screen
                    .frame(width: Self.imageSize.width, height: Self.imageSize.height)
                    .position(x: size.width / 2, y: size.height / 2)
                SplashSpinner()
                    .position(x: size.width / 2,
                              y: min(size.height / 2 + Self.spinnerOffset, size.height - 88))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
    }
}

#Preview("Splash") { SplashView() }
#Preview("Splash – Dark") { SplashView().preferredColorScheme(.dark) }
