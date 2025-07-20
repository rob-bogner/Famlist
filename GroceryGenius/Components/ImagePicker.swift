//
//  ImagePicker.swift
//  GroceryGenius
//
//  Description:
//  A reusable SwiftUI wrapper around UIKit's UIImagePickerController.
//  Allows users to capture an image using the camera or select one from their photo library.
//  Integrates captured/selected images back into SwiftUI views.
//  Originally created: 27.04.2025
//  Last updated: 27.04.2025
//

import SwiftUI
import UIKit

/// A SwiftUI wrapper for UIImagePickerController, allowing image selection from the camera or photo library.
struct ImagePicker: UIViewControllerRepresentable {
    /// The selected UIImage, bound to the parent SwiftUI view.
    @Binding var selectedImage: UIImage?
    
    /// Whether the image picker is currently showing.
    @Binding var isPresented: Bool
    
    /// The source type (camera or photo library).
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    /// Creates the UIKit view controller (UIImagePickerController) used in SwiftUI.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true // Allow simple cropping/editing
        return picker
    }
    
    /// Updates the UIKit view controller. Not needed in this simple case.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    /// Connects the UIKit delegate back to SwiftUI using a Coordinator.
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    /// Coordinator class acts as the delegate for UIImagePickerController.
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        /// Initialize the Coordinator with the parent ImagePicker.
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        /// Called when the user selects an image or cancels.
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Retrieve the edited image if available, else the original
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            // Dismiss the picker
            parent.isPresented = false
        }
        
        /// Called when the user cancels picking an image.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // Dismiss the picker
            parent.isPresented = false
        }
    }
}
