/*
 SlideToConfirm.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Schieben zum Löschen“ (Canvas: Bausteine → SlideToDelete): für alle endgültigen Löschaktionen.

 🔰 Notes for Beginners:
 - Spur 56 hoch (Kapsel, Gefahr-Ton, 1-pt-Innenrand), roter Glas-Knopf 48 (4 vom Rand) mit Mülleimer,
   Text 16/600 in Gefahrfarbe mittig (44 nach rechts gerückt) mit »»».
 - Ziehen irgendwo auf der Spur bewegt den Knopf; die Spur füllt sich rot, der Text blendet aus.
   Ab 85 % löst die Aktion aus (Knopf ans Ende, Haken, Erfolgs-Haptik), sonst federt er zurück.
 - VoiceOver: ein Knopf – Doppeltippen löst aus.
 - `isWorking`: Knopf bleibt am Ende und zeigt einen Ladekreis; wird es wieder false (z. B. Fehler),
   springt der Schieber zurück, damit man es erneut versuchen kann.

 📝 Last Change:
 - Initial creation (Wunsch Robert 29.09.2026: Löschen per Schieben statt Knopf).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// Slide-to-confirm control for irreversible delete actions.
struct SlideToConfirm: View {
    let title: String
    let k: SheetTheme
    var isWorking = false
    let action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var done = false

    private static let height: CGFloat = 56
    private static let knob: CGFloat = 48
    private static let threshold: CGFloat = 0.85

    var body: some View {
        let d = ActionCardTokens(k)
        GeometryReader { geo in
            let travel = max(1, geo.size.width - Self.height)
            let p = isWorking ? 1 : progress
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(d.dangerSoft)
                    .overlay(Capsule().strokeBorder(Color.rgba(229, 72, 77, 0.22), lineWidth: 1))
                Capsule()
                    .fill(LinearGradient(stops: [stop(.hex("#FF8A80"), 0), stop(.hex("#E5484D"), 0.55), stop(.hex("#B4232A"), 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: Self.height + travel * p)
                    .opacity(p > 0 ? 0.9 : 0)
                HStack(spacing: 10) {
                    Text(title)
                        .font(AppFont.dm(16, 600))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    SVGIcon(Icon.chevronsRight, size: 22, color: d.danger, lineWidth: 2)
                        .opacity(0.55)
                }
                .foregroundStyle(d.danger)
                .padding(.leading, 44)
                .frame(maxWidth: .infinity)
                .opacity(max(0, 1 - p * 1.6))
                knobView
                    .offset(x: 4 + travel * p)
            }
            .contentShape(Capsule())
            .gesture(drag(travel: travel))
        }
        .frame(height: Self.height)
        .onChange(of: isWorking) { _, working in
            if !working && done {
                done = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { progress = 0 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint("Zum Bestätigen nach rechts schieben oder doppeltippen")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { complete() }
    }

    private var knobView: some View {
        ZStack {
            GlassCircleBackground(style: .danger, appearance: k.appearance, accent: k.a, size: Self.knob)
            if isWorking {
                ProgressView().tint(.white)
            } else {
                SVGIcon(done ? Icon.check : Icon.trash, size: 20, color: .white, lineWidth: 2.3)
                    .shadow(color: .rgba(80, 0, 0, 0.3), radius: 1, y: 1)
            }
        }
        .frame(width: Self.knob, height: Self.knob)
    }

    private func drag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !done, !isWorking else { return }
                progress = min(1, max(0, value.translation.width / travel))
            }
            .onEnded { _ in
                guard !done, !isWorking else { return }
                if progress >= Self.threshold {
                    complete()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { progress = 0 }
                }
            }
    }

    private func complete() {
        guard !done else { return }
        done = true
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { progress = 1 }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        action()
    }
}

#Preview("SlideToConfirm") {
    VStack(spacing: 16) {
        SlideToConfirm(title: "Liste löschen", k: SheetTheme(.light)) {}
        SlideToConfirm(title: "Konto löschen", k: SheetTheme(.light), isWorking: true) {}
    }
    .padding(20)
}

#Preview("SlideToConfirm – Dark") {
    VStack(spacing: 16) {
        SlideToConfirm(title: "Kassenzettel löschen", k: SheetTheme(.dark)) {}
    }
    .padding(20)
    .background(Color.black)
}
