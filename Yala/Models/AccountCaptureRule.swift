//
//  AccountCaptureRule.swift
//  Yala
//
//  Una regla de captura de una cuenta (ticket `2026-11-20-captura-cuenta-automatica-y-reglas-parte-2`): «cuando leo un
//  pago que cumple esto, va a esta cuenta». Es un tipo de VALOR, no un `@Model`: las reglas viven en su cuenta
//  (`Account.captureRulesRaw`, JSON), así que mueren con ella, con «Vaciar mis datos» y sin código de borrado propio, y
//  viajan por CloudKit (`CD_captureRulesRaw`) y por la Nube de Yala (`accounts.capture_rules_raw`, `since: 9`) como un
//  campo más. Si dos aparatos cambian las reglas de la MISMA cuenta a la vez, gana el último (aceptado en el Paso 0).
//
//  Lo decide `CuentaSolaAlLeer.reglas` (paso 1 de la escalera): tarjeta de Apple Pay › comercio › palabras juntas ›
//  varias palabras › una palabra; empate entre reglas hacia cuentas distintas → no elige.
//

import Foundation

nonisolated struct AccountCaptureRule: Codable, Equatable, Hashable, Identifiable, Sendable {

    /// Qué mira la regla.
    enum Kind: String, Codable, CaseIterable, Sendable {
        /// El nombre de la tarjeta que entrega Apple Pay (dato «Tarjeta» del atajo).
        case applePayCard = "applePay"
        /// Palabras escritas en lo leído (medio de pago y comercio).
        case text
        /// El comercio leído.
        case merchant
    }

    /// Cómo casan las palabras de una regla de texto.
    enum Mode: String, Codable, CaseIterable, Sendable {
        /// Todas, en cualquier orden.
        case allWords
        /// Juntas, tal cual.
        case together
    }

    var id: UUID
    var kind: Kind
    var value: String
    var mode: Mode
    var createdAt: Date

    init(id: UUID = UUID(), kind: Kind, value: String, mode: Mode = .allWords, createdAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.value = value
        self.mode = mode
        self.createdAt = createdAt
    }

    /// El valor sin espacios de sobra ni saltos de línea: lo que se guarda.
    static func cleaned(_ value: String) -> String {
        value.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Dos reglas son «la misma» si miran lo mismo con el mismo valor (sin tildes ni mayúsculas). El modo de palabras
    /// cuenta solo en las de texto.
    func isSameCondition(as other: AccountCaptureRule) -> Bool {
        guard kind == other.kind else { return false }
        if kind == .text, mode != other.mode { return false }
        return PaymentMethodAccountLogic.fold(Self.cleaned(value)) == PaymentMethodAccountLogic.fold(Self.cleaned(other.value))
    }

    // MARK: - Lo que se guarda en la cuenta

    /// Tope de reglas por cuenta: más no ayuda y el campo viaja entero en cada cambio.
    static let maxPerAccount = 30
    /// Tope de largo del valor de una regla.
    static let maxValueLength = 60

    /// Las reglas guardadas en `captureRulesRaw`. Tolerante: un campo vacío, ilegible o con entradas de una versión futura
    /// da las que se entienden (nunca lanza), para que un JSON roto no deje la cuenta sin abrir.
    static func decode(_ raw: String?) -> [AccountCaptureRule] {
        guard let raw, let data = raw.data(using: .utf8), !raw.isEmpty else { return [] }
        let items: [Lenient]
        do {
            items = try JSONDecoder.captureRules.decode([Lenient].self, from: data)
        } catch {
            #if DEBUG
            print("AccountCaptureRule: Error: \(error)")
            #endif
            return []
        }
        return items.compactMap(\.rule).filter { !cleaned($0.value).isEmpty }
    }

    /// Lo que se guarda: `nil` sin reglas (el campo nace `nil` en toda cuenta de antes y así no viaja un cambio vacío).
    static func encode(_ rules: [AccountCaptureRule]) -> String? {
        let kept = rules.filter { !cleaned($0.value).isEmpty }.prefix(maxPerAccount)
        guard !kept.isEmpty else { return nil }
        do {
            let data = try JSONEncoder.captureRules.encode(Array(kept))
            return String(data: data, encoding: .utf8)
        } catch {
            #if DEBUG
            print("AccountCaptureRule: Error: \(error)")
            #endif
            return nil
        }
    }

    /// Lo que se guarda conservando las entradas de `previous` que esta versión no entiende (un `kind` de una versión
    /// futura): sin esto, editar las reglas en un teléfono viejo borraría las nuevas de todos los aparatos. Un `previous`
    /// ilegible entero no se conserva: ya no lo lee nadie.
    static func encode(_ rules: [AccountCaptureRule], preservingUnknownFrom previous: String?) -> String? {
        let unknown = unknownEntries(previous)
        guard !unknown.isEmpty else { return encode(rules) }
        do {
            let known = try JSONEncoder.captureRules.encode(Array(rules.filter { !cleaned($0.value).isEmpty }
                .prefix(maxPerAccount)))
            let knownItems = try JSONSerialization.jsonObject(with: known) as? [Any] ?? []
            let merged = try JSONSerialization.data(withJSONObject: knownItems + unknown, options: [.sortedKeys])
            return String(data: merged, encoding: .utf8)
        } catch {
            #if DEBUG
            print("AccountCaptureRule: Error: \(error)")
            #endif
            return encode(rules)
        }
    }

    /// Las entradas de un JSON guardado que esta versión no sabe leer.
    static func unknownEntries(_ raw: String?) -> [Any] {
        guard let raw, let data = raw.data(using: .utf8) else { return [] }
        let items: [Any]
        do {
            items = try JSONSerialization.jsonObject(with: data) as? [Any] ?? []
        } catch {
            return []
        }
        return items.filter { item in
            guard JSONSerialization.isValidJSONObject([item]) else { return false }
            do {
                let one = try JSONSerialization.data(withJSONObject: item)
                _ = try JSONDecoder.captureRules.decode(AccountCaptureRule.self, from: one)
                return false
            } catch {
                return true
            }
        }
    }

    /// Una entrada que se lee sin tumbar las demás.
    private struct Lenient: Decodable {
        let rule: AccountCaptureRule?

        init(from decoder: Decoder) throws {
            do {
                rule = try AccountCaptureRule(from: decoder)
            } catch {
                rule = nil
            }
        }
    }
}

private extension JSONEncoder {
    nonisolated static var captureRules: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    nonisolated static var captureRules: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
