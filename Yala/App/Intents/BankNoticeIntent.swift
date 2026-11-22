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

/// De dónde llega el texto (B3): la notificación del banco (lo de siempre) o un correo de la app Mail. Con «Correo», se
/// quita el pie legal y se leen los campos con etiqueta antes que las reglas (`BankNoticeMail`).
enum BankNoticeSourceChoice: String, AppEnum {
    case notification, mail

    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("atajoParte2.intent.source", table: "CapturaAtajoParte2"))

    static var caseDisplayRepresentations: [BankNoticeSourceChoice: DisplayRepresentation] = [
        .notification: DisplayRepresentation(
            title: LocalizedStringResource("atajoParte2.intent.source.notification", table: "CapturaAtajoParte2")),
        .mail: DisplayRepresentation(
            title: LocalizedStringResource("atajoParte2.intent.source.mail", table: "CapturaAtajoParte2")),
    ]
}

struct BankNoticeIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.bankNotice.title"
    static var description = IntentDescription("shortcut.bankNotice.description")

    static var openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Record a movement from the text \(\.$text)") {
            \.$bank
            \.$source
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

    @Parameter(title: LocalizedStringResource("atajoParte2.intent.source", table: "CapturaAtajoParte2"))
    var source: BankNoticeSourceChoice?

    @MainActor
    func perform() async throws -> some IntentResult {
        // Con Yala solo en grupos no hay Bandeja que enseñe el borrador: el aviso no se encola.
        if case .blocked = GroupsOnlyIntentGate.current() { return .result() }
        guard let text, !BankNoticeParser.normalized(text).isEmpty else { return .result() }
        let hint = bank?.bank
        let isMail = source == .mail
        // Pausado (B2): lo que llega se ignora y no se guarda, ni en la cola ni en los contadores.
        let bankForPause = BankNoticeParser.bank(text: text, hint: hint) ?? .other
        if BankNoticeActivityStore.isPaused(bankForPause) { return .result() }
        let entry = await Self.read(text: text, bankHint: hint, isMail: isMail, modelReader: BankNoticeModelReader.read)
        // El estado de «Avisos del banco»: cuándo llegó y qué se entendió, también lo que no era una compra.
        BankNoticeActivityStore.record(entry.reading, bank: entry.bank ?? .other, at: Date(timeIntervalSince1970: entry.receivedAt))
        guard entry.reading.leavesDraft else { return .result() }
        MetricsService.used(.siriAtajos)
        BankNoticePendingStore.append(entry)
        return .result()
    }

    /// Reglas primero; si no saben, el modelo del iPhone; si tampoco, «No entendimos este aviso». Inyectable para los tests.
    static func read(
        text rawText: String,
        bankHint: BankNoticeBank?,
        isMail: Bool = false,
        now: Date = .now,
        modelReader: (String) async -> BankNoticeReading?
    ) async -> BankNoticePendingEntry {
        // Un correo se recorta antes (fuera el pie legal y lo que sobra): es también lo que se guarda y lo que ve el modelo.
        let text = isMail ? BankNoticeMail.cleaned(rawText) : rawText
        let reading: BankNoticeReading
        if let ruled = isMail ? BankNoticeMail.read(rawText, bankHint: bankHint) : BankNoticeParser.read(text, bankHint: bankHint) {
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
