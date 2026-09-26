/*
 ReceiptPhotoPager.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Foto-Fläche im Kassenzettel-Detail (ReceiptDetail.dc.html): 452 hoch, Radius 22, field + Rahmen,
   Wischen blättert durch die Fotos; Seitenzähler, Vollbild-Knopf und Punkte.

 🔰 Notes for Beginners:
 - Foto: 250 breit, 18 vom oberen Rand, um −1,5° gedreht, Schatten 0 10 24 −10 rgba(0,0,0,.45);
   was unten über die Fläche hinausgeht, wird abgeschnitten (ganzes Foto: Vollbild).
 - Zähler „1 / 2“: links 12, oben 12, Padding 4/10, Radius 12, rgba(0,0,0,.55), weiß 12/600.
 - Vollbild: rechts 10, oben 10, 36 rund, rgba(0,0,0,.55), Icon 16 weiß.
 - Punkte: unten 12, Abstand 6; aktiv 18 × 6 Akzent, sonst 6 × 6 sub mit 50 %.
 - Bei nur einem Foto entfallen Zähler und Punkte (im Design nicht gezeigt, PLAN §9).

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptPhotoPager: View {
    let k: SheetTheme
    let images: [UIImage?]
    @Binding var page: Int
    var onFullscreen: () -> Void = {}

    var body: some View {
        ZStack {
            TabView(selection: $page) {
                ForEach(images.indices, id: \.self) { index in
                    photo(images[index], index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            overlays
        }
        .frame(height: 452)
        .frame(maxWidth: .infinity)
        .clipShape(RR(22))
        .background(CSSBox(shape: RR(22), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
    }

    private func photo(_ image: UIImage?, index: Int) -> some View {
        VStack(spacing: 0) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250)
                } else {
                    Color.hex("#F4F1EA").frame(width: 250, height: 480)
                        .overlay { ProgressView() }
                }
            }
            .background(CSSBox(shape: Rectangle(), paint: .color(.hex("#F4F1EA")),
                               shadows: [.drop(0, 10, 24, -10, .rgba(0, 0, 0, 0.45))]))
            .rotationEffect(.degrees(-1.5))
            .padding(.top, 18)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Foto des Kassenzettels, Teil \(index + 1) von \(images.count)")
        .accessibilityAddTraits(.isImage)
    }

    private var overlays: some View {
        ZStack {
            if images.count > 1 {
                Text("\(page + 1) / \(images.count)")
                    .font(AppFont.dm(12, 600))
                    .foregroundStyle(Color.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(RR(12).fill(Color.rgba(0, 0, 0, 0.55)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
                    .accessibilityHidden(true)
                dots
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 12)
            }
            Button(action: onFullscreen) {
                SVGIcon(Icon.expand, size: 16, color: .white, lineWidth: 2.2)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.rgba(0, 0, 0, 0.55)))
                    .contentShape(Circle().inset(by: -4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Vollbild")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(10)
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(images.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? k.accent : k.sub.opacity(0.5))
                    .frame(width: index == page ? 18 : 6, height: 6)
            }
        }
        .animation(.easeOut(duration: 0.2), value: page)
        .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var page = 0
    let bon = ReceiptSampleBon.image()
    ReceiptPhotoPager(k: SheetTheme(.light), images: [bon, bon], page: $page)
        .padding(20)
}

#Preview("Dark") {
    @Previewable @State var page = 0
    let bon = ReceiptSampleBon.image()
    ReceiptPhotoPager(k: SheetTheme(.dark), images: [bon, bon], page: $page)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
