/*
 ReceiptPagePreviewCover.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vollbild der Aufnahmen im Kamerabildschirm (Tippen auf ein Vorschaubild) mit Weg zu „Ecken anpassen“.

 🔰 Notes for Beginners:
 - Beide Ansichten liegen in EINEM Vollbild-Cover und wechseln sich ab: Vollbild → „Ecken anpassen“ →
   zurück zum Vollbild mit dem neuen Zuschnitt. So gibt es kein Stapeln mehrerer Cover.
 - ✕ im Vollbild schließt alles; ✕ in „Ecken anpassen“ führt ohne Änderung zurück zum Vollbild.

 📝 Last Change:
 - Initial creation (Kassenzettel wie ein Dokumentenscanner).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptPagePreviewCover: View {
    @ObservedObject var flow: ReceiptFlowViewModel
    @Binding var page: Int
    var onClose: () -> Void = {}

    /// Aufnahme, deren Ecken gerade angepasst werden; nil = Vollbild.
    @State private var editing: UUID?

    var body: some View {
        if let id = editing, let index = flow.scans.firstIndex(where: { $0.id == id }) {
            ReceiptCropEditView(page: flow.scans[index], number: index + 1,
                                onCancel: { editing = nil },
                                onApply: { quad in
                                    editing = nil
                                    Task { await flow.adjustCorners(of: id, to: quad) }
                                })
                .id(id)
        } else {
            ReceiptFullscreenViewer(images: flow.pages.map { Optional($0) }, page: $page, onClose: onClose,
                                    onAdjustCorners: { index in
                                        guard flow.scans.indices.contains(index) else { return }
                                        editing = flow.scans[index].id
                                    })
        }
    }
}

#Preview("Vorschau") {
    @Previewable @State var page = 0
    let flow = ReceiptFlowViewModel(listItemNames: [], catalog: nil, priceBook: PriceBook(repository: nil))
    ReceiptPagePreviewCover(flow: flow, page: $page)
        .onAppear { flow.cropPage = { .init(quad: nil, image: $0) }; flow.addPage(ReceiptSampleBon.image()) }
}

#Preview("Vorschau – Dark") {
    @Previewable @State var page = 0
    let flow = ReceiptFlowViewModel(listItemNames: [], catalog: nil, priceBook: PriceBook(repository: nil))
    ReceiptPagePreviewCover(flow: flow, page: $page)
        .onAppear { flow.cropPage = { .init(quad: nil, image: $0) }; flow.addPage(ReceiptSampleBon.image()) }
        .preferredColorScheme(.dark)
}
