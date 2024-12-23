//
//  RoundButton.swift
//  GreenScreenCam
//
//  Created by Dory on 19/10/2023.
//

import SwiftUI

struct RoundButton: View {
    private let icon: Image
    private let transparent: Bool
    private let action: () -> Void
    private let size = Metrics.roundButtonHeight
    
    init(icon: Image, transparent: Bool, action: @escaping () -> Void) {
        self.icon = icon
        self.transparent = transparent
        self.action = action
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    transparent
                    ? AnyShapeStyle(Color.clear)
                    :AnyShapeStyle(Colors.gradient)
                )
            
            icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: size / 3)
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .onTapGesture {
            action()
        }
    }
}
