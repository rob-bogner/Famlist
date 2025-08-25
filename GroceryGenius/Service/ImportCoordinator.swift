// filepath: GroceryGenius/Service/ImportCoordinator.swift
// MARK: - ImportCoordinator.swift

import Foundation
import SwiftUI
import UIKit

final class ImportCoordinator {
    static func presentImport() {
        DispatchQueue.main.async {
            guard let topVC = UIApplication.topMostViewController() else { return }
            guard let clipboard = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !clipboard.isEmpty else {
                showAlert(on: topVC, message: String(localized: "import.error.emptyClipboard"))
                return
            }
            let parsed = RecipeKeeperImportParser.parse(clipboard)
            let items = parsed.items
            guard !items.isEmpty else {
                showAlert(on: topVC, message: String(localized: "import.error.noItemsFound"))
                return
            }

            let preview = ImportPreviewView(items: items) {
                topVC.dismiss(animated: true)
            } onImport: { selected in
                // Map and append to current list (Firestore-backed)
                let mapped = selected.map { mapToItemModel($0) }
                mapped.forEach { FirestoreManager.shared.addItem($0, completion: nil) }
                topVC.dismiss(animated: true) {
                    let msg = String(format: String(localized: "import.success.message"), selected.count)
                    showToast(on: UIApplication.topMostViewController() ?? topVC, message: msg)
                }
            }

            let hosting = UIHostingController(rootView: preview)
            if let sheet = hosting.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.preferredCornerRadius = 15
            }
            hosting.view.backgroundColor = .clear
            topVC.present(hosting, animated: true)
        }
    }

    // MARK: - Mapping
    private static func mapToItemModel(_ itm: ImportedItem) -> ItemModel {
        var name = itm.title
        var extraParts: [String] = []
        if let note = itm.note, !note.isEmpty { extraParts.append(note) }

        // Map a subset of known units to internal Measure; else return nil
        func mapUnitToMeasureRaw(_ unit: String) -> String? {
            let lower = unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch lower {
            case "g": return Measure.g.rawValue
            case "kg": return Measure.kg.rawValue
            case "ml": return Measure.ml.rawValue
            case "l", "liter", "litre": return Measure.l.rawValue
            case "pack", "packung": return Measure.pack.rawValue
            case "bunch", "bund": return Measure.bunch.rawValue
            case "can", "dose": return Measure.can.rawValue
            case "tube": return Measure.tube.rawValue
            case "jar": return Measure.jar.rawValue
            case "bottle": return Measure.bottle.rawValue
            case "box": return Measure.box.rawValue
            case "bag", "tüte": return Measure.bag.rawValue
            case "slice", "scheibe": return Measure.slice.rawValue
            case "bar", "tafel": return Measure.bar.rawValue
            case "carton", "karton": return Measure.carton.rawValue
            case "crate", "kasten": return Measure.crate.rawValue
            case "net", "netz": return Measure.net.rawValue
            case "pair", "paar": return Measure.pair.rawValue
            case "piece", "stk", "stück", "item": return Measure.piece.rawValue
            case "cm": return Measure.cm.rawValue
            case "m": return Measure.m.rawValue
            default: return nil
            }
        }

        if let qty = itm.qty {
            let isInt = abs(qty.rounded() - qty) < 0.01
            if let unit = itm.unit, let measureRaw = mapUnitToMeasureRaw(unit), isInt {
                // Representable with known unit
                let units = max(Int(qty.rounded()), 1)
                return ItemModel(
                    name: name,
                    units: units,
                    measure: measureRaw,
                    price: 0.0,
                    isChecked: false,
                    category: (itm.category ?? "Andere")
                )
            } else if itm.unit == nil && isInt {
                // Qty only
                let units = max(Int(qty.rounded()), 1)
                return ItemModel(
                    name: name,
                    units: units,
                    measure: "",
                    price: 0.0,
                    isChecked: false,
                    category: (itm.category ?? "Andere")
                )
            } else {
                // Fractional or unknown unit -> keep detail in name
                let qtyText = NumberFormatter.localizedString(from: NSNumber(value: qty), number: .decimal)
                if let unit = itm.unit { extraParts.append("\(qtyText) \(unit)") }
                else { extraParts.append(qtyText) }
            }
        }

        if !extraParts.isEmpty { name += " (" + extraParts.joined(separator: ", ") + ")" }
        return ItemModel(
            name: name,
            units: 1,
            measure: "",
            price: 0.0,
            isChecked: false,
            category: (itm.category ?? "Andere")
        )
    }
}

// MARK: - Lightweight UI helpers
private func showAlert(on vc: UIViewController, message: String) {
    let alert = UIAlertController(title: String(localized: "Error"), message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
    vc.present(alert, animated: true)
}

private func showToast(on vc: UIViewController, message: String, duration: TimeInterval = 1.3) {
    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
    vc.present(alert, animated: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) { alert.dismiss(animated: true) }
}

// MARK: - topMost helper (module-wide)
extension UIApplication {
    static func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first) -> UIViewController? {
        if let nav = base as? UINavigationController { return topMostViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController { return tab.selectedViewController.flatMap { topMostViewController(base: $0) } }
        if let presented = base?.presentedViewController { return topMostViewController(base: presented) }
        return base
    }
}
