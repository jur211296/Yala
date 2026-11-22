//
//  CuentaSolaReglasStore.swift
//  Yala
//
//  Leer y escribir las reglas de captura de una cuenta (`Account.captureRulesRaw`), para «Recordar» en la hoja de la
//  foto y para «Pasarla» cuando la regla ya vive en otra cuenta. La decisión (qué regla, si es repetida) es pura y vive
//  en `CuentaSolaAlLeerReglas`; aquí solo se toca el modelo.
//
//  Una regla siempre vive en la cuenta PRINCIPAL: la escalera no mira las líneas de una tarjeta con varias divisas
//  (`DraftBuilder.cuentaSolaCandidates`), así que una regla guardada en una línea no se cumpliría nunca.
//

import Foundation
import SwiftData

@MainActor
enum CuentaSolaReglasStore {

    static func rules(of account: Account) -> [AccountCaptureRule] {
        AccountCaptureRule.decode(account.captureRulesRaw)
    }

    /// Escribe las reglas solo si cambian: reescribir el mismo valor marcaría la cuenta como cambiada y viajaría. Las
    /// entradas que esta versión no entiende (de una versión futura) se conservan.
    static func setRules(_ rules: [AccountCaptureRule], on account: Account) {
        let raw = AccountCaptureRule.encode(rules, preservingUnknownFrom: account.captureRulesRaw)
        guard raw != account.captureRulesRaw else { return }
        account.captureRulesRaw = raw
    }

    /// La cuenta donde vive una regla para `account`: su principal si es una línea, ella misma si no.
    static func owner(of account: Account, among accounts: [Account]) -> Account {
        let roles = AccountLineLogic.resolve(accounts.map { AccountLineNode($0) })
        guard roles[account.shortcutID]?.isLine == true, let parentID = account.parentAccountID,
              let principal = accounts.first(where: { $0.shortcutID == parentID }) else { return account }
        return principal
    }

    /// La misma regla en otra cuenta (no archivada), si la hay.
    static func repetida(
        _ rule: AccountCaptureRule, destino: Account, among accounts: [Account]
    ) -> (account: Account, rule: AccountCaptureRule)? {
        let cuentas = accounts.filter { !$0.isArchived }.map { (id: $0.shortcutID, rules: rules(of: $0)) }
        guard let found = CuentaSolaAlLeerReglas.repetida(rule, destino: destino.shortcutID, en: cuentas),
              let account = accounts.first(where: { $0.shortcutID == found.accountID }) else { return nil }
        return (account, found.rule)
    }

    /// Añade la regla a su cuenta y guarda.
    static func guardar(_ rule: AccountCaptureRule, en account: Account, context: ModelContext) throws {
        setRules(CuentaSolaAlLeerReglas.anadir(rule, a: rules(of: account)), on: account)
        try context.save()
    }

    /// «Pasarla»: la quita de `origen` y la pone en `destino`, en un solo guardado.
    static func pasar(
        _ rule: AccountCaptureRule, de origen: Account, a destino: Account, context: ModelContext
    ) throws {
        setRules(rules(of: origen).filter { !$0.isSameCondition(as: rule) }, on: origen)
        setRules(CuentaSolaAlLeerReglas.anadir(rule, a: rules(of: destino)), on: destino)
        try context.save()
    }
}
