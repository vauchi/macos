// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

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

    private let playbackEngine = AVAudioEngine()
    private let captureEngine = AVAudioEngine()
    private let playback = AudioOperationSlot()
    private let capture = AudioOperationSlot()

    // MARK: - Configuration

    private let ultrasonicMaxFreq: Float = 20000

    // MARK: - Initialization

    deinit {
        stop()
    }

    // MARK: - Audio Capability & Signal Methods

    /// Check device capability for ultrasonic audio.
    func checkCapability() -> String {
        let inputFormat = captureEngine.inputNode.inputFormat(forBus: 0)
        let hasInput = inputFormat.channelCount > 0

        let outputFormat = playbackEngine.outputNode.outputFormat(forBus: 0)
        let hasOutput = outputFormat.channelCount > 0

        // Check if sample rate supports ultrasonic frequencies
        let sampleRate = outputFormat.sampleRate
        let nyquist = sampleRate / 2
        let supportsUltrasonic = nyquist >= Double(ultrasonicMaxFreq)

        if !supportsUltrasonic {
            return "none"
        }

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
    func emitSignal(samples: [Float], sampleRate: UInt32, request: AudioOperationSlot.Request? = nil) -> String {
        guard !samples.isEmpty else {
            return "No samples to emit"
        }
        let request = request ?? playback.reserve()

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
            var attached = false
            let duration = Double(samples.count) / Double(sampleRate)
            try playback.run(for: duration + 0.1, request: request, start: {
                playbackEngine.attach(player)
                attached = true
                playbackEngine.connect(player, to: playbackEngine.mainMixerNode, format: format)
                try playbackEngine.start()
                guard playbackEngine.isRunning else {
                    throw NSError(domain: "AudioProximity", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Audio engine did not start"])
                }
                player.scheduleBuffer(buffer, at: nil, options: [])
                player.play()
            }, stop: { [self] in
                if attached {
                    player.stop()
                    playbackEngine.stop()
                    playbackEngine.detach(player)
                }
            })

            return "" // Success

        } catch {
            return "Emit failed: \(error.localizedDescription)"
        }
    }

    func emitSignal(samples: [Float], sampleRate: UInt32, completion: @escaping (String) -> Void) {
        let request = playback.reserve()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = emitSignal(samples: samples, sampleRate: sampleRate, request: request)
            DispatchQueue.main.async { [self] in
                playback.deliver(request) { completion(result) }
            }
        }
    }

    func receiveSignal(timeoutMs: UInt64, sampleRate: UInt32, completion: @escaping ([Float]) -> Void) {
        let request = capture.reserve()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = recordSamples(timeoutMs: timeoutMs, sampleRate: sampleRate, request: request)
            DispatchQueue.main.async { [self] in
                capture.deliver(request) { completion(result) }
            }
        }
    }

    /// Record audio and return samples.
    func receiveSignal(timeoutMs: UInt64, sampleRate: UInt32) -> [Float] {
        recordSamples(timeoutMs: timeoutMs, sampleRate: sampleRate, request: nil)
    }

    private func recordSamples(timeoutMs: UInt64, sampleRate: UInt32, request: AudioOperationSlot.Request?) -> [Float] {
        let request = request ?? capture.reserve()
        let sampleLock = NSLock()
        var recordedSamples: [Float] = []
        var acceptingSamples = true
        var recordedRate: Double = 0
        var inputNode: AVAudioInputNode?
        var tapInstalled = false
        do {
            try capture.run(for: Double(timeoutMs) / 1000, request: request, start: {
                let node = captureEngine.inputNode
                inputNode = node
                let inputFormat = node.outputFormat(forBus: 0)
                recordedRate = inputFormat.sampleRate
                node.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                    guard let self else { return }
                    let samples = extractSamples(from: buffer)
                    sampleLock.lock()
                    if acceptingSamples {
                        recordedSamples.append(contentsOf: samples)
                    }
                    sampleLock.unlock()
                }
                tapInstalled = true
                try captureEngine.start()
            }, stop: { [self] in
                sampleLock.lock()
                acceptingSamples = false
                sampleLock.unlock()
                if tapInstalled {
                    inputNode?.removeTap(onBus: 0)
                }
                captureEngine.stop()
            })

            sampleLock.lock()
            let result = recordedSamples
            sampleLock.unlock()

            // Resample if needed
            if recordedRate != Double(sampleRate) {
                return resample(result, from: Float(recordedRate), to: Float(sampleRate))
            }

            return result

        } catch {
            return []
        }
    }

    /// Check if audio is currently active.
    func isActive() -> Bool {
        capture.isActive || playback.isActive
    }

    /// Stop any ongoing audio operation.
    func stop() {
        playback.stop()
        capture.stop()
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
