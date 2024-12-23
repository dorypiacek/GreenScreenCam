//
//  VideoPreviewView.swift
//  GreenScreenCam
//
//  Created by Dory on 16/10/2023.
//

import AVFoundation
import SwiftUI

// MARK: - macOS

#if os(macOS)
import AppKit

/// A SwiftUI wrapper for the macOS camera preview view.
struct CameraPreview: NSViewRepresentable {
    @ObservedObject var manager = AVManager.shared
    
    func makeNSView(context: Context) -> CameraPreviewInternal {
        // Create and return the internal NSView that will display the camera feed
        return CameraPreviewInternal(frame: .zero)
    }
    
    func updateNSView(_ nsView: CameraPreviewInternal, context: NSViewRepresentableContext<CameraPreview>) {
        // Currently no updates needed on state changes
    }
    
    static func dismantleNSView(_ nsView: CameraPreviewInternal, coordinator: ()) {
        // If needed, stop running the capture session here:
        // nsView.stopRunning()
    }
}

/// Internal NSView subclass responsible for rendering the camera feed on macOS.
class CameraPreviewInternal: NSView {
    private var captureSession = AVManager.shared.captureSession
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupPreviewLayer(captureSession)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Set up the AVCaptureVideoPreviewLayer to display the camera feed.
    private func setupPreviewLayer(_ captureSession: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        // The previewLayer's frame is set in layout()
    }
    
    override func layout() {
        super.layout()
        // Update the preview layer's frame whenever the view's layout changes
        previewLayer.frame = bounds
        
        // Ensure the preview layer is added as a sublayer
        if previewLayer.superlayer == nil {
            layer?.addSublayer(previewLayer)
        }
    }
    
    /// Stop running the capture session if it's currently active.
    func stopRunning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
}

// MARK: - iOS

#elseif os(iOS)
import UIKit

/// A SwiftUI wrapper for the iOS camera preview view.
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var manager = AVManager.shared
    
    func makeUIView(context: Context) -> CameraPreviewInternal {
        // Create and return the internal UIView that will display the camera feed
        return CameraPreviewInternal(frame: .zero)
    }
    
    func updateUIView(_ uiView: CameraPreviewInternal, context: Context) {
        // Currently no updates needed on state changes
    }
}

/// Internal UIView subclass responsible for rendering the camera feed on iOS.
class CameraPreviewInternal: UIView {
    private var captureSession = AVManager.shared.captureSession
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPreviewLayer(captureSession)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Set up the AVCaptureVideoPreviewLayer to display the camera feed.
    private func setupPreviewLayer(_ captureSession: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        
        // Optionally set any connection properties on the preview layer
        if let connection = previewLayer.connection {
            connection.videoRotationAngle = 0
        }
        // The previewLayer's frame is set in layoutSubviews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Update the preview layer's frame whenever the view's layout changes
        previewLayer.frame = bounds
        
        // Ensure the preview layer is added as a sublayer
        if previewLayer.superlayer == nil {
            layer.addSublayer(previewLayer)
        }
    }
    
    /// Stop running the capture session if it's currently active.
    func stopRunning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
}

#endif
