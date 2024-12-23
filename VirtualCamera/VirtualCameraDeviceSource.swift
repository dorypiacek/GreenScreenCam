//
//  VirtualCameraDeviceSource.swift
//  Virtual Camera
//
//  Created by Dory on 04/10/2024.
//

import Cocoa
import CoreImage
import CoreMediaIO
import Foundation
import os.log

class VirtualCameraDeviceSource: NSObject, CMIOExtensionDeviceSource {
    private(set) var device: CMIOExtensionDevice!
    private var _streamSource: VirtualCameraStreamSource!
    private var _streamSink: VirtualCameraStreamSinkSource!
    private var _streamingCounter: UInt32 = 0
    private var _streamingSinkCounter: UInt32 = 0
    private var _timer: DispatchSourceTimer?
    private let _timerQueue = DispatchQueue(label: "timerQueue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .workItem, target: .global(qos: .userInteractive))
    private var _videoDescription: CMFormatDescription!
    private var _bufferPool: CVPixelBufferPool!
    private var _bufferAuxAttributes: NSDictionary!
    
    private var sinkStarted = false
    private var lastTimingInfo = CMSampleTimingInfo()
    
    private let dims = CMVideoDimensions(width: 1920, height: 1080)
    
    private lazy var logger = Logger(subsystem: IDs.extensionBundleID, category: "Extension")
    
    init(localizedName: String) {
        super.init()
        let deviceID = UUID()
        let deviceUID = IDs.extensionBundleID
        self.device = CMIOExtensionDevice(
            localizedName: localizedName,
            deviceID: deviceID,
            legacyDeviceID: deviceUID,
            source: self
        )
        
        CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCVPixelFormatType_32BGRA, width: dims.width, height: dims.height, extensions: nil, formatDescriptionOut: &_videoDescription)
        
        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: dims.width,
            kCVPixelBufferHeightKey: dims.height,
            kCVPixelBufferPixelFormatTypeKey: _videoDescription.mediaSubType,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as NSDictionary
        ]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &_bufferPool)
        
        let videoStreamFormat = CMIOExtensionStreamFormat.init(formatDescription: _videoDescription, maxFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), minFrameDuration: CMTime(value: 1, timescale: Int32(kFrameRate)), validFrameDurations: nil)
        _bufferAuxAttributes = [kCVPixelBufferPoolAllocationThresholdKey: 5]
        
        let videoID = UUID() // replace this with your video UUID
        _streamSource = VirtualCameraStreamSource(localizedName: IDs.cameraModelID, streamID: videoID, streamFormat: videoStreamFormat, device: device)
        let videoSinkID = UUID()
        _streamSink = VirtualCameraStreamSinkSource(localizedName: IDs.cameraModelID, streamID: videoSinkID, streamFormat: videoStreamFormat, device: device)
        do {
            try device.addStream(_streamSource.stream)
            try device.addStream(_streamSink.stream)
        } catch let error {
            fatalError("Failed to add stream: \(error.localizedDescription)")
        }
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        
        return [.deviceTransportType, .deviceModel, .providerManufacturer]
    }
    
    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let deviceProperties = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceTransportType) {
            deviceProperties.transportType = kIOAudioDeviceTransportTypeVirtual
        }
        if properties.contains(.deviceModel) {
            deviceProperties.model = IDs.cameraModelID
        }
        
        if properties.contains(.providerManufacturer) {
            deviceProperties.model = IDs.cameraManufacturer
        }
        
        return deviceProperties
    }
    
    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {}
    
    func startStreaming() {
        guard let _ = _bufferPool else {
            return
        }
        
        _streamingCounter += 1
        _timer = DispatchSource.makeTimerSource(flags: .strict, queue: _timerQueue)
        _timer!.schedule(deadline: .now(), repeating: 1.0/Double(kFrameRate), leeway: .seconds(0))
        
        _timer!.setEventHandler { [weak self] in
            guard let self, !sinkStarted else { return }
            
            var timingInfo = CMSampleTimingInfo()
            timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
            if let sampleBuffer = self.createSampleBuffer(timingInfo: timingInfo) {
                self._streamSource.stream.send(
                    sampleBuffer,
                    discontinuity: [],
                    hostTimeInNanoseconds: UInt64(timingInfo.presentationTimeStamp.seconds * Double(NSEC_PER_SEC))
                )
            }
        }
        
        _timer!.resume()
    }
    
    func stopStreaming() {
        _streamingCounter = max(0, _streamingCounter - 1)
        if _streamingCounter == 0 {
            if let timer = _timer {
                timer.cancel()
                _timer = nil
            }
        }
    }
    
    func startStreamingSink(client: CMIOExtensionClient) {
        _streamingSinkCounter += 1
        sinkStarted = true
        consumeBuffer(client)
    }
    
    func stopStreamingSink() {
        sinkStarted = false
        _streamingSinkCounter =  max(0, _streamingSinkCounter - 1)
    }
    
    func consumeBuffer(_ client: CMIOExtensionClient) {
        guard sinkStarted else {
            return
        }
        
        _streamSink.stream.consumeSampleBuffer(from: client) { [weak self] sbuf, seq, discontinuity, hasMoreSampleBuffers, err in
            guard let self else { return }
            if sbuf != nil {
                self.lastTimingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
                let output: CMIOExtensionScheduledOutput = CMIOExtensionScheduledOutput(sequenceNumber: seq, hostTimeInNanoseconds: UInt64(self.lastTimingInfo.presentationTimeStamp.seconds * Double(NSEC_PER_SEC)))
                if self._streamingCounter > 0 {
                    self._streamSource.stream.send(sbuf!, discontinuity: [], hostTimeInNanoseconds: UInt64(sbuf!.presentationTimeStamp.seconds * Double(NSEC_PER_SEC)))
                }
                self._streamSink.stream.notifyScheduledOutputChanged(output)
            }
            self.consumeBuffer(client)
        }
    }
    
}

private extension VirtualCameraDeviceSource {
    private func createSampleBuffer(timingInfo: CMSampleTimingInfo) -> CMSampleBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
            kCFAllocatorDefault,
            self._bufferPool,
            self._bufferAuxAttributes,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            logger.error("Failed to create pixel buffer")
            return nil
        }
        
        // Fill the pixel buffer with the placeholder content
        fillPixelBuffer(pixelBuffer)
        
        // Use existing _videoDescription
        guard let formatDescription = self._videoDescription else {
            logger.error("Format description missing")
            return nil
        }
        
        var timing = timingInfo
        // Create the CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        let sampleBufferStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        
        guard sampleBufferStatus == noErr, let buffer = sampleBuffer else {
            logger.error("Failed to create sample buffer")
            return nil
        }
        
        return buffer
    }
    
    private func fillPixelBuffern(_ pixelBuffer: CVPixelBuffer) {
        // Lock the pixel buffer for writing
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            logger.error("Failed to get base address of pixel buffer")
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Set up text attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let textFontAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 36),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let text = "Open GreenScreenCam app to start streaming"
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            logger.error("Failed to create CGContext")
            return
        }
        
        // Create an NSGraphicsContext without flipping
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        
        let cgContext = graphicsContext.cgContext
        
        // Flip the coordinate system vertically
        cgContext.translateBy(x: 0, y: CGFloat(height))
        
        // Clear the context and fill with black color
        let dstRect = CGRect(x: 0, y: 0, width: width, height: height)
        cgContext.clear(dstRect)
        cgContext.setFillColor(NSColor.magenta.cgColor)
        cgContext.fill(dstRect)
        
        // Calculate the size and position of the text
        let textSize = text.size(withAttributes: textFontAttributes)
        let textOrigin = CGPoint(
            x: (CGFloat(width) - textSize.width) / 2,
            y: (CGFloat(height) - textSize.height) / 2
        )
        let textRect = CGRect(origin: textOrigin, size: textSize)
        
        // Draw the text
        text.draw(in: textRect, withAttributes: textFontAttributes)
        
        NSGraphicsContext.restoreGraphicsState()
    }

    private func fillPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            logger.error("Failed to get base address of pixel buffer")
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center
        
        let textSize: CGFloat = 46
        let textFontAttributes = [
            NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: textSize),
            NSAttributedString.Key.foregroundColor: NSColor.white,
            NSAttributedString.Key.paragraphStyle: paragraphStyle
        ]
        
        let text = "Open GreenScreenCam app to start streaming"
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        if let context {
            let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphicsContext
            
            let cgContext = graphicsContext.cgContext
            let dstRect = CGRect(x: 0, y: 0, width: width, height: height)
            
            cgContext.clear(dstRect)
            cgContext.setFillColor(NSColor.black.cgColor)
            cgContext.fill(dstRect)
            
            let textOrigin = CGPoint(x: 0, y: -height/2 + Int(textSize/2.0))
            
            // Flip the context vertically
            context.translateBy(x: CGFloat(width), y: 0)
            context.scaleBy(x: -1.0, y: 1.0)

            // Calculate textRect as before
            let textRect = CGRect(
                x: 0,
                y: (CGFloat(height) - textSize) / 2,
                width: CGFloat(width),
                height: textSize * 2
            )
            
            text.draw(in: textRect, withAttributes: textFontAttributes)
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
