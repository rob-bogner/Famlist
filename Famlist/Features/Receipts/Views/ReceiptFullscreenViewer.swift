/*
 ReceiptFullscreenViewer.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vollbild eines Bon-Fotos mit Zoom (KASSENZETTEL_ARCHIV.md: „Vollbild mit Zoom“).

 🔰 Notes for Beginners:
 - Nicht gestaltet: schwarzer Hintergrund, Foto eingepasst, Aufziehen mit zwei Fingern (1–5-fach),
   Doppeltippen wechselt zwischen 1- und 2,5-fach, Verschieben im Zoom. Schließen: ✕ oben rechts in den
   Farben des Vollbild-Knopfs (rgba(0,0,0,.55), weiß). Siehe PLAN §9.
 - Wischen blättert durch die Fotos, solange nicht gezoomt ist.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptFullscreenViewer: View {
    let images: [UIImage?]
    @Binding var page: Int
    var onClose: () -> Void = {}

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(images.indices, id: \.self) { index in
                    zoomable(images[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            .ignoresSafeArea()
            closeButton
        }
        .onChange(of: page) { _, _ in resetZoom() }
        .accessibilityAction(.escape, onClose)
    }

    @ViewBuilder
    private func zoomable(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnify.simultaneously(with: scale > 1 ? pan : nil))
                .onTapGesture(count: 2) { withAnimation(.easeOut(duration: 0.2)) { toggleZoom() } }
                .accessibilityLabel("Foto des Kassenzettels")
                .accessibilityAddTraits(.isImage)
        } else {
            ProgressView().tint(.white)
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in scale = min(max(lastScale * value.magnification, 1), 5) }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 { withAnimation(.easeOut(duration: 0.2)) { resetZoom() } }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            SVGIcon(Icon.close, size: 18, color: .white, lineWidth: 2.2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.rgba(0, 0, 0, 0.55)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Schließen")
        .padding(.trailing, 20)
        .padding(.top, 8)
    }

    private func toggleZoom() {
        if scale > 1 { resetZoom() } else { scale = 2.5; lastScale = 2.5 }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}

#Preview {
    @Previewable @State var page = 0
    ReceiptFullscreenViewer(images: [ReceiptSampleBon.image(), ReceiptSampleBon.image()], page: $page)
}

#Preview("Dark") {
    @Previewable @State var page = 0
    ReceiptFullscreenViewer(images: [ReceiptSampleBon.image()], page: $page)
        .preferredColorScheme(.dark)
}
