//
//  VirtualCameraManager.swift
//  GreenScreenCam
//
//  Created by Dory on 22/11/2023.
//

import SystemExtensions

/// Manages the virtual camera system extension, handling activation, deactivation and updates
final class ExtensionManager: NSObject {
    
    // MARK: - Public properties
    
    static let shared = ExtensionManager()
    
    // MARK: - Private properties
    
    private override init() {}
    
    // MARK: - Public methods
    
    func install() {
        let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: IDs.extensionBundleID, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    func uninstall() {
        let request = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: IDs.extensionBundleID, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}

// MARK: - OSSystemExtensionRequestDelegate

extension ExtensionManager: OSSystemExtensionRequestDelegate {
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        NSLog("Replacing system extension: \(existing) with: \(ext)")
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        NSLog("System extension request needs user approval: \(request)")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        NSLog("System extension request finished with result: \(result)")
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        NSLog("System extension request failed with error: \(error.localizedDescription)")
    }
}
