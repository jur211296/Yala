//
//  DeltaEmitterGoldenTests.swift
//  YalaTests / CloudSync
//
//  Golden de un delta COMPLETO de `TransactionItem` (I8c): la proyección de dominio limpio de un INSERT
//  (todas las columnas) + su `field_hlcs` por unidad de coherencia, contra un expected explícito. Calendario
//  UTC inyectado → `local_day` determinista cross-máquina.
//

import Foundation
import Testing

@testable import Yala

@Suite("CloudSync · DeltaEmitter golden (I8c)")
@MainActor
struct DeltaEmitterGoldenTests {

    /// 2023-11-14T22:13:20Z. Con calendario UTC, el día civil es 2023-11-14.
    private let instant = Date(timeIntervalSince1970: 1_700_000_000)

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func fullProjection_transactionItem_matchesGolden() throws {
        let tx = TransactionItem(date: instant, amount: 12.5, currencyCode: "PEN")
        tx.createdAt = instant
        tx.exchangeRate = 1.0
        tx.amountInPreferredCurrency = 12.5
        tx.preferredCurrencyCode = "PEN"
        tx.isExchangeRateProvisional = false
        // note/refs/split todo nil → columnas explícitas a NULL; sin tags → tag_refs vacío.

        let result = DeltaEmitter.emit(
            model: tx, emission: EntityEmissionMap.transactionItem,
            changedColumns: EntityEmissionMap.transactionItem.columns,
            hlc: "H", calendar: utcCalendar
        )

        // Día civil derivado a medianoche UTC del 2023-11-14.
        let localDayMidnight = Date(
            timeIntervalSince1970: Double(CanonicalTime.daysFromCivil(year: 2023, month: 11, day: 14)) * 86_400
        )

        let expectedFields: [String: CanonValue] = [
            "date": .timestamp(instant),
            "local_day": .localDay(localDayMidnight),
            "amount": .money(12.5),
            "currency_code": .string("PEN"),
            "note": .null,
            "category_ref": .null,
            "subcategory_ref": .null,
            "account_ref": .null,
            "tag_refs": .uuidArray([]),
            "amount_in_preferred_currency": .money(12.5),
            "preferred_currency_code": .string("PEN"),
            "exchange_rate": .rate(1.0),
            "is_exchange_rate_provisional": .bool(false),
            "need_override": .null,
            "scheduled_payment_ref": .null,
            "balance_adjustment_type": .null,
            "transfer_pair_id": .null,
            "split_expense_id": .null,
            "split_group_zone_id": .null,
            "split_settlement_id": .null,
            "split_total_amount": .null,
            "split_type": .null,
            "split_my_value": .null,
            "split_divisor": .null,
            "created_at": .timestamp(instant),
        ]
        #expect(result.fields == expectedFields)

        // field_hlcs: unidad = grupo si lo tiene, si no la columna; todas con el HLC de la transacción.
        // §d.4bis:487 — SOLO las unidades cuyas columnas viajan en el `fields` DEL WIRE. `tag_refs` es
        // una uuidArray VACÍA que el codec OMITE (§d.1/O8) → NO viaja → su unit NO va en field_hlcs
        // (coherente con la aserción de abajo de que el encode no contiene "tag_refs").
        var expectedHlcs: [String: String] = [:]
        for (column, value) in expectedFields {
            if case .uuidArray(let ids) = value, ids.isEmpty { continue }  // omitida por el codec → sin unit
            let unit: String
            switch column {
            case "amount", "amount_in_preferred_currency", "exchange_rate",
                 "preferred_currency_code", "is_exchange_rate_provisional":
                unit = "money"
            case "split_total_amount", "split_type", "split_my_value", "split_divisor":
                unit = "tx_split"
            default:
                unit = column
            }
            expectedHlcs[unit] = "H"
        }
        #expect(result.fieldHlcs == expectedHlcs)
        #expect(result.fieldHlcs["tag_refs"] == nil)  // regresión §d.4bis:487: sin unit huérfano
        #expect(result.fieldHlcs["money"] == "H")
        #expect(result.fieldHlcs["tx_split"] == "H")

        // El codec c1 serializa sin lanzar; `local_day` = día civil UTC; `tag_refs` vacío se OMITE.
        let encoded = try Canonc1Codec.encode(result.fields)
        #expect(encoded.contains(#""local_day":"2023-11-14""#))
        #expect(encoded.contains(#""amount":"12.5000""#))
        #expect(encoded.contains(#""exchange_rate":"1.00000000""#))
        #expect(encoded.contains(#""note":null"#))
        #expect(!encoded.contains("tag_refs"))
    }
}
