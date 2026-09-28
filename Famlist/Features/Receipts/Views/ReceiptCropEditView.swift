/*
 ReceiptCropEditView.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vollbild „Ecken anpassen“ für eine Aufnahme: Originalfoto mit vier Griffen,
   „Ganzes Foto“ (Zuschnitt verwerfen) und „Übernehmen“.

 🔰 Notes for Beginners:
 - Vorlage: ReceiptCropEdit.dc.html (von Robert freigegeben 28.09.2026). Immer dunkel wie die Kamera.
   Bei 844 pt: Leiste 62, Fotofläche 126…641, Hinweis 641, Knöpfe 52 hoch, 54 über dem Rand.
 - Geöffnet über das Vollbild der Aufnahme („Ecken anpassen“). ✕ bricht ohne Änderung ab.
 - Ohne erkannten Bon starten die Griffe 8 % innerhalb des Fotorands.
 - „Übernehmen“ ist gedimmt, solange das Viereck unbrauchbar ist (überkreuzt oder kleiner als 8 % des Fotos).

 📝 Last Change:
 - Initial creation (Kassenzettel wie ein Dokumentenscanner).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptCropEditView: View {
    let page: ReceiptPage
    let number: Int
    var onCancel: () -> Void = {}
    /// Neue Ecken; nil = „Ganzes Foto“.
    var onApply: (ReceiptQuad?) -> Void = { _ in }

    @State private var quad: ReceiptQuad

    /// Immer dunkel → Akzent aus dem dunklen Theme (wie ReceiptCaptureView).
    private let k = SheetTheme(.dark)

    init(page: ReceiptPage, number: Int, onCancel: @escaping () -> Void = {},
         onApply: @escaping (ReceiptQuad?) -> Void = { _ in }) {
        self.page = page
        self.number = number
        self.onCancel = onCancel
        self.onApply = onApply
        _quad = State(initialValue: page.quad ?? .inset(by: 0.08))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 62)
            ReceiptCropCanvas(image: page.original, quad: $quad, accent: k.a.light.color())
                .padding(.top, 16)
                .layoutPriority(1)
            Text("Griffe auf die Ecken des Bons ziehen")
                .font(AppFont.dm(13, 400))
                .foregroundStyle(Color.rgba(255, 255, 255, 0.8))
                .cssLineHeight(18.2, font: AppFont.ui(.dmSans, 13, 400))
                .padding(.horizontal, 32)
                .padding(.bottom, 79)
            buttons
                .padding(.bottom, 54)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hex("#0A0F10"))
        .ignoresSafeArea()
        .accessibilityAction(.escape, onCancel)
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            Button(action: onCancel) {
                SVGIcon(Icon.close, size: 20, color: .white, lineWidth: 2.2)
                    .frame(width: 48, height: 48)
                    .background(GlassCircleBackground(style: .neutralDark, appearance: .dark, accent: k.a, size: 48))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Abbrechen")
            Spacer(minLength: 0)
            Text("Ecken anpassen · Teil \(number)")
                .font(AppFont.dm(14, 600))
                .foregroundStyle(Color.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(RR(18).fill(Color.rgba(0, 0, 0, 0.35)))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Color.clear.frame(width: 48, height: 48)
        }
        .padding(.horizontal, 20)
    }

    private var buttons: some View {
        HStack(spacing: 0) {
            Button { onApply(nil) } label: {
                Text("Ganzes Foto")
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(GlassPillBackground(style: .neutralDark, appearance: .dark, accent: k.a, height: 52))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ganzes Foto verwenden")
            Spacer(minLength: 0)
            applyButton
        }
        .padding(.horizontal, 20)
    }

    /// „Übernehmen“ im Stil der „Prüfen“-Pille (Akzent, Glanz oben, Schein unten).
    private var applyButton: some View {
        let enabled = quad.isPlausible
        return Button { onApply(quad) } label: {
            Text("Übernehmen")
                .font(AppFont.dm(15, 600))
                .foregroundStyle(k.ctaText)
                .padding(.horizontal, 24)
                .frame(height: 52)
                .background {
                    PillGlassReflection(topInset: 11, topOffset: 2, topHeight: 18, topOpacity: 0.4,
                                        glowInset: 22, glowOffset: 2, glowHeight: 6,
                                        glowOpacity: 0.14, glowBlur: 2.5)
                }
                .clipShape(Capsule())
                .background(CSSBox(shape: Capsule(), paint: k.ctaPaint,
                                   shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.5)),
                                             .drop(0, 10, 22, -10, k.a.base.color(0.8))]))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel("Zuschnitt übernehmen")
    }
}

#Preview("Ecken anpassen", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptCropEditView(page: ReceiptPage(original: ReceiptSampleBon.image()), number: 1)
}

#Preview("Ecken anpassen – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptCropEditView(page: ReceiptPage(original: ReceiptSampleBon.image()), number: 2)
        .preferredColorScheme(.dark)
}
