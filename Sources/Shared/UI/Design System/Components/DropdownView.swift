//
//  DropdownView.swift
//  GreenScreenCam
//
//  Created by Dory on 16/10/2023.
//

import SwiftUI

import SwiftUI

struct DropdownView: View {
    @State private var showMenu = false
    @Binding private var selectedOption: String?
    
    private var options: [String]
    private var title: String
    
    @State private var hoverOption: String?
    
    init(title: String, selectedOption: Binding<String?>, options: [String]) {
        self.title = title
        self._selectedOption = selectedOption
        self.options = options
    }
    
    var body: some View {
        VStack(spacing: Metrics.padding.small) {
            HStack {
                Text(title)
                
                Spacer()
            }
            
            ZStack(alignment: .top) {
                DropdownHeaderView(title: selectedOption ?? "Select an option") {
                    withAnimation {
                        showMenu.toggle()
                    }
                }
                
                if showMenu {
                    menuListView
                }
            }
        }
    }

    var menuListView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.ultraThinMaterial)
            
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white, lineWidth: 0.7)
            
            VStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button {
                        withAnimation(.easeOut) {
                            showMenu = false
                            selectedOption = option
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(hoverOption == option ? Color.cyan.opacity(0.5) : .clear)
                
                            HStack {
                                VStack {
                                    if selectedOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .frame(width: Metrics.iconSize)
                                
                                Text(option)
                                
                                Spacer()
                            }
                            .frame(height: Metrics.iconSize)
                        }
                        .padding(.all, Metrics.padding.verySmall)
                        .onHover { hovered in
                            hoverOption = hovered ? option : nil
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct DropdownHeaderView: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        VStack {
            Button {
                withAnimation {
                    action()
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white, lineWidth: 0.7)
                    
                    HStack {
                        Text(title)
                            .padding(.leading, Metrics.padding.verySmall)
                        
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.ultraThinMaterial)
                            
                            Icons.down
                                .resizable()
                                .scaledToFit()
                                .padding(.all, Metrics.padding.verySmall)
                        }
                        .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                    }
                    .padding(.all, Metrics.padding.verySmall)
                }
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
