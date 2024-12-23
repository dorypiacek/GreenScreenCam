//
//  MainView.swift
//  GreenScreenCam
//
//  Created by Dory on 16/10/2023.
//

#if os(macOS)
import AppKit
#endif

import SwiftUI

struct MainView: View {
    private enum Params {
        static let placeholderButtonWidth: CGFloat = 300
        static let preferencesURL = "x-apple.systempreferences:com.apple.preference.security"
        static let sidebarMultiplier: CGFloat = 3.5
    }
    
    @State private var sidebarExpanded = true
    
    @StateObject private var manager = AVManager.shared
    @StateObject private var greenScreenManager = GreenScreenManager.shared
    
    var body: some View {
        VStack {
            GeometryReader { geo in
                ZStack(alignment: .bottomTrailing) {
                    if manager.permissionState == .authorized {
                        #if os(macOS)
                        videoView(geo: geo)
                            .scaleEffect(x: -1, y: 1)
                        #else
                        videoView(geo: geo)
                        #endif
                    } else if manager.permissionState == .denied {
                        placeholderView
                            .padding(.trailing, geo.size.width / Params.sidebarMultiplier)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    
                    ExpandableMenuView(manager: manager)
                            .frame(alignment: .bottomTrailing)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .task {
            await manager.setup()
        }
        .onAppear {
            manager.startMonitoring()
        }
        .onDisappear {
            manager.stopMonitoring()
        }
    }
    
    private func videoView(geo: GeometryProxy) -> some View {
        ZStack {
            CameraPreview()
                .frame(width: geo.size.width, height: geo.size.height)
            
            if greenScreenManager.isRunning {
                VirtualBackgroundView()
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
    
    #if os(macOS)
    private var sidebarView: some View {
        ZStack {
            VStack {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack {
                        CameraSelectionView(manager: AVManager.shared)
                            .padding(.bottom, Metrics.spacing)
                        
                        Divider()
                        
                        GreenScreenView()
                        
                        Divider()
                    }
                    .padding(.all, Metrics.padding.medium)
                    .padding(.bottom, Metrics.padding.large)
                }
            }
        }
        .background(.thickMaterial)
    }
    #elseif os(iOS)
    private var sidebarView: some View {
        ZStack {
            VStack {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack {
                        CameraSelectionView(manager: AVManager.shared)
                            .padding(.bottom, Metrics.spacing)
                        
                        Divider()
                        
                        GreenScreenView()
                        
                        Divider()
                    }
                    .padding(.all, Metrics.padding.medium)
                    .padding(.bottom, Metrics.padding.large)
                }
            }
        }
        .background(.thickMaterial)
    }
    #endif
    
    private var placeholderView: some View {
        VStack(alignment: .center, spacing: Metrics.spacing) {
            Text(Strings.misc.placeholderTitle)
                .multilineTextAlignment(.center)
                .font(.title)
            
            #if os(macOS)
            Button(Strings.misc.placeholderButton) {
                let prefpaneUrl = URL(string: Params.preferencesURL)!
                NSWorkspace.shared.open(prefpaneUrl)
            }
            .buttonStyle(PrimaryButtonStyle(icon: Icons.right))
            .frame(width: Params.placeholderButtonWidth)
            #endif
        }
        .padding(Metrics.padding.large)
        .transition(.opacity)
    }
}

// MARK: - Platform-specific code


