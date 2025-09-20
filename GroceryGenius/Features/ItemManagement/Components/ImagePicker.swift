/*
 ImagePicker.swift

 GroceryGenius
 Created on: 27.04.2025
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - SwiftUI wrapper around UIImagePickerController enabling photo capture or library selection with optional editing.

 🛠 Includes:
 - Presents native picker (camera / photo library)
 - Delivers selected (edited or original) UIImage to binding
 - Handles cancellation cleanly

 🔰 Notes for Beginners:
 - allowsEditing = true for basic crop; disable if full fidelity needed
 - Coordinator pattern bridges UIKit delegate back into SwiftUI
 - Binding for isPresented lets parent dismiss programmatically if desired

 📝 Last Change:
 - Standardized header to required format and expanded inline comments. No functional changes.
 ------------------------------------------------------------------------
 */

import SwiftUI // Needed to conform to UIViewControllerRepresentable and build SwiftUI views.
import UIKit // Provides UIImagePickerController and UIImage types.

/// A UIKit image picker bridged into SwiftUI via UIViewControllerRepresentable.
struct ImagePicker: UIViewControllerRepresentable { // Wraps UIImagePickerController for use in SwiftUI.
    @Binding var selectedImage: UIImage? // Output: the chosen image
    @Binding var isPresented: Bool // Controls sheet presentation from parent
    var sourceType: UIImagePickerController.SourceType = .photoLibrary // Camera or library

    /// Creates and configures the UIKit image picker controller.
    func makeUIViewController(context: Context) -> UIImagePickerController { // Create and configure the UIKit controller.
        let picker = UIImagePickerController() // Native picker controller
        picker.delegate = context.coordinator // Route events back to Coordinator
        picker.sourceType = sourceType // Choose camera/library
        picker.allowsEditing = true // Let user crop/adjust lightly
        return picker // Hand back to SwiftUI
    }

    /// Updates the UIKit image picker controller. No dynamic updates are needed.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    /// Creates the Coordinator instance that bridges UIKit delegate callbacks to SwiftUI bindings.
    func makeCoordinator() -> Coordinator { Coordinator(self) } // Create Coordinator instance

    /// Bridges UIKit delegate callbacks to SwiftUI bindings.
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate { // Delegate to handle picker events.
        let parent: ImagePicker // Reference to wrapper for updating bindings

        /// Initializes the Coordinator with a reference to the parent ImagePicker.
        init(_ parent: ImagePicker) { self.parent = parent } // Store reference to representable.

        /// Called when the user picks an image. Pushes the picked image to the binding and dismisses the sheet.
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) { // Called when user picks an image.
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage { // Prefer edited image, fallback to original.
                parent.selectedImage = image // Push picked image to binding
            }
            parent.isPresented = false // Dismiss sheet
        }

        /// Dismisses the sheet when the user cancels the image picking.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.isPresented = false } // Dismiss on cancel
    }
}
