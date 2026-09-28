/*
 ReceiptLiveHint.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hinweis unten im Sucher: ohne erkannten Bon als Text (wie bisher), mit erkanntem Bon als Pille
   mit Akzent-Punkt, damit er auf dem Kamerabild lesbar bleibt.

 🔰 Notes for Beginners:
 - Vorlage: ReceiptCapture.dc.html (Text: links/rechts 32, unten 30, DM Sans 13/400, Weiß 80 %, Zeilenhöhe 1,4)
   und ReceiptCaptureLive.dc.html (Pille: Schwarz 50 %, Radius 16, Padding 7/14/7/12, Punkt 8, Abstand 8,
   DM Sans 13/600, Weiß 90 %, unten 24). Der Text steht in beiden Zuständen auf gleicher Höhe.

 📝 Last Change:
 - Initial creation (Kassenzettel wie ein Dokumentenscanner).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptLiveHint: View {
    let text: String
    let detected: Bool
    var accent: Color

    var body: some View {
        Group {
            if detected {
                HStack(spacing: 8) {
                    Circle().fill(accent).frame(width: 8, height: 8)
                    Text(text)
                        .font(AppFont.dm(13, 600))
                        .foregroundStyle(Color.rgba(255, 255, 255, 0.9))
                        .cssLineHeight(18.2, font: AppFont.ui(.dmSans, 13, 600))
                }
                .padding(.vertical, 7)
                .padding(.leading, 12)
                .padding(.trailing, 14)
                .background(RR(16).fill(Color.rgba(0, 0, 0, 0.5)))
                .padding(.bottom, 24)
            } else {
                Text(text)
                    .font(AppFont.dm(13, 400))
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.8))
                    .multilineTextAlignment(.center)
                    .cssLineHeight(18.2, font: AppFont.ui(.dmSans, 13, 400))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 30)
            }
        }
        .animation(.easeOut(duration: 0.2), value: detected)
    }
}

#Preview("Hinweis", traits: .fixedLayout(width: 350, height: 160)) {
    VStack(spacing: 0) {
        ReceiptLiveHint(text: "Ganzen Bon ins Bild · bei langen Bons in mehreren Teilen", detected: false, accent: .white)
        ReceiptLiveHint(text: "Bon erkannt · ruhig halten", detected: true,
                        accent: AccentScale(Appearance.dark.defaultAccent, .dark).light.color())
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.hex("#121A1B"))
}

#Preview("Hinweis – Dark", traits: .fixedLayout(width: 350, height: 100)) {
    ReceiptLiveHint(text: "Bon erkannt · Auslöser tippen", detected: true,
                    accent: AccentScale(Appearance.dark.defaultAccent, .dark).light.color())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.hex("#121A1B"))
        .preferredColorScheme(.dark)
}
