//
//  MobileEntityMaker.swift
//  CraftingReality
//
//  Created for Mobile Demo Adaptation
//

import SwiftUI
import Foundation
import FoundationModels

// Mobile version of command results for display
struct CommandResult: Identifiable {
    let id = UUID()
    let type: String
    let originalCommand: String
    let parameters: String
    let timestamp: Date
    let success: Bool
    
    var displayText: String {
        if success {
            return "✅ \(type.capitalized): \(parameters)"
        } else {
            return "❌ Failed to parse: \(originalCommand)"
        }
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// Same data structures as original EntityMaker
@Generable
struct StartStop {
    @Guide(description: "The action word in the input text", .anyOf(["start", "stop", "play", "pause", "begin", "enable", "disable"]))
    let arg: String
}

@Generable
struct ScaleParam {
    @Guide(description: "The amount to scale the object by. IF action includes SMALLER or SCALE DOWN or SHRINK and the number is larger than 1, divide 1 by the number to get the scale. If not specified, bigger is 2, smaller is 0.5", .range(0.1...10))
    let scale: Float
}

@Generable
struct MoveParams {
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
class MobileEntityMaker {
    let model = SystemLanguageModel.default
    
    // Mobile-specific properties
    var commandHistory: [CommandResult] = []
    var activeEntityDescription: String? = nil
    var systemStatus: Bool = false
    var processing: Bool = false
    
    let options = GenerationOptions(temperature: 0.15)
    let onWords = ["start", "play", "enable", "begin"]
    
    // Same instructions as original EntityMaker
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
    
    func warmup() async throws {
        let session = LanguageModelSession(model: model, instructions: actionInstructions)
        let _ = try await session.respond(to: "Make a red cube", generating: EntityParameters.self, includeSchemaInPrompt: false, options: options)
    }
    
    func parsePrompt(_ prompt: String) async throws {
        guard !prompt.isEmpty else {
            print("empty string whoops")
            return
        }
        
        processing = true
        
        do {
            let session = LanguageModelSession(model: model, instructions: actionInstructions)
            let response = try await session.respond(to: prompt, generating: ActionType.self, includeSchemaInPrompt: false, options: options)
            
            switch response.content.actionType {
            case "creation":
                print("creating")
                try await handleCreation(from: prompt)
            case "modification":
                if activeEntityDescription == nil {
                    addCommandResult(type: "modification", command: prompt, parameters: "No active entity selected", success: false)
                } else {
                    print("modifying")
                    try await handleModification(with: prompt)
                }
            case "scaling":
                if activeEntityDescription == nil {
                    addCommandResult(type: "scaling", command: prompt, parameters: "No active entity selected", success: false)
                } else {
                    print("starting scaling by \(prompt)")
                    try await handleScaling(by: prompt)
                }
            case "movement":
                if activeEntityDescription == nil {
                    addCommandResult(type: "movement", command: prompt, parameters: "No active entity selected", success: false)
                } else {
                    print("starting movement by \(prompt)")
                    try await handleMovement(by: prompt)
                }
            case "system":
                try await handleSystem(prompt: prompt)
            default:
                print("defaulted")
                addCommandResult(type: "unknown", command: prompt, parameters: "Unrecognized command type", success: false)
            }
        } catch {
            addCommandResult(type: "error", command: prompt, parameters: "Parsing failed: \(error.localizedDescription)", success: false)
        }
        
        processing = false
    }
    
    private func handleCreation(from prompt: String) async throws {
        let params = try await genEntityParams(from: prompt)
        
        let description = "\(params.count)x \(params.color) \(params.meshType)"
        let details = "Size: \(params.meshSize), Metallic: \(params.isMetallic), Roughness: \(params.roughness)"
        
        activeEntityDescription = description
        addCommandResult(type: "creation", command: prompt, parameters: "\(description) - \(details)", success: true)
    }
    
    private func handleModification(with prompt: String) async throws {
        let mod = try await genMods(from: prompt)
        
        let modDescription = "\(mod.modColor) color, roughness: \(mod.modRoughness), metallic: \(mod.modMetal)"
        addCommandResult(type: "modification", command: prompt, parameters: modDescription, success: true)
        
        // Update active entity description
        if let current = activeEntityDescription {
            activeEntityDescription = "Modified \(current)"
        }
    }
    
    private func handleScaling(by prompt: String) async throws {
        let session = LanguageModelSession(model: model, instructions: scaleInstructions)
        let scaleParam = try await session.respond(to: prompt, generating: ScaleParam.self, includeSchemaInPrompt: false)
        let scale = scaleParam.content.scale
        
        addCommandResult(type: "scaling", command: prompt, parameters: "Scale factor: \(scale)", success: true)
    }
    
    private func handleMovement(by prompt: String) async throws {
        let session = LanguageModelSession(model: model, instructions: moveInstructions)
        let moveParam = try await session.respond(to: prompt, generating: MoveParams.self, includeSchemaInPrompt: false)
        
        let direction = moveParam.content.direction
        let axis = moveParam.content.axis
        let distance = moveParam.content.dist
        
        addCommandResult(type: "movement", command: prompt, parameters: "\(direction) \(distance)m on \(axis)-axis", success: true)
    }
    
    private func handleSystem(prompt: String) async throws {
        let systemSession = LanguageModelSession(model: model, instructions: systemInstructions)
        let systemStatus = try await systemSession.respond(to: prompt, generating: StartStop.self)
        
        let onOff = onWords.contains(systemStatus.content.arg)
        self.systemStatus = onOff
        
        addCommandResult(type: "system", command: prompt, parameters: "System \(onOff ? "enabled" : "disabled")", success: true)
    }
    
    private func genEntityParams(from prompt: String) async throws -> EntityParameters {
        let session = LanguageModelSession(model: model, instructions: createInstructions)
        let response = try await session.respond(to: prompt, generating: EntityParameters.self, includeSchemaInPrompt: false)
        return response.content
    }
    
    private func genMods(from prompt: String) async throws -> Modifications {
        let session = LanguageModelSession(model: model, instructions: modInstructions)
        let mod = try await session.respond(to: prompt, generating: Modifications.self, includeSchemaInPrompt: false)
        return mod.content
    }
    
    private func addCommandResult(type: String, command: String, parameters: String, success: Bool) {
        let result = CommandResult(
            type: type,
            originalCommand: command,
            parameters: parameters,
            timestamp: Date(),
            success: success
        )
        commandHistory.append(result)
        
        // Keep only last 50 commands to avoid memory issues
        if commandHistory.count > 50 {
            commandHistory.removeFirst()
        }
    }
    
    func clearHistory() {
        commandHistory.removeAll()
        activeEntityDescription = nil
    }
} 