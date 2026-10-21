//
//  SiriOnDeviceEntry.swift
//  Yala
//
//  «Anotar con Siri» para quien no tiene Pro, leyendo el dictado con el modelo del propio iPhone (Apple Intelligence,
//  `FoundationModels`): sin servidor, así que sin coste para Yala y sin que el texto salga del teléfono.
//
//  Auditoría UX 2.2, lote 15, L15-6. Jürgen eligió la opción B (sin Pro, Siri abre la hoja de Pro) con un matiz: que el
//  usuario gratis pueda usar IA «usando el propio modelo de Siri si lo tienen disponible». Medido el 2026-10-21 con el
//  SDK de iOS 27.1: `SystemLanguageModel` existe desde iOS 26 (el mínimo de Yala), dice si el modelo está disponible en
//  ESTE aparato (Apple Intelligence encendido y descargado) y genera una estructura tipada (`@Generable`). Es viable.
//
//  Va APAGADO (`isEnabled`): encenderlo cambia lo que vive un usuario gratis —en vez de la hoja de Pro, un borrador en
//  la Bandeja—, y eso lo decide Jürgen (card en «espera decisión»). En DEBUG se enciende con la clave del App Group
//  `debug.siriOnDeviceFreeEntry`, para probarlo en un iPhone con Apple Intelligence.
//

import Foundation
import FoundationModels

/// Qué hace «Anotar con Siri» según quién lo usa. Pura: la elige `SiriNaturalEntryIntent` y la fija su test.
nonisolated enum SiriEntryRoute: Equatable {
    /// Pro: el texto se lee en el servidor (con el consentimiento de IA) o, si no, con la lectura local del monto.
    case server
    /// Sin Pro, con el modelo del iPhone encendido y disponible: se lee en el teléfono.
    case onDevice
    /// Sin Pro y sin modelo del iPhone: Siri lo dice y abre Yala en la hoja de Pro.
    case upgrade

    static func decide(isPro: Bool, onDeviceEnabled: Bool, onDeviceAvailable: Bool) -> SiriEntryRoute {
        if isPro { return .server }
        return onDeviceEnabled && onDeviceAvailable ? .onDevice : .upgrade
    }
}

nonisolated enum SiriOnDeviceEntry {

    /// El interruptor. Apagado en producción hasta que Jürgen decida encenderlo.
    static var isEnabled: Bool {
        #if DEBUG
        UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)?.bool(forKey: "debug.siriOnDeviceFreeEntry") ?? false
        #else
        false
        #endif
    }

    /// Si el modelo del aparato se puede usar ahora (Apple Intelligence encendido, modelo descargado, aparato compatible).
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Lo que el modelo devuelve. Los nombres de las subcategorías los elige de la lista que se le da.
    @Generable
    struct Entry {
        @Guide(description: "Importe del movimiento, en positivo. Vacío si el texto no dice ninguno.")
        var amount: Double?
        @Guide(description: "Descripción corta del movimiento, en el idioma del texto.")
        var note: String
        @Guide(description: "true si es un gasto; false si es un ingreso.")
        var isExpense: Bool
        @Guide(description: "Nombre exacto de una subcategoría de la lista dada, o vacío si ninguna encaja.")
        var subcategory: String?
        @Guide(description: "Código ISO 4217 de la moneda si el texto la dice (PEN, USD, EUR…); vacío si no.")
        var currencyCode: String?
    }

    @Generable
    struct Entries {
        @Guide(description: "Un elemento por cada movimiento que menciona el texto.")
        var entries: [Entry]
    }

    /// Lee el dictado en el teléfono. Lanza si el modelo falla; quien llama cae a la lectura local del monto.
    static func parse(
        _ text: String,
        expenseSubcategories: [String],
        incomeSubcategories: [String]
    ) async throws -> [ParsedTransaction] {
        let instructions = """
        Conviertes lo que alguien dicta en movimientos de sus finanzas personales. \
        Subcategorías de gasto: \(expenseSubcategories.joined(separator: ", ")). \
        Subcategorías de ingreso: \(incomeSubcategories.joined(separator: ", ")). \
        No inventes importes ni subcategorías.
        """
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: text, generating: Entries.self)
        return response.content.entries.map { entry in
            ParsedTransaction(
                // Por texto y no desde `Double`: `Decimal(25.9)` guarda 25,8999999999999979…
                amount: entry.amount.flatMap { Decimal(string: String(abs($0)), locale: Locale(identifier: "en_US_POSIX")) },
                date: nil,
                note: entry.note.isEmpty ? text : entry.note,
                isExpense: entry.isExpense,
                subcategoryHint: entry.subcategory.flatMap { $0.isEmpty ? nil : $0 },
                tagHints: [],
                currencyHint: entry.currencyCode.flatMap { $0.isEmpty ? nil : $0.uppercased() },
                // Confianza media: el borrador se revisa en la Bandeja igual que los demás.
                confidence: ParsedTransaction.TransactionConfidence(
                    amount: entry.amount == nil ? 0 : 0.8, date: 0, merchant: 0.5,
                    subcategory: entry.subcategory == nil ? 0 : 0.6, tags: 0
                )
            )
        }
    }
}
