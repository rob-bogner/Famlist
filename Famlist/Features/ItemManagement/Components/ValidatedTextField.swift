/*
 ValidatedTextField.swift

 Famlist
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Reusable text field component with inline validation error display

 🛠 Includes:
 - TextField with automatic error styling (red border when invalid)
 - Inline error message display
 - onChange callback for validation triggering

 🔰 Notes for Beginners:
 - Eliminates duplicated validation UI code across Add/Edit views
 - Red border appears automatically when error is not nil
 - Error message shows below field with consistent styling

 📝 Last Change:
 - Initial creation to DRY up validation UI patterns
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Reusable text field with built-in validation error display
struct ValidatedTextField: View {
    
    // MARK: - Properties
    
    let placeholder: String
    @Binding var text: String
    let error: String?
    let onChanged: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(error == nil ? Color.clear : Color.red, lineWidth: 1)
                )
                .onChange(of: text) { _, _ in onChanged() }
            
            if let error {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ValidatedTextField(
            placeholder: "Valid Field",
            text: .constant("Valid Input"),
            error: nil,
            onChanged: {}
        )
        
        ValidatedTextField(
            placeholder: "Invalid Field",
            text: .constant(""),
            error: "Field is required",
            onChanged: {}
        )
    }
    .padding()
}
