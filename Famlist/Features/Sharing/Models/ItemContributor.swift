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
 - Ring und Schatten des Profilbilds über CSSBox statt `.shadow` (Liste stotterte beim Scrollen, 11.10.2026).
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
        // box-shadow: 0 0 0 2px byRing, 0 2px 6px -2px rgba(12,40,44,.35) (Hybrid.dc.html, shared = on).
        // Über CSSBox (Core Animation), nicht `.shadow`: Ein weicher SwiftUI-Schatten in jeder Zeile wird beim
        // Scrollen in jedem Frame neu gerechnet – die Liste stotterte (Gerät, 11.10.2026; wie am 26.09.2026).
        .background(CSSBox(shape: Circle(),
                           shadows: [.drop(0, 0, 0, 2, isDark ? .hex("#16282B") : .white),
                                     .drop(0, 2, 6, -2, .rgba(12, 40, 44, 0.35))]))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hinzugefügt von \(contributor.name)")
    }
}

#Preview("Profilbild am Mengen-Chip") {
    HStack(spacing: 16) {
        ContributorAvatar(contributor: ItemContributor(id: UUID(), name: "Anna", image: nil), isDark: false)
        ContributorAvatar(contributor: ItemContributor(id: UUID(), name: "Max", image: nil), isDark: false)
    }
    .padding(24)
    .background(Color.white)
}

#Preview("Profilbild am Mengen-Chip – Dark") {
    HStack(spacing: 16) {
        ContributorAvatar(contributor: ItemContributor(id: UUID(), name: "Anna", image: nil), isDark: true)
        ContributorAvatar(contributor: ItemContributor(id: UUID(), name: "Max", image: nil), isDark: true)
    }
    .padding(24)
    .background(Color.hex("#16282B"))
}
