//
//  PanelMoneyScopeLogic.swift
//  Yala
//
//  «Tu dinero hoy», la cifra chica del hero del Panel (2026-11-16): el saldo de las cuentas que cuentan como dinero
//  para usar. Por defecto cuentan todas menos las tarjetas de crédito; la persona lo cambia por cuenta, en su formulario
//  o en la hoja del «?» del hero.
//
//  Dónde vive el ajuste: en UNA preferencia sincronizada (`PrefSyncKey.panelMoneyAccountOverrides`), con solo las cuentas
//  que la persona cambió respecto al valor por defecto de su tipo, por `Account.shortcutID`. Así no hay campo nuevo en el
//  esquema de CloudKit ni en el de Supabase, y una cuenta nueva sigue el valor de su tipo sin escribir nada.
//
//  Las líneas en otra divisa de una tarjeta (`Account.parentAccountID`) siguen a su tarjeta: el ajuste es de la tarjeta.
//

import Foundation
import SwiftData

enum PanelMoneyScopeLogic {

    // MARK: - Valor por defecto

    /// Si una cuenta de este tipo cuenta como dinero para usar cuando nadie lo cambió. Solo la tarjeta de crédito no:
    /// lo que se gastó con ella todavía no se pagó. Yala no tiene tipos de préstamo, billetera ni inversión: la
    /// billetera es «Efectivo» o «General», y las dos cuentan.
    static func countsByDefault(type: AccountType) -> Bool {
        switch type {
        case .creditCard: return false
        case .general, .cash, .checking, .savings: return true
        }
    }

    /// El tipo guardado en la cuenta. Un texto desconocido se lee «General», como en el formulario.
    static func accountType(_ account: Account) -> AccountType {
        AccountType(rawValue: account.type) ?? .general
    }

    // MARK: - La preferencia: «id:1,id:0»

    /// Lee la preferencia. Una entrada que no se entiende se ignora: la cuenta vuelve al valor de su tipo.
    static func decode(_ stored: String) -> [UUID: Bool] {
        var result: [UUID: Bool] = [:]
        for entry in stored.split(separator: ",") {
            let parts = entry.split(separator: ":")
            guard parts.count == 2, let id = UUID(uuidString: String(parts[0])) else { continue }
            switch parts[1] {
            case "1": result[id] = true
            case "0": result[id] = false
            default: continue
            }
        }
        return result
    }

    /// Escribe la preferencia en un orden fijo: el mismo mapa da siempre el mismo texto, y la sincronización no ve un
    /// cambio donde no lo hay.
    static func encode(_ overrides: [UUID: Bool]) -> String {
        overrides
            .sorted { $0.key.uuidString < $1.key.uuidString }
            .map { "\($0.key.uuidString):\($0.value ? "1" : "0")" }
            .joined(separator: ",")
    }

    /// La preferencia tras elegir `counts` para una cuenta. Si coincide con el valor de su tipo, la entrada se quita: la
    /// preferencia guarda solo lo que la persona cambió.
    static func setting(_ counts: Bool, for ownerID: UUID, type: AccountType, in stored: String) -> String {
        var overrides = decode(stored)
        if counts == countsByDefault(type: type) {
            overrides.removeValue(forKey: ownerID)
        } else {
            overrides[ownerID] = counts
        }
        return encode(overrides)
    }

    // MARK: - Qué cuenta decide

    /// La cuenta de la que sale el ajuste: la tarjeta si `account` es una línea suya viva, si no la propia cuenta. Un
    /// enlace roto (tarjeta borrada o archivada) deja la línea suelta, como la lee `AccountLineLogic`.
    static func owner(of account: Account, among accounts: [Account]) -> Account {
        guard let parentID = account.parentAccountID,
              let head = accounts.first(where: { $0.shortcutID == parentID && $0.parentAccountID == nil && !$0.isArchived })
        else { return account }
        return head
    }

    /// Si la cuenta suma en «Tu dinero hoy».
    static func counts(_ account: Account, among accounts: [Account], overrides: [UUID: Bool]) -> Bool {
        let head = owner(of: account, among: accounts)
        return overrides[head.shortcutID] ?? countsByDefault(type: accountType(head))
    }

    /// Las cuentas que tienen su propio interruptor: las que suman en un saldo y no son la línea de una tarjeta.
    static func switchableAccounts(_ accounts: [Account]) -> [Account] {
        accounts.filter { account in
            account.sumsInBalance && owner(of: account, among: accounts) === account
        }
    }

    // MARK: - La cifra

    /// Las cuentas que suma «Tu dinero hoy»: las del saldo grande (`totalAccountIDs`, el mismo conjunto que
    /// `PanelViewModel.panelTotalAccountIDs`) que cuentan como dinero para usar.
    static func moneyAccounts(
        _ accounts: [Account],
        totalAccountIDs: Set<PersistentIdentifier>,
        overrides: [UUID: Bool]
    ) -> [Account] {
        accounts.filter { account in
            totalAccountIDs.contains(account.persistentModelID) && counts(account, among: accounts, overrides: overrides)
        }
    }

    /// Si la línea chica tiene algo que decir: alguna cuenta del saldo grande no cuenta como dinero. Sin eso las dos
    /// cifras son la misma y la segunda solo repetiría la primera.
    static func showsMoneyLine(
        _ accounts: [Account],
        totalAccountIDs: Set<PersistentIdentifier>,
        overrides: [UUID: Bool]
    ) -> Bool {
        accounts.contains { account in
            totalAccountIDs.contains(account.persistentModelID) && !counts(account, among: accounts, overrides: overrides)
        }
    }

    /// «Tu dinero hoy»: el mismo cálculo que el saldo grande (`LiveBalanceCalculator`, mismo corte de hoy, misma
    /// conversión al tipo de cambio de hoy), sobre las cuentas que cuentan como dinero.
    static func moneyBreakdown(
        accounts: [Account],
        totalAccountIDs: Set<PersistentIdentifier>,
        overrides: [UUID: Bool],
        transactions: [TransactionItem],
        preferredCurrencyCode: String,
        asOf now: Date = .now,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> LiveBalanceCalculator.Breakdown {
        LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: moneyAccounts(accounts, totalAccountIDs: totalAccountIDs, overrides: overrides),
            transactions: transactions,
            preferredCurrencyCode: preferredCurrencyCode,
            asOf: now,
            converter: converter
        )
    }
}
