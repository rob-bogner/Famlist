/*
 ItemModel+Display.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Anzeige-Texte und Bild eines Artikels für die Hybrid-Oberfläche.

 🔰 Notes for Beginners:
 - quantityText folgt der bisherigen Regel aus ItemMeta: „1 Packung“ oder nur „1“ ohne Einheit.
 - image dekodiert imageData (Base64) über den ImageCache; nil, wenn kein Foto hinterlegt ist.

 📝 Last Change:
 - Initial creation (Hybrid-Redesign).
 ------------------------------------------------------------------------
 */

import UIKit

extension ItemModel {
    /// "1 Packung", "1,5 kg", "500 g" or just "2" when no measure is set.
    var quantityText: String {
        let amount = QuantityFormat.format(units)
        guard !measure.isEmpty else { return amount }
        return "\(amount) \(Measure.fromExternal(measure).localizedName)"
    }

    /// Product photo decoded from base64 imageData, if any.
    var image: UIImage? {
        ImageCache.shared.image(fromBase64: imageData)
    }
}
