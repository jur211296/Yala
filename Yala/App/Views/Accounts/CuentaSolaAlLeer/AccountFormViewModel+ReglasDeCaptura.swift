//
//  AccountFormViewModel+ReglasDeCaptura.swift
//  Yala
//
//  Lo que hace «Reglas de captura» en Editar cuenta (parte 2 de la cuenta sola al leer, 2026-11-21): añadir, cambiar y
//  quitar reglas, y preguntar si una regla igual ya vive en otra cuenta. Todo queda en el formulario hasta «Guardar»
//  (`AccountFormViewModel.applyCaptureRules`): la X lo descarta, como el resto de campos.
//

import Foundation

extension AccountFormViewModel {

    /// Una regla igual que ya vive en otra cuenta (sin contar las que este formulario ya le quitó).
    func captureRuleDuplicate(for rule: AccountCaptureRule) -> Account? {
        let selfID = accountToEdit?.shortcutID
        for other in allAccounts where other.shortcutID != selfID && !other.isArchived && !other.isSystemAccount {
            let moved = captureRulesMovedFrom[other.shortcutID] ?? []
            let rules = CuentaSolaReglasStore.rules(of: other).filter { rule in
                !moved.contains { $0.isSameCondition(as: rule) }
            }
            if rules.contains(where: { $0.isSameCondition(as: rule) }) { return other }
        }
        return nil
    }

    /// Añade la regla o cambia la que tiene su mismo `id`.
    func upsertCaptureRule(_ rule: AccountCaptureRule) {
        var cleaned = rule
        cleaned.value = String(AccountCaptureRule.cleaned(rule.value).prefix(AccountCaptureRule.maxValueLength))
        guard !cleaned.value.isEmpty else { return }
        if let index = captureRules.firstIndex(where: { $0.id == cleaned.id }) {
            captureRules[index] = cleaned
        } else {
            captureRules = CuentaSolaAlLeerReglas.anadir(cleaned, a: captureRules)
        }
    }

    /// «Pasarla»: la regla se queda en esta cuenta y sale de `other` al guardar.
    func moveCaptureRule(_ rule: AccountCaptureRule, from other: Account) {
        captureRulesMovedFrom[other.shortcutID, default: []].append(rule)
        upsertCaptureRule(rule)
    }

    func deleteCaptureRule(id: UUID) {
        captureRules.removeAll { $0.id == id }
    }

    /// La sección se enseña en una cuenta que puede tener reglas: no en una línea de una tarjeta con varias divisas (la
    /// regla vive en su principal) ni en una cuenta de sistema.
    var showsCaptureRules: Bool {
        !isCurrencyLockedAsLine && !(accountToEdit?.isSystemAccount ?? false)
    }
}
