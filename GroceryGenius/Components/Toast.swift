// MARK: - Toast.swift
// Lightweight toast overlay shown at the top of the screen.

import SwiftUI

final class ToastManager: ObservableObject {
    @Published var isShowing: Bool = false
    @Published var message: String = ""

    func show(_ message: String, duration: TimeInterval = 3.0) {
        Task { @MainActor in
            self.message = message
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.isShowing = true }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.isShowing = false }
        }
    }
}

private struct ToastView: View {
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
            Text(text).foregroundColor(.white).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.75))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 8)
        .padding(.top, 12)
    }
}

struct ToastOverlay: ViewModifier {
    @ObservedObject var manager: ToastManager
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if manager.isShowing {
                ToastView(text: manager.message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(5)
            }
        }
    }
}

extension View {
    func toast(using manager: ToastManager) -> some View { self.modifier(ToastOverlay(manager: manager)) }
}
