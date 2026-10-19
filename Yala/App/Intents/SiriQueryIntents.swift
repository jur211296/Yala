//
//  SiriQueryIntents.swift
//  Yala
//
//  Preguntarle a Siri por tus números y abrir una cuenta (opción B de `docs/siri-ios-27-2026-10.md`).
//
//  - «¿Cuánto gasté en Yala?» y «¿Cuánto tengo en Yala?»: contestan sin abrir la app, leyendo la foto de
//    `SiriFinanceSnapshot`. Piden el iPhone desbloqueado (`requiresAuthentication`): dicen importes en voz alta.
//  - «Abre mi cuenta … en Yala»: en iOS 27 adopta el esquema `.system.open`, el único de Apple que encaja con Yala (no
//    hay dominio de finanzas), y con él entra en la «caja de herramientas» del Siri con IA. Abre la ficha de la cuenta
//    en el Panel por el mismo camino que el aviso de la tarjeta (`accounts/<shortcutID>`, UX 2.2 · L10-14).
//
//  Gratis, como los widgets que enseñan esos mismos números (D4 del Paso 0; la decisión de precio es de Jürgen).
//

import AppIntents
import Foundation
import UIKit

// MARK: - Período

enum SiriSpendingPeriodOption: String, AppEnum {
    case thisWeek
    case thisMonth
    case lastMonth
    case thisYear

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "siri.query.period.type")
    }

    static var caseDisplayRepresentations: [SiriSpendingPeriodOption: DisplayRepresentation] {
        [
            .thisWeek: DisplayRepresentation(title: "siri.query.period.thisWeek"),
            .thisMonth: DisplayRepresentation(title: "siri.query.period.thisMonth"),
            .lastMonth: DisplayRepresentation(title: "siri.query.period.lastMonth"),
            .thisYear: DisplayRepresentation(title: "siri.query.period.thisYear")
        ]
    }

    var period: SiriSpendingPeriod {
        switch self {
        case .thisWeek: return .thisWeek
        case .thisMonth: return .thisMonth
        case .lastMonth: return .lastMonth
        case .thisYear: return .thisYear
        }
    }
}

// MARK: - Cuenta

/// Una tarjeta del Panel tal como la conoce Siri: nombre y divisas, nunca el saldo (el saldo lo dice la acción, con el
/// iPhone desbloqueado). El `id` es el `shortcutID` de la cuenta principal, que no cambia entre procesos.
struct YalaAccountEntity: AppEntity {
    let id: String
    /// Propiedad del sistema: Atajos la ofrece («Nombre» de la cuenta) y App Intents Testing la lee.
    @Property(title: "account.name")
    var name: String
    let currencyCodes: [String]

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "siri.entity.account")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(currencyCodes.joined(separator: " · "))")
    }

    static var defaultQuery = YalaAccountEntityQuery()

    init(id: String, name: String, currencyCodes: [String]) {
        self.id = id
        self.currencyCodes = currencyCodes
        self.name = name
    }

    init(_ account: SiriFinanceSnapshot.Account) {
        self.init(id: account.id, name: account.name, currencyCodes: account.lines.map(\.currencyCode))
    }
}

/// Busca por nombre en la foto de `SiriFinanceSnapshot`. Sin índice de Spotlight: los nombres solo salen del teléfono
/// cuando Siri pregunta (opción C, pendiente de decisión).
struct YalaAccountEntityQuery: EntityStringQuery {

    func entities(for identifiers: [String]) async throws -> [YalaAccountEntity] {
        let accounts = Self.accounts()
        return identifiers.compactMap { id in accounts.first { $0.id == id }.map(YalaAccountEntity.init) }
    }

    func entities(matching string: String) async throws -> [YalaAccountEntity] {
        SiriAccountMatching.matches(string, in: Self.accounts()).map(YalaAccountEntity.init)
    }

    func suggestedEntities() async throws -> [YalaAccountEntity] {
        Self.accounts().map(YalaAccountEntity.init)
    }

    /// En solo grupos no hay cuentas que ofrecer.
    private static func accounts() -> [SiriFinanceSnapshot.Account] {
        guard !SiriQueryContext.isGroupsOnlySession() else { return [] }
        return SiriFinanceSnapshotStore.read(from: SiriFinanceSnapshotStore.sharedDefaults)?.accounts ?? []
    }
}

/// «Mi BCP», «la visa», «ahorros»: sin tildes ni mayúsculas, y por palabras sueltas del nombre.
nonisolated enum SiriAccountMatching {
    static func matches(_ query: String, in accounts: [SiriFinanceSnapshot.Account]) -> [SiriFinanceSnapshot.Account] {
        let needle = normalized(query)
        guard !needle.isEmpty else { return accounts }
        let exact = accounts.filter { normalized($0.name) == needle }
        if !exact.isEmpty { return exact }
        return accounts.filter { account in
            let name = normalized(account.name)
            return name.contains(needle) || needle.contains(name)
        }
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Lo que las dos preguntas leen del App Group además de la foto.
nonisolated enum SiriQueryContext {
    static func isGroupsOnlySession(defaults: UserDefaults? = SiriFinanceSnapshotStore.sharedDefaults) -> Bool {
        defaults?.bool(forKey: WidgetDataCache.groupsOnlySessionKey) ?? false
    }

    static func isExpensesOnlyMode(defaults: UserDefaults? = SiriFinanceSnapshotStore.sharedDefaults) -> Bool {
        defaults?.bool(forKey: AppPreferences.Keys.expensesOnlyMode) ?? false
    }
}

// MARK: - ¿Cuánto gasté?

struct SpendingQueryIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.spending.title"
    static var description = IntentDescription("shortcut.spending.description")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "siri.query.param.period", default: .thisMonth)
    var period: SiriSpendingPeriodOption

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = SiriFinanceAnswerLogic.spending(
            snapshot: SiriFinanceSnapshotStore.read(from: SiriFinanceSnapshotStore.sharedDefaults),
            groupsOnly: SiriQueryContext.isGroupsOnlySession(),
            period: period.period,
            now: .now,
            calendar: userConfiguredCalendar()
        )
        return .result(dialog: IntentSpeech.resolved(SiriFinanceSpeech.text(for: answer)))
    }
}

// MARK: - ¿Cuánto tengo?

struct BalanceQueryIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.balance.title"
    static var description = IntentDescription("shortcut.balance.description")
    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    /// Sin cuenta: el total, el mismo número del widget de saldo.
    @Parameter(title: "siri.query.param.account")
    var account: YalaAccountEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = SiriFinanceAnswerLogic.balance(
            snapshot: SiriFinanceSnapshotStore.read(from: SiriFinanceSnapshotStore.sharedDefaults),
            groupsOnly: SiriQueryContext.isGroupsOnlySession(),
            expensesOnly: SiriQueryContext.isExpensesOnlyMode(),
            accountID: account?.id,
            now: .now,
            calendar: userConfiguredCalendar()
        )
        return .result(dialog: IntentSpeech.resolved(SiriFinanceSpeech.text(for: answer)))
    }
}

// MARK: - Abrir una cuenta (iOS 27, esquema de sistema)

// `.system.open` solo existe en el SDK de iOS 27 (Xcode 27, Swift ≥ 6.3). El CI compila con Xcode 26.6 (Swift 6.2): ahí
// esta acción no existe, y el resto de Siri no cambia.
#if compiler(>=6.3)
@available(iOS 27.0, *)
@AppIntent(schema: .system.open)
struct OpenAccountIntent: OpenIntent {

    static var title: LocalizedStringResource = "shortcut.openAccount.title"
    static var description = IntentDescription("shortcut.openAccount.description")

    @Parameter(title: "siri.query.param.account")
    var target: YalaAccountEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = SiriAccountDeepLink.url(forAccountID: target.id) {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}
#endif

/// `yala://accounts/<shortcutID>`: el enlace del aviso de la tarjeta (`AlertDeepLink.account`), que abre su ficha.
nonisolated enum SiriAccountDeepLink {
    static func url(forAccountID id: String) -> URL? {
        guard UUID(uuidString: id) != nil else { return nil }
        return WidgetURLHelper.url(for: "accounts/\(id)")
    }
}

// MARK: - Respuestas resueltas en la app

/// Toda respuesta de un intent de Yala pasa por aquí, ya traducida por la APP.
///
/// `.result(dialog: "clave")` o `requestValue("clave")` dejan la clave al sistema, que con el iPhone en es-PE la
/// resolvía en inglés (ticket `siri-shortcut-error-replies-speak-english-on-a-spanish-iphone`), mientras que lo
/// resuelto con `String(localized:)` salía en español. Lo fija `IntentSpeechTests` con un scan: ninguna clave literal
/// en un `dialog:` ni en un `requestValue` de `Yala/App/Intents`.
enum IntentSpeech {
    /// Un texto que la app ya tradujo. `IntentDialog(stringLiteral:)` lo trata como clave, el sistema no la encuentra en
    /// ninguna tabla y lo enseña tal cual.
    static func resolved(_ text: String) -> IntentDialog {
        IntentDialog(stringLiteral: text)
    }

    /// La clave, traducida aquí.
    static func dialog(_ key: String) -> IntentDialog {
        resolved(NSLocalizedString(key, comment: ""))
    }
}
