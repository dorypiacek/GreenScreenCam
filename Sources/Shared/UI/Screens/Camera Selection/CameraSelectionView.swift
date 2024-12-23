//
//  CameraSelectionView.swift
//  GreenScreenCam
//
//  Created by Dory on 16/10/2023.
//

import SwiftUI

struct CameraSelectionView: View {
    
    // MARK: - Private properties
    
    @State private var camSelection: String?

    @ObservedObject private var manager: AVManager
    
    init(manager: AVManager) {
        self.manager = manager
    }

    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .center, spacing: Metrics.spacing) {
            VStack(alignment: .leading) {
                DropdownView(
                    title: Strings.selection.camera,
                    selectedOption: $camSelection,
                    options: manager.devices.map { $0.localizedName }
                )
            }
            .onChange(of: camSelection) { newValue in
                if let camera = manager.devices.first(where: { $0.localizedName == newValue }), newValue != manager.selectedDevice?.localizedName {
                    manager.select(camera: camera)
                }
            }
        }
        .onChange(of: manager.selectedDevice) { newValue in
            camSelection = newValue?.localizedName
        }
        .onAppear {
            camSelection = manager.selectedDevice?.localizedName
        }
    }
}
