//
//  MobileContinuousVoiceController.swift
//  CraftingReality
//
//  Created for Mobile Demo Adaptation
//

import Foundation
import Speech
import SwiftUI
import AVFoundation

@Observable
@MainActor
final class MobileContinuousVoiceController {
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
    private let volatileProcessingCooldown: TimeInterval = 0.8
    
    // Timer for delayed command processing
    private var commandTimer: Timer?
    private let commandTimeoutInterval: TimeInterval = 0.5
    
    // Command processing - Mobile version
    private let mobileEntityMaker: MobileEntityMaker
    
    // Configuration
    static let locale = Locale(components: .init(languageCode: .english, script: nil, languageRegion: .unitedStates))
    
    init(mobileEntityMaker: MobileEntityMaker) {
        self.audioEngine = AVAudioEngine()
        self.mobileEntityMaker = mobileEntityMaker
    }
    
    // MARK: - Public Interface
    
    func startContinuousListening() async throws {
        print("[MobileContinuousVoice] Starting continuous listening...")
        
        guard state == .idle else { return }
        
        state = .initializing
        
        do {
            // Check permissions
            print("[MobileContinuousVoice] Checking microphone permissions...")
            guard await isAuthorized() else {
                print("[MobileContinuousVoice] Microphone permission denied")
                state = .idle
                throw TranscriptionError.failedToSetupRecognitionStream
            }
            
            // Setup audio session
            print("[MobileContinuousVoice] Setting up audio session...")
            try setupAudioSession()
            
            // Setup transcriber
            print("[MobileContinuousVoice] Setting up speech transcriber...")
            try await setupTranscriber()
            
            // Start listening
            state = .listening
            
            // Start audio stream processing
            do {
                print("[MobileContinuousVoice] Starting audio engine...")
                let audioStreamSequence = try await audioStream()
                print("[MobileContinuousVoice] Voice control ready!")
                
                for await audioBuffer in audioStreamSequence {
                    if state == .idle { break }
                    try await streamAudioToTranscriber(audioBuffer)
                }
            } catch {
                print("[MobileContinuousVoice] Audio streaming failed: \(error)")
                await stopListening()
                throw error
            }
        } catch {
            state = .idle
            throw error
        }
    }
    
    func stopListening() async {
        print("[MobileContinuousVoice] Stopping continuous listening...")
        
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
        
        print("[MobileContinuousVoice] Continuous listening stopped")
    }
    
    func toggleListening() async throws {
        switch state {
        case .listening:
            await stopListening()
        case .idle:
            try await startContinuousListening()
        case .initializing, .processing:
            return
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func setupTranscriber() async throws {
        let locale = Self.locale
        let transcriber = SpeechTranscriber(locale: locale)
        try await ensureModel(transcriber: transcriber, locale: locale)
        
        self.speechTranscriber = transcriber
        let analyzer = SpeechAnalyzer(transcriber: transcriber)
        self.speechAnalyzer = analyzer
        
        // Setup async streams
        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputSequence = inputSequence
        self.inputBuilder = inputBuilder
        
        // Set analyzer format
        self.analyzerFormat = await analyzer.acceptsFormat
        
        // Start recognition task
        recognizerTask = Task {
            for await result in analyzer.analyze(inputSequence) {
                await handleTranscriptionResult(result)
            }
        }
    }
    
    // MARK: - Audio Processing
    
    private func audioStream() async throws -> AsyncStream<AVAudioPCMBuffer> {
        return AsyncStream { continuation in
            self.outputContinuation = continuation
            
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
                continuation.yield(buffer)
            }
            
            do {
                try audioEngine.start()
            } catch {
                continuation.finish(throwing: error)
            }
        }
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
            guard state != .processing else { return }
            
            finalizedTranscript += text
            volatileTranscript = ""
            
            let processedText = String(text.characters).lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            accumulatedText += processedText + " "
            await processAccumulatedCommand()
            
        } else {
            volatileTranscript = text
            volatileTranscript.foregroundColor = .purple.opacity(0.5)

            if enableVolatileCommandProcessing && state == .listening {
                let processedText = String(text.characters).lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                let timeSinceLastUpdate = Date().timeIntervalSince(lastVolatileProcessTime)
                
                if !processedText.isEmpty && 
                   processedText.count >= 3 && 
                   timeSinceLastUpdate >= volatileProcessingCooldown {
                    
                    lastProcessedVolatileText = processedText
                    lastVolatileProcessTime = Date()
                    
                    print("[MobileContinuousVoice] 🚀 Time-based volatile processing: '\(processedText)' (interval: \(String(format: "%.1f", timeSinceLastUpdate))s)")
                    
                    volatileProcessingTask?.cancel()
                    
                    volatileProcessingTask = Task { [weak self] in
                        await self?.processVolatileCommand(processedText)
                    }
                }
            }
        }
    }
    
    @MainActor
    private func processAccumulatedCommand() async {
        let command = accumulatedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        guard !command.isEmpty && state != .processing else { return }
        
        print("[MobileContinuousVoice] Processing command: '\(command)' - State changing to .processing")
        
        let previousState = state
        state = .processing
        
        do {
            try await mobileEntityMaker.parsePrompt(command)
            
            accumulatedText = ""
            finalizedTranscript = ""
            
            print("[MobileContinuousVoice] Command processed successfully!")
            
        } catch {
            print("[MobileContinuousVoice] Command processing failed: \(error)")
        }
        
        state = previousState == .listening ? .listening : .idle
        print("[MobileContinuousVoice] State returned to: \(state)")
        commandTimer?.invalidate()
        commandTimer = nil
    }
    
    // MARK: - Volatile Command Processing
    
    @MainActor
    private func processVolatileCommand(_ command: String) async {
        guard enableVolatileCommandProcessing && state == .listening else { return }
        
        print("[MobileContinuousVoice] 🚀 Processing volatile command: '\(command)'")
        
        do {
            try await mobileEntityMaker.parsePrompt(command)
            
            print("[MobileContinuousVoice] ✅ Volatile command processed successfully!")
            
            accumulatedText = ""
            commandTimer?.invalidate()
            commandTimer = nil
            print("[MobileContinuousVoice] 🧹 Cleared accumulated text to prevent duplicate processing")
            
        } catch {
            print("[MobileContinuousVoice] ⚠️ Volatile command failed (final result will handle it): \(error.localizedDescription)")
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
            print("[MobileContinuousVoice] Locale not supported: \(locale)")
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