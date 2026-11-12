//
//  CurrenciesWithRecords.swift
//  Yala
//
//  Las monedas que tienen registros, en el orden de `CurrencyCode.allCases`. Es la lista que ofrece Registros › Filtros
//  y la que decide en qué moneda compara el monto (`RecordsAmountFilterCurrencyLogic`): la hoja y la guarda de
//  `SessionState` tienen que contar igual, o la guarda vaciaría el monto que la hoja acaba de aplicar.
//

import Foundation
import SwiftData

@MainActor
enum CurrenciesWithRecords {
    struct Result {
        let currencies: [CurrencyCode]
        /// Alguna cuenta no se pudo contar: la lista puede estar corta.
        let isIncomplete: Bool
    }

    /// Una consulta por moneda de cuenta (`fetchCount`, sin materializar registros): pocas, porque son las de las cuentas.
    static func load(accountCurrencyCodes: Set<String>, in context: ModelContext) -> Result {
        var codes = Set<String>()
        var isIncomplete = false
        for currencyCode in accountCurrencyCodes {
            let code = currencyCode
            let descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { $0.currencyCode == code }
            )
            do {
                if try context.fetchCount(descriptor) > 0 { codes.insert(code) }
            } catch {
                isIncomplete = true
                #if DEBUG
                print("CurrenciesWithRecords: Error counting transactions for currency: \(error)")
                #endif
            }
        }
        return Result(currencies: CurrencyCode.allCases.filter { codes.contains($0.rawValue) }, isIncomplete: isIncomplete)
    }

    /// Con las cuentas del contenedor. `nil` si no se pudieron leer o contar: quien decide algo con la lista no decide.
    static func load(in context: ModelContext) -> [CurrencyCode]? {
        do {
            let accounts = try context.fetch(FetchDescriptor<Account>())
            let result = load(accountCurrencyCodes: Set(accounts.map(\.currencyCode)), in: context)
            return result.isIncomplete ? nil : result.currencies
        } catch {
            #if DEBUG
            print("CurrenciesWithRecords: Error: fetch de cuentas: \(error)")
            #endif
            return nil
        }
    }
}
