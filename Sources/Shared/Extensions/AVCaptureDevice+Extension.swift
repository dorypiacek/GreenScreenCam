//
//  File.swift
//  GreenScreenCam
//
//  Created by Dory on 20/02/2024.
//

import AVFoundation

typealias AVDiscovery = AVCaptureDevice.DiscoverySession

extension AVCaptureDevice.DiscoverySession {
    public static func devicesWithoutExtension() -> [AVCaptureDevice] {
        #if os(macOS)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .deskViewCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        #elseif os(iOS)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera, .builtInDualCamera],
            mediaType: .video,
            position: .unspecified
        )
        #endif
        let devices = discoverySession.devices
        return devices.filter({ $0.localizedName != Identifiers.cameraModelID && $0.localizedName.range(of: "virtual", options: .caseInsensitive) == nil })
    }
}
