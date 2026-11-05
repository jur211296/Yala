//
//  BankEmailDraftLogic.swift
//  Yala
//
//  Correo del banco por reenvío (2.3): de lo que el gateway leyó de un aviso a lo que lleva el borrador de la Bandeja.
//  Pura: sin `ModelContext`, para que los tests la recorran entera.
//
//  - El importe lleva signo: gasto negativo, ingreso positivo. Sin `kind`, gasto (los avisos de banco casi siempre lo son,
//    y la persona lo cambia al revisar).
//  - La fecha es la del aviso a mediodía (como la foto y la voz: no cae en otro día por la zona horaria); sin fecha, la de
//    llegada.
//  - La cuenta: primero la que nombra el aviso (banco y/o 4 últimos dígitos) contra las cuentas de la persona, con la
//    misma lógica de medio de pago que Yala IA (`DraftBuilder.findAccount(paymentMention:dictatedCurrency:in:)`); si no,
//    la ÚNICA cuenta en esa divisa; si no, ninguna y la Bandeja la pide.
//

import Foundation

enum BankEmailDraftLogic {

    struct DraftFields: Equatable {
        let note: String
        let amount: Double
        let date: Date
        let currencyCode: String?
        /// Lo que se le pasa a la búsqueda de cuenta por nombre («BCP 4321»). `nil` si el aviso no nombra nada.
        let accountMention: String?
        /// La línea de evidencia del borrador: «BCP · ****4321». Nunca el correo.
        let evidence: String?
    }

    static func fields(from dto: BankEmailDraftDTO, calendar: Calendar = .current) -> DraftFields {
        let magnitude = abs(dto.amount)
        let signed = dto.kind == "income" ? magnitude : -magnitude
        let merchant = dto.merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bank = dto.bank?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let last4 = dto.accountLast4 ?? ""

        let mentionParts = [bank, last4].filter { !$0.isEmpty }
        let evidenceParts = [bank, last4.isEmpty ? "" : "****\(last4)"].filter { !$0.isEmpty }

        return DraftFields(
            note: merchant,
            amount: signed,
            date: date(from: dto.date, receivedAtMs: dto.receivedAtMs, calendar: calendar),
            currencyCode: dto.currency.map { $0.uppercased() }.flatMap { $0.count == 3 ? $0 : nil },
            accountMention: mentionParts.isEmpty ? nil : mentionParts.joined(separator: " "),
            evidence: evidenceParts.isEmpty ? nil : evidenceParts.joined(separator: " · ")
        )
    }

    /// `YYYY-MM-DD` a mediodía local. Una fecha futura (más de un día) o ilegible cae a la de llegada.
    static func date(from iso: String?, receivedAtMs: Double, calendar: Calendar = .current) -> Date {
        let received = Date(timeIntervalSince1970: receivedAtMs / 1000)
        guard let iso, iso.count == 10 else { return received }
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return received }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12
        guard let parsed = calendar.date(from: components) else { return received }
        if parsed.timeIntervalSince(received) > 86_400 { return received }
        return parsed
    }
}

/// Los ids de borradores del correo que esta app ya creó, para no duplicar si el `ack` no llegó al gateway. Guarda los
/// últimos 200; un id más viejo ya lo habrá borrado el gateway (30 días) o el `ack` siguiente.
enum BankEmailCreatedIDsStore {
    static let key = "bankEmail.createdDraftIDs"
    static let limit = 200

    static func contains(_ id: String, defaults: UserDefaults = .standard) -> Bool {
        (defaults.stringArray(forKey: key) ?? []).contains(id)
    }

    static func add(_ ids: [String], defaults: UserDefaults = .standard) {
        var current = defaults.stringArray(forKey: key) ?? []
        for id in ids where !current.contains(id) { current.append(id) }
        if current.count > limit { current.removeFirst(current.count - limit) }
        defaults.set(current, forKey: key)
    }
}

/// La persona abrió la guía y ya tiene dirección: solo entonces la app pregunta al gateway por correos nuevos. Sin esto,
/// cada vuelta a primer plano de cada teléfono en la nube haría una petición que casi nadie necesita.
enum BankEmailSetupStore {
    static let key = "bankEmail.addressCreated"

    static func isSetUp(defaults: UserDefaults = .standard) -> Bool { defaults.bool(forKey: key) }
    static func markSetUp(defaults: UserDefaults = .standard) { defaults.set(true, forKey: key) }
}
