//
//  ObjectPlaygroundView.swift
//  CraftingReality
//
//  Created by Tianhe on 7/7/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ObjectPlaygroundView: View {
    @Environment(EntityMaker.self) var entityMaker
    
    let anchor = AnchorEntity()
    
    let followRoot = Entity()
    
    let centeringEntity = Entity()
    
    let counterEntity = Entity()
    
    // Entity parent for all created objects
    let entitiesParent = Entity()
    
    var body: some View {
        
        RealityView { content in
            
            followRoot.components.set(FollowComponent())
            
            followRoot.setPosition(SIMD3<Float>(0, 1.5, -2), relativeTo: nil)
            
            anchor.addChild(followRoot)
            
            content.add(anchor)
            
            // Add entities parent at a convenient position in front of user
            entitiesParent.setPosition(SIMD3<Float>(0, 1, -1.5), relativeTo: nil)
            anchor.addChild(entitiesParent)
            
            followRoot.addChild(counterEntity)
            
            var countText = TextComponent()
            countText.text = AttributedString("Voice-Controlled Playground\nEntities created: \(entityMaker.entities.count)")
            
            counterEntity.components.set(countText)
            
            counterEntity.setPosition(SIMD3<Float>(-0.8, 0.2, -0.5), relativeTo: followRoot)
            
            followRoot.addChild(centeringEntity)
            
            centeringEntity.setPosition(SIMD3<Float>(0, -0.5, -3), relativeTo: followRoot)
            
            // create a bounding box
            // top and bottom faces
            var size = SIMD3<Float>(3, 1E-3, 3)
            
            let topFace = Entity.boxWithCollisionPhysics(.zero, size)
            centeringEntity.addChild(topFace)
            topFace.setPosition(SIMD3<Float>(0, 1, 0), relativeTo: centeringEntity)
            
            
            let bottomFace = Entity.boxWithCollisionPhysics(.zero, size)
            centeringEntity.addChild(bottomFace)
            bottomFace.setPosition(SIMD3<Float>(0, -1, 0), relativeTo: centeringEntity)
            
            // left right
            size = SIMD3<Float>(1E-3, 2, 3)
            
            let leftFace = Entity.boxWithCollisionPhysics(.zero, size)
            centeringEntity.addChild(leftFace)
            leftFace.setPosition(SIMD3<Float>(-1.5, 0, 0), relativeTo: centeringEntity)
            print(leftFace.position(relativeTo: centeringEntity))
            
            
            let rightFace = Entity.boxWithCollisionPhysics(.zero, size)
            centeringEntity.addChild(rightFace)
            rightFace.setPosition(SIMD3<Float>(1.5, 0, 0), relativeTo: centeringEntity)
            
            
            // front back
            size = SIMD3<Float>(3, 2, 1E-3)
            
            let frontFace = Entity.boxWithCollisionPhysics(.zero, size)
            centeringEntity.addChild(frontFace)
            frontFace.setPosition(SIMD3<Float>(0, 0, -1.5), relativeTo: centeringEntity)
            
            
            let backFace = Entity.boxWithCollisionPhysics(.zero, size)
            centeringEntity.addChild(backFace)
            backFace.setPosition(SIMD3<Float>(0, 0, 1.5), relativeTo: centeringEntity)
            
        } update: { content in
            
            // Update entity counter
            var countText = TextComponent()
            countText.text = AttributedString("Voice-Controlled Playground\nEntities created: \(entityMaker.entities.count)\nActive entity: \(entityMaker.activeEntity?.name ?? "None")")
            counterEntity.components.set(countText)
            
            if entityMaker.newEntitiesCount > 0 {
                
                let models = entityMaker.entities.suffix(entityMaker.newEntitiesCount)
                
                let model = entityMaker.entities.last!
                do {
                    let sound = try AudioFileResource.load(named: "Trolleybus Bell Interior 3", configuration: .init(shouldLoop: false))
                    model.playAudio(sound)
                } catch {
                    print("Error loading audio file: \(error.localizedDescription)")
                }
                
                // Add new entities to entitiesParent instead of anchor
                for model in models {
                    entitiesParent.addChild(model)
                }
                
                entityMaker.reset()
            }
        }
        .gesture(TapGesture().targetedToAnyEntity()
            .onEnded({ entity in
                // 设置选中的entity为
                entityMaker.activeEntity = (entity.entity as! ModelEntity)
                do {
                    let sound = try AudioFileResource.load(named: "Glass Bong", configuration: .init(shouldLoop: false))
                    (entity.entity as! ModelEntity).playAudio(sound)
                } catch {
                    print("Error loading audio file: \(error.localizedDescription)")
                }
            })
        )
        .gesture(ForceDragGesture())
    }
}

#Preview {
    ObjectPlaygroundView()
        .environment(EntityMaker())
}
