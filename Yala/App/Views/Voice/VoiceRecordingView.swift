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
    @State private var createdDraft: InboxDraft?

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
            .interactiveDismissDisabled(recorder.state != .idle || createdDraft != nil)
            .sheet(item: $createdDraft) { draft in
                InboxDraftEditSheet(draft: draft) {
                    // onApproved callback - dismiss voice view
                    dismiss()
                }
            }
        }
    }

    // MARK: - Recording Visualization

    private var recordingVisualization: some View {
        ZStack {
            // Pulsing rings when recording
            if recorder.state == .recording {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            Color.hotPink.opacity(0.3 - Double(index) * 0.1),
                            lineWidth: 2
                        )
                        .frame(width: 140 + CGFloat(index) * 30, height: 140 + CGFloat(index) * 30)
                        .scaleEffect(1.0 + sin(recorder.recordingDuration * 3 - Double(index) * 0.5) * 0.08)
                        .animation(.easeInOut(duration: 0.3), value: recorder.recordingDuration)
                }
            }

            // Outer glow when recording
            if recorder.state == .recording {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.hotPink.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 50,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 10)
            }

            // Main circle with gradient
            Circle()
                .fill(circleGradient)
                .frame(width: 120, height: 120)
                .shadow(color: circleColor.opacity(0.4), radius: 20, x: 0, y: 8)

            // Glass overlay
            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: 120, height: 120)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // Icon
            Group {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else {
                    Image(systemName: recorder.state == .recording ? "waveform" : "mic.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, isActive: recorder.state == .recording)
                }
            }
        }
    }

    private var circleColor: Color {
        switch recorder.state {
        case .idle:
            return .electricIndigo
        case .recording:
            return .hotPink
        case .processing:
            return .electricIndigo
        }
    }

    private var circleGradient: LinearGradient {
        switch recorder.state {
        case .idle:
            return LinearGradient(
                colors: [Color.electricIndigo, Color.electricIndigo.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .recording:
            return LinearGradient(
                colors: [Color.hotPink, Color.hotPink.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .processing:
            return LinearGradient(
                colors: [Color.electricIndigo.opacity(0.8), Color.electricIndigo.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        .background(Color.yalaCard)
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
        .background(Color.yalaCard)
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
        HStack(spacing: DS.Spacing.xxl) {
            if recorder.state == .recording {
                // Cancel button
                Button {
                    recorder.cancelRecording()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }

                // Stop and process button
                Button {
                    Task {
                        await stopAndProcess()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(
                            LinearGradient(
                                colors: [Color.electricIndigo, Color.electricIndigo.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.electricIndigo.opacity(0.4), radius: 12, x: 0, y: 6)
                }
            } else if !isProcessing {
                // Start recording button
                Button {
                    Task {
                        await startRecording()
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(
                            LinearGradient(
                                colors: [Color.electricIndigo, Color.electricIndigo.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.electricIndigo.opacity(0.4), radius: 16, x: 0, y: 8)
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
            processingStatus = L10n.Voice.analyzing
            let transcription = try await VoiceTranscriptionService.shared.transcribe(
                audioData: audioData,
                language: voiceLanguage
            )

            // Step 3: Parse transcription
            processingStatus = L10n.Voice.parsing
            let parsed = try await TranscriptionParserService.shared.parse(text: transcription.text)

            // Validate: Must have amount to create draft
            guard parsed.amount != nil else {
                isProcessing = false
                errorMessage = L10n.Voice.errorNoAmount
                return
            }

            // Step 4: Create InboxDraft
            processingStatus = L10n.Voice.saving
            let draft = createInboxDraft(from: parsed, transcription: transcription.text)

            isProcessing = false

            // Open the draft in approval screen directly
            createdDraft = draft

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

    private func createInboxDraft(from parsed: ParsedTransaction, transcription: String) -> InboxDraft {
        // Convert Decimal to Double for amount, apply sign based on isExpense
        var amountDouble: Double? = nil
        if let amount = parsed.amount {
            let value = NSDecimalNumber(decimal: amount).doubleValue
            amountDouble = parsed.isExpense ? -abs(value) : abs(value)
        }

        // Try to match account by currency hint
        var matchedAccount: Account?
        var needsUserInputFields = ["account", "subcategory"]

        if let currencyHint = parsed.currencyHint, !currencyHint.isEmpty {
            matchedAccount = findAccount(byCurrency: currencyHint)
            if matchedAccount != nil {
                needsUserInputFields.removeAll { $0 == "account" }
            }
        }

        // Try to match subcategory hint with existing subcategories
        var matchedSubcategory: Subcategory?

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
            account: matchedAccount,
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
        return draft
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

    /// Finds or creates tags matching the hints (case-insensitive)
    /// Creates new tags if they don't exist
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
        var usedColors = allTags.map { $0.colorHex }

        for hint in hints {
            let normalizedHint = hint.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedHint.isEmpty else { continue }

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
                continue
            }

            // No match found - create new tag
            let capitalizedName = hint.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
            let nextColor = Tag.nextAvailableColor(excluding: usedColors)
            let newTag = Tag(name: capitalizedName, colorHex: nextColor)
            usedColors.append(nextColor)
            modelContext.insert(newTag)
            matched.append(newTag)
        }

        return matched
    }

    /// Finds an account matching the currency code
    /// Returns nil if no match or multiple matches (ambiguous)
    private func findAccount(byCurrency currencyCode: String) -> Account? {
        let normalizedCode = currencyCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { account in
                account.isArchived == false
            }
        )

        guard let accounts = try? modelContext.fetch(descriptor) else {
            return nil
        }

        // Find accounts with matching currency
        let matches = accounts.filter { $0.currencyCode.uppercased() == normalizedCode }

        // Return only if exactly one match
        if matches.count == 1 {
            return matches.first
        }

        return nil
    }
}

#Preview {
    VoiceRecordingView()
}
