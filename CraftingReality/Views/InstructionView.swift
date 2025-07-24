//
//  InstructionView.swift
//  CraftingReality
//
//  Created by Tianhe on 7/18/25.
//

import SwiftUI

struct InstructionView: View {
    @Binding var instructionSeen: Bool
    @State private var visibleTexts: [Bool] = Array(repeating: false, count: 6) // 6 lines of text
    @State private var showButton = false
    @State private var isTransitioning = false
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    
    let instructionTexts = [
        "Welcome to the Voice-Controlled Playground!",
        "Just say what you want to create:",
        "'Make a red cube', 'Create a blue sphere'",
        "Or control existing objects:",
        "'Move it left', 'Make it bigger', 'Change color to green'",
        "Your voice will be heard continuously in the immersive space!"
    ]
    
    var body: some View {
        VStack{
            ForEach(instructionTexts.indices, id: \.self) { index in
                Text(instructionTexts[index])
                    .font(.title)
                    .opacity(visibleTexts[index] ? 1 : 0)
                    .animation(.easeInOut(duration: 0.8), value: visibleTexts[index])
                    .padding(.top, index == 0 ? 5 : 0)
            }
            
            Text("Double-tap in space to hide/show voice controls.")
                .font(.title2)
                .foregroundStyle(.secondary)
                .opacity(visibleTexts[5] ? 1 : 0)
                .animation(.easeInOut(duration: 0.8), value: visibleTexts[5])
            
            Button() {
                handleGotItButtonTap()
            } label: {
                HStack(spacing: 8) {
                    if isTransitioning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "mic.circle.fill")
                            .font(.title2)
                    }
                    
                    Text(isTransitioning ? "Initializing AI System..." : "Got It! Start Voice Control")
                        .font(.title)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(isTransitioning ? .secondary : .primary)
            }
            .padding(.vertical, 5)
            .opacity(showButton ? 1 : 0)
            .animation(.easeInOut(duration: 0.8), value: showButton)
            .disabled(isTransitioning)
            
            if isTransitioning {
                VStack(spacing: 8) {
                    Text("Please wait while we prepare the voice control system")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("This may take a few moments on first launch")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.5), value: isTransitioning)
            }
        }
        .padding(20)
        .background(Color.clear)
        .onAppear {
            startTextAnimation()
        }
    }
    
    private func startTextAnimation() {
        for index in 0..<visibleTexts.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.6) {
                visibleTexts[index] = true
            }
        }
        
        // Show button after all texts are visible
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(visibleTexts.count) * 0.6 + 0.5) {
            showButton = true
        }
    }
    
    private func handleGotItButtonTap() {
        guard !isTransitioning else { return }
        
        isTransitioning = true
        
        Task {
            do {
                print("[InstructionView] Starting voice-controlled immersive experience...")
                
                // Start warmup in background while opening immersive space
                let warmupTask = Task {
                    do {
                        print("[InstructionView] Starting EntityMaker warmup...")
                        try await AppModel.shared.entityMaker.warmup()
                        await MainActor.run {
                            AppModel.shared.isEntityMakerReady = true
                            AppModel.shared.entityMakerError = nil
                        }
                        print("[InstructionView] EntityMaker warmup completed")
                    } catch {
                        await MainActor.run {
                            AppModel.shared.isEntityMakerReady = false
                            AppModel.shared.entityMakerError = error.localizedDescription
                        }
                        print("[InstructionView] EntityMaker warmup failed: \(error)")
                        throw error
                    }
                }
                
                // Mark instructions as seen
                await MainActor.run {
                    instructionSeen = true
                }
                
                // Open immersive space
                print("[InstructionView] Opening immersive space...")
                let result = await openImmersiveSpace(id: AppModel.shared.immersiveSpaceID)
                
                switch result {
                case .opened:
                    print("[InstructionView] Immersive space opened successfully")
                    
                    // Wait for warmup to complete before enabling voice control
                    print("[InstructionView] Waiting for warmup to complete...")
                    try await warmupTask.value
                    
                    // Small additional delay to ensure everything is ready
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    // Enable voice control in main window
                    await MainActor.run {
                        AppModel.shared.showVoiceControl = true
                    }
                    
                    print("[InstructionView] Voice-controlled immersive experience started!")
                    
                case .userCancelled:
                    print("[InstructionView] User cancelled immersive space")
                    warmupTask.cancel() // Cancel warmup if user cancelled
                    await MainActor.run {
                        isTransitioning = false
                        instructionSeen = false
                    }
                    
                case .error:
                    print("[InstructionView] Error opening immersive space")
                    warmupTask.cancel() // Cancel warmup on error
                    await MainActor.run {
                        isTransitioning = false
                        instructionSeen = false
                    }
                    
                @unknown default:
                    print("[InstructionView] Unknown result opening immersive space")
                    warmupTask.cancel() // Cancel warmup on unknown error
                    await MainActor.run {
                        isTransitioning = false
                        instructionSeen = false
                    }
                }
                
            } catch {
                print("[InstructionView] Failed to start voice-controlled experience: \(error)")
                await MainActor.run {
                    isTransitioning = false
                    instructionSeen = false
                }
            }
        }
    }
}
