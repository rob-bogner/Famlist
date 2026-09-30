/*
 CutoutFixView.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Nachbessern“ (Design: PhotoCutoutFix): Foto mit dem gewählten Motiv (Akzent-Rand), Antippen fügt ein
   weiteres Motiv hinzu bzw. nimmt es weg. „Zurücksetzen“ und „Fertig“.

 🔰 Notes for Beginners:
 - Liegt als eigene Ebene über dem Produktdetails-Sheet (Titel 22 oben 20, ✕ oben rechts).
 - Foto höchstens 350 × 296, Radius 24; Hintergrund 50 % abgedunkelt, gewähltes Motiv hell obenauf,
   dahinter ein weicher Rand in der Akzentfarbe.
 - Antippen: ProductCutout.Analysis.instance(at:) liefert das Motiv an der Stelle; Umschalter
   „Hinzufügen · Entfernen“ entscheidet, was passiert. Mindestens ein Motiv bleibt gewählt.

 📝 Last Change:
 - Initial creation (Wunsch Robert 30.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

struct CutoutFixView: View {
    let k: SheetTheme
    let analysis: ProductCutout.Analysis
    let initialSelection: IndexSet
    let onCancel: () -> Void
    let onDone: (IndexSet, UIImage?) -> Void

    @State private var selection = IndexSet()
    @State private var preview: UIImage?
    @State private var adding = true
    @State private var tapMarker: CGPoint?
    @State private var isFinishing = false

    private var photoSize: CGSize {
        let src = analysis.source.size
        guard src.width > 0, src.height > 0 else { return CGSize(width: 350, height: 296) }
        let aspect = src.height / src.width
        return aspect * 350 <= 296 ? CGSize(width: 350, height: 350 * aspect) : CGSize(width: 296 / aspect, height: 296)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nachbessern")
                        .font(AppFont.outfit(22, 600))
                        .foregroundStyle(k.text)
                        .accessibilityAddTraits(.isHeader)
                    Text("Objekte antippen: hinzufügen oder entfernen")
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(k.sub)
                }
                Spacer(minLength: 0)
                GlassCircleButton(style: .neutral, appearance: k.appearance, accent: k.a, icon: Icon.close,
                                  label: "Abbrechen", action: onCancel)
                    .padding(.top, -6)
            }
            .padding(.top, 20)

            photo
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

            Text("Tippe auf Dinge im Foto, die zum Artikel gehören. Mit „Entfernen“ tippst du weg, was nicht dazugehört.")
                .font(AppFont.dm(14, 400))
                .lineSpacing(4)
                .foregroundStyle(k.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
                .padding(.horizontal, 4)

            modeSegment.padding(.top, 16)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(action: reset) {
                    Text("Zurücksetzen")
                        .font(AppFont.dm(16, 600))
                        .foregroundStyle(k.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(GlassPillBackground(style: .neutral, appearance: k.appearance, accent: k.a, height: 56))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                CTAButton(title: "Fertig", k: k, isEnabled: !isFinishing, action: finish)
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1.4)
            }
            .padding(.bottom, 34)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            selection = initialSelection
            preview = await analysis.renderInBackground(initialSelection, cropped: false)
        }
    }

    // MARK: - Foto

    private var photo: some View {
        let size = photoSize
        return ZStack {
            Image(uiImage: analysis.source)
                .resizable()
                .frame(width: size.width, height: size.height)
            Color.black.opacity(0.5)
            if let preview {
                // weicher Akzent-Rand hinter dem Motiv
                Image(uiImage: preview)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(k.accent)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(1.035)
                    .blur(radius: 1.5)
                Image(uiImage: preview)
                    .resizable()
                    .frame(width: size.width, height: size.height)
            }
            if let tapMarker {
                Circle()
                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                    .frame(width: 64, height: 64)
                    .overlay(
                        SVGIcon(adding ? Icon.plus : [.path("M5 12h14")], size: 16, color: .white, lineWidth: 2.8)
                            .frame(width: 34, height: 34)
                            .background(GlassCircleBackground(style: .accent, appearance: k.appearance, accent: k.a, size: 34))
                    )
                    .position(tapMarker)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RR(24))
        .contentShape(RR(24))
        .onTapGesture(coordinateSpace: .local) { location in tap(at: location, in: size) }
        .accessibilityElement()
        .accessibilityLabel("Foto mit ausgewähltem Artikel")
        .accessibilityHint("Antippen, um Objekte hinzuzufügen oder zu entfernen")
    }

    private var modeSegment: some View {
        HStack(spacing: 4) {
            segment("Hinzufügen", icon: Icon.plus, isOn: adding) { adding = true }
            segment("Entfernen", icon: [.path("M5 12h14")], isOn: !adding) { adding = false }
        }
        .padding(4)
        .background(RR(16).fill(k.isDark ? Color.rgba(255, 255, 255, 0.06) : .hex("#F1F5F5")))
    }

    private func segment(_ title: String, icon: [SVGElement], isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.18)) { action() } }) {
            HStack(spacing: 8) {
                SVGIcon(icon, size: 16, color: isOn ? k.accentText : k.sub, lineWidth: 2.4)
                Text(title)
                    .font(AppFont.dm(14, isOn ? 600 : 500))
                    .foregroundStyle(isOn ? k.text : k.sub)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background {
                if isOn {
                    RR(12).fill(k.isDark ? Color.rgba(255, 255, 255, 0.14) : .white)
                        .shadow(color: .black.opacity(0.12), radius: 1.5, y: 1)
                }
            }
            .contentShape(RR(12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Aktionen

    private func tap(at location: CGPoint, in size: CGSize) {
        let point = CGPoint(x: location.x / size.width, y: location.y / size.height)
        guard let id = analysis.instance(at: point) else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        var next = selection
        if adding { next.insert(id) } else { next.remove(id) }
        guard !next.isEmpty, next != selection else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selection = next
        withAnimation(.easeOut(duration: 0.15)) { tapMarker = location }
        Task {
            let image = await analysis.renderInBackground(next, cropped: false)
            withAnimation(.easeInOut(duration: 0.2)) { preview = image }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.25)) { tapMarker = nil }
        }
    }

    private func reset() {
        selection = analysis.primary
        Task {
            let image = await analysis.renderInBackground(analysis.primary, cropped: false)
            withAnimation(.easeInOut(duration: 0.2)) { preview = image }
        }
    }

    private func finish() {
        isFinishing = true
        let chosen = selection
        Task {
            let image = await analysis.renderInBackground(chosen, cropped: true)
            onDone(chosen, image)
        }
    }
}
