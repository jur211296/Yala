//
//  InboxJoinRecord.swift
//  Yala
//
//  Bandeja sin duplicados, lote 2: lo que se recuerda de una unión, para poder deshacerla con «Separar». Vive en
//  `InboxDraft.joinRecordRaw` del borrador que sostiene el consumo (el primero que llegó) y viaja con él a iCloud y a la
//  nube. Pura: sin `ModelContext`; el cableado está en `InboxArrivalJoin`.
//
//  Por qué un registro en el borrador y no una fila «unida» por cada fuente: una app anterior a 2.3 lee un estado que no
//  conoce como pendiente (`DraftStatus` cae a `.pending`) y volvería a enseñar los duplicados. Con el registro, esa app
//  ve un borrador y nada más (Paso 0, D2).
//
//  Qué guarda:
//  - `holderBefore`: los campos del que sostiene ANTES de la primera unión (los que «Separar» le devuelve).
//  - `holderAfter`: los campos que dejó la última unión. «Separar» solo devuelve un campo que sigue así: lo que la persona
//    cambió después de unir se queda (Paso 0, D6).
//  - `holderSource`: la fuente del que sostiene, con lo que el emparejador necesita y el borrador no guarda (moneda que
//    dijo la fuente, últimos 4, si trae hora).
//  - `members`: lo absorbido, en orden de llegada, con todo lo que hace falta para volver a crear su borrador.
//  - `holderCreatedByJoin` y `holderIsEstimate` (lote 4, opcionales: un registro sin ellos se lee igual): el borrador de
//    un pago planificado que la unión creó para casar un cargo («Separar» lo borra), y si su importe era un estimado (la
//    fila dice «Antes S/ 120.00 estimado»).
//

import Foundation

nonisolated struct InboxJoinRecord: Codable, Equatable, Sendable {

    /// La versión que escribe este build. Un registro de una versión mayor no se entiende y no se toca (Paso 0, D8).
    static let currentVersion = 1

    var version: Int
    var holderSource: SourceFacts
    var holderBefore: Fields
    var holderAfter: Fields
    var members: [Member]
    /// Lote 4: el borrador del planificado lo creó la unión (aún no había vencido o no se había sacado). «Separar» lo borra.
    var holderCreatedByJoin: Bool?
    /// Lote 4: el importe del planificado era un estimado; `holderBefore.amount` es ese estimado.
    var holderIsEstimate: Bool?

    /// Si el que sostiene es el borrador de un pago planificado (lote 4).
    var holderIsPlanned: Bool { holderSource.source == InboxMatchLogic.Source.planned.rawValue }

    init(version: Int, holderSource: SourceFacts, holderBefore: Fields, holderAfter: Fields, members: [Member],
         holderCreatedByJoin: Bool? = nil, holderIsEstimate: Bool? = nil) {
        self.version = version
        self.holderSource = holderSource
        self.holderBefore = holderBefore
        self.holderAfter = holderAfter
        self.members = members
        self.holderCreatedByJoin = holderCreatedByJoin
        self.holderIsEstimate = holderIsEstimate
    }

    /// Los campos del borrador que una unión puede cambiar.
    nonisolated struct Fields: Codable, Equatable, Sendable {
        var note: String
        var amount: Double?
        var date: Date?
        var accountShortcutID: UUID?
        var subcategoryShortcutID: UUID?
        var cachedCurrencyCode: String?
    }

    /// Lo que dijo una fuente y el borrador no guarda, para volver a comparar después.
    nonisolated struct SourceFacts: Codable, Equatable, Sendable {
        /// `InboxMatchLogic.Source.rawValue`.
        var source: String
        var currencyCode: String?
        var last4: String?
        var hasExactTime: Bool
    }

    /// Un borrador absorbido: todo lo necesario para volver a crearlo tal como llegó.
    nonisolated struct Member: Codable, Equatable, Sendable {
        var facts: SourceFacts
        var fields: Fields
        var sourceTypeRaw: String
        var createdAt: Date
        var rawText: String?
        var evidence: String?
        var confidenceAmount: Double?
        var confidenceDate: Double?
        var confidenceMerchant: Double?
        var confidenceSubcategory: Double?
        var joinedAt: Date
    }

    // MARK: - Leer y escribir

    nonisolated enum Reading: Equatable, Sendable {
        /// Nada unido.
        case none
        case record(InboxJoinRecord)
        /// Hay algo y no se entiende (una versión futura, o el JSON roto): no se une encima ni se separa.
        case unreadable
    }

    static func read(_ raw: String?) -> Reading {
        guard let raw, !raw.isEmpty else { return .none }
        guard let data = raw.data(using: .utf8) else { return .unreadable }
        do {
            let record = try decoder.decode(InboxJoinRecord.self, from: data)
            guard record.version <= currentVersion, !record.members.isEmpty else { return .unreadable }
            return .record(record)
        } catch {
            #if DEBUG
            print("InboxJoinRecord: Error: \(error)")
            #endif
            return .unreadable
        }
    }

    /// El JSON del registro, o `nil` si no se pudo codificar (no pasa con estos tipos; quien llama no une).
    func encoded() -> String? {
        do {
            let data = try Self.encoder.encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            #if DEBUG
            print("InboxJoinRecord: Error: \(error)")
            #endif
            return nil
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}

// MARK: - Unir y separar

nonisolated enum InboxJoinLogic {

    /// Los campos del que sostiene tras unir, según lo que manda en el consumo (`InboxMatchLogic.Resolved`): importe del
    /// banco, hora de Apple Pay o del aviso, comercio por su prioridad. Cuenta y subcategoría solo se rellenan si faltaban
    /// (en una unión fuerte las cuentas coinciden o una falta: nunca se pisa una elegida). Paso 0, D5. El borrador de un
    /// pago planificado conserva su nota («Luz del Sur», no «LUZ DEL SUR SAA PAGO»): es el nombre que la persona le puso
    /// (lote 4, D4).
    static func mergedFields(
        holder current: InboxJoinRecord.Fields,
        arriving: InboxJoinRecord.Fields,
        resolved: InboxMatchLogic.Resolved
    ) -> InboxJoinRecord.Fields {
        var merged = current
        merged.amount = resolved.money.amount
        merged.date = resolved.date
        let resolvedMerchant = resolved.merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let holderIsPlanned = resolved.sources.first == .planned
        if !resolvedMerchant.isEmpty && !holderIsPlanned { merged.note = resolvedMerchant }
        if merged.accountShortcutID == nil { merged.accountShortcutID = arriving.accountShortcutID }
        if merged.subcategoryShortcutID == nil { merged.subcategoryShortcutID = arriving.subcategoryShortcutID }
        if merged.accountShortcutID == nil {
            merged.cachedCurrencyCode = resolved.money.currencyCode ?? current.cachedCurrencyCode ?? arriving.cachedCurrencyCode
        }
        return merged
    }

    /// Los campos que «Separar» deja en el que sostiene: cada uno vuelve al de antes de unir solo si sigue siendo el que
    /// dejó la unión. Lo que la persona cambió después se queda.
    static func restoredFields(current: InboxJoinRecord.Fields, record: InboxJoinRecord) -> InboxJoinRecord.Fields {
        let before = record.holderBefore
        let after = record.holderAfter
        var restored = current
        if current.note == after.note { restored.note = before.note }
        if current.amount == after.amount { restored.amount = before.amount }
        if current.date == after.date { restored.date = before.date }
        if current.accountShortcutID == after.accountShortcutID { restored.accountShortcutID = before.accountShortcutID }
        if current.subcategoryShortcutID == after.subcategoryShortcutID {
            restored.subcategoryShortcutID = before.subcategoryShortcutID
        }
        if current.cachedCurrencyCode == after.cachedCurrencyCode { restored.cachedCurrencyCode = before.cachedCurrencyCode }
        return restored
    }

    /// El candidato del emparejador para una fuente, con sus campos.
    static func candidate(
        id: UUID, facts: InboxJoinRecord.SourceFacts, fields: InboxJoinRecord.Fields, fallbackDate: Date
    ) -> InboxMatchLogic.Candidate? {
        guard let source = InboxMatchLogic.Source(rawValue: facts.source), let amount = fields.amount else { return nil }
        return InboxMatchLogic.Candidate(
            id: id,
            source: source,
            amount: amount,
            currencyCode: facts.currencyCode,
            date: fields.date ?? fallbackDate,
            hasExactTime: facts.hasExactTime,
            accountID: fields.accountShortcutID,
            last4: facts.last4,
            merchant: fields.note
        )
    }

    /// El consumo que sostiene un borrador con registro: el que sostiene tal como llegó y lo que absorbió. Así lo que llega
    /// después se compara con lo que manda en el consumo, y con sus fuentes ya ocupadas.
    static func consumption(holderID: UUID, record: InboxJoinRecord, fallbackDate: Date) -> InboxMatchLogic.Consumption? {
        guard let holder = candidate(id: holderID, facts: record.holderSource, fields: record.holderBefore,
                                     fallbackDate: fallbackDate) else { return nil }
        var consumption = InboxMatchLogic.Consumption(holder)
        for member in record.members {
            guard let absorbed = candidate(id: UUID(), facts: member.facts, fields: member.fields,
                                           fallbackDate: member.createdAt) else { continue }
            consumption.absorb(absorbed)
        }
        return consumption
    }

    /// Las fuentes de un consumo unido, en orden: la del que sostiene y las absorbidas.
    static func sources(of record: InboxJoinRecord) -> [InboxMatchLogic.Source] {
        ([record.holderSource] + record.members.map(\.facts)).compactMap { InboxMatchLogic.Source(rawValue: $0.source) }
    }
}
