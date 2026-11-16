//
//  BankNoticeIntent.swift
//  Yala
//
//  Atajo del banco (2.3, B1): la acción de Atajos «Registrar movimiento desde texto». La automatización «Al recibir una
//  notificación de <app del banco>» le pasa el aviso y el movimiento queda en la Bandeja por confirmar.
//
//  Medido en el iPhone 14 con iOS 27.2.1 (prueba B0, 2026-11-14): la variable «Notificación» del disparador entrega
//  «título␤cuerpo» con el importe, y la automatización corre con el iPhone bloqueado sin pedir nada.
//
//  Como Apple Pay: corre por detrás, NO toca SwiftData y encola en el App Group; la app crea el borrador al abrir.
//  Lee aquí (reglas y, si no, el modelo del iPhone) para que el modelo corra una vez, con el aviso recién llegado.
//  Sin diálogo ni vista: con el iPhone bloqueado iOS no puede enseñar UI y daría el atajo por fallido. Y sin notificación
//  propia (decisión A5): el banco ya avisó y el estado se ve en la Bandeja.
//

import AppIntents
import Foundation

/// El banco del atajo instalado. Cada atajo listo por enlace (B2, opción I2) lo trae puesto; sin él, se deduce del texto.
enum BankNoticeBankChoice: String, AppEnum {
    case bcp, yape, interbank, plin, bbva, scotiabank, other

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "shortcut.bankNotice.param.bank"

    static var caseDisplayRepresentations: [BankNoticeBankChoice: DisplayRepresentation] = [
        .bcp: "BCP",
        .yape: "Yape",
        .interbank: "Interbank",
        .plin: "Plin",
        .bbva: "BBVA",
        .scotiabank: "Scotiabank",
        .other: "shortcut.bankNotice.bank.other",
    ]

    var bank: BankNoticeBank { BankNoticeBank(rawValue: rawValue) ?? .other }
}

struct BankNoticeIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.bankNotice.title"
    static var description = IntentDescription("shortcut.bankNotice.description")

    static var openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Record a movement from the text \(\.$text)") {
            \.$bank
        }
    }

    init() {}

    @Parameter(
        title: "shortcut.bankNotice.param.text",
        description: "shortcut.bankNotice.param.text.description",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String?

    @Parameter(title: "shortcut.bankNotice.param.bank")
    var bank: BankNoticeBankChoice?

    @MainActor
    func perform() async throws -> some IntentResult {
        // Con Yala solo en grupos no hay Bandeja que enseñe el borrador: el aviso no se encola.
        if case .blocked = GroupsOnlyIntentGate.current() { return .result() }
        guard let text, !BankNoticeParser.normalized(text).isEmpty else { return .result() }
        let hint = bank?.bank
        let entry = await Self.read(text: text, bankHint: hint, modelReader: BankNoticeModelReader.read)
        guard entry.reading.leavesDraft else { return .result() }
        MetricsService.used(.siriAtajos)
        BankNoticePendingStore.append(entry)
        return .result()
    }

    /// Reglas primero; si no saben, el modelo del iPhone; si tampoco, «No entendimos este aviso». Inyectable para los tests.
    static func read(
        text: String,
        bankHint: BankNoticeBank?,
        now: Date = .now,
        modelReader: (String) async -> BankNoticeReading?
    ) async -> BankNoticePendingEntry {
        let reading: BankNoticeReading
        if let ruled = BankNoticeParser.read(text, bankHint: bankHint) {
            reading = ruled
        } else if let modeled = await modelReader(text) {
            reading = modeled
        } else {
            reading = .notUnderstood
        }
        return BankNoticePendingEntry(
            rawText: text,
            bank: BankNoticeParser.bank(text: text, hint: bankHint),
            reading: reading,
            receivedAt: now.timeIntervalSince1970
        )
    }
}
