//
//  ExpandableMenuView.swift
//  GreenScreenCam
//
//  Created by Dory on 10/12/2024.
//

import SwiftUI

struct ExpandableMenuView: View {
    @State private var isExpanded = false
    private var manager: AVManager
    
    init(manager: AVManager) {
        self.manager = manager
    }
    
    var body: some View {
        HStack {
            GeometryReader { geo in
                ZStack(alignment: .bottomTrailing) {
                    if isExpanded {
                        expandedMenu(geo: geo)
                    }
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            RoundButton(icon: Icons.settings, transparent: isExpanded) {
                                withAnimation(.spring) {
                                    isExpanded.toggle()
                                }
                            }
                            .padding([.bottom, .trailing], Metrics.padding.medium)
                            .transition(.opacity)
                        }
                    }
                }
            }
        }
    }
    
    private func expandedMenu(geo: GeometryProxy) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 30)
                .fill(Colors.gradient)
            
            VStack(spacing: Metrics.spacing) {
                CameraSelectionView(manager: manager)
                
                Divider()
                
                GreenScreenView()
            }
            .padding(Metrics.padding.medium)
            .padding(.bottom, Metrics.roundButtonHeight)
        }
        .padding(Metrics.padding.medium)
        .frame(width: geo.size.width / 3)
        .fixedSize()
        .transition(.opacity)
    }
}
