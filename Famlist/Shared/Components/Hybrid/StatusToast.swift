/*
 StatusToast.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Glas-Toast für Rückmeldungen auf Vollbild-Screens (Anmelden, Einladung annehmen):
   Icon links (Häkchen oder Warnung), Text rechts. Maße aus SignIn.dc.html (Höhe 60, Radius 22).

 🔰 Notes for Beginners:
 - Aus SignInView ausgelagert, damit „Einladung annehmen“ Fehler genauso zeigt.
 - Das Ein- und Ausblenden steuert der Aufrufer über `text`.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct StatusToast: View {
    let text: String
    let isError: Bool
    let appearance: Appearance

    var body: some View {
        let k = OverlayTheme(appearance)
        GlassToast(k: k, height: 60, radius: 22, leading: 10, trailing: 16) {
            SVGIcon(isError ? EKKIcon.alert : Icon.check, size: 20,
                    color: isError ? .hex("#FF8A80") : k.toastAccent, lineWidth: 2.4)
                .frame(width: 40, height: 40)
                .background(Circle().fill(isError ? Color.rgba(229, 72, 77, 0.22) : k.okBg))
            Text(text)
                .font(AppFont.dm(14, 600))
                .foregroundStyle(k.toastText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Toast", traits: .fixedLayout(width: 390, height: 160)) {
    VStack(spacing: 12) {
        StatusToast(text: "Link gesendet", isError: false, appearance: .light)
        StatusToast(text: "Diese Einladung ist abgelaufen oder wurde zurückgezogen.", isError: true, appearance: .light)
    }
    .padding(20)
}

#Preview("Toast – Dark", traits: .fixedLayout(width: 390, height: 160)) {
    VStack(spacing: 12) {
        StatusToast(text: "Link gesendet", isError: false, appearance: .dark)
        StatusToast(text: "Diese Einladung ist abgelaufen oder wurde zurückgezogen.", isError: true, appearance: .dark)
    }
    .padding(20)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
