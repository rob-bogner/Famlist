// MARK: - ImagePicker.swift

/*
 File: ImagePicker.swift
 Project: GroceryGenius
 Created: 27.04.2025
 Last Updated: 17.08.2025

 Overview:
 SwiftUI wrapper around UIImagePickerController enabling photo capture or library selection with optional editing.

 Responsibilities / Includes:
 - Presents native picker (camera / photo library)
 - Delivers selected (edited or original) UIImage to binding
 - Handles cancellation cleanly

 Design Notes:
 - allowsEditing = true for basic crop; disable if full fidelity needed
 - Coordinator pattern bridges UIKit delegate back into SwiftUI
 - Binding for isPresented lets parent dismiss programmatically if desired

 Possible Enhancements:
 - Add PHPickerViewController path (modern photo picker) for multi-select
 - Add permission handling / user guidance on denial
 - Inject configuration (mediaTypes, quality settings)
*/

import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.isPresented = false
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.isPresented = false }
    }
}
