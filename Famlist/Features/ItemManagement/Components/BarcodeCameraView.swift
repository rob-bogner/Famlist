/*
 BarcodeCameraView.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kameravorschau mit Barcode-Erkennung über VisionKit `DataScannerViewController` (EAN-8, EAN-13, UPC-E).

 🔰 Notes for Beginners:
 - Das Design-UI (Rahmen, Knöpfe, Ergebniskarte) liegt in BarcodeScanSheet ÜBER dieser Vorschau.
 - DataScanner braucht ein echtes Gerät (A12 oder neuer). Im Simulator ist `isSupported` false;
   dann zeigt BarcodeScanSheet den dunklen Design-Hintergrund mit Hinweis.
 - Jeder neue Code wird nur einmal gemeldet; `isPaused` stoppt die Meldungen, solange eine Karte offen ist.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 3).
 ------------------------------------------------------------------------
 */

import SwiftUI
import VisionKit
import AVFoundation

struct BarcodeCameraView: UIViewControllerRepresentable {
    /// true = keine Meldungen (Karte „Artikel erkannt“ ist offen).
    var isPaused: Bool
    var torchOn: Bool
    let onCode: (String) -> Void

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
        Self.setTorch(torchOn)
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
        setTorch(false)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    /// Taschenlampe der Rückkamera (Knopf „Licht“ oben rechts).
    static func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch,
              (device.torchMode == .on) != on else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: BarcodeCameraView

        init(parent: BarcodeCameraView) { self.parent = parent }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !parent.isPaused else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let code = barcode.payloadStringValue, !code.isEmpty {
                    parent.onCode(code)
                    return
                }
            }
        }
    }
}
