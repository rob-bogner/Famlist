/*
 Logger.swift

 Famlist
 Created on: 07.09.2025
 Last updated on: 07.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lightweight logging helpers to record function parameters and results with source location.

 🛠 Includes:
 - stringifyParams helpers, redaction for sensitive keys, and logResult/logVoid functions.

 🔰 Notes for Beginners:
 - Use these functions to print concise, readable logs during development.
 - Sensitive fields like tokens or imageData are redacted in parameters automatically.

 📝 Last Change:
 - Initial addition of a small, dependency-free logger used by Supabase client and repositories.
 ------------------------------------------------------------------------
*/

import Foundation // Provides core types like Mirror and String used by the logger.

/// Builds a readable "name=value, ..." string from a tuple via Mirror.
private func stringifyParams<P>(_ params: P) -> String {
    // Updated to support tuples and dictionaries using describeValue for values
    let mirror = Mirror(reflecting: params)
    switch mirror.displayStyle {
    case .tuple:
        return mirror.children.compactMap { child -> String? in
            guard let label = child.label else { return nil }
            return "\(label)=\(describeValue(child.value))"
        }.joined(separator: ", ")
    case .dictionary:
        return describeValue(params)
    default:
        return describeValue(params)
    }
}

/// Redacts likely sensitive/large values by key name (extend if needed).
private func redactIfSensitive(_ key: String, value: Any) -> String {
    let k = key.lowercased()
    if k.contains("imagedata") || k.contains("token") || k.contains("password") || k.contains("key") {
        return "\(key)=<redacted>"
    }
    return "\(key)=\(describeValue(value))" // Use describeValue for nested structures
}

/// Stringify with redaction for labeled tuple children.
private func stringifyParamsWithRedaction<P>(_ params: P) -> String {
    // Updated to support tuples and dictionaries, leveraging describeValue for pretty-printing
    let mirror = Mirror(reflecting: params)
    switch mirror.displayStyle {
    case .tuple:
        return mirror.children.compactMap { child -> String? in
            guard let label = child.label else { return nil }
            return redactIfSensitive(label, value: child.value)
        }.joined(separator: ", ")
    case .dictionary:
        // Keys come from the dictionary; describeValue applies redaction per key
        return describeValue(params)
    default:
        return describeValue(params)
    }
}

/// Describes any value including Optional, Collections (Array/Set), and Dictionaries with redaction by key for dict entries.
private func describeValue(_ value: Any) -> String {
    // Optional unwrap handling
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
        if let child = mirror.children.first { // Non-nil optional
            return describeValue(child.value) // Recurse into wrapped value
        } else {
            return "nil" // Nil optional
        }
    }
    // Collections: Array / Set (ordered output)
    if mirror.displayStyle == .collection || mirror.displayStyle == .set {
        let elements = mirror.children.map { String(describing: $0.value) } // Describe each element
        return "[\(elements.joined(separator: ", "))]" // Join with commas
    }
    // Dictionary: pretty print key=value pairs with redaction by key
    if mirror.displayStyle == .dictionary {
        let pairs = mirror.children.compactMap { pairChild -> String? in
            // Each dictionary child is a (key: K, value: V) tuple
            let pairChildren = Mirror(reflecting: pairChild.value).children // Access (key, value)
            guard let keyChild = pairChildren.first, // Key element
                  let valueChild = pairChildren.dropFirst().first // Value element
            else { return nil }
            let keyStr = String(describing: keyChild.value) // Convert key to string
            return redactIfSensitive(keyStr, value: valueChild.value) // Apply redaction using key
        }
        return "{\(pairs.joined(separator: ", "))}" // Wrap in braces
    }
    // Default fallback for all other types
    return String(describing: value)
}

/// Logs a function result with function name and source location.
@discardableResult
func logResult<T, P>(
    _ function: StaticString = #function,
    file: StaticString = #fileID,
    line: UInt = #line,
    params: P,
    result: T
) -> T {
    let paramsStr = stringifyParamsWithRedaction(params)
    print("[LOG] \(function) @\(file):\(line) [\(paramsStr)] → \(String(describing: result))")
    return result
}

/// Convenience overload if there are no parameters to log.
@discardableResult
func logResult<T>(
    _ function: StaticString = #function,
    file: StaticString = #fileID,
    line: UInt = #line,
    result: T
) -> T {
    print("[LOG] \(function) @\(file):\(line) → \(String(describing: result))")
    return result
}

/// Logs completion of a Void function with parameters.
func logVoid<P>(
    _ function: StaticString = #function,
    file: StaticString = #fileID,
    line: UInt = #line,
    params: P
) {
    let paramsStr = stringifyParamsWithRedaction(params)
    print("[LOG] \(function) @\(file):\(line) [\(paramsStr)] → Void")
}

/// Convenience overload for Void functions without parameters.
func logVoid(
    _ function: StaticString = #function,
    file: StaticString = #fileID,
    line: UInt = #line
) {
    print("[LOG] \(function) @\(file):\(line) → Void")
}
