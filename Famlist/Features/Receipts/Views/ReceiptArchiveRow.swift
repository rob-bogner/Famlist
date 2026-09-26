/*
 ReceiptArchiveRow.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zeile im Kassenzettel-Archiv (ReceiptArchive.dc.html): Mini-Bon, Laden, Datum · Liste, Positionen,
   rechts Summe und Avatar-Initiale der Person, die gescannt hat.

 🔰 Notes for Beginners:
 - Maße: min. 86 hoch, Padding 12/14, Abstand 14; Folgezeilen haben oben eine Trennlinie k.line (1 pt).
 - Laden Outfit 17/600, Unterzeilen DM Sans 12 sub (Abstand 3), Summe Outfit 16/600, Avatar 22 rund 11/700.
 - Das Vorschaubild lädt die Zeile selbst (ReceiptArchive.image, 184 px lange Kante = 62 pt × 3 Retina).

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptArchiveRow: View {
    let receipt: ArchivedReceipt
    let t: ListAccountTokens
    let archive: ReceiptArchive
    var hasTopLine = false
    var onOpen: () -> Void = {}

    @State private var thumbnail: UIImage?

    var body: some View {
        let k = t.k
        Button(action: onOpen) {
            HStack(spacing: 14) {
                ReceiptMiniBon(k: k, image: thumbnail, count: receipt.photoPaths.count)
                texts(k: k)
                trailing(k: k)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(minHeight: hasTopLine ? 85 : 86)
            .padding(.top, hasTopLine ? 1 : 0)
            .overlay(alignment: .top) {
                if hasTopLine { Rectangle().fill(t.line).frame(height: 1) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ReceiptArchiveViewModel.accessibilityLabel(receipt))
        .task(id: receipt.photoPaths.first) {
            guard let path = receipt.photoPaths.first else { return }
            thumbnail = await archive.image(path: path, maxPixel: 184)
        }
    }

    private func texts(k: SheetTheme) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(receipt.storeName)
                .font(AppFont.outfit(17, 600))
                .foregroundStyle(k.text)
                .lineLimit(1)
            Text(ReceiptArchiveViewModel.dateAndList(receipt))
                .font(AppFont.dm(12, 400))
                .foregroundStyle(k.sub)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(ReceiptArchiveViewModel.positions(receipt))
                .font(AppFont.dm(12, 400))
                .foregroundStyle(k.sub)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trailing(k: SheetTheme) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(ReceiptArchiveViewModel.euro(receipt.total))
                .font(AppFont.outfit(16, 600))
                .foregroundStyle(k.text)
                .fixedSize()
            Text(receipt.creatorInitial)
                .font(AppFont.dm(11, 700))
                .foregroundStyle(Color.white)
                .frame(width: 22, height: 22)
                .background(CSSBox(shape: Circle(), paint: t.avatar))
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    let archive = ReceiptArchive(repository: nil)
    let t = ListAccountTokens(.light)
    VStack(spacing: 0) {
        ReceiptArchiveRow(receipt: .designSamples[0], t: t, archive: archive)
        ReceiptArchiveRow(receipt: .designSamples[1], t: t, archive: archive, hasTopLine: true)
    }
    .padding(1)
    .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
    .padding(20)
}

#Preview("Dark") {
    let archive = ReceiptArchive(repository: nil)
    let t = ListAccountTokens(.dark)
    VStack(spacing: 0) {
        ReceiptArchiveRow(receipt: .designSamples[0], t: t, archive: archive)
        ReceiptArchiveRow(receipt: .designSamples[1], t: t, archive: archive, hasTopLine: true)
    }
    .padding(1)
    .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
    .padding(20)
    .background(Color.hex("#0A1416"))
}
