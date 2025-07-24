//
//  MobileContentView.swift
//  CraftingReality
//
//  Created for Mobile Demo Adaptation
//

import SwiftUI

struct MobileContentView: View {
    @State private var mobileEntityMaker = MobileEntityMaker()
    @State private var voiceController: MobileContinuousVoiceController
    @State private var showVoiceControl = true
    @State private var isEntityMakerReady = false
    @State private var entityMakerError: String?

    init() {
        let entityMaker = MobileEntityMaker()
        _mobileEntityMaker = State(initialValue: entityMaker)
        _voiceController = State(initialValue: MobileContinuousVoiceController(mobileEntityMaker: entityMaker))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if showVoiceControl {
                    // Voice control interface
                    VStack(spacing: 20) {
                        Text("Mobile Voice-Controlled Playground")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.top)
                        
                        if !isEntityMakerReady {
                            if let error = entityMakerError {
                                // Show error state
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                        .font(.largeTitle)
                                    
                                    Text("AI System Error")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Button("Retry") {
                                        Task {
                                            await initializeEntityMaker()
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
                            Text("Speak commands to interact with the virtual playground!")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        
                            MobileVoiceStatusIndicator()
                                .environment(voiceController)
                                .padding()
                        }
                        
                        Divider()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
                
                // Command display area
                CommandDisplayView()
                    .environment(mobileEntityMaker)
            }
        }
        .onAppear {
            Task {
                await initializeEntityMaker()
            }
        }
        .onDisappear {
            Task {
                await voiceController.stopListening()
                print("[MobileContentView] Stopped voice control on disappear")
            }
        }
    }
    
    private func initializeEntityMaker() async {
        do {
            print("[MobileContentView] Starting MobileEntityMaker warmup...")
            try await mobileEntityMaker.warmup()
            
            await MainActor.run {
                isEntityMakerReady = true
                entityMakerError = nil
            }
            
            print("[MobileContentView] MobileEntityMaker warmup completed")
            
            // Auto-start voice control after successful initialization
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                try await voiceController.startContinuousListening()
                print("[MobileContentView] Auto-started voice control")
            } catch {
                print("[MobileContentView] Failed to auto-start voice control: \(error)")
            }
            
        } catch {
            await MainActor.run {
                isEntityMakerReady = false
                entityMakerError = error.localizedDescription
            }
            print("[MobileContentView] MobileEntityMaker warmup failed: \(error)")
        }
    }
}

#Preview {
    MobileContentView()
} 