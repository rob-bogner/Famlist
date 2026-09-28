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
 - ✕ reagiert auf der ganzen Glasfläche (vorher nur auf den Strichen); optional Pille „Ecken anpassen“.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptFullscreenViewer: View {
    let images: [UIImage?]
    @Binding var page: Int
    var onClose: () -> Void = {}
    /// Nur im Kamerabildschirm: Pille „Ecken anpassen“ unten (öffnet den Ecken-Editor für `page`).
    var onAdjustCorners: ((Int) -> Void)? = nil

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
            if let onAdjustCorners {
                adjustButton { onAdjustCorners(page) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
            }
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
                .background(GlassCircleBackground(style: .neutralDark, appearance: .dark, accent: AccentScale(Appearance.dark.defaultAccent, .dark), size: 44))   // Glas neutral dunkel (Token gnd)
                // Der Glas-Hintergrund nimmt keine Berührungen an; ohne Tippfläche reagierten nur die Striche des ✕.
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Schließen")
        .accessibilityIdentifier("receiptFullscreenClose")
        .padding(.trailing, 20)
        .padding(.top, 8)
    }

    /// „Ecken anpassen“: Glas-Pille neutral dunkel, 44 hoch, mittig, 100 über dem Bildschirmrand – über den
    /// Seitenpunkten (ReceiptFullscreenCrop.dc.html).
    private func adjustButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Ecken anpassen")
                .font(AppFont.dm(15, 600))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 20)
                .frame(height: 44)
                .background(GlassPillBackground(style: .neutralDark, appearance: .dark,
                                                accent: AccentScale(Appearance.dark.defaultAccent, .dark), height: 44))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 100)
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
