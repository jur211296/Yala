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
        makeDraftsWithAccountChoice(from: response, rawText: rawText, context: context).map(\.draft)
    }

    /// Lo mismo, con la elección de cuenta de cada borrador (`CuentaSolaAlLeer`): la hoja de la foto la usa para el chip
    /// con estrella, la línea de «por qué» y el selector con «Coinciden con…».
    static func makeDraftsWithAccountChoice(
        from response: VisionResponse,
        rawText: String?,
        context: ModelContext
    ) -> [(draft: InboxDraft, eleccion: CuentaSolaAlLeer.Eleccion)] {
        let sourceType = mapImageTypeToSource(response.imageType)
        // Un solo fetch para todos los movimientos de la foto.
        let accounts = DraftBuilder.fetchActiveAccounts(context: context)

        return response.transactions.map { transaction in
            createDraft(
                from: transaction,
                sourceType: sourceType,
                rawText: rawText,
                confidence: response.confidence,
                accounts: accounts,
                context: context
            )
        }
    }

    // MARK: - Private Methods

    private static func createDraft(
        from transaction: VisionTransaction,
        sourceType: DraftSourceType,
        rawText: String?,
        confidence: VisionConfidence,
        accounts: [Account],
        context: ModelContext
    ) -> (draft: InboxDraft, eleccion: CuentaSolaAlLeer.Eleccion) {
        // Parse date from YYYY-MM-DD string
        let parsedDate = parseDate(transaction.date)

        // Build note from merchant and/or note
        let note = buildNote(merchant: transaction.merchant, note: transaction.note)

        // La cuenta: la escalera común con el medio de pago leído y, en la nube, la cuenta que propone la IA; sin nada que
        // decida, la única cuenta en la moneda, como antes (`DraftBuilder.chooseAccount`).
        let payment = transaction.payment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let choice = DraftBuilder.chooseAccount(
            mention: payment?.isEmpty == false ? payment : nil,
            last4: nil,
            aiAccount: transaction.account,
            currency: transaction.currency,
            in: accounts
        )
        let matchedAccount = choice.account

        // Naturaleza de la transacción. Aquí no hay un `isExpense` que el parser haya resuelto: el
        // prompt de visión pide el monto YA FIRMADO («expenses are NEGATIVE, income is POSITIVE»,
        // `ImageVisionService`), así que el signo del monto ES el tipo. Sin monto no hay signo del que
        // leerlo, y se asume gasto — el mismo default que aplica la hoja de edición del Inbox al
        // prefijar un draft sin monto (`InboxDraftEditSheet.prefillFromDraft`), que es donde acaba
        // este draft.
        let isExpense = transaction.amount.map { $0 < 0 } ?? true

        // Subcategory inference via MerchantMemory (delegated to DraftBuilder). Descarta lo que
        // contradiga el tipo: la memoria de comercios no mira naturaleza (ver `matchesNature`).
        let matchedSubcategory: Subcategory? = DraftBuilder.suggestSubcategory(
            merchant: note,
            isExpense: isExpense,
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

        let eleccion = CuentaSolaAlLeer.Eleccion(resultado: choice.resultado, mention: payment, last4: nil)
        return (draft, eleccion)
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

    /// La nota del draft: el comercio limpio y, si aporta, un dato útil. Nunca la plantilla del banco
    /// («Consumo con tarjeta de crédito BCP»), números de operación ni la tarjeta enmascarada: lo quita
    /// `VisionNoteCleaner`, también de las respuestas que el prompt nuevo no evite.
    static func buildNote(merchant: String?, note: String?) -> String {
        VisionNoteCleaner.note(merchant: merchant, note: note)
    }
}
