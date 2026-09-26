/*
 WatchDoneScreen.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Alles erledigt (WatchDone.dc.html): voller Ring im 96er-Feld (r 42, Strich 9, Verlauf light → accent diagonal),
   Haken weiß (Strich 6), „Alles erledigt“ Outfit 19/600, „6 Artikel · My List“ DM 12 weiß .6,
   unten Glas-Knopf „Zurücksetzen“ (40 hoch, Radius 20, DM 14/600).

 🔰 Notes for Beginners:
 - Inhalt: top 36, bottom 10, links/rechts 12, Abstand 6; der Knopf sitzt ganz unten (margin-top: auto).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchDoneScreen: View {
    var w = WatchTheme()
    let count: Int
    let listName: String
    var onReset: () -> Void = {}

    var body: some View {
        VStack(spacing: 6) {
            ring
            Text("Alles erledigt").font(WatchFont.outfit(19)).foregroundStyle(w.text)
                .watchLineBox(WatchFont.outfitLineHeight(19))
                .padding(.top, 2)
            Text("\(count) Artikel · \(listName)").font(WatchFont.dm(12)).foregroundStyle(w.sub)
                .watchLineBox(WatchFont.dmLineHeight(12))
            Spacer(minLength: 0)
            resetButton
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .watchScreen(listName, contentTop: 36, w: w)
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: 9)
            Circle().stroke(LinearGradient(colors: [w.accentText, w.accent.color()],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round))
            SVGIcon(WatchIcon.doneCheck, size: 96, color: .white, lineWidth: WatchIcon.doneCheckLineWidth)
                .padding(-6)
        }
        .padding(6)                                   // SVG: r 42 in 96 → Kreis-Mittellinie 6 pt vom Rand
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)
    }

    private var resetButton: some View {
        Button(action: onReset) {
            Text("Zurücksetzen").font(WatchFont.dm(14, 600)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(CSSBox(shape: Capsule(), paint: w.glassButton, border: 1, borderColor: w.glassBorder))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Hebt alle Haken der Liste auf")
    }
}

#Preview("Erledigt") {
    NavigationStack {
        WatchDoneScreen(count: 6, listName: "My List")
    }
}
