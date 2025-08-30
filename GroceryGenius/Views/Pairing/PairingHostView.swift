// PairingHostView.swift
// Extracted from original SessionGateView.swift
import SwiftUI

struct PairingHostView: View {
    let publicId: PublicUserId
    @Binding var pendingInviteCode: String?
    @StateObject private var vm: PairingViewModel
    private let trailingMenu: AnyView?

    // Production initializer (no debug-only params)
    init(publicId: PublicUserId, pendingInviteCode: Binding<String?>, @ViewBuilder trailingMenu: () -> some View = { EmptyView() }) {
        self.publicId = publicId
        self._pendingInviteCode = pendingInviteCode
        _vm = StateObject(wrappedValue: PairingViewModel(myId: publicId, pairingRepo: FirebasePairingRepository()))
        let view = trailingMenu()
        self.trailingMenu = (view is EmptyView) ? nil : AnyView(view)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let headerHeight: CGFloat = proxy.size.height * DS.Layout.headerHeightRatio
                let contentOffsetBelowHeader: CGFloat = headerHeight * 0.75
                ZStack(alignment: .top) {
                    Color.theme.background.ignoresSafeArea()
                    AccentHeader(title: String(localized: "pairing.title"), style: .plain)
                        .frame(height: headerHeight)
                        .zIndex(0)
                    VStack(spacing: 0) {
                        Spacer().frame(height: contentOffsetBelowHeader)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                GroupBox {
                                    HStack { Text(publicId.value).font(.callout).textSelection(.enabled); Spacer() }
                                } label: { Text("pairing.myPublicId", tableName: "Localizable") }
                                .padding(.horizontal)
                                GroupBox {
                                    HStack {
                                        Text(vm.inviteCode.isEmpty ? "—" : vm.inviteCode).font(.title2.monospaced())
                                        Spacer()
                                        Button(action: { Task { await vm.generateInvite() } }) { Text("pairing.generate", tableName: "Localizable") }
                                    }
                                    if !vm.inviteCode.isEmpty {
                                        let link = "gg://pair/\(vm.inviteCode)"
                                        QRCodeView(text: link).frame(width: 160, height: 160)
                                        HStack {
                                            // Repurpose Copy to Share invite code directly
                                            ShareLink(item: vm.inviteCode) { Text("pairing.copyCode", tableName: "Localizable") }
                                            // Share link preference: URL if valid, else fallback to code string
                                            if let url = URL(string: link) {
                                                ShareLink(item: url) { Text("pairing.shareLink", tableName: "Localizable") }
                                            } else {
                                                ShareLink(item: vm.inviteCode) { Text("pairing.shareLink", tableName: "Localizable") }
                                            }
                                        }
                                    }
                                } label: { Text("pairing.invitePartner", tableName: "Localizable") }
                                .padding(.horizontal)
                                GroupBox {
                                    AcceptInviteView(pendingInviteCode: $pendingInviteCode) { code in Task { await vm.acceptInvite(code: code) } }
                                } label: { Text("pairing.acceptInvite", tableName: "Localizable") }
                                .padding(.horizontal)
                                ApprovalsListView(vm: vm)
                                    .padding(.horizontal)
                                PartnersListView(partners: vm.partners)
                                    .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                    }
                    .zIndex(1)
                }
            }
            .toolbar {
                if let trailingMenu { ToolbarItem(placement: .navigationBarTrailing) { trailingMenu } }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onChange(of: pendingInviteCode) { _, new in
            if let code = new, !code.isEmpty { Task { await vm.acceptInvite(code: code) }; pendingInviteCode = nil }
        }
        .alert(item: Binding(get: { vm.errorMessage.map { IdentifiedAlert(message: $0) } }, set: { _ in vm.errorMessage = nil })) { ia in
            Alert(title: Text("Error"), message: Text(ia.message), dismissButton: .default(Text("OK")))
        }
    }
}

#if DEBUG
extension PairingHostView {
    // Debug-only initializer to inject a mock view model factory for previews
    init(publicId: PublicUserId, pendingInviteCode: Binding<String?>, @ViewBuilder trailingMenu: () -> some View = { EmptyView() }, viewModelFactory: @escaping () -> PairingViewModel) {
        self.publicId = publicId
        self._pendingInviteCode = pendingInviteCode
        _vm = StateObject(wrappedValue: viewModelFactory())
        let view = trailingMenu()
        self.trailingMenu = (view is EmptyView) ? nil : AnyView(view)
    }
}

#Preview("Pairing") {
    PairingHostView(
        publicId: PreviewData.publicId,
        pendingInviteCode: .constant(nil),
        viewModelFactory: { PairingViewModel(myId: PreviewData.publicId, pairingRepo: PreviewPairingRepository()) }
    )
}
#endif
