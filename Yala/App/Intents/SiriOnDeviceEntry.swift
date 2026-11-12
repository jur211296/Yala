//
//  SiriOnDeviceEntry.swift
//  Yala
//
//  «Anotar con Siri» para quien no tiene Pro, leyendo el dictado con el modelo del propio iPhone (Apple Intelligence,
//  `FoundationModels`): sin servidor, así que sin coste para Yala y sin que el texto salga del teléfono.
//
//  Auditoría UX 2.2, lote 15, L15-6. Jürgen eligió la opción B (sin Pro, Siri abre la hoja de Pro) con un matiz: que el
//  usuario gratis pueda usar IA «usando el propio modelo de Siri si lo tienen disponible». El 2026-10-21 decidió
//  encenderlo (opción A de la card «Siri gratis con el modelo del propio iPhone»): sin Pro y con el modelo listo en ESTE
//  aparato, el dictado se lee en el teléfono y deja el borrador en la Bandeja; sin el modelo, la hoja de Pro de siempre.
//
//  «Modelo listo» es `SystemLanguageModel.default.availability == .available` Y que admita el idioma del teléfono: Yala
//  tiene 16 y el modelo no los cubre todos. Cada motivo de «no» se nombra (`SiriOnDeviceModelState`) para la señal del
//  gate (`siriEntryRoute`); todos llevan a la hoja de Pro.
//

import Foundation
import FoundationModels

/// Qué hace «Anotar con Siri» según quién lo usa. Pura: la elige `SiriNaturalEntryIntent` y la fija su test.
nonisolated enum SiriEntryRoute: String, Equatable {
    /// Pro: el texto se lee en el servidor (con el consentimiento de IA) o, si no, con la lectura local del monto.
    case server
    /// Sin Pro, con el modelo del iPhone listo: se lee en el teléfono.
    case onDevice
    /// Sin Pro y sin modelo del iPhone: Siri lo dice y abre Yala en la hoja de Pro.
    case upgrade

    static func decide(isPro: Bool, onDeviceEnabled: Bool, model: SiriOnDeviceModelState) -> SiriEntryRoute {
        if isPro { return .server }
        return onDeviceEnabled && model == .available ? .onDevice : .upgrade
    }
}

/// En qué estado está el modelo del iPhone para leer un dictado. Solo `available` lo usa; el resto nombra el motivo.
nonisolated enum SiriOnDeviceModelState: String, Equatable, CaseIterable {
    case available
    /// El aparato no tiene Apple Intelligence (anterior al iPhone 15 Pro).
    case deviceNotEligible
    /// Lo tiene, pero la persona no lo ha encendido.
    case appleIntelligenceNotEnabled
    /// Encendido, pero el modelo aún no está descargado o listo.
    case modelNotReady
    /// Listo, pero no admite el idioma del teléfono.
    case languageNotSupported
    /// Un motivo que este build no conoce.
    case unavailable

    /// `supportsLocale` solo se pregunta con el modelo disponible.
    static func from(
        _ availability: SystemLanguageModel.Availability,
        supportsLocale: () -> Bool
    ) -> SiriOnDeviceModelState {
        switch availability {
        case .available:
            return supportsLocale() ? .available : .languageNotSupported
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .appleIntelligenceNotEnabled
            case .modelNotReady: return .modelNotReady
            @unknown default: return .unavailable
            }
        @unknown default:
            return .unavailable
        }
    }
}

nonisolated enum SiriOnDeviceEntry {

    /// El interruptor. Encendido desde el 2026-10-21 (decisión A de Jürgen); apagarlo es cambiar esta línea.
    static let isEnabled = true

    /// El estado del modelo de ESTE aparato ahora. En DEBUG, `-uitest-siri-model` lo finge (el simulador no lo tiene).
    static var modelState: SiriOnDeviceModelState {
        #if DEBUG
        if let forced = UITestHooks.siriModelOverride {
            return SiriOnDeviceModelState(rawValue: forced) ?? .unavailable
        }
        #endif
        let model = SystemLanguageModel.default
        return .from(model.availability) { model.supportsLocale(Locale.current) }
    }

    /// Detalle sin datos personales del error de una lectura fallida: tipo y código, nunca el mensaje.
    static func failureDetail(_ error: Error) -> String {
        let code = (error as NSError).code
        return "failed:\(String(describing: type(of: error)))#\(code)"
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
        #if DEBUG
        if UITestHooks.siriModelOverride == SiriOnDeviceModelState.available.rawValue {
            return [stubEntry]
        }
        #endif
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

    #if DEBUG
    /// Lo que «lee» el modelo fingido de `-uitest-siri-model available`: una nota que no sale de ningún otro camino,
    /// para que el XCUITest distinga el borrador del teléfono del borrador básico de la lectura local.
    static let stubNote = "QA modelo del iPhone"
    private static var stubEntry: ParsedTransaction {
        ParsedTransaction(
            amount: 20, date: nil, note: stubNote, isExpense: true, subcategoryHint: nil, tagHints: [],
            currencyHint: nil,
            confidence: ParsedTransaction.TransactionConfidence(amount: 0.8, date: 0, merchant: 0.5, subcategory: 0, tags: 0)
        )
    }
    #endif
}
