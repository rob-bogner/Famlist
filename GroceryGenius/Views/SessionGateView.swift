// MARK: - SessionGateView
import SwiftUI

struct SessionGateView: View {
    @StateObject private var vm: SessionGateViewModel

    init(idService: UserIdService, recipeImportPresenter: RecipeImportPresenting = RecipeImportPresenter()) {
        _vm = StateObject(wrappedValue: SessionGateViewModel(idService: idService, recipeImportPresenter: recipeImportPresenter))
    }

    var body: some View {
        Group {
            switch vm.sessionState {
            case .initializing:
                ProgressView().controlSize(.large)
            case .signedIn(let pubId):
                HomeView(publicId: pubId, pendingInviteCode: $vm.pendingInviteCode, onImport: { vm.presentImport() })
                    .onOpenURL { url in vm.handleOpenURL(url) }
            }
        }
        .alert(item: Binding(get: {
            if let msg = vm.errorMessage { return IdentifiedAlert(message: msg) }
            return nil
        }, set: { _ in vm.errorMessage = nil })) { ia in
            Alert(title: Text("Error"), message: Text(ia.message), dismissButton: .default(Text("OK")))
        }
    }
}

private struct IdentifiedAlert: Identifiable { let id = UUID(); let message: String }

// MARK: - HomeView with Hamburger Menu
struct HomeView: View {
    enum Section { case lists, pairing, settings }
    let publicId: PublicUserId
    @Binding var pendingInviteCode: String?
    let onImport: () -> Void
    @State private var section: Section = .lists

    var body: some View {
        Group {
            switch section {
            case .lists:
                ShoppingListView()
                    .overlay(alignment: .topTrailing) {
                        HamburgerMenuButton(section: $section, onImport: onImport)
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                    }
            case .pairing:
                PairingHostView(publicId: publicId, pendingInviteCode: $pendingInviteCode) {
                    HamburgerMenuButton(section: $section, onImport: onImport)
                }
            case .settings:
                NavigationStack {
                    SettingsView(publicId: publicId)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { HamburgerMenuButton(section: $section, onImport: onImport) } }
                }
            }
        }
        .onChange(of: pendingInviteCode) { _, new in
            if let code = new, !code.isEmpty { section = .pairing }
        }
    }
}

// MARK: - Hamburger Button
private struct HamburgerMenuButton: View {
    @Binding var section: HomeView.Section
    var onImport: () -> Void = {}
    var body: some View {
        Menu {
            Button(action: { section = .lists }) {
                Label { Text("menu.lists", tableName: "Localizable") } icon: { Image(systemName: "list.bullet") }
            }
            Button(action: { section = .pairing }) {
                Label { Text("menu.pairing", tableName: "Localizable") } icon: { Image(systemName: "person.2") }
            }
            Button(action: { section = .settings }) {
                Label { Text("menu.settings", tableName: "Localizable") } icon: { Image(systemName: "gearshape") }
            }
            // Import Recipe Keeper via VM
            Button(action: { onImport() }) {
                Label { Text("menu.importRecipeKeeper", tableName: "Localizable") } icon: { Image(systemName: "tray.and.arrow.down") }
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.title3.weight(.semibold))
                .padding(10)
                .background(Circle().fill(Color.theme.accent))
                .foregroundColor(Color.theme.background)
        }
    }
}

// MARK: - Pairing Host
struct PairingHostView: View {
    let publicId: PublicUserId
    @Binding var pendingInviteCode: String?
    @StateObject private var vm: PairingViewModel
    private let trailingMenu: AnyView?

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

// MARK: - Settings (User ID display only)
struct SettingsView: View {
    let publicId: PublicUserId

    var body: some View {
        GeometryReader { proxy in
            let headerHeight: CGFloat = proxy.size.height * DS.Layout.headerHeightRatio
            let contentOffsetBelowHeader: CGFloat = headerHeight * 0.75
            ZStack(alignment: .top) {
                Color.theme.background.ignoresSafeArea()
                AccentHeader(title: String(localized: "settings.title"), style: .plain)
                    .frame(height: headerHeight)
                VStack(spacing: 0) {
                    Spacer().frame(height: contentOffsetBelowHeader)
                    Form {
                        Section {
                            HStack {
                                Text("settings.userId", tableName: "Localizable")
                                Spacer()
                                Text(publicId.value).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                            HStack {
                                // Repurpose copy to share sheet (still labeled by localization key)
                                ShareLink(item: publicId.value) { Text("settings.copy", tableName: "Localizable") }
                                ShareLink(item: publicId.value) { Text("settings.share", tableName: "Localizable") }
                            }
                        } header: { Text("settings.identity", tableName: "Localizable") }
                    }
                }
            }
        }
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - AcceptInviteView
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

// MARK: - ApprovalsListView
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

// MARK: - Partners List
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

// MARK: - QRCodeView (CGImage based)
struct QRCodeView: View {
    let text: String
    var body: some View {
        if let cg = QRCodeGenerator.cgImage(from: text) {
            Image(decorative: cg, scale: 1, orientation: .up)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else { EmptyView() }
    }
}

private enum QRCodeGenerator {
    static let context = CIContext(options: nil)
    static func cgImage(from string: String) -> CGImage? {
        guard let data = string.data(using: .utf8), let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let scaleX: CGFloat = 8, scaleY: CGFloat = 8
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let rect = transformed.extent.integral
        return context.createCGImage(transformed, from: rect)
    }
}
