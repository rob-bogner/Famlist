// filepath: GroceryGenius/Service/RecipeImportService.swift
// MARK: - RecipeImportService / Presenter

import Foundation

struct RecipeImportPresenter: RecipeImportPresenting {
    func presentImport() {
        ImportCoordinator.presentImport()
    }
}
