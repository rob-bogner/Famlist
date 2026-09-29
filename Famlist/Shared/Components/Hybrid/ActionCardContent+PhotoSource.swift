/*
 ActionCardContent+PhotoSource.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fertige Aktionskarte „Foto hinzufügen“ (Canvas: PhotoSourceDialog) für Produktdetails und Foto-Kachel.

 🔰 Notes for Beginners:
 - Kacheln „Foto aufnehmen“ (nur mit Kamera) und „Aus Mediathek“, darunter bei vorhandenem Foto
   „Foto entfernen“ (neutrale Pille, rote Schrift) und „Abbrechen“.
 - Die Auswahl läuft erst nach dem Ausblenden der Karte – dann kann die Bildauswahl als Sheet öffnen.

 📝 Last Change:
 - Initial creation (Designsprache statt Systemdialoge).
 - 29.09.2026: @MainActor, damit es unter Swift 6 kompiliert.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

extension ActionCardContent {
    /// "Add photo" card: camera / library tiles, optional "remove photo".
    /// @MainActor: baut eine View (PhotoSourceTiles); sonst meldet Swift 6 „sending non-Sendable value“.
    @MainActor
    static func photoSource(k: SheetTheme, hasImage: Bool, onCamera: @escaping () -> Void,
                            onLibrary: @escaping () -> Void, onRemove: @escaping () -> Void) -> ActionCardContent {
        var buttons: [ActionCardButton] = []
        if hasImage {
            buttons.append(ActionCardButton(title: "Foto entfernen", icon: Icon.trash,
                                            tint: ActionCardTokens(k).danger, action: onRemove))
        }
        buttons.append(.cancel())
        return ActionCardContent(
            icon: Icon.camera, tone: .info, title: hasImage ? "Foto ändern" : "Foto hinzufügen",
            message: "Nimm ein Foto auf oder wähle eines aus deiner Mediathek.",
            buttons: buttons,
            accessory: { close in
                AnyView(PhotoSourceTiles(k: k, hasCamera: UIImagePickerController.isSourceTypeAvailable(.camera),
                                         onCamera: { close(onCamera) }, onLibrary: { close(onLibrary) }))
            })
    }
}
