//
//  ContinuousVoiceController.swift
//  CraftingReality
//
//  Created by Tianhe on 1/14/25.
//

import Foundation
import Speech
import SwiftUI
import AVFoundation

@Observable
@MainActor
final class ContinuousVoiceController {
    // Voice control state enumeration
    enum VoiceControlState {
        case idle
        case initializing
        case listening
        case processing
    }
    
    // Audio engine and transcription components
    private let audioEngine: AVAudioEngine
    private var speechTranscriber: SpeechTranscriber?
    private var speechAnalyzer: SpeechAnalyzer?
    private var recognizerTask: Task<(), Error>?
    
    // Async stream for audio processing
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var outputContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    
    // Audio format and converter
    var analyzerFormat: AVAudioFormat?
    private let converter = BufferConverter()
    
    // State management
    var state: VoiceControlState = .idle
    
    // Computed properties for backward compatibility
    var isListening: Bool { state == .listening }
    var isProcessing: Bool { state == .processing }
    var isInitializing: Bool { state == .initializing }
    
    // Text transcription
    var volatileTranscript: AttributedString = ""
    var finalizedTranscript: AttributedString = ""
    private var accumulatedText: String = ""
    private var lastCommandTime: Date = Date()
    
    // Feature gate for volatile command processing
    var enableVolatileCommandProcessing: Bool = false
    private var lastProcessedVolatileText: String = ""
    private var volatileProcessingTask: Task<Void, Never>?
    private var lastVolatileProcessTime: Date = Date.distantPast
    private let volatileProcessingCooldown: TimeInterval = 0.8  // 0.8秒间隔判断新句子
    
    // Timer for delayed command processing
    private var commandTimer: Timer?
    private let commandTimeoutInterval: TimeInterval = 0.5
    
    // Command processing
    private let entityMaker: EntityMaker
    
    // Configuration
    static let locale = Locale(components: .init(languageCode: .english, script: nil, languageRegion: .unitedStates))
    
    init(entityMaker: EntityMaker) {
        self.audioEngine = AVAudioEngine()
        self.entityMaker = entityMaker
    }
    
    // MARK: - Public Interface
    
    func startContinuousListening() async throws {
        print("[ContinuousVoice] Starting continuous listening...")
        
        guard state == .idle else { return }
        
        state = .initializing
        
        do {
            // Check permissions
            print("[ContinuousVoice] Checking microphone permissions...")
            guard await isAuthorized() else {
                print("[ContinuousVoice] Microphone permission denied")
                state = .idle
                throw TranscriptionError.failedToSetupRecognitionStream
            }
            
            // Setup audio session
            print("[ContinuousVoice] Setting up audio session...")
            try setupAudioSession()
            
            // Setup transcriber
            print("[ContinuousVoice] Setting up speech transcriber...")
            try await setupTranscriber()
            
            // Start listening
            state = .listening
            
            // Start audio stream processing
            do {
                print("[ContinuousVoice] Starting audio engine...")
                let audioStreamSequence = try await audioStream()
                print("[ContinuousVoice] Voice control ready!")
                
                for await audioBuffer in audioStreamSequence {
                    if state == .idle { break }  // 只有在idle时才停止
                    try await streamAudioToTranscriber(audioBuffer)
                }
            } catch {
                print("[ContinuousVoice] Audio streaming failed: \(error)")
                await stopListening()
                throw error
            }
        } catch {
            state = .idle
            throw error
        }
    }
    
    func stopListening() async {
        print("[ContinuousVoice] Stopping continuous listening...")
        
        state = .idle
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Clean up transcriber
        inputBuilder?.finish()
        try? await speechAnalyzer?.finalizeAndFinishThroughEndOfInput()
        recognizerTask?.cancel()
        recognizerTask = nil
        
        // Clean up continuation
        outputContinuation?.finish()
        outputContinuation = nil
        
        // Stop command timer
        commandTimer?.invalidate()
        commandTimer = nil
        
        // Clean up volatile processing
        volatileProcessingTask?.cancel()
        volatileProcessingTask = nil
        lastProcessedVolatileText = ""
        lastVolatileProcessTime = Date.distantPast
        
        print("[ContinuousVoice] Continuous listening stopped")
    }
    
    func toggleListening() async throws {
        switch state {
        case .listening:
            await stopListening()
        case .idle:
            try await startContinuousListening()
        case .initializing, .processing:
            // Do nothing if initializing or processing
            return
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupTranscriber() async throws {
        print("[ContinuousVoice] Setting up transcriber...")
        
        speechTranscriber = SpeechTranscriber(
            locale: Self.locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        
        guard let transcriber = speechTranscriber else {
            throw TranscriptionError.failedToSetupRecognitionStream
        }
        
        speechAnalyzer = SpeechAnalyzer(modules: [transcriber])
        
        // Ensure model is available
        print("[ContinuousVoice] Ensuring speech model is available...")
        try await ensureModel(transcriber: transcriber, locale: Self.locale)
        
        // Get best audio format
        print("[ContinuousVoice] Getting best audio format...")
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        
        guard analyzerFormat != nil else {
            throw TranscriptionError.invalidAudioDataType
        }
        
        // Create input stream
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputSequence = stream
        inputBuilder = continuation
        
        // Start recognition task
        print("[ContinuousVoice] Starting speech recognition task...")
        recognizerTask = Task {
            guard let transcriber = speechTranscriber else { return }
            
            do {
                for try await case let result in transcriber.results {
                    await handleTranscriptionResult(result)
                }
            } catch {
                print("[ContinuousVoice] Speech recognition failed: \(error)")
            }
        }
        
        // Start analyzer
        print("[ContinuousVoice] Starting speech analyzer...")
        guard let inputSequence = inputSequence else { return }
        try await speechAnalyzer?.start(inputSequence: inputSequence)
        
        print("[ContinuousVoice] Transcriber setup completed")
    }
    
    private func setupAudioSession() throws {
        print("[ContinuousVoice] Setting up audio session...")
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        print("[ContinuousVoice] iOS audio session configured")
        #else
        // macOS setup if needed
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        print("[ContinuousVoice] macOS audio engine reset")
        #endif
    }
    
    // MARK: - Audio Stream Processing
    
    private func audioStream() async throws -> AsyncStream<AVAudioPCMBuffer> {
        print("[ContinuousVoice] Setting up audio engine...")
        try setupAudioEngine()
        
        print("[ContinuousVoice] Installing audio tap...")
        audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: audioEngine.inputNode.outputFormat(forBus: 0)
        ) { [weak self] (buffer, time) in
            guard let self = self else { return }
            self.outputContinuation?.yield(buffer)
        }
        
        print("[ContinuousVoice] Preparing audio engine...")
        audioEngine.prepare()
        
        print("[ContinuousVoice] Starting audio engine...")
        try audioEngine.start()
        
        print("[ContinuousVoice] Audio engine started successfully!")
        
        return AsyncStream(AVAudioPCMBuffer.self, bufferingPolicy: .unbounded) { continuation in
            self.outputContinuation = continuation
        }
    }
    
    private func setupAudioEngine() throws {
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    private func streamAudioToTranscriber(_ buffer: AVAudioPCMBuffer) async throws {
        guard let analyzerFormat = analyzerFormat,
              let inputBuilder = inputBuilder else {
            throw TranscriptionError.invalidAudioDataType
        }
        
        let converted = try converter.convertBuffer(buffer, to: analyzerFormat)
        let input = AnalyzerInput(buffer: converted)
        inputBuilder.yield(input)
    }
    
    // MARK: - Transcription Result Handling
    
    @MainActor
    private func handleTranscriptionResult(_ result: SpeechTranscriber.Result) async {
        let text = result.text
        
        if result.isFinal {
            // Skip processing new final results while we're already processing a command
            guard state != .processing else { return }
            
            // Add to finalized transcript
            finalizedTranscript += text
            volatileTranscript = ""
            
            // Process the finalized text
            let processedText = String(text.characters).lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // Add to accumulated text and process immediately
            accumulatedText += processedText + " "

            await processAccumulatedCommand()
            
        } else {
            // Always update volatile transcript (even during processing)
            volatileTranscript = text
            volatileTranscript.foregroundColor = .purple.opacity(0.5)

            // Feature: Process volatile results based on sentence timing
            if enableVolatileCommandProcessing && state == .listening {
                let processedText = String(text.characters).lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                // Check time interval since last volatile text update
                let timeSinceLastUpdate = Date().timeIntervalSince(lastVolatileProcessTime)
                
                // Process if enough time passed since last update (indicating end of sentence/command)
                if !processedText.isEmpty && 
                   processedText.count >= 3 && 
                   timeSinceLastUpdate >= volatileProcessingCooldown {
                    
                    lastProcessedVolatileText = processedText
                    lastVolatileProcessTime = Date()
                    
                    print("[ContinuousVoice] 🚀 Time-based volatile processing: '\(processedText)' (interval: \(String(format: "%.1f", timeSinceLastUpdate))s)")
                    
                    // Cancel any previous volatile processing task
                    volatileProcessingTask?.cancel()
                    
                    // Process command directly - let AI model determine validity
                    volatileProcessingTask = Task { [weak self] in
                        await self?.processVolatileCommand(processedText)
                    }
                }
            }
        }
    }
    
//    private func isCompleteCommand(_ text: String) -> Bool {
//        // Check if the text forms a complete command pattern (for final results only)
//        let commandPatterns = [
//            // Complete creation patterns
//            "^(create|make|add|build) (a |an )?(red|blue|green|yellow|black|white|orange|purple) (cube|sphere|box|ball|cone|cylinder)$",
//            "^(create|make|add|build) (a |an )?(big|small|tiny|huge) (cube|sphere|box|ball|cone|cylinder)$", 
//            "^(create|make|add|build) (a |an )?(cube|sphere|box|ball|cone|cylinder)$",
//            
//            // Complete movement patterns  
//            "^(move|slide|translate) (left|right|up|down|forward|backward|front|back)$",
//            "^(move|slide|translate) .* (left|right|up|down|forward|backward|front|back)$",
//            
//            // Complete scaling patterns
//            "^(make|scale) .* (bigger|smaller|larger|tiny|huge)$",
//            
//            // Complete modification patterns
//            "^(make|change|turn) .* (red|blue|green|yellow|black|white|orange|purple|pink|gray|grey)$",
//            
//            // System patterns
//            "^(start|stop|enable|disable|play|pause)\\s+.*",
//        ]
//        
//        return commandPatterns.contains { pattern in
//            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
//        }
//    }
//    
//    private func startCommandTimer() {
//        commandTimer?.invalidate()
//        commandTimer = Timer.scheduledTimer(withTimeInterval: commandTimeoutInterval, repeats: false) { [weak self] _ in
//            Task { @MainActor in
//                print("[ContinuousVoice debug] 🚀 TIMER processing triggered for: '\(self?.accumulatedText ?? "")'")
//                await self?.processAccumulatedCommand()
//            }
//        }
//    }
    
    @MainActor
    private func processAccumulatedCommand() async {
        let command = accumulatedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        guard !command.isEmpty && state != .processing else { return }
        
        print("[ContinuousVoice] Processing command: '\(command)' - State changing to .processing")
        
        let previousState = state
        state = .processing
        
        do {
            try await entityMaker.parsePrompt(command)
            
            // Clear accumulated text after successful processing
            accumulatedText = ""
            
            // Reset finalized transcript to show only current session
            finalizedTranscript = ""
            
            print("[ContinuousVoice] Command processed successfully!")
            
        } catch {
            print("[ContinuousVoice] Command processing failed: \(error)")
            // Don't clear accumulated text on error, allow retry
        }
        
        // Return to previous state (should be listening if we were listening)
        state = previousState == .listening ? .listening : .idle
        print("[ContinuousVoice] State returned to: \(state)")
        commandTimer?.invalidate()
        commandTimer = nil
    }
    
    // MARK: - Volatile Command Processing
    
    @MainActor
    private func processVolatileCommand(_ command: String) async {
        guard enableVolatileCommandProcessing && state == .listening else { return }
        
        print("[ContinuousVoice] 🚀 Processing volatile command: '\(command)'")
        
        do {
            // Let the model decide if this is a valid command and process it
            try await entityMaker.parsePrompt(command)
            
            print("[ContinuousVoice] ✅ Volatile command processed successfully!")
            
            // Clear accumulated text to prevent duplicate processing from final result
            // Since we processed this command, clear the accumulated text
            accumulatedText = ""
            commandTimer?.invalidate()
            commandTimer = nil
            print("[ContinuousVoice] 🧹 Cleared accumulated text to prevent duplicate processing")
            
        } catch {
            // Volatile processing failed - let the final result handle it normally
            print("[ContinuousVoice] ⚠️ Volatile command failed (final result will handle it): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Authorization and Model Management
    
    private func isAuthorized() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            return true
        }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }
    
    private func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
        guard await supported(locale: locale) else {
            print("[ContinuousVoice] Locale not supported: \(locale)")
            throw TranscriptionError.localeNotSupported
        }
        
        if await installed(locale: locale) {
            return
        } else {
            try await downloadIfNeeded(for: transcriber)
        }
    }
    
    private func supported(locale: Locale) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }
    
    private func installed(locale: Locale) async -> Bool {
        let installed = await Set(SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }
    
    private func downloadIfNeeded(for module: SpeechTranscriber) async throws {
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await downloader.downloadAndInstall()
        }
    }
    
    // MARK: - Public State Access
    
    var currentTranscript: String {
        String((finalizedTranscript + volatileTranscript).characters)
    }
    
    var hasAccumulatedCommand: Bool {
        !accumulatedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
    }
    
    var currentCommand: String {
        accumulatedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
} 
