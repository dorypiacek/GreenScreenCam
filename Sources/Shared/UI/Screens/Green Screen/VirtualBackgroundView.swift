//
//  VirtualBackgroundView.swift
//  GreenScreenCam
//
//  Created by Dory on 09/09/2024.
//

import SwiftUI

struct VirtualBackgroundView: View {
    @ObservedObject var manager = GreenScreenManager.shared
    
    var body: some View {
        Group {
            if let frame = manager.processedFrame {
                Image(frame, scale: 1.0, orientation: .up, label: Text("Processed Video"))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            }
        }
        .id(UUID())
        .transition(.opacity)
    }
}
