//
//  CuentaSolaAlLeerReglas.swift
//  Yala
//
//  Paso 1 de la escalera de `CuentaSolaAlLeer`: las reglas de captura del usuario (parte 2, decisión A + B de Jürgen,
//  20-nov-2026). Una regla cumplida manda: gana a los últimos 4, al nombre y a lo que diga la IA.
//
//  La más concreta gana: tarjeta de Apple Pay › comercio › palabras juntas (dos o más) › varias palabras › una palabra.
//  Si las que empatan en lo más concreto apuntan a cuentas distintas, no elige: el selector las enseña con su regla.
//
//  Puro: sin `@Model`. Las reglas llegan dentro de cada `CuentaSolaAlLeer.Cuenta`.
//

import Foundation

nonisolated enum CuentaSolaAlLeerReglas {

    /// Lo que se leyó de la captura, para las reglas.
    struct Lectura: Equatable, Sendable {
        /// El medio de pago tal como lo dice la captura.
        var mention: String?
        /// El comercio leído.
        var merchant: String?
        /// El nombre de la tarjeta que entregó Apple Pay, solo si la captura viene de Apple Pay.
        var applePayCard: String?

        init(mention: String? = nil, merchant: String? = nil, applePayCard: String? = nil) {
            self.mention = mention
            self.merchant = merchant
            self.applePayCard = applePayCard
        }

        /// El texto donde buscan las reglas de palabras: todo lo leído junto.
        var texto: String {
            [applePayCard, mention, merchant].compactMap { $0 }.joined(separator: " · ")
        }
    }

    /// Una regla cumplida, con su cuenta.
    struct Cumplida: Equatable, Sendable {
        let accountID: UUID
        let rule: AccountCaptureRule
    }

    /// Lo que deciden las reglas.
    enum Decision: Equatable, Sendable {
        case elegida(UUID, AccountCaptureRule)
        /// Reglas igual de concretas hacia cuentas distintas: una por cuenta, en el orden de las cuentas.
        case choque([Cumplida])
        case ninguna
    }

    /// Cuánto de concreta es una regla (más alto, más concreta).
    static func concrecion(_ rule: AccountCaptureRule) -> Int {
        switch rule.kind {
        case .applePayCard: return 5
        case .merchant: return 4
        case .text:
            // Cuenta lo que la persona escribió, también las palabras de relleno: «uber eats» son dos.
            let words = PaymentMethodAccountLogic.tokens(PaymentMethodAccountLogic.fold(rule.value))
                .filter { !$0.allSatisfy(\.isNumber) }
            if words.count >= 2 { return rule.mode == .together ? 3 : 2 }
            return 1
        }
    }

    /// Si la regla se cumple con lo leído.
    static func cumple(_ rule: AccountCaptureRule, _ lectura: Lectura) -> Bool {
        let value = AccountCaptureRule.cleaned(rule.value)
        guard !PaymentMethodAccountLogic.fold(value).isEmpty else { return false }
        switch rule.kind {
        case .applePayCard:
            guard let card = lectura.applePayCard else { return false }
            return PaymentMethodAccountLogic.appears(value, in: card)
        case .merchant:
            guard let merchant = lectura.merchant else { return false }
            return PaymentMethodAccountLogic.appears(value, in: merchant)
        case .text:
            let texto = lectura.texto
            guard !texto.isEmpty else { return false }
            if rule.mode == .together || containsUnspacedScript(value) {
                return PaymentMethodAccountLogic.appears(value, in: texto)
            }
            let wanted = palabras(value)
            guard !wanted.isEmpty else { return false }
            let present = Set(PaymentMethodAccountLogic.tokens(PaymentMethodAccountLogic.fold(texto))
                .map(PaymentMethodAccountLogic.canonicalWallet))
            return Set(wanted).isSubset(of: present)
        }
    }

    /// El paso 1 con lo leído y las cuentas elegibles (cada una con sus reglas).
    static func decidir(_ lectura: Lectura, among candidates: [CuentaSolaAlLeer.Cuenta]) -> Decision {
        var cumplidas: [Cumplida] = []
        for cuenta in candidates {
            for rule in cuenta.rules where cumple(rule, lectura) {
                cumplidas.append(Cumplida(accountID: cuenta.id, rule: rule))
            }
        }
        guard let top = cumplidas.map({ concrecion($0.rule) }).max() else { return .ninguna }
        let ganadoras = cumplidas.filter { concrecion($0.rule) == top }
        // Una por cuenta: la primera regla de cada cuenta, en el orden de las cuentas.
        var porCuenta: [Cumplida] = []
        for cumplida in ganadoras where !porCuenta.contains(where: { $0.accountID == cumplida.accountID }) {
            porCuenta.append(cumplida)
        }
        if porCuenta.count == 1, let unica = porCuenta.first { return .elegida(unica.accountID, unica.rule) }
        return .choque(porCuenta)
    }

    // MARK: - Lo que se recuerda

    /// La regla que ofrece «Recordar» tras corregir la cuenta de una captura con medio de pago leído: «El texto dice
    /// "Zip"», juntas si son varias palabras. `nil` si lo leído no deja palabras (solo «••4417»).
    static func reglaParaRecordar(mention: String?, now: Date = .now) -> AccountCaptureRule? {
        guard let citada = CuentaSolaAlLeer.palabraCitada(mention) else { return nil }
        let value = String(AccountCaptureRule.cleaned(citada).prefix(AccountCaptureRule.maxValueLength))
        guard !palabras(value).isEmpty else { return nil }
        let mode: AccountCaptureRule.Mode = palabras(value).count >= 2 ? .together : .allWords
        return AccountCaptureRule(kind: .text, value: value, mode: mode, createdAt: now)
    }

    /// La regla que se ofrece con «Recordar» en un borrador leído, o `nil` si no toca: la persona CAMBIÓ la cuenta con la
    /// que nació el borrador (o eligió una donde no había ninguna), lo leído deja palabras y no fue una regla suya la que
    /// eligió esa misma cuenta.
    static func ofertaRecordar(_ eleccion: CuentaSolaAlLeer.Eleccion?, currentAccountID: UUID?) -> AccountCaptureRule? {
        guard let eleccion, let current = currentAccountID, current != eleccion.cuentaInicial else { return nil }
        if case .sola(let id, .regla) = eleccion.resultado, id == current { return nil }
        return reglaParaRecordar(mention: eleccion.mention)
    }

    /// Una regla igual (`isSameCondition`) que ya vive en OTRA cuenta: el «¿La paso a…?».
    static func repetida(
        _ rule: AccountCaptureRule, destino: UUID, en cuentas: [(id: UUID, rules: [AccountCaptureRule])]
    ) -> (accountID: UUID, rule: AccountCaptureRule)? {
        for cuenta in cuentas where cuenta.id != destino {
            if let igual = cuenta.rules.first(where: { $0.isSameCondition(as: rule) }) { return (cuenta.id, igual) }
        }
        return nil
    }

    /// Añade `rule` a las reglas de una cuenta, sin repetir una igual (la deja en su sitio con el valor nuevo).
    static func anadir(_ rule: AccountCaptureRule, a rules: [AccountCaptureRule]) -> [AccountCaptureRule] {
        if let index = rules.firstIndex(where: { $0.isSameCondition(as: rule) || $0.id == rule.id }) {
            var updated = rules
            updated[index] = AccountCaptureRule(
                id: rules[index].id, kind: rule.kind, value: rule.value, mode: rule.mode, createdAt: rules[index].createdAt)
            return updated
        }
        guard rules.count < AccountCaptureRule.maxPerAccount else { return rules }
        return rules + [rule]
    }

    // MARK: - Palabras

    /// Las palabras que cuentan de un valor: sin las de relleno ni las que son solo cifras. Si solo quedan palabras de
    /// relleno, cuentan ellas: la persona escribió «Uber» a propósito, aunque «uber» sea relleno en alemán.
    static func palabras(_ value: String) -> [String] {
        let all = PaymentMethodAccountLogic.tokens(PaymentMethodAccountLogic.fold(value))
            .map(PaymentMethodAccountLogic.canonicalWallet)
            .filter { !$0.allSatisfy(\.isNumber) }
        let meaningful = all.filter { !PaymentMethodAccountLogic.fillerWords.contains($0) }
        return meaningful.isEmpty ? all : meaningful
    }

    private static func containsUnspacedScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF: return true
            default: return false
            }
        }
    }
}
