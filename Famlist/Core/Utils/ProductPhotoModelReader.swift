/*
 ProductPhotoModelReader.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Per Foto hinzufügen“ ab iOS 27: Sprachmodell auf dem Gerät (Foundation Models mit Bild) ordnet die
   gelesene Aufschrift zu (Name, Marke, Sorte, Menge) und schreibt – wenn Open Food Facts nichts hat –
   eine kurze Beschreibung („Automatisch erstellt“).

 🔰 Notes for Beginners:
 - Nicht verfügbar (Gerät ohne Apple Intelligence, Modell lädt) → nil; dann gelten die Regeln aus
   ProductPhotoRecognizer.
 - Die Rahmen im Produktkopf kommen weiter aus Vision: Die Modell-Antwort wird den gelesenen Zeilen zugeordnet.
 - API neu in Xcode 27 (WWDC26). Weichen Namen im SDK ab, hier anpassen.

 📝 Last Change:
 - Initial creation (Wunsch Robert 30.09.2026).
 ------------------------------------------------------------------------
 */

import FoundationModels
import UIKit

@available(iOS 27.0, *)
enum ProductPhotoModelReader {
    @Generable
    struct Label {
        @Guide(description: "Produktname ohne Marke und ohne Menge, wie er groß auf der Packung steht, z. B. „Hafer Drink“.")
        var name: String
        @Guide(description: "Marke bzw. Hersteller, leer wenn keine erkennbar.")
        var brand: String
        @Guide(description: "Sorte oder Variante, z. B. „Barista“, „Laktosefrei“; leer wenn keine.")
        var variant: String
        @Guide(description: "Füllmenge wie aufgedruckt, z. B. „1 L“, „500 g“; leer wenn keine.")
        var quantity: String
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func fields(image: UIImage, reading: ProductPhotoReading) async -> ProductPhotoFields? {
        guard isAvailable, let cg = image.cgImage else { return nil }
        let text = reading.lines.map(\.text).joined(separator: "\n")
        let session = LanguageModelSession(instructions: "Du liest Verpackungen von Lebensmitteln und Haushaltsartikeln für eine deutsche Einkaufsliste. Übernimm Wörter genau so, wie sie aufgedruckt sind.")
        let prompt = Prompt {
            "Gelesene Aufschrift (Zeile für Zeile):\n\(text)\n\nOrdne Name, Marke, Sorte und Füllmenge zu."
            Attachment(cg)
        }
        guard let label = try? await session.respond(to: prompt, generating: Label.self).content else { return nil }
        let name = label.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let quantity = ProductPhotoRecognizer.parseQuantity(label.quantity)
        let fallback = ProductPhotoRecognizer.fields(from: reading)
        return ProductPhotoFields(name: name, brand: label.brand.isEmpty ? nil : label.brand,
                                  variant: label.variant.isEmpty ? nil : label.variant,
                                  units: quantity?.0, measure: quantity?.1,
                                  highlights: fallback?.highlights ?? [])
    }

    @Generable
    struct Choice {
        @Guide(description: "Nummer des Produkts, das auf dem Foto zu sehen ist; 0, wenn keines sicher passt.")
        var number: Int
    }

    /// Welcher Kandidat ist auf dem Foto? Index in `candidates` oder nil (keiner / Modell nicht verfügbar).
    /// Nur ein zusätzliches Signal – ProductPhotoMatcher entscheidet.
    static func pick(image: UIImage, reading: ProductPhotoReading, candidates: [String]) async -> Int? {
        guard isAvailable, let cg = image.cgImage, !candidates.isEmpty else { return nil }
        let list = candidates.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let text = reading.lines.map(\.text).joined(separator: "\n")
        let session = LanguageModelSession(instructions: "Du vergleichst ein Foto einer Verpackung mit Produkten aus einem Katalog. Wähle nur, wenn Produktart, Sorte und Marke zur Aufschrift passen. Ähnliche Wörter reichen nicht (Butter ist nicht Erdnussbutter).")
        let prompt = Prompt {
            "Aufschrift auf der Packung:\n\(text)\n\nKatalog:\n\(list)\n\nWelche Nummer ist auf dem Foto? 0 = keine."
            Attachment(cg)
        }
        guard let choice = try? await session.respond(to: prompt, generating: Choice.self).content,
              (1...candidates.count).contains(choice.number) else { return nil }
        return choice.number - 1
    }

    /// Ein bis zwei sachliche Sätze, wenn Open Food Facts nichts liefert.
    static func description(name: String, brand: String?) async -> String? {
        guard isAvailable else { return nil }
        let session = LanguageModelSession(instructions: "Du schreibst sachliche, kurze Produktbeschreibungen auf Deutsch. Keine Werbesprache, keine erfundenen Zahlen oder Zutaten.")
        let product = [brand, name].compactMap { $0 }.joined(separator: " ")
        guard let text = try? await session.respond(to: "Beschreibe in höchstens zwei kurzen Sätzen, was „\(product)“ ist und wofür man es verwendet.").content else { return nil }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
}
