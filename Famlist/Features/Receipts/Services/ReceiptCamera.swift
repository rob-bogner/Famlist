/*
 ReceiptCamera.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Rückkamera für „Kassenzettel“: Vorschau, Foto aufnehmen, Licht (Taschenlampe).

 🔰 Notes for Beginners:
 - Die Kamera ist eine Systemkomponente; das Design-UI (Sucher, Knöpfe) liegt in ReceiptCaptureView darüber.
 - Die Session läuft auf einer eigenen Warteschlange (startRunning blockiert sonst die Oberfläche).
 - Im Simulator gibt es keine Kamera → `isAvailable` false; Fotos können dann aus der Mediathek kommen.
 - Kamera-Berechtigung: NSCameraUsageDescription (Build-Setting), Text in PLAN.md §9.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import AVFoundation
import UIKit

final class ReceiptCamera: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "famlist.receiptCamera")
    private var continuation: CheckedContinuation<UIImage?, Never>?

    static var isAvailable: Bool { AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil }

    /// Fragt die Berechtigung an und startet die Vorschau.
    func start() async -> Bool {
        guard Self.isAvailable else { return false }
        guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
        queue.async { [self] in
            if session.inputs.isEmpty, let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device) {
                session.beginConfiguration()
                session.sessionPreset = .photo
                if session.canAddInput(input) { session.addInput(input) }
                if session.canAddOutput(output) { session.addOutput(output) }
                session.commitConfiguration()
            }
            if !session.isRunning { session.startRunning() }
        }
        return true
    }

    func stop() {
        setTorch(false)
        queue.async { [self] in if session.isRunning { session.stopRunning() } }
    }

    func capture() async -> UIImage? {
        guard session.isRunning else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            queue.async { [self] in
                output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

extension ReceiptCamera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        continuation?.resume(returning: image)
        continuation = nil
    }
}
