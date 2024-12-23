//
//  ImagePicker.swift
//  GreenScreenCam Mobile
//
//  Created by Dory on 11/10/2024.
//

import SwiftUI
import UIKit

// ImagePicker wrapper for UIImagePickerController
struct ImagePicker: UIViewControllerRepresentable {
    var didPick: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    // Coordinator class to handle UIImagePickerControllerDelegate
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.didPick(uiImage)
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            picker.modalPresentationStyle = .popover
            if let popoverController = picker.popoverPresentationController {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                                popoverController.sourceView = keyWindow.rootViewController?.view
                                popoverController.sourceRect = CGRect(x: keyWindow.bounds.midX, y: keyWindow.bounds.midY, width: 0, height: 0)
                                popoverController.permittedArrowDirections = []
                            }
            }
        }
        
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
