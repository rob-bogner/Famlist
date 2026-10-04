/*
 ProductPhotoModelSuggester.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Namensvorschlag aus dem Foto mit dem Sprachmodell auf dem Gerät (Foundation Models mit Bild-Eingabe,
   ab iOS 27, Geräte mit Apple Intelligence). Design: PhotoCutoutDone („Erkannt: …“).

 🔰 Notes for Beginners:
 - Das Modell bekommt das Foto und die Kategorien des Nutzers und antwortet strukturiert (@Generable):
   ein kurzer deutscher Name und genau eine der Kategorien.
 - Nicht verfügbar (älteres Gerät, Apple Intelligence aus, Modell lädt noch) → nil; dann übernimmt
   ProductPhotoSuggester die Vision-Erkennung.
 - API neu in Xcode 27 (WWDC26: `Prompt { … Attachment(image) }`). Weichen Namen im SDK ab, hier anpassen.

 📝 Last Change:
 - Initial creation (iOS 27 installiert, Wunsch Robert 30.09.2026).
 ------------------------------------------------------------------------
 */

import FoundationModels
import UIKit

@available(iOS 27.0, *)
enum ProductPhotoModelSuggester {
    @Generable
    struct Guess {
        @Guide(description: "Kurzer deutscher Artikelname wie auf einer Einkaufsliste, z. B. „Orangen“, „Hafermilch“, „Vollkornbrot“. Ohne Marke, ohne Menge.")
        var name: String
        @Guide(description: "Genau eine Kategorie aus der Liste im Prompt, wörtlich übernommen.")
        var category: String
    }

    static func suggest(for image: UIImage, categories: [String]) async -> ProductPhotoSuggestion? {
        guard case .available = SystemLanguageModel.default.availability, let cg = image.cgImage else { return nil }
        let session = LanguageModelSession(instructions: "Du erkennst Lebensmittel und Haushaltsartikel auf Fotos für eine deutsche Einkaufsliste. Antworte knapp.")
        let list = categories.joined(separator: ", ")
        let prompt = Prompt {
            "Welcher Artikel ist auf dem Foto? Nenne den Artikelnamen und wähle die passende Kategorie aus: \(list)."
            Attachment(cg)
        }
        do {
            let guess = try await session.respond(to: prompt, generating: Guess.self).content
            let name = guess.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 40 else { return nil }
            let category = categories.first { $0.caseInsensitiveCompare(guess.category.trimmingCharacters(in: .whitespaces)) == .orderedSame } ?? ""
            return ProductPhotoSuggestion(name: name, category: category)
        } catch {
            logVoid(params: (action: "photoModelSuggestion.failed", error: (error as NSError).localizedDescription))
            return nil
        }
    }
}
