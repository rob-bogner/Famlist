/*
 ListContributorsStore.swift
 Famlist
 Created on: 11.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Geteilte Liste: lädt Namen und Profilbilder der Mitglieder (inkl. Besitzer, ohne den angemeldeten Nutzer)
   für das Profilbild am Mengen-Chip (ItemCard, Design: ListShared).

 🔰 Notes for Beginners:
 - Mitglieder: `fetchMembers` (ohne Besitzer) + Besitzer der Liste. Profile über `ProfilesRepository.profile(id:)`
   (Regel profiles_comember_read), Fotos über signierte Links aus dem privaten Bucket `avatars`.
 - Erst Namen/Initialen (sofort sichtbar), dann die Fotos. Fotos werden klein (72 px) im Speicher gehalten,
   je Storage-Pfad nur einmal geladen.
 - Neu geladen wird bei Listenwechsel und wenn ein Artikel von einer noch unbekannten Person auftaucht
   (z. B. jemand ist gerade beigetreten).
 - Offline / Fehler: Das bisherige Verzeichnis bleibt stehen.

 📝 Last Change:
 - Initial creation (Wunsch Robert 11.10.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

@MainActor
final class ListContributorsStore: ObservableObject {
    /// Profil-ID (klein) → Mitglied. Ohne den angemeldeten Nutzer.
    @Published private(set) var byId: [String: ItemContributor] = [:]

    private var loadedListId: UUID?
    private var imageCache: [String: UIImage] = [:]

    /// Lädt die Mitglieder der Liste. `force` lädt auch dieselbe Liste neu (unbekannte Person aufgetaucht).
    func load(list: ListModel?, me: UUID?, lists: ListsRepository?, profiles: ProfilesRepository, force: Bool = false) async {
        guard let list, let me else { byId = [:]; loadedListId = nil; return }
        if loadedListId != list.id { byId = [:] }
        guard force || loadedListId != list.id else { return }
        loadedListId = list.id

        let members = (try? await lists?.fetchMembers(listId: list.id)) ?? []
        var people: [UUID: String] = [:]
        for m in members { people[m.id] = m.displayName }
        if people[list.ownerId] == nil { people[list.ownerId] = "" }
        people[me] = nil
        guard loadedListId == list.id else { return }
        if people.isEmpty { byId = [:]; return }

        // 1. Namen (Profil) → Initialen sofort.
        var result: [String: ItemContributor] = [:]
        var avatarPaths: [UUID: String] = [:]
        for (id, fallback) in people {
            let profile = try? await profiles.profile(id: id)
            let name = [profile?.fullName, profile?.username, fallback.isEmpty ? nil : fallback]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? "Mitglied"
            let key = id.uuidString.lowercased()
            result[key] = ItemContributor(id: id, name: name, image: byId[key]?.image)
            if let path = profile?.avatarUrl, !path.isEmpty { avatarPaths[id] = path }
        }
        guard loadedListId == list.id else { return }
        byId = result

        // 2. Fotos nachladen.
        for (id, path) in avatarPaths {
            let key = id.uuidString.lowercased()
            if let cached = imageCache[path] {
                byId[key]?.image = cached
                continue
            }
            guard let url = try? await profiles.avatarURL(path: path),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 72, height: 72)) else { continue }
            imageCache[path] = image
            guard loadedListId == list.id else { return }
            byId[key]?.image = image
        }
    }
}
