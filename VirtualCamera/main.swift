//
//  main.swift
//  Virtual Camera
//
//  Created by Dory on 04/10/2024.
//

import Foundation
import CoreMediaIO

let providerSource = VirtualCameraProviderSource(clientQueue: nil)

CMIOExtensionProvider.startService(provider: providerSource.provider)

CFRunLoopRun()
