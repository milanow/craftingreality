//
//  ContentView.swift
//  CraftingReality
//
//  Created by Tianhe on 7/3/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @State var appModel = AppModel.shared
    @State private var voiceController: ContinuousVoiceController

    init() {
        // Initialize voice controller with shared entity maker
        _voiceController = State(initialValue: ContinuousVoiceController(entityMaker: AppModel.shared.entityMaker))
    }

    var body: some View {
        VStack {
            if appModel.showVoiceControl {
                // Voice control interface
                VStack(spacing: 20) {
                    Text("Voice-Controlled 3D Playground")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    if !appModel.isEntityMakerReady {
                        if let error = appModel.entityMakerError {
                            // Show error state
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.orange)
                                
                                Text("AI System Initialization Failed")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Error: \(error)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("Retry") {
                                    Task {
                                        do {
                                            try await appModel.entityMaker.warmup()
                                            appModel.isEntityMakerReady = true
                                            appModel.entityMakerError = nil
                                        } catch {
                                            appModel.entityMakerError = error.localizedDescription
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            // Show loading state
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                
                                Text("Initializing AI System...")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Please wait while we prepare the voice control system")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                    } else {
                        // Show normal voice control interface
                        if ProcessInfo.isRunningOnSimulator {
                            Text("Look around you to see the 3D playground.\nUse the text input below to create and control objects!")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            Text("Look around you to see the 3D playground.\nSpeak commands to create and control objects!")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    
                    VoiceStatusIndicator()
                        .environment(voiceController)
                        .padding()
                    }
                    
                    Spacer()
                }
                .onAppear {
                    // Sync initial volatile command processing setting
                    voiceController.enableVolatileCommandProcessing = appModel.enableVolatileCommandProcessing
                    
                    // Only auto-start voice control if EntityMaker is ready AND not running on simulator
                    if appModel.isEntityMakerReady && !ProcessInfo.isRunningOnSimulator {
                        Task {
                            do {
                                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                                try await voiceController.startContinuousListening()
                                print("[ContentView] Auto-started voice control")
                            } catch {
                                print("[ContentView] Failed to auto-start voice control: \(error)")
                            }
                        }
                    } else if ProcessInfo.isRunningOnSimulator {
                        print("[ContentView] Simulator detected - skipping voice control auto-start")
                    }
                }
                .onDisappear {
                    // Stop voice control when the interface disappears (only if not on simulator)
                    if !ProcessInfo.isRunningOnSimulator {
                        Task {
                            await voiceController.stopListening()
                            print("[ContentView] Stopped voice control on disappear")
                        }
                    }
                }
                .onChange(of: appModel.isEntityMakerReady) { _, isReady in
                    // Auto-start voice control when EntityMaker becomes ready (only if not on simulator)
                    if isReady && !ProcessInfo.isRunningOnSimulator {
                        Task {
                            do {
                                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                                try await voiceController.startContinuousListening()
                                print("[ContentView] Auto-started voice control after EntityMaker ready")
                            } catch {
                                print("[ContentView] Failed to auto-start voice control: \(error)")
                            }
                        }
                    }
                }
                .onChange(of: appModel.enableVolatileCommandProcessing) { _, enabled in
                    // Sync volatile command processing setting to voice controller
                    voiceController.enableVolatileCommandProcessing = enabled
                    print("[ContentView] Volatile command processing \(enabled ? "enabled" : "disabled")")
                }
            } else {
                EmptyView()
            }
        }
        .environment(voiceController)
    }
}

#Preview(windowStyle: PlainWindowStyle()) {
    ContentView()
        .environment(AppModel())
}
