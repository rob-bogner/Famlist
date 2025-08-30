// SettingsView.swift
// Extracted from original SessionGateView.swift
import SwiftUI

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

#if DEBUG
#Preview("Settings") { SettingsView(publicId: PreviewData.publicId) }
#endif
