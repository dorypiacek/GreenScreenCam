//
//  Colors.swift
//  GreenScreenCam
//
//  Created by Dory on 10/12/2024.
//

import SwiftUI

struct Colors {
    static let accentColor = Color(.purple)
    
    static let blue = Color(
        red:   0 / 255.0,
        green: 146 / 255.0,
        blue:  175 / 255.0,
        opacity: 1.0
    )

    static let purple = Color(
        red:   120 / 255.0,
        green: 39 / 255.0,
        blue:  172 / 255.0,
        opacity: 1.0
    )
    
    
    static let gradientColors: [Color] = [Colors.blue, Colors.purple]
    static let gradient = LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
}


