//
//  ExportLote20Tests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 20: el fin del período que exporta el asistente (B1), los errores del asistente en el idioma
//  de la app (B4) y el plural de «Inicia sesión para subir N cambios» (B7).
//

import Foundation
import Testing

@testable import Yala

struct ExportLote20Tests {

    private var lima: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0) -> Date {
        lima.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    private func filters(from: Date, to: Date) -> ExportFilters {
        var f = ExportFilters.default
        f.dateFrom = from
        f.dateTo = to
        return f
    }

    // MARK: - B1 · el período en curso termina hoy, no mañana a medianoche

    /// «Últimos 30 días» cierra en el INICIO de mañana; un `DateInterval` es cerrado, así que sin el segundo de menos un
    /// registro de mañana a medianoche entraba en la exportación y el resumen decía «… - 18 oct.» un 17 de octubre.
    @Test func midnightEnd_isPulledBackOneSecond() {
        let f = filters(from: date(2026, 9, 17), to: date(2026, 10, 18))
        let interval = f.effectiveDateInterval(calendar: lima)
        #expect(interval.end == date(2026, 10, 17, 23, 59, 59))
        #expect(!interval.contains(date(2026, 10, 18)), "Un registro de mañana a medianoche no puede entrar.")
        #expect(interval.contains(date(2026, 10, 17, 23, 0)), "Lo de hoy tiene que seguir entrando.")
    }

    /// El personalizado y «Mes pasado» ya cierran en 23:59:59: no pierden ni un instante.
    @Test func endAlreadyAtEndOfDay_isUntouched() {
        let end = date(2026, 9, 30, 23, 59, 59)
        let interval = filters(from: date(2026, 9, 1), to: end).effectiveDateInterval(calendar: lima)
        #expect(interval.end == end)
    }

    /// La copia de todo (`allTransactions`) no tiene fin y no se toca.
    @Test func distantFuture_isUntouched() {
        let interval = ExportFilters.allTransactions.effectiveDateInterval(calendar: lima)
        #expect(interval.end == .distantFuture)
        #expect(interval.start == .distantPast)
    }

    /// Un rango de un instante a medianoche no se invierte.
    @Test func zeroLengthMidnightRange_isNotInverted() {
        let d = date(2026, 10, 18)
        let interval = filters(from: d, to: d).effectiveDateInterval(calendar: lima)
        #expect(interval.start <= interval.end)
    }

    // MARK: - B4 · los errores del asistente salen del catálogo, no de un literal en español

    @Test func exportErrors_comeFromTheCatalog() {
        #expect(TransactionsExportError.noTransactionsToExport.errorDescription == L10n.Export.errorNoTransactions)
        #expect(TransactionsExportError.invalidCustomDateRange.errorDescription == L10n.Export.errorInvalidDateRange)
        let underlying = NSError(domain: "test", code: 1)
        #expect(TransactionsExportError.fileWriteFailed(underlying: underlying).errorDescription
                == L10n.Export.errorFileWriteFailed)
    }

    /// Las tres claves se resuelven (ninguna cae a su nombre crudo) y ya no dicen «transacciones».
    @Test func exportErrorKeys_resolve() {
        for value in [L10n.Export.errorNoTransactions, L10n.Export.errorInvalidDateRange, L10n.Export.errorFileWriteFailed] {
            #expect(!value.hasPrefix("export.error."), "Clave sin traducir: \(value)")
            #expect(!value.contains("transacciones"))
        }
    }

    /// Las tres claves están en los 16 idiomas: hasta el lote 20 solo existía el literal en español.
    @Test func exportErrorKeys_existInEverySupportedLocale() throws {
        let keys = ["export.error.invalidDateRange", "export.error.noTransactions", "export.error.fileWriteFailed"]
        let sentinel = "__MISSING__"
        var checked = 0
        for locale in SupportedLocale.allCases {
            let path = try #require(Bundle.main.path(forResource: locale.bundleResourceName, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            for key in keys {
                #expect(bundle.localizedString(forKey: key, value: sentinel, table: nil) != sentinel,
                        "\(key) falta en \(locale.bundleResourceName)")
            }
            checked += 1
        }
        #expect(checked >= 16)
    }

    // MARK: - B7 · «Inicia sesión para subir 1 cambio», con plural

    /// El texto sale del `.stringsdict` en los idiomas con plural: con `String(format:)` decía «1 cambios». Se mide sobre el
    /// bundle de es-419, que es el idioma de referencia del catálogo.
    @Test func needsSignIn_isPluralized() throws {
        let path = try #require(Bundle.main.path(forResource: "es-419", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let format = bundle.localizedString(forKey: "storage.sync.needsSignIn", value: "__MISSING__", table: nil)
        #expect(format != "__MISSING__")
        let one = String.localizedStringWithFormat(format, 1)
        let three = String.localizedStringWithFormat(format, 3)
        #expect(one == "Inicia sesión para subir 1 cambio")
        #expect(three == "Inicia sesión para subir 3 cambios")
    }
}
