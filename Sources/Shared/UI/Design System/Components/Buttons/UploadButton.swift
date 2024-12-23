//
//  UploadButton.swift
//  GreenScreenCam
//
//  Created by Dory on 25/10/2023.
//

import SwiftUI

struct UploadButton: View {
    var title: String
    var image: Image
    var fileName: String? = nil
    var buttonTitle: String
    var action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundColor(.white)
            
            GeometryReader { geo in
                ZStack {
                    HStack(alignment: .center, spacing: Metrics.spacing) {
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.buttonCornerRadius))
                            .frame(height: Metrics.buttonHeight)
                        
                        Button(fileName ?? buttonTitle) {
                            action()
                        }
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .buttonStyle(PrimaryButtonStyle(icon: Icons.upload))
                        .layoutPriority(0)
                    }
                    .frame(width: geo.size.width)
                }
                .frame(width: geo.size.width)
            }
        }
    }
}
