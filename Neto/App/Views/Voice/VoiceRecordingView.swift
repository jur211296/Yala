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
                instructionsView
            }
        }
    }

    // MARK: - Instructions View

    private var instructionsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.lg) {
                Text(L10n.Voice.tapToRecord)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Hints grid
                hintsSection

                // Examples
                examplesSection
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    private var hintsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Voice.youCanSay)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DS.Spacing.sm) {
                hintChip(icon: "arrow.left.arrow.right", text: L10n.Voice.hintTypeExample)
                hintChip(icon: "dollarsign.circle", text: L10n.Voice.hintAmountExample)
                hintChip(icon: "folder", text: L10n.Voice.hintSubcategoryExample)
                hintChip(icon: "mappin", text: L10n.Voice.hintMerchantExample)
                hintChip(icon: "tag", text: L10n.Voice.hintTagExample)
                hintChip(icon: "calendar", text: L10n.Voice.hintDateExample)
            }
        }
        .padding(DS.Spacing.md)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func hintChip(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(Color.electricIndigo)

            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.electricIndigo.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Voice.exampleLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: DS.Spacing.xs) {
                exampleRow(text: L10n.Voice.example1)
                exampleRow(text: L10n.Voice.example2)
                exampleRow(text: L10n.Voice.example3)
            }
        }
        .padding(DS.Spacing.md)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func exampleRow(text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "text.quote")
                .font(.caption)
                .foregroundStyle(Color.electricIndigo)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .italic()

            Spacer()
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .stroke(Color.electricIndigo.opacity(0.2), lineWidth: 1)
        )
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

        // Try to match subcategory hint with existing subcategories
        var matchedSubcategory: Subcategory?
        var needsUserInputFields = ["account", "subcategory"]

        if let hint = parsed.subcategoryHint, !hint.isEmpty {
            matchedSubcategory = findSubcategory(matching: hint, isExpense: parsed.isExpense)
            if matchedSubcategory != nil {
                needsUserInputFields.removeAll { $0 == "subcategory" }
            }
        }

        // Try to match tag hints with existing tags
        var matchedTags: [Tag] = []
        if !parsed.tagHints.isEmpty {
            matchedTags = findTags(matching: parsed.tagHints)
        }

        let draft = InboxDraft(
            note: parsed.note,
            amount: amountDouble,
            date: parsed.date,
            subcategory: matchedSubcategory,
            tags: matchedTags,
            sourceType: .voice,
            rawText: transcription,
            confidenceAmount: parsed.confidence.amount,
            confidenceDate: parsed.confidence.date,
            confidenceMerchant: parsed.confidence.merchant,
            confidenceSubcategory: matchedSubcategory != nil ? parsed.confidence.subcategory : nil,
            needsUserInput: needsUserInputFields
        )
        modelContext.insert(draft)
        try? modelContext.save()
    }

    // MARK: - Entity Matching

    /// Finds a subcategory matching the hint (case-insensitive, partial match)
    /// Returns nil if multiple matches found (ambiguous) to let user choose manually
    private func findSubcategory(matching hint: String, isExpense: Bool) -> Subcategory? {
        let normalizedHint = hint.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate<Subcategory> { subcategory in
                subcategory.isVisible == true
            }
        )

        guard let subcategories = try? modelContext.fetch(descriptor) else {
            return nil
        }

        // Filter by expense type (subcategories in expense categories for expenses, income for income)
        let filtered = subcategories.filter { sub in
            let category = sub.category
            return isExpense ? !category.isIncome : category.isIncome
        }

        // Try exact match first - check for duplicates
        let exactMatches = filtered.filter { $0.name.lowercased() == normalizedHint }
        if exactMatches.count == 1 {
            return exactMatches.first
        } else if exactMatches.count > 1 {
            // Ambiguous: multiple subcategories with same name in different categories
            return nil
        }

        // Try contains match - check for duplicates
        let partialMatches = filtered.filter { $0.name.lowercased().contains(normalizedHint) }
        if partialMatches.count == 1 {
            return partialMatches.first
        } else if partialMatches.count > 1 {
            // Ambiguous: multiple matches
            return nil
        }

        // Try if hint contains subcategory name - check for duplicates
        let reverseMatches = filtered.filter { normalizedHint.contains($0.name.lowercased()) }
        if reverseMatches.count == 1 {
            return reverseMatches.first
        }
        // Multiple reverse matches = ambiguous, return nil

        return nil
    }

    /// Finds tags matching the hints (case-insensitive)
    private func findTags(matching hints: [String]) -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate<Tag> { tag in
                tag.isActive == true
            }
        )

        guard let allTags = try? modelContext.fetch(descriptor) else {
            return []
        }

        var matched: [Tag] = []
        for hint in hints {
            let normalizedHint = hint.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // Try exact match first
            if let exact = allTags.first(where: { $0.name.lowercased() == normalizedHint }) {
                if !matched.contains(where: { $0.persistentModelID == exact.persistentModelID }) {
                    matched.append(exact)
                }
                continue
            }

            // Try contains match
            if let partial = allTags.first(where: { $0.name.lowercased().contains(normalizedHint) }) {
                if !matched.contains(where: { $0.persistentModelID == partial.persistentModelID }) {
                    matched.append(partial)
                }
            }
        }

        return matched
    }
}

#Preview {
    VoiceRecordingView()
}
