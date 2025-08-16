import SwiftUI

struct ModalHeader: View {
    let title: String
    let onClose: () -> Void
    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.theme.background)
                .frame(maxWidth: .infinity, alignment: .center)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(Color.theme.background)
                    .padding(6)
                    .background(Circle().fill(Color.theme.accent))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Wiederverwendbare Modal-View mit einheitlichem Header-Layout.
struct CustomModalView<Content: View>: View {
    let title: String
    let onClose: () -> Void
    let content: Content

    init(title: String, onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    Color.theme.accent
                        .frame(width: geometry.size.width, height: 52)
                        .ignoresSafeArea(.all, edges: .top)
                    ModalHeader(title: title, onClose: onClose)
                        .frame(height: 52)
                        .padding(.horizontal, 16)
                }
            }
            .frame(height: 52)
            content
        }
    }
}

#Preview {
    CustomModalView(title: "Modal Title", onClose: {}) {
        VStack {
            Text("Modal Content")
                .padding()
        }
    }
}
