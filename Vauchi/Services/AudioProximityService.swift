// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// AudioProximityService.swift
// Ultrasonic audio proximity verification for Vauchi macOS
// Audio proximity verification (inherent methods, PlatformAudioHandler removed in core 0.19.21)
//
// Ported from iOS AudioProximityService with macOS adaptations:
// - No AVAudioSession (macOS doesn't have it)
// - Mic permission via AVCaptureDevice instead of AVAudioSession
// - Capability detection via AVAudioEngine node formats

import AVFoundation

/// Service for ultrasonic audio proximity verification on macOS.
/// Uses AVAudioEngine to emit and receive signals at 18-20 kHz.
class AudioProximityService {
    // MARK: - Audio Engine

    private let audioEngine = AVAudioEngine()
    private var playerNode: AVAudioPlayerNode?
    private var isRecording = false
    private var isPlaying = false
    private var recordedSamples: [Float] = []
    private let sampleLock = NSLock()

    // MARK: - Configuration

    private let ultrasonicMaxFreq: Float = 20000

    // MARK: - Initialization

    deinit {
        stop()
    }

    // MARK: - Audio Capability & Signal Methods

    /// Check device capability for ultrasonic audio.
    func checkCapability() -> String {
        let inputFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        let hasInput = inputFormat.channelCount > 0

        let outputFormat = audioEngine.outputNode.outputFormat(forBus: 0)
        let hasOutput = outputFormat.channelCount > 0

        // Check if sample rate supports ultrasonic frequencies
        let sampleRate = outputFormat.sampleRate
        let nyquist = sampleRate / 2
        let supportsUltrasonic = nyquist >= Double(ultrasonicMaxFreq)

        if !supportsUltrasonic {
            return "none"
        }

        // Check microphone permission
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let micAllowed = micStatus == .authorized

        if hasInput, micAllowed, hasOutput {
            return "full"
        } else if hasOutput {
            return "emit_only"
        } else if hasInput, micAllowed {
            return "receive_only"
        } else {
            return "none"
        }
    }

    /// Emit ultrasonic signal with given samples.
    func emitSignal(samples: [Float], sampleRate: UInt32) -> String {
        guard !samples.isEmpty else {
            return "No samples to emit"
        }

        do {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1) else {
                return "Failed to create audio format for sample rate \(sampleRate)"
            }
            let capacity = AVAudioFrameCount(samples.count)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
                return "Failed to create PCM buffer with capacity \(samples.count)"
            }
            buffer.frameLength = AVAudioFrameCount(samples.count)

            guard let channelData = buffer.floatChannelData?[0] else {
                return "Failed to access float channel data"
            }
            for (index, sample) in samples.enumerated() {
                channelData[index] = sample
            }

            let player = AVAudioPlayerNode()
            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: format)

            try audioEngine.start()

            isPlaying = true
            playerNode = player

            player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                }
            }
            player.play()

            // Wait for playback to complete
            let duration = Double(samples.count) / Double(sampleRate)
            Thread.sleep(forTimeInterval: duration + 0.1)

            player.stop()
            audioEngine.stop()
            audioEngine.detach(player)
            playerNode = nil
            isPlaying = false

            return "" // Success

        } catch {
            isPlaying = false
            return "Emit failed: \(error.localizedDescription)"
        }
    }

    /// Record audio and return samples.
    func receiveSignal(timeoutMs: UInt64, sampleRate: UInt32) -> [Float] {
        do {
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            // Clear previous samples
            sampleLock.lock()
            recordedSamples = []
            sampleLock.unlock()

            isRecording = true

            // Install tap on input
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self, isRecording else { return }

                let samples = extractSamples(from: buffer)

                sampleLock.lock()
                recordedSamples.append(contentsOf: samples)
                sampleLock.unlock()
            }

            try audioEngine.start()

            // Record for timeout duration
            Thread.sleep(forTimeInterval: Double(timeoutMs) / 1000.0)

            // Stop recording
            isRecording = false
            inputNode.removeTap(onBus: 0)
            audioEngine.stop()

            // Get recorded samples
            sampleLock.lock()
            let result = recordedSamples
            recordedSamples = []
            sampleLock.unlock()

            // Resample if needed
            if inputFormat.sampleRate != Double(sampleRate) {
                return resample(result, from: Float(inputFormat.sampleRate), to: Float(sampleRate))
            }

            return result

        } catch {
            isRecording = false
            return []
        }
    }

    /// Check if audio is currently active.
    func isActive() -> Bool {
        isRecording || isPlaying
    }

    /// Stop any ongoing audio operation.
    func stop() {
        isRecording = false
        isPlaying = false

        playerNode?.stop()
        playerNode = nil

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
    }

    // MARK: - Helper Methods

    private func extractSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }

        let frameCount = Int(buffer.frameLength)
        var samples = [Float](repeating: 0, count: frameCount)

        for idx in 0 ..< frameCount {
            samples[idx] = channelData[0][idx]
        }

        return samples
    }

    private func resample(_ samples: [Float], from sourceSampleRate: Float, to targetSampleRate: Float) -> [Float] {
        guard sourceSampleRate != targetSampleRate else { return samples }

        let ratio = targetSampleRate / sourceSampleRate
        let newCount = Int(Float(samples.count) * ratio)
        var result = [Float](repeating: 0, count: newCount)

        for idx in 0 ..< newCount {
            let srcIndex = Float(idx) / ratio
            let srcIndexInt = Int(srcIndex)
            let fraction = srcIndex - Float(srcIndexInt)

            if srcIndexInt + 1 < samples.count {
                result[idx] = samples[srcIndexInt] * (1 - fraction) + samples[srcIndexInt + 1] * fraction
            } else if srcIndexInt < samples.count {
                result[idx] = samples[srcIndexInt]
            }
        }

        return result
    }
}

// MARK: - Shared Instance

extension AudioProximityService {
    static let shared = AudioProximityService()
}
