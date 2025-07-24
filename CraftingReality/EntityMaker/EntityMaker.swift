//
//  EntityMaker.swift
//  CraftingReality
//
//  Created by Tianhe on 7/4/25.
//

import SwiftUI
import Foundation
import FoundationModels
import Playgrounds
import RealityKit
import AVFoundation

#Playground {
    let model = SystemLanguageModel.default
    
    let actionInstructions = """
    Identify whether the input text is a creation action, movement action, rotation action, scaling action, modification action, or system action.
    IF the input contains START/STOP/PLAY/BEGIN/PAUSE/ENABLE/DISABLE, assume it is a system action.
    IF the input contains RIGHT/LEFT/FORWARD/BACKWARD OR MOVE/LIFT/SLIDE/TRANSLATE, assume it is a movement action.
    IF the input contains BIG/SMALL/BIGGER/SMALLER/SCALE, assume it is a scaling action. 
    IF there is NO action, assume it is creation action, EVEN IF input contains SIZE. 
    IF the input is similar to MAKE (IT/THE object) (COLOR/SHINY/METALLIC/ROUGHNESS), assume it is a modification. 
    IF the input is similar to MAKE (IT/THE object) ((X TIMES)? BIGGER/SMALLER), assume it is a scaling action. 
    IF the input contains MORE, assume it is a creation action.
    ELSE, IF the action word is MAKE, assume it is a creation action.
    """

    let systemInstructions = "Determine what the action word in the input is."
    
    let prompts = [
        "Start the system",
        "Stop the system",
        "Start physics",
        "Stop physics",
        "Play the game",
        "Pause the physics",
        "Disable system",
        "Enable gravity"
    ]
    
    	
    
    let options = GenerationOptions(sampling: .greedy, temperature: 0.7)
    
    let tempSesh = LanguageModelSession(model: model, instructions: actionInstructions)
    let warmupResponse = try await tempSesh.respond(to: "Create a ball", generating: ActionType.self, includeSchemaInPrompt: false)
    
    for prompt in prompts {
        let actionSession = LanguageModelSession(model: model, instructions: actionInstructions)
        let response = try await actionSession.respond(to: prompt, generating: ActionType.self, includeSchemaInPrompt: false)
        if response.content.actionType == "system" {
            let systemSession = LanguageModelSession(model: model, instructions: systemInstructions)
            let sysResponse = try await systemSession.respond(to: prompt, generating: StartStop.self, includeSchemaInPrompt: false)
        }
    }
  
}

@Generable
struct StartStop {
    @Guide(description: "The action word in the input text", .anyOf(["start", "stop", "play", "pause", "begin", "enable", "disable"]))
    let arg: String
}

@Generable
struct ScaleParam {
    // only uniform scaling here
    @Guide(description: "The amount to scale the object by. IF action includes SMALLER or SCALE DOWN or SHRINK and the number is larger than 1, divide 1 by the number to get the scale. If not specified, bigger is 2, smaller is 0.5", .range(0.1...10))
    let scale: Float
}

@Generable
struct MoveParams {
    // x, y, z axes, pos/neg translation - simple? maybe not if we want to do free translation
    @Guide(description: "Whether the movement is positive or not. Right, front, forward, and up are positive. Left, backward, and down are negative.", .anyOf(["positive", "negative"]))
    let direction: String
    
    @Guide(description: "Which axis the movement is on. Right/left is x, up/down is y, forward/backward is z.", .anyOf(["x", "y", "z"]))
    let axis: String
    
    @Guide(description: "The amount to translate, in meters. If unspecified default to 0.5", .range(0...2))
    let dist: Float
}

@Generable
struct ActionType {
    @Guide(description: "What type of action is in the input text.", .anyOf(["creation", "movement", "rotation", "scaling", "modification", "system"]))
    let actionType: String
}

@Generable
struct Modifications {
    @Guide(description: "What color the modification in the input is", .anyOf(["black", "blue", "brown", "cyan", "gray", "green", "magenta", "orange", "purple", "red", "white", "yellow"]))
    let modColor: String
    
    @Guide(description: "What roughness the modification is. Metallic, shiny are closer to 0, matte is closer to 1.", .range(0...1))
    let modRoughness: Float
    
    @Guide(description: "Whether the modification is metallic or not")
    let modMetal: Bool
}

@Generable
struct EntityParameters {
    @Guide(description: "Type of object in the input text. Cube is ALWAYS box. Orb and Ball are sphere", .anyOf(["box", "sphere", "cone", "cylinder"]))

    let meshType: String
    
    @Guide(description: "The size/radius of the object in the input text", .range(0.1...0.15))
    let meshSize: Float
    
    @Guide(description: "System standard color in the input text", .anyOf(["black", "blue", "brown", "cyan", "gray", "green", "magenta", "orange", "purple", "red", "white", "yellow"]))
    let color: String
    
    @Guide(description: "Whether the color is metallic or not")
    let isMetallic: Bool
    
    @Guide(description: "What roughness the object is. Metallic, shiny are closer to 0, matte is closer to 1.", .range(0...1))
    let roughness: Float
    
    @Guide(description: "The number of objects to make. MORE means minimum 2 objects, unspecified or default is 1.", .range(1...5))
    let count: Int
}

@Observable
class EntityMaker {
    let model = SystemLanguageModel.default
    
    var entities: [ModelEntity] = []
    
    var activeEntity: ModelEntity?
    
    var newEntitiesCount: Int = 0
    
    var physicsStatus: Bool = false
    
    let options = GenerationOptions(temperature: 0.15)
    
    let onWords = ["start", "play", "enable", "begin"]
    
    var processing: Bool = false
    
    let actionInstructions = """
    Identify whether the input text is a creation action, movement action, rotation action, scaling action, modification action, or system action.
    IF the input contains START/STOP/PLAY/BEGIN/PAUSE/ENABLE/DISABLE, assume it is a system action.
    IF the input contains RIGHT/LEFT/FORWARD/BACKWARD OR MOVE/LIFT/SLIDE/TRANSLATE, assume it is a movement action.
    IF the input contains BIG/SMALL/BIGGER/SMALLER/SCALE, assume it is a scaling action. 
    IF there is NO action, assume it is creation action, EVEN IF input contains SIZE. 
    IF the input is similar to MAKE (IT/THE object) (COLOR/SHINY/METALLIC/ROUGHNESS), assume it is a modification. 
    IF the input is similar to MAKE (IT/THE object) ((X TIMES)? BIGGER/SMALLER), assume it is a scaling action. 
    IF the input contains MORE, assume it is a creation action.
    ELSE, IF the action word is MAKE, assume it is a creation action.
    """

    let createInstructions = "Identify the type of object, its size, its color, how rough it should be, and whether that color is metallic or not. Orb and ball are sphere, cube is box. IF the input contains MORE, entity count is 3. OTHERWISE, entity count is 1."
    
    let modInstructions = "From the input text, identify the color, the roughness, and whether that color is metallic or not."
    
    let scaleInstructions = "Identify the number to scale the object by. IF the input is similar to SCALE DOWN or MAKE SMALLER, AND there is a numerical value greater than 1, divide 1 by the numerical value to get the correct scale factor. IF no number is specified, BIGGER is 2, SMALLER is 0.5"
    
    let moveInstructions = """
    Identify which axis the movement is in, whether it's a positive direction, and how far the distance to move is, in meters.
    For each axis, its positive-negative is as follows:
    X is RIGHT-LEFT
    Y is UP-DOWN
    Z is FRONT-BACK
    The x-axis is right-left, the y-axis is up-down, and the z-axis is front-back, with directions being positive-negative.
    Forward is z-axis and positive.
    Toward me is z-axis and positive.
    Back is z-axis and negative.
    Backward is z-axis and negative.
    Away is z-axis and negative.
    Right is x-axis and positive.
    Left is x-axis and negative.
    Up is y-axis and positive.
    Down is y-axis and negative.
    The following are ALWAYS positive/true: RIGHT, FORWARD, TOWARD ME, and UP. 
    The following are ALWAYS negative/false: LEFT, BACK, BACKWARD, AWAY, and DOWN. 
    RIGHT and LEFT are ALWAYS x.
    BACK, BACKWARD, AWAY, TOWARD, FRONT, and FORWARD are ALWAYS z.
    UP and DOWN are ALWAYS y. 
    IF no distance is specified the DEFAULT is 0.5.
    """
    
    let systemInstructions = "Determine what the action word in the input is."
  
    let colorMap: [String: UIColor] = [
        "black": .black,
        "blue": .blue,
        "brown": .brown,
        "cyan": .cyan,
        "gray": .gray,
        "green": .green,
        "magenta": .magenta,
        "orange": .orange,
        "purple": .purple,
        "red": .red,
        "white": .white,
        "yellow": .yellow
    ]
    
    let axisMap: [String: Int] = [
        "x": 0,
        "y": 1,
        "z": 2
    ]
    /*
    init() {
        // will need to try and sort this later to display an error correctly
        switch model.availability {
            case .available:
                print("Ready to go!")
            case .unavailable(.deviceNotEligible):
                print("Device not eligible.")
            case .unavailable(.appleIntelligenceNotEnabled):
                print("Apple Intelligence not enabled.")
            case .unavailable(.modelNotReady):
                print("Apple Intelligence isn't ready yet.")
            case .unavailable(_):
                print("uh oh other error??")
        }
    }
    */
    func warmup() async throws {
        let session = LanguageModelSession(model: model, instructions: actionInstructions)
        let _ = try await session.respond(to: "Make a red cube", generating: EntityParameters.self, includeSchemaInPrompt: false, options: options)
    }
    
    func parsePrompt(_ prompt: String) async throws {
        if prompt == "" {
            print("empty string whoops")
        } else {
            processing = true
            let session = LanguageModelSession(model: model, instructions: actionInstructions)
            let response = try await session.respond(to: prompt, generating: ActionType.self, includeSchemaInPrompt: false, options: options)
            switch response.content.actionType{
            case "creation":
                print("creating")
                try await promptToEntity(from: prompt)
            case "modification":
                if activeEntity == nil {
                    print("No active entity selected")
                } else {
                    print("modifying")
                    try await modEntity(with: prompt)
                }
            case "scaling":
                if activeEntity == nil {
                    print("No active entity selected")
                } else {
                    print("starting scaling by \(prompt)")
                    try await scaleEntity(by: prompt)
                }
            case "movement":
                if activeEntity == nil {
                    print("No active entity selected")
                } else {
                    print("starting movement by \(prompt)")
                    try await moveEntity(by: prompt)
                }
            case "system":
                let systemSession = LanguageModelSession(model: model, instructions: systemInstructions)
                let systemStatus = try await systemSession.respond(to: prompt, generating: StartStop.self)
                var onOff = false
                if onWords.contains(systemStatus.content.arg) {
                    onOff = true
                }
                if onOff != physicsStatus {
                    // diff value, change physics
                    physicsStatus = onOff
                    for entity in entities {
                        if physicsStatus {
                            // enable EntityAttraction
                            entity.components.set(EntityAttractionComponent())
                        } else {
                            entity.components.remove(EntityAttractionComponent.self)
                        }
                    }
                }
            default:
                print("defaulted")
            }
            processing = false
        }
    }
    
    func promptToEntity(from: String) async throws {
        let params = try await genEntityParams(from: from)
        print(params)
        
        for _ in 0..<params.count {
            let ent = makeEntity(parameters: params)
            print(ent)
            
            // Position entities in a more reasonable area around the parent location
            // Since the parent is at (0, 1, -1.5), we want entities to spawn around that area
            ent.transform = Transform(
                    translation: SIMD3<Float>(
                        Float.random(in: -0.5...0.5),
                        Float.random(in: -0.5...0.5),
                        Float.random(in: -0.5...0.3)))
            entities.append(ent)
        }
        
        newEntitiesCount = params.count
    }
    
    func reset() {
        newEntitiesCount = 0
    }
    
    func genEntityParams(from prompt: String) async throws -> EntityParameters {
        let session = LanguageModelSession(model: model, instructions: createInstructions)
        let response = try await session.respond(to: prompt, generating: EntityParameters.self, includeSchemaInPrompt: false)
        return response.content
    }
    
    func shapeVolume(of: String, size: Float) -> Float {
        let r = size / 2
        switch of {
        case "box":
            return size * size * size
        case "sphere":
            return r * r * r * 4 / 3 * .pi
        case "cone":
            return r * r * size * .pi / 3
        case "cylinder":
            return r * r * size * .pi
        default:
            return 0
        }
    }
    
    func makeEntity(parameters: EntityParameters) -> ModelEntity {
        var myMesh: MeshResource
        var myShape: ShapeResource
        let size = parameters.meshSize
        let myMass: Float = shapeVolume(of: parameters.meshType, size: size)
        
        switch parameters.meshType {
        case "box":
            myMesh = MeshResource.generateBox(size: size)
            myShape = ShapeResource.generateBox(width: size, height: size, depth: size)
        case "sphere":
            myMesh = MeshResource.generateSphere(radius: size/2)
            myShape = ShapeResource.generateSphere(radius: size/2)
        case "cone":
            myMesh = MeshResource.generateCone(height: size, radius: size/2)
            myShape = ShapeResource.generateConvex(from: myMesh)
        case "cylinder":
            myMesh = MeshResource.generateCylinder(height: size, radius: size/2)
            myShape = ShapeResource.generateConvex(from: myMesh)
        default:
            fatalError("Unsupported mesh type: \(parameters.meshType)")
        }
        
        let rough = MaterialScalarParameter(floatLiteral: parameters.roughness)
        
        let myMaterial = SimpleMaterial(color: colorMap[parameters.color]!, roughness: rough, isMetallic: parameters.isMetallic)
        
        let myEntity = ModelEntity(mesh: myMesh, materials: [myMaterial], collisionShape: myShape, mass: myMass)
        
        myEntity.generateCollisionShapes(recursive: false)
        
        // adding inputTarget and Collision to enable interactions, potential physics
        myEntity.components.set(InputTargetComponent())
        myEntity.physicsBody = .init()
        myEntity.physicsBody?.mode = .dynamic
        myEntity.physicsBody?.isAffectedByGravity = false
        
        // add audio component
        myEntity.spatialAudio = SpatialAudioComponent()
        
        if physicsStatus {
            myEntity.components.set(EntityAttractionComponent())
        }
        
        // adding hover effect
        myEntity.components.set(HoverEffectComponent())
        
        activeEntity = myEntity
        
        return myEntity
    }
    
    func genMods(from prompt: String) async throws -> Modifications {
        let session = LanguageModelSession(model: model, instructions: modInstructions)
        let mod = try await session.respond(to: prompt, generating: Modifications.self, includeSchemaInPrompt: false)
        print(mod.content)
        return mod.content
    }
    
    // first assuming that we are only modding activeEntity
    // and only its material, not its shape
    func modEntity(with prompt: String) async throws {
        let mod = try await genMods(from: prompt)
        let newMaterial = SimpleMaterial(color: colorMap[mod.modColor]!, roughness: MaterialScalarParameter(floatLiteral: mod.modRoughness), isMetallic: mod.modMetal)
        
        activeEntity!.model!.materials[0] = newMaterial
    }
    
    func scaleEntity(by prompt: String) async throws {
        let session = LanguageModelSession(model: model, instructions: scaleInstructions)
        let scaleParam = try await session.respond(to: prompt, generating: ScaleParam.self, includeSchemaInPrompt: false)
        let scale = scaleParam.content.scale
        
        let currScale = activeEntity!.scale(relativeTo: nil)
        activeEntity!.setScale(SIMD3<Float>(x: currScale.x * scale, y: currScale.y * scale, z: currScale.z * scale), relativeTo: nil)
    }
    
    func moveEntity(by prompt: String) async throws {
        let session = LanguageModelSession(model: model, instructions: moveInstructions)
        let moveParam = try await session.respond(to: prompt, generating: MoveParams.self, includeSchemaInPrompt: false)
        let axis = axisMap[moveParam.content.axis]!
        let direction = moveParam.content.direction == "positive"
        ? 1 : -1
        let dist = moveParam.content.dist
        var moveVector: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
        moveVector[axis] += (Float(direction) * dist)
        
        activeEntity!.move(to: Transform(translation: moveVector), relativeTo: activeEntity!)
        
    }
    
}
