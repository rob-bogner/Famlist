/*
 ActionCardButtonView.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein Knopf der Aktionskarte: CTA (56), rote Glas-Pille (56) oder neutrale Glas-Pille (52).

 🔰 Notes for Beginners:
 - `.primary` nutzt CTAButton unverändert. `.destructive` = GlassPillBackground(.danger), Text weiß 16/600.
 - `.secondary` / `.cancel` = GlassPillBackground(.neutral), Text 15/600 (Standard: Textfarbe der Karte).
 - Symbole links vom Text: 19 (rot) bzw. 18 (neutral), Strich 2.

 📝 Last Change:
 - Initial creation (Designsprache statt Systemdialoge).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// One button of an action card.
struct ActionCardButtonView: View {
    let button: ActionCardButton
    let k: SheetTheme
    let tokens: ActionCardTokens
    let tap: () -> Void

    var body: some View {
        switch button.role {
        case .primary:
            CTAButton(title: button.title, k: k, isEnabled: button.isEnabled, icon: button.icon, action: tap)
        case .slide:
            SlideToConfirm(title: button.title, k: k, action: tap)
        case .destructive:
            pill(height: 56, style: .danger, color: .white, fontSize: 16, iconSize: 19)
        case .secondary, .cancel:
            pill(height: 52, style: .neutral, color: button.tint ?? tokens.text, fontSize: 15, iconSize: 18)
        }
    }

    private func pill(height: CGFloat, style: GlassOrb.Style, color: Color, fontSize: CGFloat,
                      iconSize: CGFloat) -> some View {
        Button(action: tap) {
            HStack(spacing: 8) {
                if let icon = button.icon {
                    SVGIcon(icon, size: iconSize, color: color, lineWidth: 2)
                        .accessibilityHidden(true)
                }
                Text(button.title)
                    .font(AppFont.dm(fontSize, 600))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(GlassPillBackground(style: style, appearance: k.appearance, accent: k.a, height: height))
            .contentShape(Pill)
        }
        .buttonStyle(.plain)
        .disabled(!button.isEnabled)
        .opacity(button.isEnabled ? 1 : 0.45)
    }
}
