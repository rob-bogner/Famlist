// filepath: GroceryGenius/Extensions/DeepLinkParser.swift
// MARK: - DeepLinkParser

import Foundation

struct DeepLinkParser {
    /// Extracts a pairing code from a URL with scheme gg://pair/<CODE>
    static func pairCode(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "gg", url.host?.lowercased() == "pair" else { return nil }
        return url.lastPathComponent.uppercased()
    }
}
