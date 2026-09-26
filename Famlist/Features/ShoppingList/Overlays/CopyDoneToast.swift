/*
 CopyDoneToast.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Toast „Liste kopiert“ nach dem Kopieren (2 s), dazu zeigt das Dock „Kopiert“ mit Haken.

 🔰 Notes for Beginners:
 - Vorlage: CopyDoneScreen in design-handoff/MyListUI/Screens/OverlayScreens.swift
   (CopyDone.dc.html): links/rechts 20, unten 112, Höhe 60, padding 0 16 0 10, Radius 22.
 - Untertitel: „1 offener Artikel · bereit zum Einfügen“ (Design). Für „Alle Artikel“:
   „n Artikel · bereit zum Einfügen“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct CopyDoneToast: View {
    let k: OverlayTheme
    var count = 1
    var scope: ListClipboardFormatter.Scope = .open

    private var subtitle: String {
        switch scope {
        case .open: return count == 1 ? "1 offener Artikel · bereit zum Einfügen" : "\(count) offene Artikel · bereit zum Einfügen"
        case .all: return "\(count) Artikel · bereit zum Einfügen"
        }
    }

    var body: some View {
        GlassToast(k: k, height: 60, radius: 22, leading: 10, trailing: 16) {
            SVGIcon(Icon.check, size: 20, color: k.toastAccent, lineWidth: 2.4)
                .frame(width: 40, height: 40)
                .background(Circle().fill(k.okBg))
            VStack(alignment: .leading, spacing: 1) {
                Text("Liste kopiert")
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(k.toastText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(k.toastSub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Artboard „Zwischenablage: Kopiert“ – Toast über der Liste, Dock im Zustand „Kopiert“.
struct CopyDoneScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        return OverlayStage(appearance: appearance, accentHex: accentHex, showsScrim: false, dock: .copied) {
            CopyDoneToast(k: k)
                .overlayToastPosition(bottom: 112)
        }
    }
}

#Preview("Kopiert", traits: .fixedLayout(width: 390, height: 844)) { CopyDoneScreen(appearance: .light) }
#Preview("Kopiert – Dark", traits: .fixedLayout(width: 390, height: 844)) { CopyDoneScreen(appearance: .dark) }
