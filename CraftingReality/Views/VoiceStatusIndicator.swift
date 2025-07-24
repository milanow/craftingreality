//
//  VoiceStatusIndicator.swift
//  CraftingReality
//
//  Created by Tianhe on 1/14/25.
//

import SwiftUI
import RealityKit

// MARK: - Simulator Detection
extension ProcessInfo {
    static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - Text Input View for Simulator
struct TextInputView: View {
    @Environment(ContinuousVoiceController.self) var voiceController
    @State private var commandText: String = ""
    @State private var isProcessing: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Simulator indicator
            HStack {
                Image(systemName: "laptopcomputer")
                    .foregroundStyle(.blue)
                Text("Simulator Mode - Text Input")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            
            // Text input field
            VStack(spacing: 12) {
                TextField("Enter command (e.g., 'make a red cube')", text: $commandText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        sendCommand()
                    }
                    .disabled(isProcessing)
                
                // Send button
                Button(action: sendCommand) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Send Command")
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: isProcessing ? [.gray, .gray.opacity(0.8)] : [.blue, .blue.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(commandText.isEmpty || isProcessing)
            }
            
            // Current command preview
            if !commandText.isEmpty && !isProcessing {
                VStack(spacing: 8) {
                    Text("Ready to Send:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(commandText)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .multilineTextAlignment(.center)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Processing indicator
            if isProcessing {
                VStack(spacing: 8) {
                    Text("Processing Command:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(commandText)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .multilineTextAlignment(.center)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .onAppear {
            // Auto-focus text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
        .animation(.smooth(duration: 0.3), value: isProcessing)
        .animation(.smooth(duration: 0.3), value: commandText.isEmpty)
    }
    
    private func sendCommand() {
        guard !commandText.isEmpty && !isProcessing else { return }
        
        let command = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        
        print("[TextInput] 📝 Sending command: '\(command)'")
        
        isProcessing = true
        
        Task {
            do {
                // Send command directly to EntityMaker
                try await AppModel.shared.entityMaker.parsePrompt(command)
                print("[TextInput] ✅ Command processed successfully: '\(command)'")
                
                await MainActor.run {
                    // Clear text field and reset state
                    commandText = ""
                    isProcessing = false
                    isTextFieldFocused = true // Re-focus for next command
                }
            } catch {
                print("[TextInput] ❌ Error processing command '\(command)': \(error)")
                
                await MainActor.run {
                    isProcessing = false
                    // Keep text in field so user can retry or modify
                }
            }
        }
    }
}

struct VoiceStatusIndicator: View {
    @Environment(ContinuousVoiceController.self) var voiceController
    @State private var pulseAnimation = false
    
    var body: some View {
        // Show different UI based on environment
        if ProcessInfo.isRunningOnSimulator {
            // Show text input for simulator
            TextInputView()
        } else {
            // Show voice control for real device
            voiceControlView
        }
    }
    
    private var voiceControlView: some View {
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
                    .fontWeight(.semibold)
                    .foregroundStyle(textColor)
                
                if voiceController.state == .listening || voiceController.state == .initializing {
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Current command preview
            if voiceController.hasAccumulatedCommand {
                VStack(spacing: 8) {
                    Text("Current Command:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(voiceController.currentCommand)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .multilineTextAlignment(.center)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Live transcript
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
            // return "Initializing..."
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
            return "Speak your command"
        case .initializing:
            // return "Setting up microphone and speech recognition"
            return ""
        case .listening:
            if voiceController.hasAccumulatedCommand {
                return "Say 'execute' or wait 2 seconds"
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
    
    private var iconForCurrentState: String {
        switch voiceController.state {
        case .idle:
            return "mic.circle.fill"
        case .listening:
            return "stop.circle.fill"
        case .initializing, .processing:
            return "mic.circle.fill" // fallback, though these states show ProgressView
        }
    }
    
    private var backgroundGradient: some ShapeStyle {
        switch voiceController.state {
        case .idle:
            return AnyShapeStyle(LinearGradient(
                colors: [.gray, .secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .initializing:
            return AnyShapeStyle(LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .listening:
            return AnyShapeStyle(LinearGradient(
                colors: [.green, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .processing:
            return AnyShapeStyle(LinearGradient(
                colors: [.orange, .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
    }
    
    private var iconColor: Color {
        return .white
    }
    
    private var textColor: Color {
        switch voiceController.state {
        case .idle:
            return .primary
        case .initializing:
            return .blue
        case .listening:
            return .green
        case .processing:
            return .orange
        }
    }
    
    private var shadowColor: Color {
        switch voiceController.state {
        case .idle:
            return .gray
        case .initializing:
            return .blue
        case .listening:
            return .green
        case .processing:
            return .orange
        }
    }
    
    private var buttonText: String {
        switch voiceController.state {
        case .idle:
            return "Start Voice Control"
        case .initializing:
            return "Initializing Voice Control..."
        case .listening:
            return "Stop Listening"
        case .processing:
            return "Processing..." // Though button is disabled
        }
    }
    
    private var buttonGradient: some ShapeStyle {
        switch voiceController.state {
        case .idle:
            return AnyShapeStyle(LinearGradient(
                colors: [.green, .green.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            ))
        case .initializing:
            return AnyShapeStyle(LinearGradient(
                colors: [.blue, .blue.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            ))
        case .listening:
            return AnyShapeStyle(LinearGradient(
                colors: [.red, .red.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            ))
        case .processing:
            return AnyShapeStyle(LinearGradient(
                colors: [.orange, .orange.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
    }
}

#Preview {
    @Previewable @State var voiceController = ContinuousVoiceController(entityMaker: EntityMaker())
    
    VoiceStatusIndicator()
        .environment(voiceController)
} 
