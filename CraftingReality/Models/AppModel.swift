//
//  AppModel.swift
//  CraftingReality
//
//  Created by Tianhe on 7/3/25.
//

import SwiftUI
import RealityKit
import ARKit

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    static let shared = AppModel()
    
    let immersiveSpaceID = "ImmersiveSpace"
    let windowID = "mainWindow"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    // Voice control state
    var showVoiceControl = false
    
    // Advanced voice control features
    var enableVolatileCommandProcessing = false  // 启用volatile command processing
    
    // EntityMaker initialization state
    var isEntityMakerReady = false
    var entityMakerError: String?
    
    var entityMaker: EntityMaker = EntityMaker()
}
