//
//  CameraManager.swift
//  DressMe
//
//  Created by Francesco Granozio on 08/09/25.
//

import AVFoundation
import CoreImage
import UIKit

/// Manages the camera capture session and delivers frames to the UI.
final class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext()

    /// Called when a new frame is available. Always invoked on the main thread.
    var onFrame: ((CGImage) -> Void)?

    @Published var isAuthorized: Bool = false

    override init() {
        super.init()
        configureSession()
    }

    /// Sets up camera authorization, input, and output.
    private func configureSession() {
        session.sessionPreset = .high

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                DispatchQueue.main.async { self.isAuthorized = true }
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async { self.isAuthorized = granted }
                }
            default:
                DispatchQueue.main.async { self.isAuthorized = false }
            }

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }

            do {
                self.session.beginConfiguration()

                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) { self.session.addInput(input) }

                self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.queue"))
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                if self.session.canAddOutput(self.videoOutput) { self.session.addOutput(self.videoOutput) }

                if let connection = self.videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                }

                self.session.commitConfiguration()
            } catch {
                print("Camera session configuration failed: \(error)")
            }
        }
    }

    /// Starts the capture session on a background queue.
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    /// Stops the capture session on a background queue.
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var cgImage: CGImage?
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)

        if let cgImage = cgImage {
            DispatchQueue.main.async { [weak self] in
                self?.onFrame?(cgImage)
            }
        }
    }
}


