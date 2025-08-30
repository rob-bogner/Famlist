// QRCodeView.swift
// Extracted from original SessionGateView.swift. Includes internal QRCodeGenerator helper.
import SwiftUI
import CoreImage
import CoreGraphics

struct QRCodeView: View {
    let text: String
    var body: some View {
        if let cg = QRCodeGenerator.cgImage(from: text) {
            Image(decorative: cg, scale: 1, orientation: .up)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else { EmptyView() }
    }
}

// Internal helper scoped to this file
enum QRCodeGenerator {
    static let context = CIContext(options: nil)
    static func cgImage(from string: String) -> CGImage? {
        guard let data = string.data(using: .utf8), let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let scaleX: CGFloat = 8, scaleY: CGFloat = 8
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let rect = transformed.extent.integral
        return context.createCGImage(transformed, from: rect)
    }
}

#if DEBUG
#Preview("QR") {
    QRCodeView(text: "gg://pair/ABCD1")
        .frame(width: 160, height: 160)
        .padding()
}
#endif
