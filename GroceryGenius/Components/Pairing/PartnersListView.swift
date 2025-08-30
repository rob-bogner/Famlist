// PartnersListView.swift
// Extracted from original SessionGateView.swift
import SwiftUI

struct PartnersListView: View {
    let partners: [PublicUserId]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("pairing.partners", tableName: "Localizable").font(.headline)
            if partners.isEmpty {
                Text("pairing.noPartners", tableName: "Localizable").foregroundStyle(.secondary)
            } else {
                ForEach(partners, id: \.self) { p in HStack { Text(p.value); Spacer() } }
            }
        }
    }
}

#if DEBUG
#Preview("Partners – empty") { PartnersListView(partners: []).padding() }
#Preview("Partners – with data") { PartnersListView(partners: PreviewData.partners).padding() }
#endif
