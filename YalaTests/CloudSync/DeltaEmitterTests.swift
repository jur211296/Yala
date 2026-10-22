//
//  DeltaEmitterTests.swift
//  YalaTests / CloudSync
//
//  Emisión de deltas del Modo Nube (I8c): `DeltaEmitter` proyecta un `@Model` + columnas tocadas al
//  `fields` (dominio limpio, PATCH parcial) + `field_hlcs` (por unidad de coherencia). Cubre el
//  invariante de emisión (§d.4bis: grupo tocado → grupo entero), el PATCH parcial, la tri-estado null,
//  y la resolución de mirrors M2M a syncIDs (§d.1). Pure-logic sobre modelos en memoria (sin container:
//  los helpers `resolved*` leen el CSV mirror SSOT, que sobrevive sin relación M2M hidratada).
//

import Foundation
import Testing

@testable import Yala

@Suite("CloudSync · DeltaEmitter (I8c)")
@MainActor
struct DeltaEmitterTests {

    // MARK: - Helpers

    private func makeTx(amount: Double = 10, currency: String = "PEN") -> TransactionItem {
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000),
                                 amount: amount, currencyCode: currency)
        tx.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        return tx
    }

    // MARK: - Money triple: tocar `amount` expande al grupo money entero

    @Test func moneyGroup_touchingAmount_expandsToWholeMoneyGroup_singleUnitHLC() throws {
        let tx = makeTx(amount: 12.5)
        tx.amountInPreferredCurrency = 12.5
        tx.preferredCurrencyCode = "PEN"
        tx.exchangeRate = 1.0
        tx.isExchangeRateProvisional = false

        let result = DeltaEmitter.emit(model: tx, emission: EntityEmissionMap.transactionItem,
                                       changedColumns: ["amount"], hlc: "H")

        // Las 5 columnas del grupo money, y SOLO esas (amount tocado no arrastra singletons).
        #expect(Set(result.fields.keys) == [
            "amount", "amount_in_preferred_currency", "exchange_rate",
            "preferred_currency_code", "is_exchange_rate_provisional",
        ])
        #expect(result.fields["amount"] == .money(12.5))
        #expect(result.fields["exchange_rate"] == .rate(1.0))
        #expect(result.fields["is_exchange_rate_provisional"] == .bool(false))
        // UNA sola unidad "money" con el HLC de la transacción.
        #expect(result.fieldHlcs == ["money": "H"])
    }

    // MARK: - Golden byte-a-byte del grupo money vía el codec c1

    @Test func moneyGroup_encodesToExpectedCanonicalBytes() throws {
        let tx = makeTx(amount: 12.5)
        tx.amountInPreferredCurrency = 12.5
        tx.preferredCurrencyCode = "PEN"
        tx.exchangeRate = 1.0
        tx.isExchangeRateProvisional = false

        let result = DeltaEmitter.emit(model: tx, emission: EntityEmissionMap.transactionItem,
                                       changedColumns: ["amount"], hlc: "H")
        let encoded = try Canonc1Codec.encode(result.fields)
        #expect(encoded == #"{"amount":"12.5000","amount_in_preferred_currency":"12.5000","exchange_rate":"1.00000000","is_exchange_rate_provisional":false,"preferred_currency_code":"PEN"}"#)
    }

    // MARK: - Unidades DISJUNTAS: note + amount → 2 unidades, mismo HLC, 2 keys

    @Test func disjointUnits_noteAndAmount_twoUnitsSameHLC() throws {
        let tx = makeTx(amount: 30)
        tx.note = "Café"

        let result = DeltaEmitter.emit(model: tx, emission: EntityEmissionMap.transactionItem,
                                       changedColumns: ["note", "amount"], hlc: "H")
        // note (singleton) + los 5 money.
        #expect(result.fields["note"] == .string("Café"))
        #expect(result.fields["amount"] == .money(30))
        #expect(Set(result.fields.keys).contains("preferred_currency_code"))  // expandido
        // Dos unidades, ambas con el mismo HLC de la transacción.
        #expect(result.fieldHlcs == ["note": "H", "money": "H"])
    }

    // MARK: - tx_split expande (grupo distinto de money en la MISMA entidad)

    @Test func txSplitGroup_touchingSplitMyValue_expandsWholeGroup() throws {
        let tx = makeTx(amount: 50)
        tx.splitType = "shares"
        tx.splitTotalAmount = 100
        tx.splitMyValue = 2
        tx.splitDivisor = 4

        let result = DeltaEmitter.emit(model: tx, emission: EntityEmissionMap.transactionItem,
                                       changedColumns: ["split_my_value"], hlc: "H")
        #expect(Set(result.fields.keys) == [
            "split_type", "split_total_amount", "split_my_value", "split_divisor",
        ])
        #expect(result.fields["split_my_value"] == .money(2))
        #expect(result.fields["split_type"] == .string("shares"))
        #expect(result.fieldHlcs == ["tx_split": "H"])
        // money NO se toca (grupo independiente en la misma entidad).
        #expect(result.fields["amount"] == nil)
    }

    // MARK: - budget expande

    @Test func budgetGroup_touchingLimit_expandsWholeGroup() throws {
        let budget = Budget(currencyCode: "PEN", limitAmount: 500, name: "Comida")

        let result = DeltaEmitter.emit(model: budget, emission: EntityEmissionMap.budget,
                                       changedColumns: ["limit_amount"], hlc: "H")
        #expect(Set(result.fields.keys) == [
            "limit_amount", "currency_code", "natures",
            "subcategory_ids", "account_ids", "tag_refs",
        ])
        #expect(result.fields["limit_amount"] == .money(500))
        #expect(result.fields["currency_code"] == .string("PEN"))
        #expect(result.fieldHlcs == ["budget": "H"])
    }

    // MARK: - budget: uuid[] vacías DENTRO del grupo viajan como [] explícito (DIFERIDOS #25 opción 1)

    @Test func budgetGroup_emptyUuidArrays_travelExplicitInGroup() throws {
        let budget = Budget(currencyCode: "PEN", limitAmount: 500, name: "Comida")  // sin filtros (caso mayoritario)

        let result = DeltaEmitter.emit(model: budget, emission: EntityEmissionMap.budget,
                                       changedColumns: ["limit_amount"], hlc: "H")
        // Las 3 uuid[] del grupo están en el mapa como vacías…
        #expect(result.fields["subcategory_ids"] == .uuidArray([]))
        #expect(result.fields["account_ids"] == .uuidArray([]))
        #expect(result.fields["tag_refs"] == .uuidArray([]))
        // …la unidad budget viaja (regla nueva: el skip de field_hlcs es SOLO para singletons vacías)…
        #expect(result.fieldHlcs == ["budget": "H"])
        // …y el codec, con el contexto de grupo, las emite como [] explícito — NUNCA omitidas
        // (sin esto el Worker rechazaría el grupo con coherence_group_partial 422 y el budget
        // jamás sincronizaría — el bug que motivó DIFERIDOS #25).
        let encoded = try Canonc1Codec.encode(result.fields,
                                              groupedColumns: Set(EntityEmissionMap.budget.groupByColumn.keys))
        #expect(encoded == #"{"account_ids":[],"currency_code":"PEN","limit_amount":"500.0000","natures":null,"subcategory_ids":[],"tag_refs":[]}"#)
    }

    // MARK: - scheduled_payments split expande

    @Test func scheduledPaymentSplitGroup_touchingAmount_expandsWholeGroup() throws {
        let payment = ScheduledPayment(
            name: "Renta", amount: 100, currencyCode: "PEN",
            nextDueDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        payment.splitType = "equal"
        payment.splitTotalAmount = 200

        let result = DeltaEmitter.emit(model: payment, emission: EntityEmissionMap.scheduledPayment,
                                       changedColumns: ["amount"], hlc: "H")
        #expect(Set(result.fields.keys) == [
            "amount", "split_type", "split_total_amount",
            "split_participant_ids_raw", "split_values_raw",
        ])
        #expect(result.fields["amount"] == .money(100))
        #expect(result.fieldHlcs == ["split": "H"])
    }

    // MARK: - PATCH parcial: solo lo tocado (columna singleton no arrastra nada)

    @Test func patchPartial_singletonTouched_onlyThatColumn() throws {
        let tx = makeTx(amount: 10)
        tx.note = "Solo la nota"

        let result = DeltaEmitter.emit(model: tx, emission: EntityEmissionMap.transactionItem,
                                       changedColumns: ["note"], hlc: "H")
        #expect(result.fields.count == 1)
        #expect(result.fields["note"] == .string("Solo la nota"))
        #expect(result.fieldHlcs == ["note": "H"])
    }

    // MARK: - null explícito (opcional tocado a nil → .null, ≠ ausente)

    @Test func explicitNull_optionalSetToNil_emitsNull() throws {
        let tx = makeTx(amount: 10)
        tx.note = nil

        let result = DeltaEmitter.emit(model: tx, emission: EntityEmissionMap.transactionItem,
                                       changedColumns: ["note"], hlc: "H")
        #expect(result.fields["note"] == .null)
    }

    // MARK: - Dominio limpio: mirror M2M → syncIDs resueltos (Tag.id lowercase por el codec)

    @Test func cleanDomain_tagMirrorResolvedToSyncIDs() throws {
        let tagID = UUID(uuidString: "AABBCCDD-1122-3344-5566-778899AABBCC")!
        let tag = Tag(id: tagID, name: "viaje")
        let tx = makeTx(amount: 10)
        tx.setTags(from: [tag])  // dual-write: escribe el CSV mirror (SSOT de lectura)

        let result = DeltaEmitter.emit(model: tx, emission: EntityEmissionMap.transactionItem,
                                       changedColumns: ["tag_refs"], hlc: "H")
        #expect(result.fields["tag_refs"] == .uuidArray([tagID]))
        // El codec baja a lowercase y emite un array JSON.
        let encoded = try Canonc1Codec.encode(result.fields)
        #expect(encoded == #"{"tag_refs":["aabbccdd-1122-3344-5566-778899aabbcc"]}"#)
    }

    // MARK: - tag_refs vacío → el codec OMITE la key (sin-filtro ≠ [] ≠ null)

    @Test func emptyTagRefs_codecOmitsKey() throws {
        let tx = makeTx(amount: 10)  // sin tags

        let result = DeltaEmitter.emit(model: tx, emission: EntityEmissionMap.transactionItem,
                                       changedColumns: ["tag_refs"], hlc: "H")
        // En el MAPA está presente como array vacío…
        #expect(result.fields["tag_refs"] == .uuidArray([]))
        // …pero el codec la OMITE al serializar.
        #expect(try Canonc1Codec.encode(result.fields) == "{}")
        // …y su unidad NO viaja en `field_hlcs` (§d.4bis:487: solo unidades cuyas columnas están en el
        // `fields` DEL WIRE; el codec omite la uuidArray vacía → sin columna → sin unit huérfano).
        #expect(result.fieldHlcs == [:])
    }

    // MARK: - field_hlcs NO embarca un unit huérfano de una uuidArray vacía OMITIDA (regresión §d.4bis:487)

    @Test func emptyTagRefsAmongTouched_fieldHlcsExcludesOrphanUnit() throws {
        let tagID = UUID(uuidString: "AABBCCDD-1122-3344-5566-778899AABBCC")!
        let tag = Tag(id: tagID, name: "viaje")
        let tx = makeTx(amount: 10)
        tx.note = "Con nota"
        tx.setTags(from: [tag])

        // Un insert-like: se tocan note + amount(→money) + tag_refs(no vacío). tag_refs viaja → su unit sí.
        let withTags = DeltaEmitter.emit(model: tx, emission: EntityEmissionMap.transactionItem,
                                         changedColumns: ["note", "amount", "tag_refs"], hlc: "H")
        #expect(withTags.fieldHlcs == ["note": "H", "money": "H", "tag_refs": "H"])

        // Ahora sin tags: tag_refs es .uuidArray([]) → el codec la OMITE → su unit NO debe ir en field_hlcs.
        tx.setTags(from: [])
        let noTags = DeltaEmitter.emit(model: tx, emission: EntityEmissionMap.transactionItem,
                                       changedColumns: ["note", "amount", "tag_refs"], hlc: "H")
        #expect(noTags.fieldHlcs == ["note": "H", "money": "H"])  // sin "tag_refs" huérfano
        #expect(noTags.fields["tag_refs"] == .uuidArray([]))       // sigue en el mapa; el codec la omite
        #expect(try Canonc1Codec.encode(noTags.fields).contains("tag_refs") == false)
    }
}
