//
//  VirtualCameraStreamManager.swift
//  GreenScreenCam
//
//  Created by Dory on 07/11/2024.
//

import AVFoundation
import Cocoa
import CoreMediaIO
import os

/// Manages the virtual camera system stream and frame enqueueing for video processing.
final class VirtualCameraStreamManager: NSObject {
    static let shared = VirtualCameraStreamManager()
    
    // MARK: - Properties
    
    var deviceConnected = false
    
    private var readyToEnqueue = false
    private var enqueued = false
    private var videoDescription: CMFormatDescription!
    private var bufferPool: CVPixelBufferPool!
    private var bufferAuxAttributes: NSDictionary!
    private var sequenceNumber = 0
    
    private var sourceStream: CMIOStreamID?
    private var sinkStream: CMIOStreamID?
    private var sinkQueue: CMSimpleQueue?
    
    private var timer: Timer?
    private var propertyTimer: Timer?
    
    private let logger = Logger(subsystem: IDs.extensionBundleID, category: "StreamManager")

    private var currentFrame: CGImage?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        registerForDeviceNotifications()
        makeDevicesVisible()
        connectToCamera()
        setupTimers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
        propertyTimer?.invalidate()
    }
    
    // MARK: - Device and Stream Management
    
    /// Makes virtual camera devices visible to the system.
    private func makeDevicesVisible() {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: .global,
            mElement: .main
        )
        var allow: UInt32 = 1
        CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout.size(ofValue: allow)),
            &allow
        )
    }
    
    /// Connects to the virtual camera device.
    private func connectToCamera() {
        guard let device = getDevice(named: IDs.cameraModelID), let deviceID = getCMIODevice(uid: device.uniqueID) else { return }
        let streamIDs = getInputStreams(deviceID: deviceID)
        
        if streamIDs.count >= 2 {
            sinkStream = streamIDs[1]
            initSink(deviceID: deviceID, sinkStreamID: streamIDs[1])
        }
        
        if let firstStream = streamIDs.first {
            sourceStream = firstStream
        }
        
        deviceConnected = true
    }
    
    /// Initializes the sink stream for frame enqueueing.
    private func initSink(deviceID: CMIODeviceID, sinkStreamID: CMIOStreamID) {
        let dimensions = CMVideoDimensions(width: 1920, height: 1080)
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: dimensions.width,
            height: dimensions.height,
            extensions: nil,
            formatDescriptionOut: &videoDescription
        )
        
        let pixelBufferAttributes: NSDictionary = [
            kCVPixelBufferWidthKey: dimensions.width,
            kCVPixelBufferHeightKey: dimensions.height,
            kCVPixelBufferPixelFormatTypeKey: videoDescription.mediaSubType,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &bufferPool)
                
        let refCon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let pointerQueue = UnsafeMutablePointer<Unmanaged<CMSimpleQueue>?>.allocate(capacity: 1)
        let res = CMIOStreamCopyBufferQueue(sinkStreamID, { id, buffer, refcon in
            guard let refcon = refcon else { return }
            let manager = Unmanaged<VirtualCameraStreamManager>.fromOpaque(refcon).takeUnretainedValue()
            manager.readyToEnqueue = true
        }, refCon, pointerQueue)
        
        if res == noErr, let queue = pointerQueue.pointee {
            sinkQueue = queue.takeUnretainedValue()
            let startResult = CMIODeviceStartStream(deviceID, sinkStreamID) == noErr
            if startResult {
                logger.info("Sink stream started successfully.")
            } else {
                logger.error("Failed to start sink stream.")
            }
        } else {
            logger.error("Error initializing sink stream: \(res, privacy: .public).")
        }
    }
    
    // MARK: - Frame Enqueueing
    
    /// Enqueues a provided CGImage frame to the sink queue.
    /// - Parameters:
    ///   - queue: The CMSimpleQueue to enqueue the frame.
    ///   - image: The CGImage to enqueue.
    func enqueueFrame(with image: CGImage) {
        guard deviceConnected else { return }
        
        guard let sinkQueue, CMSimpleQueueGetCount(sinkQueue) < CMSimpleQueueGetCapacity(sinkQueue) else {
            logger.info("Queue is full. Dropping frame.")
            return
        }
        
        currentFrame = image
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
            kCFAllocatorDefault,
            bufferPool,
            bufferAuxAttributes,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            logger.error("Failed to create pixel buffer: \(status, privacy: .public)")
            return
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        if let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) {
            context.interpolationQuality = .high
            
            // Calculate the scale factor and draw rectangle for aspect fill
            let imageWidth = CGFloat(image.width)
            let imageHeight = CGFloat(image.height)
            let destinationWidth = CGFloat(width)
            let destinationHeight = CGFloat(height)
            
            let imageAspectRatio = imageWidth / imageHeight
            let destinationAspectRatio = destinationWidth / destinationHeight
            
            var drawRect: CGRect
            
            if imageAspectRatio > destinationAspectRatio {
                // Image is wider than destination
                let scaleFactor = destinationHeight / imageHeight
                let scaledWidth = imageWidth * scaleFactor
                let xOffset = (destinationWidth - scaledWidth) / 2
                drawRect = CGRect(x: xOffset, y: 0, width: scaledWidth, height: destinationHeight)
            } else {
                // Image is taller than destination
                let scaleFactor = destinationWidth / imageWidth
                let scaledHeight = imageHeight * scaleFactor
                let yOffset = (destinationHeight - scaledHeight) / 2
                drawRect = CGRect(x: 0, y: yOffset, width: destinationWidth, height: scaledHeight)
            }
            
            context.draw(image, in: drawRect)
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        
        let creationStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        if creationStatus == noErr, let sample = sampleBuffer {
            let retainedSample = Unmanaged.passRetained(sample).toOpaque()
            CMSimpleQueueEnqueue(sinkQueue, element: retainedSample)
        } else {
            logger.error("Failed to create sample buffer: \(creationStatus, privacy: .public)")
        }
    }

    
    // MARK: - Device Utilities
    
    /// Retrieves an AVCaptureDevice by name.
    /// - Parameter name: The name of the device.
    /// - Returns: The AVCaptureDevice if found.
    private func getDevice(named name: String) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices.first { $0.localizedName == name }
    }
    
    /// Retrieves the CMIOObjectID for a device with the given UID.
    /// - Parameter uid: The unique identifier of the device.
    /// - Returns: The CMIOObjectID if found.
    private func getCMIODevice(uid: String) -> CMIOObjectID? {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: .global,
            mElement: .main
        )
        var dataSize: UInt32 = 0
        CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        let numberOfDevices = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var deviceIDs = [CMIOObjectID](repeating: 0, count: numberOfDevices)
        CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &propertyAddress, 0, nil, dataSize, &dataSize, &deviceIDs)
        
        for deviceID in deviceIDs {
            var uidPropertyAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID),
                mScope: .global,
                mElement: .main
            )
            var uidSize: UInt32 = 0
            CMIOObjectGetPropertyDataSize(deviceID, &uidPropertyAddress, 0, nil, &uidSize)
            
            var deviceUID: CFString = "" as NSString
            CMIOObjectGetPropertyData(deviceID, &uidPropertyAddress, 0, nil, uidSize, &uidSize, &deviceUID)
            
            if String(deviceUID) == uid {
                return deviceID
            }
        }
        return nil
    }
    
    /// Retrieves input streams for a given device.
    /// - Parameter deviceID: The CMIODeviceID.
    /// - Returns: An array of CMIOStreamID.
    private func getInputStreams(deviceID: CMIODeviceID) -> [CMIOStreamID] {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyStreams),
            mScope: .global,
            mElement: .main
        )
        var dataSize: UInt32 = 0
        CMIOObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        
        let numberOfStreams = Int(dataSize) / MemoryLayout<CMIOStreamID>.size
        var streamIDs = [CMIOStreamID](repeating: 0, count: numberOfStreams)
        CMIOObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, dataSize, &dataSize, &streamIDs)
        
        return streamIDs
    }
    
    // MARK: - Notifications
    
    /// Registers for device connection notifications.
    private func registerForDeviceNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceConnected(_:)),
            name: .AVCaptureDeviceWasConnected,
            object: nil
        )
    }
    
    /// Handles device connection notifications.
    @objc private func handleDeviceConnected(_ notification: Notification) {
        if sourceStream == nil {
            connectToCamera()
        }
    }
    
    // MARK: - Timers
    
    /// Sets up timers for frame processing and property checking.
    private func setupTimers() {
        timer = Timer.scheduledTimer(timeInterval: 1/30.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        propertyTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(firePropertyTimer), userInfo: nil, repeats: true)
    }
    
    /// Timer callback for frame enqueueing.
    @objc private func fireTimer() {
        guard readyToEnqueue, let sinkQueue, enqueued == false else { return }
        enqueued = true
        readyToEnqueue = false
        
        if let frame = currentFrame {
            enqueueFrame(with: frame)
        }
    }
    
    /// Timer callback for property checking.
    @objc private func firePropertyTimer() {
        guard let sourceStream = sourceStream else { return }
        setJustProperty(streamID: sourceStream, newValue: "random")
        if let just = getJustProperty(streamID: sourceStream), just == "sc=1" {
            readyToEnqueue = true
        } else {
            readyToEnqueue = false
        }
    }
    
    // MARK: - Helper Methods
    
    /// Retrieves a property value from a stream.
    /// - Parameter streamID: The CMIOStreamID.
    /// - Returns: The property value as a String if it exists.
    private func getJustProperty(streamID: CMIOStreamID) -> String? {
        let selector = FourCharCode("just")
        var propertyAddress = CMIOObjectPropertyAddress(selector, .global, .main)
        guard CMIOObjectHasProperty(streamID, &propertyAddress) else { return nil }
        
        var dataSize: UInt32 = 0
        CMIOObjectGetPropertyDataSize(streamID, &propertyAddress, 0, nil, &dataSize)
        
        var name: CFString = "" as NSString
        CMIOObjectGetPropertyData(streamID, &propertyAddress, 0, nil, dataSize, &dataSize, &name)
        return name as String
    }
    
    /// Sets a property value for a stream.
    /// - Parameters:
    ///   - streamID: The CMIOStreamID.
    ///   - newValue: The new value to set.
    private func setJustProperty(streamID: CMIOStreamID, newValue: String) {
        let selector = FourCharCode("just")
        var propertyAddress = CMIOObjectPropertyAddress(selector, .global, .main)
        guard CMIOObjectHasProperty(streamID, &propertyAddress) else { return }
        
        var settable: DarwinBoolean = false
        CMIOObjectIsPropertySettable(streamID, &propertyAddress, &settable)
        guard settable.boolValue else { return }
        
        var dataSize: UInt32 = 0
        CMIOObjectGetPropertyDataSize(streamID, &propertyAddress, 0, nil, &dataSize)
        
        var newName: CFString = newValue as NSString
        CMIOObjectSetPropertyData(streamID, &propertyAddress, 0, nil, dataSize, &newName)
    }
    
}

// MARK: - FourCharCode Extension

extension FourCharCode: ExpressibleByStringLiteral {
    
    public init(stringLiteral value: StringLiteralType) {
        var code: FourCharCode = 0
        if value.count == 4, let data = value.data(using: .ascii), data.count == 4 {
            for byte in data {
                code = (code << 8) + FourCharCode(byte)
            }
        } else {
            print("Invalid FourCharCode string literal: \(value). Using '????'.")
            code = 0x3F3F3F3F // '????'
        }
        self = code
    }
    
    public var string: String? {
        let bytes: [CChar] = [
            CChar((self >> 24) & 0xFF),
            CChar((self >> 16) & 0xFF),
            CChar((self >> 8) & 0xFF),
            CChar(self & 0xFF),
            0
        ]
        return String(cString: bytes)
    }
}

// MARK: - CMIOObjectPropertyAddress Extension

extension CMIOObjectPropertyAddress {
    init(_ selector: CMIOObjectPropertySelector,
         _ scope: CMIOObjectPropertyScope = .anyScope,
         _ element: CMIOObjectPropertyElement = .anyElement) {
        self.init(mSelector: selector, mScope: scope, mElement: element)
    }
}

// MARK: - CMIOObjectPropertyScope Extension

extension CMIOObjectPropertyScope {
    static let global = CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal)
    static let anyScope = CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard)
    static let deviceInput = CMIOObjectPropertyScope(kCMIODevicePropertyScopeInput)
    static let deviceOutput = CMIOObjectPropertyScope(kCMIODevicePropertyScopeOutput)
    static let devicePlayThrough = CMIOObjectPropertyScope(kCMIODevicePropertyScopePlayThrough)
}

// MARK: - CMIOObjectPropertyElement Extension

extension CMIOObjectPropertyElement {
    static let main = CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    static let anyElement = CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
}
