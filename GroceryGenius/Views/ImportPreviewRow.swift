// filepath: GroceryGenius/Views/ImportPreviewRow.swift
// MARK: - ImportPreviewRow.swift

import SwiftUI

struct ImportPreviewRow: View {
    var item: ImportPreviewView.ImportCandidate
    var toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundColor(item.isSelected ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body)
                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let qty = item.qty {
                    Text(qty.asLocalizedString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let unit = item.unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private extension Double {
    var asLocalizedString: String {
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 3
        return nf.string(from: NSNumber(value: self)) ?? String(self)
    }
}

#Preview {
    ImportPreviewRow(
        item: .init(title: "Champignons", note: "in Scheiben", qty: 200, unit: "g", category: "Obst & Gemüse", isSelected: true),
        toggle: {}
    )
}
