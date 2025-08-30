// ApprovalsListView.swift
// Extracted from original SessionGateView.swift
import SwiftUI

struct ApprovalsListView: View {
    @ObservedObject var vm: PairingViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("pairing.requests", tableName: "Localizable").font(.headline)
            ForEach(vm.incoming, id: \.id) { req in
                HStack {
                    HStack(spacing: 4) {
                        Text("pairing.from", tableName: "Localizable").font(.subheadline)
                        Text(req.from.value).font(.subheadline).lineLimit(1)
                    }
                    Spacer()
                    if req.status == .pending {
                        Button(action: { Task { await vm.approve(req) } }) { Text("pairing.approve", tableName: "Localizable") }
                        Button(action: { Task { await vm.deny(req) } }) { Text("pairing.deny", tableName: "Localizable") }
                            .foregroundColor(.red)
                    } else {
                        Text(req.status.rawValue.capitalized).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Approvals") {
    let repo = PreviewPairingRepository(partners: PreviewData.partners)
    repo.incoming = [
        PairingRequest(id: UUID().uuidString, from: PublicUserId("genius-111"), toCode: "PREV-1234", status: .pending, createdAt: Date()),
        PairingRequest(id: UUID().uuidString, from: PublicUserId("genius-222"), toCode: "PREV-5678", status: .approved, createdAt: Date().addingTimeInterval(-3600))
    ]
    let vm = PairingViewModel(myId: PreviewData.publicId, pairingRepo: repo)
    return ApprovalsListView(vm: vm).padding()
}
#endif
