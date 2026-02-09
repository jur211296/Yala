//
//  AudioRecorderService.swift
//  Yala
//
//  Service for recording audio from the microphone for voice transcription.
//

import AVFoundation
import Combine
import Foundation

// MARK: - Recording State

enum RecordingState {
    case idle
    case recording
    case processing
}

// MARK: - Recording Error

enum RecordingError: LocalizedError {
    case microphonePermissionDenied
    case microphonePermissionRestricted
    case failedToStartRecording
    case noRecordingInProgress
    case recordingTooShort
    case failedToReadAudioFile

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access was denied. Please enable it in Settings."
        case .microphonePermissionRestricted:
            return "Microphone access is restricted on this device."
        case .failedToStartRecording:
            return "Failed to start audio recording."
        case .noRecordingInProgress:
            return "No recording is currently in progress."
        case .recordingTooShort:
            return "Recording was too short. Please try again."
        case .failedToReadAudioFile:
            return "Failed to read the recorded audio file."
        }
    }
}

// MARK: - Audio Recorder Service

@MainActor
final class AudioRecorderService: NSObject, ObservableObject {
    static let shared = AudioRecorderService()

    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var recordingDuration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var durationTimer: Timer?

    private let minimumRecordingDuration: TimeInterval = 0.5

    private override init() {
        super.init()
    }

    // MARK: - Permission

    var hasMicrophonePermission: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    func requestMicrophonePermission() async -> Bool {
        let currentStatus = AVAudioApplication.shared.recordPermission

        switch currentStatus {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Recording Control

    func startRecording() async throws {
        guard await requestMicrophonePermission() else {
            let status = AVAudioApplication.shared.recordPermission
            if status == .denied {
                throw RecordingError.microphonePermissionDenied
            } else {
                throw RecordingError.microphonePermissionRestricted
            }
        }

        // Configure audio session for recording
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)

        // Create temporary file URL for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "voice_recording_\(UUID().uuidString).m4a"
        recordingURL = tempDir.appendingPathComponent(fileName)

        guard let url = recordingURL else {
            throw RecordingError.failedToStartRecording
        }

        // Recording settings optimized for speech recognition
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,  // Whisper works well with 16kHz
            AVNumberOfChannelsKey: 1,  // Mono is sufficient for speech
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self

        guard audioRecorder?.record() == true else {
            throw RecordingError.failedToStartRecording
        }

        state = .recording
        recordingDuration = 0

        // Start duration timer
        startDurationTimer()
    }

    func stopRecording() async throws -> Data {
        guard state == .recording, let recorder = audioRecorder else {
            throw RecordingError.noRecordingInProgress
        }

        let duration = recorder.currentTime

        // Stop timer and recorder
        durationTimer?.invalidate()
        durationTimer = nil
        recorder.stop()

        state = .processing

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            #if DEBUG
            print("AudioRecorderService: Error deactivating audio session: \(error)")
            #endif
        }

        // Check minimum duration
        guard duration >= minimumRecordingDuration else {
            cleanup()
            throw RecordingError.recordingTooShort
        }

        // Read audio data
        guard let url = recordingURL else {
            cleanup()
            throw RecordingError.failedToReadAudioFile
        }
        let audioData: Data
        do {
            audioData = try Data(contentsOf: url)
        } catch {
            #if DEBUG
            print("AudioRecorderService: Error reading audio file: \(error)")
            #endif
            cleanup()
            throw RecordingError.failedToReadAudioFile
        }

        cleanup()
        return audioData
    }

    func cancelRecording() {
        durationTimer?.invalidate()
        durationTimer = nil
        audioRecorder?.stop()
        cleanup()
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.recordingDuration = self.audioRecorder?.currentTime ?? 0
            }
        }
    }

    private func cleanup() {
        // Delete temporary file
        if let url = recordingURL {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                #if DEBUG
                print("AudioRecorderService: Error removing temp file: \(error)")
                #endif
            }
        }

        audioRecorder = nil
        recordingURL = nil
        state = .idle
        recordingDuration = 0
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Recording finished (handled in stopRecording)
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            cancelRecording()
        }
    }
}
