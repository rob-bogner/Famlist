/*
 ClipboardImportView.swift
 Created: 19.10.2025 | Updated: 19.10.2025
 
 Purpose: Sheet UI for importing shopping list items from clipboard
 
 CHANGELOG:
 - 19.10.2025: Initial version with preview and import functionality
*/

import SwiftUI

/// View for importing items from clipboard with preview
struct ClipboardImportView: View {
    
    // MARK: - Environment & Dependencies
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listViewModel: ListViewModel
    
    // MARK: - State
    
    @State private var parseResult: ClipboardImportParser.ParseResult?
    @State private var clipboardText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedItems: Set<Int> = []
    
    // MARK: - Body
    
    var body: some View {
        CustomModalView(
            title: String(localized: "import.title"),
            onClose: { dismiss() }
        ) {
            VStack(spacing: DS.Spacing.m) {
                if let parseResult = parseResult {
                    importPreview(parseResult)
                } else {
                    emptyState
                }
                
                Spacer()
                
                buttonSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                loadClipboard()
            }
        }
        .presentationBackground(Color.theme.card)
        .background(Color.theme.card)
    }
    
    // MARK: - Components
    
    /// Empty state when clipboard is empty or parsing failed
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.m) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.top, 40)
            
            Text(String(localized: "import.empty.title"))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(String(localized: "import.empty.message"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
    }
    
    /// Preview of parsed items with selection
    private func importPreview(_ result: ClipboardImportParser.ParseResult) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            // Store name if available
            if let storeName = result.storeName {
                HStack {
                    Image(systemName: "storefront")
                        .foregroundColor(.secondary)
                    Text(storeName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal)
                .padding(.top, DS.Spacing.s)
            }
            
            // Items count
            HStack {
                Text(String(localized: "import.items.count"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(result.items.count)")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
            
            Divider()
            
            // Item list
            ScrollView {
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(Array(result.items.enumerated()), id: \.offset) { index, item in
                        itemRow(item, index: index, isSelected: selectedItems.contains(index))
                    }
                }
                .padding(.horizontal)
            }
            
            // Skipped lines warning
            if !result.skippedLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "import.skipped.title"))
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                    Text(result.skippedLines.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal)
                .padding(.vertical, DS.Spacing.xs)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    /// Single item row with selection checkbox
    private func itemRow(_ item: ClipboardImportParser.ParsedItem, index: Int, isSelected: Bool) -> some View {
        HStack(spacing: DS.Spacing.s) {
            // Checkbox
            Button(action: { toggleSelection(index) }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color.theme.accent : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain) // Remove iOS default button styling to prevent gray border on iOS 26 devices.
            
            VStack(alignment: .leading, spacing: 2) {
                // Name with brand
                HStack(spacing: 4) {
                    if let brand = item.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    Text(item.name)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                // Category and quantity
                HStack(spacing: 8) {
                    if let category = item.category {
                        Text(category)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if item.units > 1 || !item.measure.isEmpty {
                        Text("\(item.units)\(item.measure.isEmpty ? "x" : " \(item.measure)")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture { toggleSelection(index) }
    }
    
    /// Action buttons
    private var buttonSection: some View {
        VStack(spacing: DS.Spacing.s) {
            // Select All / Deselect All
            if let result = parseResult, !result.items.isEmpty {
                Button(action: toggleAllSelection) {
                    Text(selectedItems.count == result.items.count
                         ? String(localized: "import.button.deselectAll")
                         : String(localized: "import.button.selectAll"))
                        .font(.subheadline)
                        .foregroundColor(Color.theme.accent)
                }
            }
            
            // Import button
            PrimaryButton(
                title: String(localized: "import.button.import")
            ) {
                importSelectedItems()
            }
            .disabled(selectedItems.isEmpty || isLoading)
            
            // Reload button
            if parseResult != nil {
                Button(action: loadClipboard) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(String(localized: "import.button.reload"))
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, DS.Spacing.s)
    }
    
    // MARK: - Actions
    
    private func loadClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            errorMessage = String(localized: "import.error.emptyClipboard")
            parseResult = nil
            return
        }
        
        clipboardText = text
        let result = ClipboardImportParser.parse(text)
        
        if result.items.isEmpty {
            errorMessage = String(localized: "import.error.noItemsFound")
            parseResult = nil
        } else {
            parseResult = result
            // Select all items by default
            selectedItems = Set(0..<result.items.count)
            errorMessage = nil
        }
    }
    
    private func toggleSelection(_ index: Int) {
        if selectedItems.contains(index) {
            selectedItems.remove(index)
        } else {
            selectedItems.insert(index)
        }
    }
    
    private func toggleAllSelection() {
        guard let result = parseResult else { return }
        
        if selectedItems.count == result.items.count {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(0..<result.items.count)
        }
    }
    
    private func importSelectedItems() {
        guard let result = parseResult else { return }
        guard !isLoading else { return }
        
        isLoading = true
        
        let itemsToImport = selectedItems
            .sorted()
            .compactMap { index -> ItemModel? in
                guard index < result.items.count else { return nil }
                let parsed = result.items[index]
                
                return ItemModel(
                    name: parsed.name,
                    units: parsed.units,
                    measure: parsed.measure,
                    category: parsed.category,
                    productDescription: parsed.productDescription,
                    brand: parsed.brand
                )
            }
        
        // User-friendly log
        UserLog.Data.clipboardImport(count: itemsToImport.count)
        
        // Add items to list
        Task { @MainActor in
            defer {
                isLoading = false
            }
            
            for item in itemsToImport {
                listViewModel.addItem(item)
            }
            
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    ClipboardImportView()
        .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}
