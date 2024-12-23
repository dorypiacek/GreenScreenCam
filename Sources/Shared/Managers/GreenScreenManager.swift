//
//  GreenScreenManager.swift
//  GreenScreenCam
//
//  Created by Dory on 09/09/2024.
//

import AVFoundation
import Combine
import CoreImage
import CoreML
import Foundation
import Vision

/// Manages the real-time application of a virtual background or blurred background behind a person
/// in a camera feed using person segmentation via Vision and Core ML.
///
/// `GreenScreenManager` sets up a pipeline that receives frames from `AVManager`, segments the person
/// from the background, and optionally blends in a selected background image or a blurred version of the
/// original background. The class publishes a processed frame (`processedFrame`) that can be displayed
/// in a UI, and also supports a virtual camera output on macOS.
///
/// Usage:
/// - Enable green screen functionality by setting `isEnabled` to `true` and optionally providing a `selectedImage`
///   or enabling `backgroundBlur`.
/// - The class automatically starts and stops processing frames based on `isEnabled` and `backgroundBlur` states.
/// - Reset the manager state using `reset()` when done.
///
/// This class leverages Vision's `VNGeneratePersonSegmentationRequest` for segmentation and Core Image for
/// blending and optional blurring.
final class GreenScreenManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    /// A shared singleton instance for convenient access.
    static let shared = GreenScreenManager()
    
    /// A Boolean value indicating whether the green screen effect is enabled.
    /// When `true`, the manager attempts to run person segmentation if a background image or blur is available.
    @Published var isEnabled = false {
        willSet {
            isRunning = newValue == true && (selectedImage != nil || backgroundBlur)
        }
    }
    
    /// A Boolean value indicating whether to apply a blur to the background instead of using a selected image.
    /// When enabled, if `isEnabled` is also `true`, the manager will run and blur the original background
    /// rather than inserting a custom image, if no image is selected.
    @Published var backgroundBlur = false {
        willSet {
            isRunning = isEnabled && (newValue == true || selectedImage != nil)
        }
    }
    
    /// A Boolean value indicating whether the segmentation process is currently running.
    /// This depends on `isEnabled` and the presence of a background (image or blur).
    @Published var isRunning = false
    
    /// The currently processed frame as a `CGImage`, updated whenever a new segmented frame is ready.
    @Published var processedFrame: CGImage?
    
    /// An optional background image (as `CGImage`) to be placed behind the person. If not set,
    /// and `backgroundBlur` is enabled, a blurred version of the original background is used.
    @Published var selectedImage: CGImage?
    
    /// Indicates whether the segmentation request is currently processing a frame.
    private var isProcessing = false
    
    /// The Vision model used for person segmentation.
    private var model: VNCoreMLModel?
    
    /// The person segmentation request configured with the selected model.
    private var segmentationRequest: VNGeneratePersonSegmentationRequest
    
    /// A cached and scaled background `CIImage` to match the current video frame size.
    private var cachedScaledBackgroundImage: CIImage?
    
    /// A `CIContext` for performing Core Image operations efficiently.
    private let ciContext: CIContext
    
    /// Initializes the green screen manager, configuring the Core ML model and segmentation request,
    /// and setting up the `AVManager` delegate.
    private override init() {
        // Prefer a Metal device for CIContext if available.
        if let device = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: device)
        } else {
            self.ciContext = CIContext(options: nil)
        }
        
        self.segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest.qualityLevel = .balanced
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
        segmentationRequest.revision = VNGeneratePersonSegmentationRequestRevision1
        
        super.init()
        
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        model = try? VNCoreMLModel(for: DeepLabV3(configuration: config).model)
        
        // Assign self as the AVManager delegate on the main actor.
        Task { @MainActor in
            AVManager.shared.delegate = self
        }
    }
    
    // MARK: - Public Methods
    
    /// Selects a background image to be placed behind the person. If `isEnabled` is `true`,
    /// the pipeline starts running automatically.
    ///
    /// - Parameter image: The `CGImage` to use as the background.
    func selectImage(image: CGImage) {
        cachedScaledBackgroundImage = nil
        selectedImage = image
        
        if isEnabled {
            isRunning = true
        }
    }
    
    /// Resets the manager state and stops any ongoing segmentation process.
    /// This clears the selected image, processed frame, and cached images.
    func reset() {
        isEnabled = false
        isRunning = false
        isProcessing = false
        backgroundBlur = false
        processedFrame = nil
        selectedImage = nil
        cachedScaledBackgroundImage = nil
    }
    
    // MARK: - Private Methods
    
    /// Performs person segmentation on the given pixel buffer using the Vision model.
    /// Calls the completion handler with a mask `CVPixelBuffer` representing the segmented person.
    ///
    /// - Parameters:
    ///   - pixelBuffer: The pixel buffer containing the original video frame.
    ///   - completion: A closure called with the segmentation mask or `nil` if segmentation failed.
    private func performPersonSegmentation(on pixelBuffer: CVPixelBuffer, completion: @escaping (CVPixelBuffer?) -> Void) {
        guard model != nil else {
            completion(nil)
            return
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                try handler.perform([self.segmentationRequest])
                if let results = self.segmentationRequest.results?.first as? VNPixelBufferObservation {
                    completion(results.pixelBuffer)
                } else {
                    completion(nil)
                }
            } catch {
                print("Person segmentation error: \(error)")
                completion(nil)
            }
        }
    }
    
    /// Applies the virtual background (custom image or blur) behind the person using the segmentation mask.
    ///
    /// - Parameters:
    ///   - originalPixelBuffer: The pixel buffer of the original video frame.
    ///   - mask: The segmentation mask pixel buffer for the person.
    /// - Returns: A `CGImage` representing the combined image, or `nil` if blending failed.
    private func applyVirtualBackground(originalPixelBuffer: CVPixelBuffer, mask: CVPixelBuffer) -> CGImage? {
        #if os(iOS)
        let originalImage = CIImage(cvPixelBuffer: originalPixelBuffer).oriented(.downMirrored)
        let maskImage = CIImage(cvPixelBuffer: mask).oriented(.downMirrored)
        #else
        let originalImage = CIImage(cvPixelBuffer: originalPixelBuffer)
        let maskImage = CIImage(cvPixelBuffer: mask)
        #endif
        
        var bgImage: CIImage
        
        // Use the selected image if available, otherwise fall back to the original image.
        if selectedImage != nil {
            // Recompute cached background if the frame size changed.
            if cachedScaledBackgroundImage?.extent != originalImage.extent {
                cachedScaledBackgroundImage = nil
            }
            
            // Cache and scale background image if needed.
            if cachedScaledBackgroundImage == nil {
                cachedScaledBackgroundImage = cacheAndScaleBackgroundImage(with: originalImage)
            }
            
            guard let cachedScaledBackgroundImage else { return nil }
            bgImage = cachedScaledBackgroundImage
        } else {
            bgImage = originalImage
        }
        
        // Scale the mask to match the original image size.
        let scaledMaskImage = maskImage.transformed(
            by: CGAffineTransform(
                scaleX: originalImage.extent.width / maskImage.extent.width,
                y: originalImage.extent.height / maskImage.extent.height
            )
        )
        
        // Apply background blur if requested.
        if backgroundBlur {
            let originalExtent = bgImage.extent
            bgImage = bgImage
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 10])
                .cropped(to: originalExtent)
        }
        
        // Blend the original image with the background using the mask.
        let blendedImage = originalImage.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: bgImage,
            kCIInputMaskImageKey: scaledMaskImage
        ])
        
        return ciContext.createCGImage(blendedImage, from: blendedImage.extent)
    }
    
    /// Caches and scales the selected background image to fit the current video frame size,
    /// maintaining aspect ratio.
    ///
    /// - Parameter bufferImage: The `CIImage` representing the current frame from the camera.
    /// - Returns: A `CIImage` representing the scaled and cropped background image.
    private func cacheAndScaleBackgroundImage(with bufferImage: CIImage) -> CIImage? {
        guard let selectedImage else { return nil }
        
        let backgroundImage = CIImage(cgImage: selectedImage)
        
        let videoFrameSize = bufferImage.extent.size
        // Compute scale factor to fill the entire frame.
        let scale = max(videoFrameSize.width / backgroundImage.extent.width,
                        videoFrameSize.height / backgroundImage.extent.height)
        
        let scaledBackgroundImage = backgroundImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // Center the scaled background image over the video frame.
        let xOffset = (videoFrameSize.width - scaledBackgroundImage.extent.width) / 2
        let yOffset = (videoFrameSize.height - scaledBackgroundImage.extent.height) / 2
        
        let translatedBackgroundImage = scaledBackgroundImage.transformed(
            by: CGAffineTransform(translationX: xOffset, y: yOffset)
        )
        
        // Crop to the video frame size.
        let croppedBackgroundImage = translatedBackgroundImage.cropped(
            to: CGRect(origin: .zero, size: videoFrameSize)
        )
        
        #if os(macOS)
        // Flip the image horizontally for macOS compatibility.
        let flipTransform = CGAffineTransform(translationX: croppedBackgroundImage.extent.width, y: 0)
            .scaledBy(x: -1, y: 1)
        return croppedBackgroundImage.transformed(by: flipTransform)
        #else
        return croppedBackgroundImage
        #endif
    }
}

// MARK: - AVManagerDelegate

extension GreenScreenManager: AVManagerDelegate {
    /// Delegate method called whenever a new video frame is available.
    /// Processes the frame if `isRunning` is true and updates `processedFrame`.
    ///
    /// - Parameters:
    ///   - manager: The `AVManager` instance providing the frame.
    ///   - sampleBuffer: The `CMSampleBuffer` containing the video frame data.
    func avManager(_ manager: AVManager, didOutput sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), !isProcessing else {
            return
        }
        
        if isRunning {
            isProcessing = true
            
            performPersonSegmentation(on: pixelBuffer) { [weak self] mask in
                guard let self = self else { return }
                
                if let mask = mask {
                    let processedImage = self.applyVirtualBackground(originalPixelBuffer: pixelBuffer, mask: mask)
                    DispatchQueue.main.async {
                        self.processedFrame = processedImage
                    }
                    
                    self.isProcessing = false
                    
                    #if os(macOS)
                    if let processedImage {
                        VirtualCameraStreamManager.shared.enqueueFrame(with: processedImage)
                    }
                    #endif
                } else {
                    self.isProcessing = false
                }
            }
        } else {
            #if os(macOS)
            // If not running green screen processing, forward raw frames if virtual camera is connected.
            if VirtualCameraStreamManager.shared.deviceConnected {
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                if let frame = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                    VirtualCameraStreamManager.shared.enqueueFrame(with: frame)
                }
            }
            #endif
        }
    }
}

