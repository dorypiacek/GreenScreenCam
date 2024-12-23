//
//  GreenScreenCamApp.swift
//  GreenScreenCam
//
//  Created by Dory on 16/10/2023.
//

import Combine
import SwiftUI
import SystemExtensions

@main
struct GreenScreenCamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 1200, maxWidth: .infinity, minHeight: 700, maxHeight: .infinity)
                .onAppear {
                    ExtensionManager.shared.install()
                }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
