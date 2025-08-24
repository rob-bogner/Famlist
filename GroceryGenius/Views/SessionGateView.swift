// MARK: - SessionGateView
import SwiftUI
import UIKit

struct SessionGateView: View {
    @StateObject private var sessionVM: SessionViewModel
    @State private var selectedTab: Int = 0 // 0: Lists, 1: Pairing

    init(idService: UserIdService) {
        _sessionVM = StateObject(wrappedValue: SessionViewModel(idService: idService))
    }

    var body: some View {
        Group {
            switch sessionVM.state {
            case .initializing:
                ProgressView().controlSize(.large)
            case .signedIn(let pubId):
                HomeView(publicId: pubId, pendingInviteCode: $sessionVM.pendingInviteCode)
                    .onOpenURL { url in
                        if let code = DeepLinkParser.pairCode(from: url) {
                            sessionVM.pendingInviteCode = code
                        }
                    }
            }
        }
        .environmentObject(sessionVM)
        .alert(item: Binding(get: {
            if let msg = sessionVM.errorMessage { return IdentifiedAlert(message: msg) }
            return nil
        }, set: { _ in sessionVM.errorMessage = nil })) { ia in
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
    @State private var section: Section = .lists

    var body: some View {
        Group {
            switch section {
            case .lists:
                ShoppingListView()
                    .overlay(alignment: .topTrailing) {
                        HamburgerMenuButton(section: $section)
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                    }
            case .pairing:
                PairingHostView(publicId: publicId, pendingInviteCode: $pendingInviteCode) {
                    HamburgerMenuButton(section: $section)
                }
            case .settings:
                NavigationView {
                    SettingsView(publicId: publicId)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { HamburgerMenuButton(section: $section) } }
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
    var body: some View {
        Menu {
            Button(action: { section = .lists }) { Label("Lists", systemImage: "list.bullet") }
            Button(action: { section = .pairing }) { Label("Pairing", systemImage: "person.2") }
            Button(action: { section = .settings }) { Label("Settings", systemImage: "gearshape") }
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

    private var headerHeight: CGFloat { UIScreen.main.bounds.height * DS.Layout.headerHeightRatio }
    private var contentOffsetBelowHeader: CGFloat { headerHeight * 0.75 }

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                Color.theme.background.ignoresSafeArea()
                AccentHeader(title: "Pairing", style: .plain)
                    .frame(height: headerHeight)
                    .zIndex(0)
                VStack(spacing: 0) {
                    Spacer().frame(height: contentOffsetBelowHeader)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            GroupBox("My Public ID") {
                                HStack { Text(publicId.value).font(.callout).textSelection(.enabled); Spacer() }
                            }.padding(.horizontal)
                            GroupBox("Invite a partner") {
                                HStack {
                                    Text(vm.inviteCode.isEmpty ? "—" : vm.inviteCode).font(.title2.monospaced())
                                    Spacer()
                                    Button("Generate") { Task { await vm.generateInvite() } }
                                }
                                if !vm.inviteCode.isEmpty {
                                    let link = "gg://pair/\(vm.inviteCode)"
                                    QRCodeView(text: link).frame(width: 160, height: 160)
                                    HStack {
                                        Button("Copy code") { UIPasteboard.general.string = vm.inviteCode }
                                        Button("Share link") {
                                            let av = UIActivityViewController(activityItems: [URL(string: link)!], applicationActivities: nil)
                                            UIApplication.shared.topMostViewController()?.present(av, animated: true)
                                        }
                                    }
                                }
                            }.padding(.horizontal)
                            GroupBox("Accept invite") {
                                AcceptInviteView(pendingInviteCode: $pendingInviteCode) { code in Task { await vm.acceptInvite(code: code) } }
                            }.padding(.horizontal)
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

    private var headerHeight: CGFloat { UIScreen.main.bounds.height * DS.Layout.headerHeightRatio }
    private var contentOffsetBelowHeader: CGFloat { headerHeight * 0.75 }

    var body: some View {
        ZStack(alignment: .top) {
            Color.theme.background.ignoresSafeArea()
            AccentHeader(title: "Settings", style: .plain)
                .frame(height: headerHeight)
            VStack(spacing: 0) {
                Spacer().frame(height: contentOffsetBelowHeader)
                Form {
                    Section("Identity") {
                        HStack { Text("Your User ID"); Spacer(); Text(publicId.value).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled) }
                        HStack {
                            Button("Copy") { UIPasteboard.general.string = publicId.value }
                            ShareLink("Share", item: publicId.value)
                        }
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
            TextField("Enter code", text: Binding(get: { pendingInviteCode ?? code }, set: { code = $0 }))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
            Button("Accept") { onSubmit(pendingInviteCode ?? code) }
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - ApprovalsListView
struct ApprovalsListView: View {
    @ObservedObject var vm: PairingViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Requests").font(.headline)
            ForEach(vm.incoming, id: \.id) { req in
                HStack {
                    Text("From: \(req.from.value)").font(.subheadline).lineLimit(1)
                    Spacer()
                    if req.status == .pending {
                        Button("Approve") { Task { await vm.approve(req) } }
                        Button("Deny") { Task { await vm.deny(req) } }.foregroundColor(.red)
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
            Text("Partners").font(.headline)
            if partners.isEmpty {
                Text("No partners yet").foregroundStyle(.secondary)
            } else {
                ForEach(partners, id: \.self) { p in HStack { Text(p.value); Spacer() } }
            }
        }
    }
}

// MARK: - QRCodeView
struct QRCodeView: View {
    let text: String
    var body: some View {
        if let img = QRGenerator.qrImage(from: text) {
            Image(uiImage: img).interpolation(.none).resizable().scaledToFit()
        } else { EmptyView() }
    }
}

// MARK: - Helpers
struct DeepLinkParser { static func pairCode(from url: URL) -> String? { guard url.scheme == "gg", url.host == "pair" else { return nil }; return url.lastPathComponent.uppercased() } }

private struct QRGenerator {
    static func qrImage(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8), let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let scaleX: CGFloat = 8, scaleY: CGFloat = 8
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        return UIImage(ciImage: transformed)
    }
}

private extension UIApplication { func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first) -> UIViewController? { if let nav = base as? UINavigationController { return topMostViewController(base: nav.visibleViewController) } ; if let tab = base as? UITabBarController { return tab.selectedViewController.flatMap { topMostViewController(base: $0) } } ; if let presented = base?.presentedViewController { return topMostViewController(base: presented) } ; return base } }
