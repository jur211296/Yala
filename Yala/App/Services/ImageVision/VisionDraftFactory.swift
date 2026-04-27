//
//  VisionDraftFactory.swift
//  Yala
//
//  Factory for creating InboxDrafts from GPT-4o Vision responses.
//

import Foundation
import SwiftData

/// Factory for creating InboxDrafts from Vision API responses
@MainActor struct VisionDraftFactory {

    /// Creates InboxDrafts from a VisionResponse and inserts them into context.
    /// - Parameters:
    ///   - response: The VisionResponse from GPT-4o Vision
    ///   - rawText: Optional raw OCR text for reference
    ///   - context: SwiftData ModelContext for creating drafts
    /// - Returns: Array of created InboxDrafts (already inserted)
    static func createDrafts(
        from response: VisionResponse,
        rawText: String?,
        context: ModelContext
    ) -> [InboxDraft] {
        let drafts = makeDrafts(from: response, rawText: rawText, context: context)
        for draft in drafts {
            context.insert(draft)
        }
        return drafts
    }

    /// Creates InboxDrafts from a VisionResponse WITHOUT inserting into context.
    /// Use this when you need to deduplicate before insertion.
    static func makeDrafts(
        from response: VisionResponse,
        rawText: String?,
        context: ModelContext
    ) -> [InboxDraft] {
        let sourceType = mapImageTypeToSource(response.imageType)

        var drafts: [InboxDraft] = []

        for transaction in response.transactions {
            let draft = createDraft(
                from: transaction,
                sourceType: sourceType,
                rawText: rawText,
                confidence: response.confidence,
                context: context
            )
            drafts.append(draft)
        }

        return drafts
    }

    // MARK: - Private Methods

    private static func createDraft(
        from transaction: VisionTransaction,
        sourceType: DraftSourceType,
        rawText: String?,
        confidence: VisionConfidence,
        context: ModelContext
    ) -> InboxDraft {
        // Parse date from YYYY-MM-DD string
        let parsedDate = parseDate(transaction.date)

        // Build note from merchant and/or note
        let note = buildNote(merchant: transaction.merchant, note: transaction.note)

        // Account inference (delegated to DraftBuilder for chat reuse)
        let matchedAccount: Account? = transaction.currency.flatMap {
            DraftBuilder.findAccount(byCurrency: $0, context: context)
        }

        // Subcategory inference via MerchantMemory (delegated to DraftBuilder)
        let matchedSubcategory: Subcategory? = DraftBuilder.suggestSubcategory(
            merchant: note,
            context: context
        )

        // Determine which fields need user input
        let needsUserInput = DraftBuilder.computeNeedsUserInput(
            hasAmount: transaction.amount != nil,
            hasAccount: matchedAccount != nil,
            hasSubcategory: matchedSubcategory != nil
        )

        // Create the draft
        let draft = InboxDraft(
            note: note,
            amount: transaction.amount,
            date: parsedDate,
            subcategory: matchedSubcategory,
            sourceType: sourceType,
            rawText: rawText,
            evidence: transaction.merchant,
            confidenceAmount: transaction.amount != nil ? confidence.overall : nil,
            confidenceDate: parsedDate != nil ? confidence.overall : nil,
            confidenceMerchant: transaction.merchant != nil ? confidence.overall : nil,
            confidenceSubcategory: matchedSubcategory != nil ? confidence.overall : nil,
            needsUserInput: needsUserInput
        )

        // Assign matched account if found
        if let account = matchedAccount {
            draft.account = account
        }

        return draft
    }

    static func mapImageTypeToSource(_ imageType: String) -> DraftSourceType {
        switch imageType.lowercased() {
        case "single":
            return .screenshotSingle
        case "list":
            return .screenshotList
        case "receipt":
            return .receiptPhoto
        default:
            return .screenshotSingle
        }
    }

    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = formatter.date(from: dateString) else { return nil }

        // Set time to noon to avoid timezone edge cases
        let calendar = Calendar.current
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
    }

    static func buildNote(merchant: String?, note: String?) -> String {
        let parts = [merchant, note].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.joined(separator: " - ")
    }
}
