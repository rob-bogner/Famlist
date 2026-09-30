/*
 PhotoPickerSource.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Quelle der Bildauswahl (Kamera oder Mediathek) als Auslöser für `.sheet(item:)`.

 🔰 Notes for Beginners:
 - Fehler 30.09.2026: „Foto aufnehmen“ öffnete beim ersten Mal die Mediathek. Quelle und `showPicker` wurden
   getrennt gesetzt; das Sheet wurde mit dem alten Wert der Quelle gebaut (Startwert Mediathek), erst beim
   zweiten Mal stimmte er. Mit `.sheet(item:)` IST die Quelle der Auslöser und kann nicht veralten.
 - `presentedFlag` macht daraus das Bool-Binding, das `ImagePicker` zum Schließen braucht.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

enum PhotoPickerSource: Int, Identifiable {
    case camera
    case library

    var id: Int { rawValue }

    var sourceType: UIImagePickerController.SourceType {
        switch self {
        case .camera: .camera
        case .library: .photoLibrary
        }
    }
}

extension Binding where Value == PhotoPickerSource? {
    /// true, solange eine Quelle gewählt ist; false setzen schließt die Bildauswahl.
    var presentedFlag: Binding<Bool> {
        Binding<Bool>(get: { wrappedValue != nil }, set: { if !$0 { wrappedValue = nil } })
    }
}
