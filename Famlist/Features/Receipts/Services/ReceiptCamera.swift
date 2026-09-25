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

/// `@unchecked Sendable`: Veränderlich ist nur `pending`, und das ausschließlich unter `lock`.
/// Session und Ausgabe werden nur auf `queue` konfiguriert (Apples Vorgabe für AVCaptureSession).
final class ReceiptCamera: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "famlist.receiptCamera")
    /// Wartende Aufnahmen je `AVCapturePhotoSettings.uniqueID`. Vorher gab es nur eine Wartestelle:
    /// Zwei schnelle Aufnahmen überschrieben sie, die erste wartete dann für immer (Audit 25.09.2026).
    private let lock = NSLock()
    private var pending: [Int64: CheckedContinuation<UIImage?, Never>] = [:]

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
        let settings = AVCapturePhotoSettings()
        return await withCheckedContinuation { continuation in
            lock.withLock { pending[settings.uniqueID] = continuation }
            queue.async { [self] in
                output.capturePhoto(with: settings, delegate: self)
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
        let waiting = lock.withLock { pending.removeValue(forKey: photo.resolvedSettings.uniqueID) }
        waiting?.resume(returning: image)
    }

    /// Letzter Rückruf jeder Aufnahme. Kam kein Bild (Fehler, Session gestoppt), endet das Warten mit nil.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        let waiting = lock.withLock { pending.removeValue(forKey: resolvedSettings.uniqueID) }
        waiting?.resume(returning: nil)
    }
}
