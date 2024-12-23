//
//  Virtual_CameraProvider.swift
//  Virtual Camera
//
//  Created by Dory on 04/10/2024.
//

import Foundation
import CoreMediaIO
import IOKit.audio
import os.log

let kFrameRate: Int = 60

class VirtualCameraProviderSource: NSObject, CMIOExtensionProviderSource {
    
    private(set) var provider: CMIOExtensionProvider!
    
    private var deviceSource: VirtualCameraDeviceSource!
    
    // CMIOExtensionProviderSource protocol methods (all are required)
    
    init(clientQueue: DispatchQueue?) {
        
        super.init()
        
        provider = CMIOExtensionProvider(source: self, clientQueue: clientQueue)
        
        deviceSource = VirtualCameraDeviceSource(localizedName: IDs.cameraModelID)
        
        do {
            try provider.addDevice(deviceSource.device)
        } catch let error {
            fatalError("Failed to add device: \(error.localizedDescription)")
        }
    }
    
    func connect(to client: CMIOExtensionClient) throws {
        
        // Handle client connect
    }
    
    func disconnect(from client: CMIOExtensionClient) {
        
        // Handle client disconnect
    }
    
    var availableProperties: Set<CMIOExtensionProperty> {
        
        // See full list of CMIOExtensionProperty choices in CMIOExtensionProperties.h
        return [.providerManufacturer]
    }
    
    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        
        let providerProperties = CMIOExtensionProviderProperties(dictionary: [:])
        if properties.contains(.providerManufacturer) {
            providerProperties.manufacturer = IDs.cameraManufacturer
        }
        return providerProperties
    }
    
    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {
        
        // Handle settable properties here.
    }
}
