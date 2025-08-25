// AcceptInviteView.swift
// Extracted from original SessionGateView.swift
import SwiftUI

struct AcceptInviteView: View {
    @Binding var pendingInviteCode: String?
    let onSubmit: (String) -> Void
    @State private var code: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(LocalizedStringKey("pairing.enterCode"), text: Binding(get: { pendingInviteCode ?? code }, set: { code = $0 }))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
            Button(action: { onSubmit(pendingInviteCode ?? code) }) { Text("pairing.accept", tableName: "Localizable") }
                .buttonStyle(.borderedProminent)
        }
    }
}
