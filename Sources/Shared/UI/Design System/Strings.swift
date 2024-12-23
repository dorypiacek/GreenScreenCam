//
//  Strings.swift
//  GreenScreenCam
//
//  Created by Dory on 16/10/2023.
//

import Foundation

struct Strings {
    static let selection = CameraSelection()
    static let greenScreen = GreenScreen()
    static let misc = Misc()
}

struct CameraSelection {
    let camera = "Select camera"
    let microphone = "Select microphone"
}

struct GreenScreen {
    let title = "Green screen"
    let enable = "Enable green screen"
    let disable = "Disable green screen"
    let blur = "Blur background"
    let background = "Select background:"
    let uploadImage = "Upload Image"
    let reset = "Reset green screen settings"
}

struct Misc {
    let placeholderTitle = "This app needs camera and microphone permissions in order to show, edit and capture video output. Please grant this permission in System Preferences."
    let placeholderButton = "Open System Preferences"
}
