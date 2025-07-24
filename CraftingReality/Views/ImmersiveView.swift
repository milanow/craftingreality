//
//  ImmersiveView.swift
//  CraftingReality
//
//  Created by Tianhe on 7/3/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @State var appModel = AppModel.shared
    
    init() {
        FollowSystem.registerSystem()
        FollowComponent.registerComponent()
        EntityAttractionSystem.registerSystem()
        EntityAttractionComponent.registerComponent()
    }
  
    var body: some View {
        // Pure 3D playground view without any voice control interface
        ObjectPlaygroundView()
            .environment(appModel.entityMaker)
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
