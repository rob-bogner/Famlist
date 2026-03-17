/*
 ShareListView.swift

 Famlist
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet zum Teilen einer Liste via Deep Link (FAM-31).
 - Generiert famlist://invite?listId=X&inviterPublicId=Y&listTitle=Z
 - Nur für den Listen-Owner sichtbar.

 ⚠️ Bekannte Einschränkung: famlist:// funktioniert nur mit installierter App.
    Universal Links (HTTPS-Fallback) erfordern ein separates Web-Backend (zukünftiges Ticket).

 📝 Last Change:
 - FAM-21: Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Sheet zum Teilen einer Liste per Deep Link.
struct ShareListView: View {
    let list: ListModel?
    let currentPublicId: String

    @Environment(\.dismiss) private var dismiss

    private var inviteURL: URL? {
        guard let list else { return nil }
        let title = list.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? list.title
        return URL(string: "famlist://invite?listId=\(list.id.uuidString)&inviterPublicId=\(currentPublicId)&listTitle=\(title)")
    }

    var body: some View {
        CustomModalView(title: "Liste teilen", onClose: { dismiss() }) {
            VStack(spacing: 20) {
                if let list {
                    Text("Lade Familienmitglieder oder Freunde ein, auf '\(list.title)' zuzugreifen.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 16)
                }

                if let url = inviteURL {
                    ShareLink(item: url) {
                        Label("Einladungslink teilen", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                    Button {
                        UIPasteboard.general.string = url.absoluteString
                    } label: {
                        Label("Link kopieren", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                } else {
                    Text("Keine Liste ausgewählt.")
                        .foregroundColor(.secondary)
                }

                Text("Der Link funktioniert nur mit installierter Famlist-App.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

#Preview {
    ShareListView(
        list: ListModel(id: UUID(), ownerId: UUID(), title: "Wocheneinkauf",
                        isDefault: true, createdAt: Date(), updatedAt: Date()),
        currentPublicId: "genius-demo"
    )
    .presentationDetents([.medium])
}
