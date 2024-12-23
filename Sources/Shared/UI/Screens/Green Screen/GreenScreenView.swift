//
//  GreenScreenView.swift
//  GreenScreenCam
//
//  Created by Dory on 25/10/2023.
//

import CoreGraphics
import SwiftUI

struct GreenScreenView: View {
    @State var backgroundImage: Image? = nil
    @State private var showImagePicker = false
    
    @StateObject var manager = GreenScreenManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.padding.small) {
            toggleView(
                title: manager.isEnabled
                       ? Strings.greenScreen.disable
                       : Strings.greenScreen.enable, 
                value: $manager.isEnabled
            )
            
            toggleView(
                title: Strings.greenScreen.blur,
                value: $manager.backgroundBlur
            )
            
            Divider()
            
            uploadView
                .padding(.top, Metrics.padding.small)
        }
    }
    
    private var uploadButton: some View {
        Group {
            if let image = manager.selectedImage {
                UploadButton(
                    title: Strings.greenScreen.background,
                    image: Image(image, scale: 1.0, label: Text("")),
                    buttonTitle: Strings.greenScreen.uploadImage
                ) {
                    selectImage()
                }
            } else {
                UploadButton(
                    title: Strings.greenScreen.background,
                    image: Icons.photo,
                    buttonTitle: Strings.greenScreen.uploadImage
                ) {
                    selectImage()
                }
            }
        }
    }
    
    private func toggleView(title: String, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            HStack {
                Text(title)
                Spacer()
            }
        }
        .toggleStyle(.switch)
        .tint(.purple)
        .frame(alignment: .leading)
    }
    
    private func reset() {
        backgroundImage = nil
        GreenScreenManager.shared.reset()
        showImagePicker = false
    }
}

// MARK: - Platform specific code

private extension GreenScreenView {
    #if os(macOS)
    var uploadView: some View {
        uploadButton
    }
    
    func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.urls.first, let nsImage = NSImage(contentsOf: url), let image = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                GreenScreenManager.shared.selectImage(image: image)
                backgroundImage = Image(image, scale: 1.0, label: Text(""))
            }
        }
    }
    #else
    var uploadView: some View {
        uploadButton
            .sheet(isPresented: $showImagePicker) {
                ImagePicker { image in
                    backgroundImage = Image(uiImage: image)
                    
                    if let cgImage = image.cgImage {
                        GreenScreenManager.shared.selectImage(image: cgImage)
                    }
                    
                    showImagePicker = false
                }
            }
    }
    
    func selectImage() {
        showImagePicker = true
    }
    #endif
}
