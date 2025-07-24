//
//  CraftingRealityApp.swift
//  CraftingReality
//
//  Created by Tianhe on 7/3/25.
//

import SwiftUI

// @main // Disabled for mobile demo - using CraftingRealityMobileApp instead
struct CraftingRealityApp: App {

    @State private var appModel: AppModel = AppModel.shared
    @State private var beginPressed: Bool = false
    @State private var instructionSeen: Bool = false

    var body: some Scene {
        // Main control window
        WindowGroup(id: appModel.windowID) {
            Group {
                if !beginPressed {
                    SplashScreenView(beginPressed: $beginPressed)
                } else if !instructionSeen {
                    InstructionView(instructionSeen: $instructionSeen)
                        .transition(.scale)
                } else if beginPressed && instructionSeen {
                    ContentView()
                }
            }
        }
        .windowStyle(.plain)
        .windowResizability(.contentMinSize)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
