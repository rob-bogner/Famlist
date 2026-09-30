/*
 PhotoSuggestionBanner.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hinweis „Erkannt: Orangen · Obst & Gemüse · aus dem Foto“ mit „Übernehmen“ (Design: PhotoCutoutDone).

 🔰 Notes for Beginners:
 - Fläche field, Rand 1 fieldBorder, Radius 18, Innenabstand 10 / 10 / 12; Kachel 34 (Radius 11, Akzent-Tönung)
   mit Funken; rechts Glas-Pille 34 „Übernehmen“.

 📝 Last Change:
 - Initial creation (Wunsch Robert 30.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct PhotoSuggestionBanner: View {
    let k: SheetTheme
    let suggestion: ProductPhotoSuggestion
    let onApply: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SVGIcon(ProductDetailIcon.sparkle, size: 18, color: k.accentText, lineWidth: 1.9)
                .frame(width: 34, height: 34)
                .background(RR(11).fill(k.a.base.color(k.isDark ? 0.16 : 0.08)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Erkannt: \(suggestion.name)")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(k.text)
                    .lineLimit(1)
                Text("\(suggestion.category) · aus dem Foto")
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(k.sub)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onApply) {
                Text("Übernehmen")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(GlassPillBackground(style: .accent, appearance: k.appearance, accent: k.a, height: 34))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Setzt Name und Kategorie")
        }
        .padding(.vertical, 10)
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .background(CSSBox(shape: RR(18), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
        .accessibilityElement(children: .combine)
    }
}
