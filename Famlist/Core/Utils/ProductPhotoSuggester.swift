/*
 ProductPhotoSuggester.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vorschlag „Erkannt: Orangen · Obst & Gemüse“ aus einem Artikelfoto (Design: PhotoCutoutDone).

 🔰 Notes for Beginners:
 - Nutzt die Bildklassifizierung von Vision (VNClassifyImageRequest, auf dem Gerät, ohne Apple Intelligence).
   Vision liefert englische Begriffe („orange“, „banana“ …); eine kleine Liste übersetzt die häufigsten
   Lebensmittel in einen deutschen Namen und eine Standard-Kategorie.
 - Nur wenn ein bekannter Begriff sicher genug erkannt wird (≥ 0,25), gibt es einen Vorschlag – sonst nil.
 - Später (ab iOS 27) kann hier das Sprachmodell mit Bild-Eingabe freiere Namen liefern.

 📝 Last Change:
 - Feinere Kategorien (Käse, Eier, Wurst, Kaffee/Tee, Bier/Wein); fehlt eine davon in den
   Kategorien des Nutzers, gilt die gröbere von früher (12.10.2026).
 - Ab iOS 27 zuerst ProductPhotoModelSuggester (Foundation Models mit Bild) (30.09.2026).
 - Initial creation (Wunsch Robert 30.09.2026).
 ------------------------------------------------------------------------
 */

import UIKit
import Vision

struct ProductPhotoSuggestion: Equatable, Sendable {
    let name: String
    /// Name einer Standard-Kategorie (ItemCategory.rawValue).
    let category: String
}

enum ProductPhotoSuggester {
    private static let minimumConfidence: Float = 0.25

    /// Vorschlag: ab iOS 27 zuerst das Sprachmodell (freie Namen, Kategorien des Nutzers), sonst/ohne Treffer
    /// die Vision-Klassifizierung mit der festen Liste.
    static func suggest(for image: UIImage, categories: [String]) async -> ProductPhotoSuggestion? {
        if #available(iOS 27.0, *), let model = await ProductPhotoModelSuggester.suggest(for: image, categories: categories) {
            return model
        }
        return await suggest(for: image, userCategories: categories)
    }

    /// Kategorie für den Vorschlag: die feine, wenn der Nutzer sie hat (oder keine Kategorien bekannt sind),
    /// sonst die gröbere von früher (Käse → Milchprodukte).
    static func categoryName(_ category: ItemCategory, userCategories: [String]) -> String {
        let has: (ItemCategory) -> Bool = { c in
            userCategories.contains { $0.caseInsensitiveCompare(c.rawValue) == .orderedSame }
        }
        if userCategories.isEmpty || has(category) { return category.rawValue }
        if let coarser = category.coarser, has(coarser) { return coarser.rawValue }
        return category.rawValue
    }

    static func suggest(for image: UIImage, userCategories: [String] = []) async -> ProductPhotoSuggestion? {
        await Task.detached(priority: .utility) { () -> ProductPhotoSuggestion? in
            guard let cg = image.cgImage else { return nil }
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation(image.imageOrientation))
            do { try handler.perform([request]) } catch { return nil }
            let hits = (request.results ?? []).filter { $0.confidence >= minimumConfidence }
            for hit in hits.sorted(by: { $0.confidence > $1.confidence }) {
                if let match = catalog[hit.identifier.lowercased()] {
                    return ProductPhotoSuggestion(name: match.0,
                                                  category: categoryName(match.1, userCategories: userCategories))
                }
            }
            return nil
        }.value
    }

    private static func orientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    /// Vision-Begriff → (deutscher Name, Kategorie). Bewusst nur eindeutige Lebensmittel.
    private static let catalog: [String: (String, ItemCategory)] = {
        let og = ItemCategory.obstGemuese, mi = ItemCategory.milch, ba = ItemCategory.backwaren
        let ge = ItemCategory.getraenke, fl = ItemCategory.fleisch, tk = ItemCategory.tiefkuehl, ha = ItemCategory.haushalt
        let ka = ItemCategory.kaese, ei = ItemCategory.eier, wu = ItemCategory.wurst
        let al = ItemCategory.alkohol, kt = ItemCategory.kaffeeTee
        return [
            "orange": ("Orangen", og), "citrus_fruit": ("Zitrusfrüchte", og), "lemon": ("Zitronen", og), "lime": ("Limetten", og),
            "grapefruit": ("Grapefruit", og), "apple": ("Äpfel", og), "banana": ("Bananen", og), "pear": ("Birnen", og),
            "strawberry": ("Erdbeeren", og), "raspberry": ("Himbeeren", og), "blueberry": ("Heidelbeeren", og),
            "cherry": ("Kirschen", og), "grape": ("Trauben", og), "pineapple": ("Ananas", og), "watermelon": ("Wassermelone", og),
            "melon": ("Melone", og), "mango": ("Mango", og), "kiwi": ("Kiwis", og), "peach": ("Pfirsiche", og),
            "plum": ("Pflaumen", og), "apricot": ("Aprikosen", og), "avocado": ("Avocados", og), "coconut": ("Kokosnuss", og),
            "pomegranate": ("Granatapfel", og), "fig": ("Feigen", og),
            "tomato": ("Tomaten", og), "carrot": ("Karotten", og), "cucumber": ("Gurke", og), "potato": ("Kartoffeln", og),
            "onion": ("Zwiebeln", og), "garlic": ("Knoblauch", og), "broccoli": ("Brokkoli", og), "cauliflower": ("Blumenkohl", og),
            "lettuce": ("Salat", og), "cabbage": ("Kohl", og), "mushroom": ("Champignons", og), "corn": ("Mais", og),
            "bell_pepper": ("Paprika", og), "pepper_veggie": ("Paprika", og), "zucchini": ("Zucchini", og),
            "eggplant": ("Aubergine", og), "pumpkin": ("Kürbis", og), "asparagus": ("Spargel", og), "spinach": ("Spinat", og),
            "radish": ("Radieschen", og), "celery": ("Sellerie", og), "leek": ("Lauch", og), "ginger": ("Ingwer", og),
            "cheese": ("Käse", ka), "milk": ("Milch", mi), "yogurt": ("Joghurt", mi), "butter": ("Butter", mi), "egg": ("Eier", ei),
            "bread": ("Brot", ba), "baguette": ("Baguette", ba), "croissant": ("Croissants", ba), "pretzel": ("Brezeln", ba),
            "bagel": ("Bagels", ba), "cake": ("Kuchen", ba), "muffin": ("Muffins", ba), "cookie": ("Kekse", ba), "donut": ("Donuts", ba),
            "wine": ("Wein", al), "wine_bottle": ("Wein", al), "beer": ("Bier", al), "coffee": ("Kaffee", kt), "tea": ("Tee", kt),
            "juice": ("Saft", ge), "water": ("Wasser", ge), "soda": ("Limonade", ge),
            "meat": ("Fleisch", fl), "steak": ("Steak", fl), "sausage": ("Würstchen", wu), "bacon": ("Speck", wu),
            "chicken": ("Hähnchen", fl), "fish": ("Fisch", fl), "salmon": ("Lachs", fl), "shrimp": ("Garnelen", fl),
            "ice_cream": ("Eis", tk), "pizza": ("Pizza", tk),
            "toilet_paper": ("Toilettenpapier", ha), "sponge": ("Schwämme", ha), "detergent": ("Waschmittel", ha),
        ]
    }()
}
