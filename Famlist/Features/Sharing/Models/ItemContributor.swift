/*
 ItemContributor.swift
 Famlist
 Created on: 11.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Geteilte Liste: ein Mitglied, das Artikel hinzugefügt hat (Name, Initiale, Profilbild, Farbe).
   ItemCard zeigt es neben dem Mengen-Chip (Design: ListShared / ListSharedNoImages).

 🔰 Notes for Beginners:
 - Die Liste bekommt die Mitglieder über die Umgebung (`\.itemContributors`), Schlüssel = Profil-ID klein
   geschrieben (wie `ItemModel.createdBy`). Der angemeldete Nutzer steht NICHT darin → eigene Artikel
   zeigen kein Profilbild; nicht geteilte Listen haben ein leeres Verzeichnis.
 - Ohne Profilfoto: Initiale auf einem Farbverlauf; die Farbe hängt fest an der Profil-ID.

 📝 Last Change:
 - Initial creation (Wunsch Robert 11.10.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

struct ItemContributor: Identifiable, Equatable {
    let id: UUID
    let name: String
    var image: UIImage?

    var initial: String { name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?" }

    /// Feste Farbe je Person (Verlauf hell → dunkel).
    var colors: (Color, Color) {
        let palette: [(String, String)] = [("#9C8CFF", "#6A55E0"), ("#FF9E7A", "#E0603B"), ("#5EC8A8", "#24936F"),
                                           ("#F7B955", "#D3891B"), ("#6FB1FF", "#3A78D8"), ("#F08DB8", "#C9497F")]
        let sum = id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let p = palette[sum % palette.count]
        return (.hex(p.0), .hex(p.1))
    }

    static func == (lhs: ItemContributor, rhs: ItemContributor) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.image === rhs.image
    }
}

private struct ItemContributorsKey: EnvironmentKey {
    static let defaultValue: [String: ItemContributor] = [:]
}

extension EnvironmentValues {
    /// Mitglieder der aktiven Liste ohne den angemeldeten Nutzer; Schlüssel = Profil-ID (klein).
    var itemContributors: [String: ItemContributor] {
        get { self[ItemContributorsKey.self] }
        set { self[ItemContributorsKey.self] = newValue }
    }
}

/// Rundes Profilbild 24 mit Rand (Kartenfarbe) – „Hinzugefügt von …“.
struct ContributorAvatar: View {
    let contributor: ItemContributor
    let isDark: Bool
    var size: CGFloat = 24

    var body: some View {
        let colors = contributor.colors
        ZStack {
            if let image = contributor.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [colors.0, colors.1], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(contributor.initial)
                    .font(AppFont.dm(size * 0.46, 700))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(isDark ? Color.hex("#16282B") : .white, lineWidth: 2).padding(-2))
        .shadow(color: Color.rgba(12, 40, 44, 0.3), radius: 3, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hinzugefügt von \(contributor.name)")
    }
}
