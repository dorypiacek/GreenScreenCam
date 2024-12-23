//
//  PrimaryButton.swift
//  GreenScreenCam
//
//  Created by Dory on 24/10/2023.
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    private let icon: Image?
    
    init(icon: Image? = nil) {
        self.icon = icon
    }

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Metrics.buttonCornerRadius)
                .stroke(Color.white, lineWidth: 1.5)
                .frame(height: Metrics.buttonHeight)
            
            HStack(alignment: .center) {
                configuration
                    .label
                    .font(.body)
                    .minimumScaleFactor(0.4)
                    .foregroundColor(.white)
                
                if icon != nil {
                    icon?
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                        .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                }
            }
            .padding(.horizontal, Metrics.padding.small)
        }
        .background(Color.white.opacity(0.0001))
    }
}
