/*
 ItemImageSetting.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einstellung „Artikelbilder anzeigen“ (Design: Settings, SettingsImagesOff, MenuOverlay, ListNoImages,
   AddInlineNoImages, ProductDetailNoImage, ProductNewNoImage).

 🔰 Notes for Beginners:
 - Gilt nur auf diesem Gerät (@AppStorage wie „Preise anzeigen“), Standard: an.
 - Aus: keine Bild-Kachel auf den Artikelkarten (Karte bleibt 94 hoch, Tippen auf den Namen öffnet die
   Produktdetails), keine Bilder in den Vorschlägen, kein Bildkopf in den Produktdetails (Sheet 500 bzw. 560,
   Stift „Bearbeiten“ neben ✕).
 - Umschalten: Einstellungen → Liste oder Schnellschalter „Artikelbilder“ im Menü ☰.

 📝 Last Change:
 - Initial creation (Wunsch Robert 30.09.2026: Fotos optional).
 ------------------------------------------------------------------------
 */

import Foundation

enum ItemImageSetting {
    static let storageKey = "list.showImages"
    static let defaultValue = true
}
