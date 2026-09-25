/*
 ClipboardImportSheet.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Import aus Zwischenablage“ im Hybrid-Stil (Höhe 790): erkannte Artikel mit Auswahl,
   übersprungene Zeilen, Knopf „n Artikel übernehmen“. Ersetzt ClipboardImportView (Systemsheet).

 🔰 Notes for Beginners:
 - Das Design-Paket hat keinen eigenen Import-Screen. Freigegeben ist der Umbau auf die Hybrid-Bausteine
   (design-handoff/PLAN.md §9, F4): HybridSheetLayer, EKKSectionLabel, Karten wie Eingabefelder, CTAButton.
 - Der Knopf sitzt wie bei „Artikel bearbeiten“ fest unten; die Liste scrollt darüber.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ClipboardImportSheet: View {
    @EnvironmentObject private var listViewModel: ListViewModel
    @StateObject private var viewModel: ClipboardImportViewModel
    let k: SheetTheme
    let maxHeight: CGFloat
    let onClose: () -> Void

    private let bottomInset: CGFloat = 34

    /// `viewModel` nur für Vorschauen und Tests; sonst liest das Sheet die echte Zwischenablage.
    @MainActor
    init(viewModel: ClipboardImportViewModel? = nil, k: SheetTheme, maxHeight: CGFloat,
         onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel ?? ClipboardImportViewModel())
        self.k = k
        self.maxHeight = maxHeight
        self.onClose = onClose
    }

    var body: some View {
        HybridSheetLayer(k: k, title: String(localized: "import.title"), designHeight: 790,
                         maxHeight: maxHeight, onClose: onClose) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    Group {
                        if let result = viewModel.result {
                            preview(result)
                        } else {
                            emptyState
                        }
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 56 + bottomInset + 20)
                }
                .scrollIndicators(.hidden)

                cta
                    .padding(.horizontal, 20)
                    .padding(.bottom, bottomInset)
            }
        }
        .onAppear(perform: viewModel.load)
    }

    // MARK: - Inhalt

    private func preview(_ result: ClipboardImportParser.ParseResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                EKKSectionLabel(text: "\(String(localized: "import.items.count")) · \(result.items.count)", k: k)
                Button(action: viewModel.toggleAll) {
                    Text(String(localized: viewModel.allSelected ? "import.button.deselectAll" : "import.button.selectAll"))
                        .font(AppFont.dm(13, 600))
                        .foregroundStyle(k.accentText)
                        .fixedSize()
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if let store = result.storeName {
                Text(store)
                    .font(AppFont.dm(14, 500))
                    .foregroundStyle(k.sub)
                    .padding(.horizontal, 4)
            }
            ForEach(Array(result.items.enumerated()), id: \.offset) { index, item in
                ClipboardImportRow(k: k, item: item, isSelected: viewModel.selected.contains(index)) {
                    viewModel.toggle(index)
                }
            }
            if !result.skippedLines.isEmpty {
                skipped(result.skippedLines)
                    .padding(.top, 8)
            }
        }
    }

    private func skipped(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "import.skipped.title"))
                .font(AppFont.dm(13, 600))
                .foregroundStyle(k.text)
            Text(lines.joined(separator: ", "))
                .font(AppFont.dm(13, 400))
                .foregroundStyle(k.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CSSBox(shape: RR(16), paint: .color(k.chip)))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            SVGIcon(OverlayIcon.clipboard, size: 40, color: k.accentText, lineWidth: 1.6)
                .frame(width: 80, height: 80)
                .background(CSSBox(shape: RR(26), paint: .color(k.a.base.color(k.isDark ? 0.16 : 0.1))))
                .accessibilityHidden(true)
                .padding(.top, 40)
            Text(viewModel.errorMessage ?? String(localized: "import.empty.title"))
                .font(AppFont.outfit(20, 600))
                .foregroundStyle(k.text)
                .multilineTextAlignment(.center)
            Text(String(localized: "import.empty.message"))
                .font(AppFont.dm(14, 400))
                .foregroundStyle(k.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var cta: some View {
        if viewModel.result == nil {
            CTAButton(title: String(localized: "import.button.reload"), k: k, action: viewModel.load)
        } else {
            let count = viewModel.selected.count
            CTAButton(title: count == 1 ? "1 Artikel übernehmen" : "\(count) Artikel übernehmen",
                      k: k, isEnabled: count > 0) {
                viewModel.importSelected(into: listViewModel)
                onClose()
            }
        }
    }
}

/// Zeile: Karte wie ein Eingabefeld (Radius 16), Haken-Kreis 28, Name 15/500, darunter Menge · Kategorie 13.
private struct ClipboardImportRow: View {
    let k: SheetTheme
    let item: ClipboardImportParser.ParsedItem
    let isSelected: Bool
    let onToggle: () -> Void

    private var details: String {
        let amount = item.measure.isEmpty ? "\(item.units)" : "\(item.units) \(Measure.fromExternal(item.measure).localizedName)"
        return [amount, item.category].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                checkCircle
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(AppFont.dm(15, 500))
                        .foregroundStyle(k.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(details)
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
            .contentShape(RR(16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(details)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var checkCircle: some View {
        if isSelected {
            SVGIcon(Icon.check, size: 16, color: k.ctaText, lineWidth: 2.6)
                .frame(width: 28, height: 28)
                .background(CSSBox(shape: Circle(), paint: k.ctaPaint))
        } else {
            Circle()
                .strokeBorder(k.fieldBorder, lineWidth: 2)
                .frame(width: 28, height: 28)
        }
    }
}

private enum ClipboardImportPreview {
    static let text = "Milch 2 l\nEier 10 Stk\nBrot\n---\nÄpfel 1 kg"

    @MainActor
    static func sheet(_ appearance: Appearance, text: String? = ClipboardImportPreview.text) -> some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
            ClipboardImportSheet(viewModel: ClipboardImportViewModel(readClipboard: { text }),
                                 k: SheetTheme(appearance), maxHeight: 790, onClose: {})
        }
        .ignoresSafeArea()
        .environmentObject(PreviewMocks.makeListViewModelWithSamples())
    }
}

#Preview("Import") { ClipboardImportPreview.sheet(.light) }
#Preview("Import – Dark") { ClipboardImportPreview.sheet(.dark) }
#Preview("Import leer") { ClipboardImportPreview.sheet(.light, text: nil) }
#Preview("Import leer – Dark") { ClipboardImportPreview.sheet(.dark, text: nil) }
