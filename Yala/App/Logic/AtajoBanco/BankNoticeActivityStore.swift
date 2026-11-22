//
//  BankNoticeActivityStore.swift
//  Yala
//
//  Atajo del banco, B2: lo que la app sabe de cada banco instalado. Yala no ve la automatización de Atajos (ni si existe
//  ni si está encendida): solo sabe lo que le llega. Con eso pinta el estado («Esperando el primer aviso»,
//  «Funcionando», «Hace 9 días que no llega nada») y los contadores del mes.
//
//  Vive en el App Group porque la escribe la acción de Atajos, en su propio proceso. Dos escritores, cada uno con sus
//  claves: la acción escribe la actividad (`bankNoticeActivity.<banco>`) y la app, la pausa y la cuenta por defecto
//  (`bankNoticeSettings.<banco>`). `UserDefaults` no tiene compare-and-swap entre procesos: si los dos escribieran la
//  misma clave, uno pisaría al otro.
//
//  Ningún texto del aviso se guarda aquí: solo cuándo llegó, qué se entendió y el importe y el comercio del último.
//  Lo borran «Vaciar datos» y las fronteras de cuenta (`AppGroupInboundPurge`).
//

import Foundation

/// La actividad de un banco: la escribe solo la acción de Atajos.
nonisolated struct BankNoticeActivity: Codable, Equatable {
    /// Las últimas llegadas (segundos desde 1970), de la más vieja a la más nueva. Para el aviso de silencio.
    var arrivals: [Double] = []
    /// Contadores por mes («2026-11»): leídos, sin entender, no eran compras.
    var months: [String: Counts] = [:]
    /// Lo último que se leyó como movimiento, para «Último aviso hoy 9:41 · S/ 45,90 en Tambo+».
    var lastMovement: LastMovement?

    nonisolated struct Counts: Codable, Equatable {
        var read = 0
        var notUnderstood = 0
        var notPurchases = 0
    }

    nonisolated struct LastMovement: Codable, Equatable {
        let amount: Decimal
        let currencyCode: String?
        let counterparty: String?
        let isExpense: Bool
    }

    /// Cuántas llegadas se recuerdan: bastan para saber si los avisos llegaban con frecuencia.
    static let arrivalsKept = 30
    /// Cuántos meses de contadores se guardan.
    static let monthsKept = 3

    var lastArrival: Date? { arrivals.last.map { Date(timeIntervalSince1970: $0) } }

    /// Apunta un aviso que llegó y lo que se leyó de él.
    mutating func record(_ reading: BankNoticeReading, at date: Date, calendar: Calendar = .current) {
        arrivals.append(date.timeIntervalSince1970)
        if arrivals.count > Self.arrivalsKept { arrivals.removeFirst(arrivals.count - Self.arrivalsKept) }
        let month = Self.monthKey(date, calendar: calendar)
        var counts = months[month] ?? Counts()
        switch reading {
        case .movement(let movement, _):
            counts.read += 1
            lastMovement = LastMovement(
                amount: movement.amount, currencyCode: movement.currencyCode,
                counterparty: movement.counterparty, isExpense: movement.isExpense)
        case .notUnderstood:
            counts.notUnderstood += 1
        case .notAMovement:
            counts.notPurchases += 1
        }
        months[month] = counts
        let kept = Set(months.keys.sorted().suffix(Self.monthsKept))
        months = months.filter { kept.contains($0.key) }
    }

    func counts(for date: Date, calendar: Calendar = .current) -> Counts {
        months[Self.monthKey(date, calendar: calendar)] ?? Counts()
    }

    static func monthKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }
}

/// Lo que la persona eligió para un banco: lo escribe solo la app.
nonisolated struct BankNoticeSettings: Codable, Equatable {
    /// Pausado: lo que llegue se ignora y no se guarda.
    var isPaused = false
    /// `Account.shortcutID` de la cuenta por defecto, para cuando el aviso no dice cuál es.
    var defaultAccountShortcutID: UUID?
    /// Los bancos que la persona activó desde «¿De qué banco?» (para listarlos aunque aún no haya llegado nada).
    var isSetUp = false
}

nonisolated enum BankNoticeActivityStore {

    static let activityPrefix = "bankNoticeActivity."
    static let settingsPrefix = "bankNoticeSettings."

    static var appGroupDefaults: UserDefaults? { BankNoticePendingStore.appGroupDefaults }

    // MARK: - Actividad (la acción de Atajos)

    static func activity(for bank: BankNoticeBank, defaults: UserDefaults? = appGroupDefaults) -> BankNoticeActivity {
        decode(BankNoticeActivity.self, defaults?.data(forKey: activityPrefix + bank.rawValue)) ?? BankNoticeActivity()
    }

    static func record(
        _ reading: BankNoticeReading, bank: BankNoticeBank, at date: Date, defaults: UserDefaults? = appGroupDefaults
    ) {
        guard let defaults else { return }
        var activity = activity(for: bank, defaults: defaults)
        activity.record(reading, at: date)
        encode(activity).map { defaults.set($0, forKey: activityPrefix + bank.rawValue) }
    }

    // MARK: - Ajustes (la app)

    static func settings(for bank: BankNoticeBank, defaults: UserDefaults? = appGroupDefaults) -> BankNoticeSettings {
        decode(BankNoticeSettings.self, defaults?.data(forKey: settingsPrefix + bank.rawValue)) ?? BankNoticeSettings()
    }

    static func save(_ settings: BankNoticeSettings, for bank: BankNoticeBank, defaults: UserDefaults? = appGroupDefaults) {
        guard let defaults else { return }
        encode(settings).map { defaults.set($0, forKey: settingsPrefix + bank.rawValue) }
    }

    static func isPaused(_ bank: BankNoticeBank, defaults: UserDefaults? = appGroupDefaults) -> Bool {
        settings(for: bank, defaults: defaults).isPaused
    }

    /// Los bancos con algo: activados a mano o con algún aviso recibido. En el orden de `allCases`.
    static func knownBanks(defaults: UserDefaults? = appGroupDefaults) -> [BankNoticeBank] {
        BankNoticeBank.allCases.filter { bank in
            settings(for: bank, defaults: defaults).isSetUp || !activity(for: bank, defaults: defaults).arrivals.isEmpty
        }
    }

    /// Todas las claves de este almacén, para borrarlas en «Vaciar datos» y en las fronteras de cuenta.
    static func allKeys(defaults: UserDefaults? = appGroupDefaults) -> [String] {
        guard let defaults else { return [] }
        return defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(activityPrefix) || $0.hasPrefix(settingsPrefix)
        }
    }

    static func removeAll(defaults: UserDefaults? = appGroupDefaults) {
        guard let defaults else { return }
        for key in allKeys(defaults: defaults) { defaults.removeObject(forKey: key) }
    }

    // MARK: - Disco

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            #if DEBUG
            print("BankNoticeActivityStore: Error encoding: \(error)")
            #endif
            return nil
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            #if DEBUG
            print("BankNoticeActivityStore: Error decoding: \(error)")
            #endif
            return nil
        }
    }
}
