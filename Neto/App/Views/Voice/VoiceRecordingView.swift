//
//  VoiceRecordingView.swift
//  Neto
//
//  Sheet view for recording voice input and creating transaction drafts.
//

import SwiftData
import SwiftUI

struct VoiceRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var recorder = AudioRecorderService.shared

    @AppStorage("voiceLanguage") private var voiceLanguageRaw: String = VoiceLanguage.system.rawValue

    @State private var errorMessage: String?
    @State private var isProcessing = false
    @State private var processingStatus: String = ""

    private var voiceLanguage: VoiceLanguage {
        VoiceLanguage(rawValue: voiceLanguageRaw) ?? .system
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                // Recording visualization
                recordingVisualization

                // Status text
                statusText

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                }

                Spacer()

                // Action buttons
                actionButtons
            }
            .padding(DS.Spacing.xl)
            .navigationTitle(L10n.Voice.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        recorder.cancelRecording()
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled(recorder.state != .idle)
        }
    }

    // MARK: - Recording Visualization

    private var recordingVisualization: some View {
        ZStack {
            // Outer pulsing circle when recording
            if recorder.state == .recording {
                Circle()
                    .fill(Color.electricIndigo.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .scaleEffect(1.0 + sin(recorder.recordingDuration * 4) * 0.1)
                    .animation(.easeInOut(duration: 0.25), value: recorder.recordingDuration)
            }

            // Main circle
            Circle()
                .fill(circleColor)
                .frame(width: 120, height: 120)

            // Icon
            Group {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else {
                    Image(systemName: recorder.state == .recording ? "waveform" : "mic.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var circleColor: Color {
        switch recorder.state {
        case .idle:
            return .electricIndigo
        case .recording:
            return .red
        case .processing:
            return .electricIndigo.opacity(0.7)
        }
    }

    // MARK: - Status Text

    private var statusText: some View {
        VStack(spacing: DS.Spacing.sm) {
            if recorder.state == .recording {
                Text(formatDuration(recorder.recordingDuration))
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)

                Text(L10n.Voice.recording)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if isProcessing {
                Text(processingStatus)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(L10n.Voice.pleaseWait)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(L10n.Voice.tapToRecord)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(L10n.Voice.instruction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: DS.Spacing.xl) {
            if recorder.state == .recording {
                // Cancel button
                Button {
                    recorder.cancelRecording()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.secondary)
                        .clipShape(Circle())
                }

                // Stop and process button
                Button {
                    Task {
                        await stopAndProcess()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.electricIndigo)
                        .clipShape(Circle())
                }
            } else if !isProcessing {
                // Start recording button
                Button {
                    Task {
                        await startRecording()
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.electricIndigo)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.bottom, DS.Spacing.xxl)
    }

    // MARK: - Recording Actions

    private func startRecording() async {
        errorMessage = nil

        do {
            try await recorder.startRecording()
        } catch let error as RecordingError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopAndProcess() async {
        errorMessage = nil
        isProcessing = true

        do {
            // Step 1: Stop recording and get audio data
            processingStatus = L10n.Voice.processingAudio
            let audioData = try await recorder.stopRecording()

            // Step 2: Transcribe audio
            processingStatus = L10n.Voice.transcribing
            let transcription = try await VoiceTranscriptionService.shared.transcribe(
                audioData: audioData,
                language: voiceLanguage
            )

            // Step 3: Parse transcription
            processingStatus = L10n.Voice.parsing
            let parsed = try await TranscriptionParserService.shared.parse(text: transcription.text)

            // Step 4: Create InboxDraft
            processingStatus = L10n.Voice.saving
            createInboxDraft(from: parsed, transcription: transcription.text)

            isProcessing = false
            dismiss()

        } catch let error as RecordingError {
            isProcessing = false
            errorMessage = error.localizedDescription
        } catch let error as TranscriptionError {
            isProcessing = false
            errorMessage = error.localizedDescription
        } catch let error as ParserError {
            isProcessing = false
            errorMessage = error.localizedDescription
        } catch {
            isProcessing = false
            errorMessage = error.localizedDescription
        }
    }

    private func createInboxDraft(from parsed: ParsedTransaction, transcription: String) {
        // Convert Decimal to Double for amount, apply sign based on isExpense
        var amountDouble: Double? = nil
        if let amount = parsed.amount {
            let value = NSDecimalNumber(decimal: amount).doubleValue
            amountDouble = parsed.isExpense ? -abs(value) : abs(value)
        }

        let draft = InboxDraft(
            note: parsed.note,
            amount: amountDouble,
            date: parsed.date,
            sourceType: .voice,
            rawText: transcription,
            confidenceAmount: parsed.confidence.amount,
            confidenceDate: parsed.confidence.date,
            confidenceMerchant: parsed.confidence.merchant
        )
        modelContext.insert(draft)
        try? modelContext.save()
    }
}

#Preview {
    VoiceRecordingView()
}
