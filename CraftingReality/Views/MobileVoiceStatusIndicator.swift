//
//  MobileVoiceStatusIndicator.swift
//  CraftingReality
//
//  Created for Mobile Demo Adaptation
//

import SwiftUI

struct MobileVoiceStatusIndicator: View {
    @Environment(MobileContinuousVoiceController.self) var voiceController
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Main status indicator
            ZStack {
                // Background circle
                Circle()
                    .fill(backgroundGradient)
                    .frame(width: 80, height: 80)
                    .shadow(color: shadowColor, radius: pulseAnimation ? 20 : 10)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                
                // Microphone icon
                Image(systemName: microphoneIcon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.bounce, isActive: voiceController.state == .processing)
                    .symbolEffect(.pulse, isActive: voiceController.state == .listening)
                    .symbolEffect(.variableColor, isActive: voiceController.state == .initializing)
            }
            
            // Status text
            VStack(spacing: 4) {
                Text(statusText)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Current command display
            if voiceController.hasAccumulatedCommand {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Command:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text(voiceController.currentCommand)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .frame(maxWidth: 250)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Live transcript display
            if voiceController.state == .listening && !voiceController.currentTranscript.isEmpty {
                ScrollView {
                    Text(voiceController.currentTranscript)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .frame(maxWidth: 300)
                }
                .frame(maxHeight: 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Toggle button
            Button(action: {
                Task {
                    do {
                        try await voiceController.toggleListening()
                    } catch {
                        print("Failed to toggle voice listening: \(error)")
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if voiceController.state == .initializing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: iconForCurrentState)
                            .font(.title2)
                        Text(buttonText)
                            .fontWeight(.medium)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(buttonGradient, in: RoundedRectangle(cornerRadius: 25))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(voiceController.state == .processing || voiceController.state == .initializing)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .onAppear {
            pulseAnimation = true
        }
        .animation(.smooth(duration: 0.3), value: voiceController.state)
        .animation(.smooth(duration: 0.3), value: voiceController.hasAccumulatedCommand)
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        switch voiceController.state {
        case .idle:
            return "Voice Control"
        case .initializing:
            return ""
        case .listening:
            return "Listening"
        case .processing:
            return "Processing..."
        }
    }
    
    private var subtitleText: String {
        switch voiceController.state {
        case .idle:
            return "Tap to start speaking commands"
        case .initializing:
            return ""
        case .listening:
            if voiceController.hasAccumulatedCommand {
                return "Command detected, processing..."
            } else {
                return "Speak your command"
            }
        case .processing:
            return "Executing your command"
        }
    }
    
    private var microphoneIcon: String {
        switch voiceController.state {
        case .idle:
            return "mic.slash.fill"
        case .initializing:
            return "mic.badge.xmark"
        case .listening:
            return "mic.fill"
        case .processing:
            return "gearshape.fill"
        }
    }
    
    private var backgroundGradient: LinearGradient {
        switch voiceController.state {
        case .idle:
            return LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case .initializing:
            return LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case .listening:
            return LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case .processing:
            return LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private var iconColor: LinearGradient {
        LinearGradient(colors: [.white, .white.opacity(0.9)], startPoint: .top, endPoint: .bottom)
    }
    
    private var shadowColor: Color {
        switch voiceController.state {
        case .idle:
            return .gray.opacity(0.3)
        case .initializing:
            return .orange.opacity(0.3)
        case .listening:
            return .green.opacity(0.3)
        case .processing:
            return .blue.opacity(0.3)
        }
    }
    
    private var buttonText: String {
        switch voiceController.state {
        case .idle:
            return "Start Listening"
        case .initializing:
            return "Initializing..."
        case .listening:
            return "Stop Listening"
        case .processing:
            return "Processing..."
        }
    }
    
    private var buttonGradient: LinearGradient {
        switch voiceController.state {
        case .idle:
            return LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case .initializing:
            return LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case .listening:
            return LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case .processing:
            return LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private var iconForCurrentState: String {
        switch voiceController.state {
        case .idle:
            return "play.fill"
        case .initializing:
            return "ellipsis"
        case .listening:
            return "stop.fill"
        case .processing:
            return "gear"
        }
    }
}

#Preview {
    MobileVoiceStatusIndicator()
        .environment(MobileContinuousVoiceController(mobileEntityMaker: MobileEntityMaker()))
} 