//
//  DeviceManager.swift
//  GreenScreenCam
//
//  Created by Dory on 16/10/2023.
//

import Combine
import Foundation
import AVFoundation

// MARK: - Protocol Declaration

/// A delegate protocol for receiving video frames from `AVManager`.
protocol AVManagerDelegate: AnyObject {
    /// Called when `AVManager` outputs a new video frame.
    /// - Parameters:
    ///   - manager: The `AVManager` instance.
    ///   - sampleBuffer: The new video frame as a `CMSampleBuffer`.
    func avManager(_ manager: AVManager, didOutput sampleBuffer: CMSampleBuffer)
}

/// A singleton manager responsible for setting up and controlling AV capture sessions,
/// handling device selection, permissions, and video/photo capture.
///
/// This class observes and publishes state changes about the capture devices, permissions,
/// and capture states, making it easy to integrate with SwiftUI.
@MainActor
final class AVManager: NSObject, ObservableObject {
    // MARK: - Nested Types
    
    /// Represents the current permission state for camera and microphone access.
    enum PermissionState {
        case initial, authorized, denied
    }

    // MARK: - Public Properties
    
    /// The shared singleton instance of `AVManager`.
    static let shared = AVManager()
    
    /// The delegate to receive video sample buffers.
    weak var delegate: AVManagerDelegate?
    
    /// The main `AVCaptureSession` used for video and audio capture.
    let captureSession = AVCaptureSession()

    /// Available devices to select from
    @Published var devices: [AVCaptureDevice] = []

    /// The currently selected camera device.
    @Published var selectedDevice: AVCaptureDevice?
    
    /// State of user permissions
    @Published var permissionState: PermissionState = .initial
    
    // MARK: - Private Properties
    
    /// Returns `true` if both audio and video permissions are granted.
    private var isAuthorized: Bool {
        get async {
            return await permissionStatus(for: .video)
        }
    }
    
    private let videoDataOutput = AVCaptureVideoDataOutput()

    // MARK: - Initializer
    
    private override init() {
        super.init()
        devices = AVDiscovery.devicesWithoutExtension()
    }

    // MARK: - Setup Methods
    
    /// Sets up the capture session by requesting permissions, choosing devices,
    /// configuring inputs/outputs, and starting the session.
    func setup() async {
        guard await isAuthorized else {
            permissionState = .denied
            return
        }
        
        selectedDevice = AVCaptureDevice.default(for: .video)
        
        captureSession.beginConfiguration()
        
        if let selectedDevice {
            // Attempt to add camera input.
            do {
                let cameraInput = try AVCaptureDeviceInput(device: selectedDevice)
                
                if captureSession.canAddInput(cameraInput) {
                    captureSession.addInput(cameraInput)
                }
                
                // Configure video data output for sample buffer delegation.
                if captureSession.canAddOutput(videoDataOutput) {
                    let settings: [String: Any] = [
                        String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
                    ]
                    videoDataOutput.videoSettings = settings
                    videoDataOutput.alwaysDiscardsLateVideoFrames = true
                    videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
                    
                    captureSession.addOutput(videoDataOutput)
                }
            } catch {
                NSLog("Error configuring inputs: \(error.localizedDescription)")
            }
        }
        
        captureSession.commitConfiguration()
        permissionState = .authorized
        
        #if os(macOS)
        // On macOS, just start running the session.
        captureSession.startRunning()
        #else
        // On iOS, start the session off the main thread.
        DispatchQueue.global().async { [weak self] in
            self?.captureSession.startRunning()
        }
        #endif
    }
    
    // MARK: - Camera Selection
    
    /// Selects a specific camera device and updates formats, codecs, and the capture session.
    func select(camera: AVCaptureDevice) {
        selectedDevice = camera
        
        if let selectedDevice {
            if let cameraInput = try? AVCaptureDeviceInput(device: selectedDevice) {
                captureSession.beginConfiguration()
                
                // Remove existing camera input.
                if let currentCameraInput = captureSession.inputs
                    .compactMap({ $0 as? AVCaptureDeviceInput })
                    .first(where: { $0.device.hasMediaType(.video) }) {
                    captureSession.removeInput(currentCameraInput)
                }
                
                // Add the new camera input if possible.
                if captureSession.canAddInput(cameraInput) {
                    captureSession.addInput(cameraInput)
                }
                
                captureSession.commitConfiguration()
            }
        }
    }
    
    // MARK: - Device Monitoring
    
    /// Starts monitoring for device connection and disconnection events.
    func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceAdded(notif:)),
            name: NSNotification.Name.AVCaptureDeviceWasConnected,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceRemoved(notif:)),
            name: NSNotification.Name.AVCaptureDeviceWasDisconnected,
            object: nil
        )
    }

    /// Stops monitoring for device connection and disconnection events.
    func stopMonitoring() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.AVCaptureDeviceWasConnected,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.AVCaptureDeviceWasDisconnected,
            object: nil
        )
    }
}

// MARK: - Private Methods

private extension AVManager {
    /// Checks the authorization status for a given media type and requests it if necessary.
    /// - Parameter type: The media type to check (audio/video).
    /// - Returns: `true` if authorized, `false` otherwise.
    func permissionStatus(for type: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: type)
        case .authorized:
            return true
        default:
            return false
        }
    }

    /// Handles device addition events.
    @objc func deviceAdded(notif: NSNotification) {
        guard let device = notif.object as? AVCaptureDevice,
              AVDiscovery.devicesWithoutExtension().contains(device) else {
            return
        }

        devices.append(device)
    }

    /// Handles device removal events.
    @objc func deviceRemoved(notif: NSNotification) {
        guard let device = notif.object as? AVCaptureDevice else {
            return
        }

        let index = devices.firstIndex { $0.uniqueID == device.uniqueID }

        guard let index else { return }

        devices.remove(at: index)

        // If the removed device was the selected device, select another one if available.
        if device.uniqueID == selectedDevice?.uniqueID {
            DispatchQueue.main.async { [weak self] in
                if let nextDevice = self?.devices.first {
                    self?.select(camera: nextDevice)
                } else {
                    self?.selectedDevice = nil
                }
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension AVManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Called whenever a new video frame is captured.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.avManager(self, didOutput: sampleBuffer)
    }
}
