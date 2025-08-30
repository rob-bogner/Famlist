// MARK: - ImagePicker.swift

/*
 File: ImagePicker.swift
 Project: GroceryGenius
 Created: 27.04.2025
 Last Updated: 17.08.2025

 Overview:
 SwiftUI wrapper around UIImagePickerController enabling photo capture or library selection with optional editing.

 Responsibilities / Includes:
 - Presents native picker (camera / photo library)
 - Delivers selected (edited or original) UIImage to binding
 - Handles cancellation cleanly

 Design Notes:
 - allowsEditing = true for basic crop; disable if full fidelity needed
 - Coordinator pattern bridges UIKit delegate back into SwiftUI
 - Binding for isPresented lets parent dismiss programmatically if desired

 Possible Enhancements:
 - Add PHPickerViewController path (modern photo picker) for multi-select
 - Add permission handling / user guidance on denial
 - Inject configuration (mediaTypes, quality settings)
*/

import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct ImagePicker: View {
    enum Source { case library, camera }
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    var sourceType: Source = .library

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        Group {
            switch sourceType {
            case .library:
                EmptyView()
                    .photosPicker(isPresented: $isPresented, selection: $pickerItem, matching: .images, preferredItemEncoding: .automatic)
                    .onChange(of: pickerItem) { _, newItem in
                        guard let item = newItem else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let ui = UIImage(data: data) { await MainActor.run { self.selectedImage = ui } }
                            await MainActor.run { self.isPresented = false }
                        }
                    }
            case .camera:
                CameraCaptureView(onCancel: { isPresented = false }) { ui in
                    selectedImage = ui
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - SwiftUI Camera using AVFoundation (no UIKit views)
private final class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    @Published var previewCGImage: CGImage?
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let context = CIContext()
    // Retain photo delegate until callback finishes
    private var photoDelegateRef: PhotoDelegate?

    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { session.commitConfiguration(); return }
        session.addInput(input)

        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.preview"))
        session.commitConfiguration()
        updateOrientation()
    }

    private func updateOrientation() {
        setRotation(on: videoOutput.connection(with: .video))
        setRotation(on: photoOutput.connection(with: .video))
    }
    private func setRotation(on connection: AVCaptureConnection?) {
        guard let conn = connection else { return }
        // Prefer 90° for portrait if supported; fall back to any supported angle close to 90°
        let preferredAngles: [NSNumber] = [90, 270, 0]
        if #available(iOS 17, *) {
            for num in preferredAngles {
                let deg = num.doubleValue
                if conn.isVideoRotationAngleSupported(deg) {
                    conn.videoRotationAngle = deg
                    return
                }
            }
        } else {
            if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
        }
    }

    func start() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.updateOrientation() }
        }
    }
    func stop() { guard session.isRunning else { return }; session.stopRunning() }

    // Capture still photo
    func capture(completion: @escaping (UIImage?) -> Void) {
        let settings = AVCapturePhotoSettings()
        let delegate = PhotoDelegate(onData: { data in
            if let data, let ui = UIImage(data: data) { completion(ui) } else { completion(nil) }
        }, onDone: { [weak self] in self?.photoDelegateRef = nil })
        photoDelegateRef = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    // Live preview delegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: buffer)
        if let cg = context.createCGImage(ci, from: ci.extent) { DispatchQueue.main.async { self.previewCGImage = cg } }
    }

    // Photo delegate nesting to keep this class small
    private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        let onData: (Data?) -> Void
        let onDone: () -> Void
        init(onData: @escaping (Data?) -> Void, onDone: @escaping () -> Void) { self.onData = onData; self.onDone = onDone }
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            if let error { print("Camera capture error: \(error.localizedDescription)") }
            onData(photo.fileDataRepresentation())
            onDone()
        }
    }
}

private struct CameraPreview: View {
    @ObservedObject var manager: CameraManager
    var body: some View {
        ZStack {
            if let cg = manager.previewCGImage {
                Image(decorative: cg, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Color.black
            }
        }
        .onAppear { manager.start() }
        .onDisappear { manager.stop() }
    }
}

private struct CameraCaptureView: View {
    @StateObject private var manager = CameraManager()
    var onCancel: () -> Void
    var onCapture: (UIImage) -> Void

    var body: some View {
        ZStack {
            CameraPreview(manager: manager)
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                Spacer()
                Button(action: { manager.capture { if let ui = $0 { onCapture(ui) } else { onCancel() } } }) {
                    Circle().fill(Color.white).frame(width: 70, height: 70)
                        .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 2))
                        .shadow(radius: 2)
                        .contentShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .background(Color.clear.ignoresSafeArea())
        }
    }
}

#if DEBUG
private struct ImagePickerPreviewHost: View {
    @State private var img: UIImage? = nil
    @State private var show = false
    var body: some View {
        VStack(spacing: 12) {
            if let img { Image(uiImage: img).resizable().scaledToFit().frame(height: 120) }
            Button("Present Library") { show = true }
        }
        .sheet(isPresented: $show) {
            ImagePicker(selectedImage: $img, isPresented: $show, sourceType: .library)
        }
        .padding()
    }
}
#Preview("ImagePicker – Library") { ImagePickerPreviewHost() }
#endif
