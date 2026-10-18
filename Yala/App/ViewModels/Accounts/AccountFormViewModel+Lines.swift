//
//  AccountFormViewModel+Lines.swift
//  Yala
//
//  Tarjeta con varias divisas, entrega 2 (ticket `multi-currency-accounts-2-card-view`): lo que el formulario de cuenta
//  ofrece sobre las líneas. Qué es cada cuenta y qué se puede vincular lo deciden `AccountLineLogic` y
//  `AccountCardLogic`; lo que escribe, `AccountLineService`. Aquí solo se juntan para la vista.
//
//  - Una tarjeta (o una cuenta que puede serlo) ofrece «Añadir línea en otra divisa» y «Vincular cuenta existente».
//  - Una línea dice de qué tarjeta es, ofrece desvincularse, no cambia de divisa y no tiene recordatorio de pago.
//  - Una cuenta con un enlace roto se ve suelta y ofrece desvincularse antes de nada.
//  - Archivar una tarjeta con líneas vivas pregunta si archivarlas también.
//

import Foundation
import SwiftData

extension AccountFormViewModel {

    // MARK: - Lectura

    func loadAccounts() {
        guard let context = modelContextForLines else { return }
        do {
            allAccounts = try context.fetch(FetchDescriptor<Account>())
        } catch {
            #if DEBUG
            print("AccountFormViewModel: Error loading accounts: \(error)")
            #endif
            allAccounts = []
        }
    }

    private var lineNodes: [AccountLineNode] { allAccounts.map { AccountLineNode($0) } }

    private var lineRoles: [UUID: AccountLineRole] { AccountLineLogic.resolve(lineNodes) }

    /// Qué es la cuenta que se edita. `nil` al crear.
    var lineRole: AccountLineRole? {
        guard let account = accountToEdit else { return nil }
        return lineRoles[account.shortcutID]
    }

    /// La tarjeta de la que esta cuenta es línea, si lo es.
    var principalOfLine: Account? {
        guard case .line(let principalID)? = lineRole else { return nil }
        return allAccounts.first { $0.shortcutID == principalID }
    }

    /// Declara un enlace que no vale (huérfana, misma divisa, duplicada…): se ve suelta y lo primero es desvincularla.
    var hasBrokenLink: Bool {
        guard let account = accountToEdit, account.parentAccountID != nil else { return false }
        return !(lineRole?.isLine ?? false)
    }

    /// Esta cuenta puede tener líneas: ya guardada, de usuario, viva y sin enlace propio.
    var canManageLines: Bool {
        guard let account = accountToEdit, !allAccounts.isEmpty else { return false }
        return AccountCardLogic.canHaveLines(AccountLineNode(account))
    }

    /// Sus líneas vivas, por divisa.
    var cardLines: [Account] {
        guard let account = accountToEdit, case .principal(let ids)? = lineRole else { return [] }
        let idSet = Set(ids)
        return allAccounts
            .filter { idSet.contains($0.shortcutID) && !$0.isArchived && $0.shortcutID != account.shortcutID }
            .sorted { $0.currencyCode < $1.currencyCode }
    }

    /// Recordatorio y día de pago: solo la principal o una cuenta suelta.
    var ownsCardSettings: Bool {
        AccountCardLogic.ownsCardSettings(lineRole)
    }

    /// La divisa de una línea no cambia: es lo que la hace línea.
    var isCurrencyLockedAsLine: Bool {
        lineRole?.isLine ?? false
    }

    /// Si la tarjeta pasaría a la divisa de una de sus líneas, esa divisa (y el guardado se bloquea).
    var currencyCollidingLine: String? {
        guard let account = accountToEdit else { return nil }
        let code = normalizeCurrencyCode(selectedCurrency.rawValue)
        guard code != normalizeCurrencyCode(account.currencyCode) else { return nil }
        return AccountCardLogic.currencyCollidesWithLine(
            principalID: account.shortcutID, currencyCode: code, nodes: lineNodes) ? code : nil
    }

    /// Las divisas en las que se puede añadir una línea, en el orden del selector de divisas.
    var addableLineCurrencies: [CurrencyCode] {
        guard let account = accountToEdit, canManageLines else { return [] }
        let available = CurrencyCode.allCases.map(\.rawValue)
        let codes = Set(AccountCardLogic.addableCurrencies(
            principalID: account.shortcutID, nodes: lineNodes, available: available))
        return CurrencyCode.allCases.filter { codes.contains($0.rawValue) }
    }

    /// El nombre que tendrá una línea nueva en `currency`.
    func newLineName(for currency: CurrencyCode) -> String {
        AccountCardLogic.lineName(
            cardName: accountToEdit?.name ?? trimmedName, currencyCode: currency.rawValue,
            taken: allAccounts.map(\.name))
    }

    /// Las cuentas que se ofrecen para vincular a esta tarjeta, con el motivo ya traducido de las que no se pueden.
    var linkCandidates: [(account: Account, reason: String?)] {
        guard let account = accountToEdit, canManageLines else { return [] }
        let byID = Dictionary(allAccounts.map { ($0.shortcutID, $0) }, uniquingKeysWith: { first, _ in first })
        return AccountCardLogic.linkCandidates(principalID: account.shortcutID, nodes: lineNodes).compactMap { candidate in
            guard let candidateAccount = byID[candidate.id] else { return nil }
            return (candidateAccount, candidate.rejection.map { Self.reason(for: $0, among: byID) })
        }
    }

    /// El porqué de un rechazo, en palabras de la persona.
    static func reason(for rejection: AccountLinkRejection, among byID: [UUID: Account]) -> String {
        switch rejection {
        case .sameCurrencyAsPrincipal:
            return L10n.Account.Lines.rejectSameCurrency
        case .lineHasLines:
            return L10n.Account.Lines.rejectHasLines
        case .currencyAlreadyLinked(let existingLineID):
            let code = byID[existingLineID].map { normalizeCurrencyCode($0.currencyCode) } ?? ""
            return L10n.Account.Lines.rejectCurrencyTaken(code)
        case .accountNotFound, .ambiguousIdentity, .selfLink, .cycle, .systemAccount, .archivedAccount,
             .principalIsLine:
            return L10n.Account.Lines.rejectOther
        }
    }

    // MARK: - Escritura

    /// Añade una línea en `currency`. Devuelve si se añadió; si no, deja el motivo en `lineActionError` para la hoja.
    @discardableResult
    func addLine(currency: CurrencyCode, initialBalance: Double?) -> Bool {
        guard let context = modelContextForLines, let account = accountToEdit else { return false }
        do {
            try AccountLineService.addLine(
                currencyCode: currency.rawValue, to: account, initialBalance: initialBalance, in: context)
            afterLineChange(context)
            return true
        } catch AccountLineService.AddLineError.rejected(let rejection) {
            showLineError(Self.reason(
                for: rejection, among: Dictionary(allAccounts.map { ($0.shortcutID, $0) }, uniquingKeysWith: { a, _ in a })))
        } catch {
            #if DEBUG
            print("AccountFormViewModel: Error adding line: \(error)")
            #endif
            showLineError(L10n.Common.saveError)
        }
        return false
    }

    /// Vincula `candidate` como línea de esta tarjeta. Solo escribe el enlace: ningún movimiento cambia.
    @discardableResult
    func link(_ candidate: Account) -> Bool {
        guard let context = modelContextForLines, let account = accountToEdit else { return false }
        do {
            try AccountLineService.link(candidate, to: account, in: context)
            afterLineChange(context)
            return true
        } catch AccountLineService.LinkError.rejected(let rejection) {
            showLineError(Self.reason(
                for: rejection, among: Dictionary(allAccounts.map { ($0.shortcutID, $0) }, uniquingKeysWith: { a, _ in a })))
        } catch {
            #if DEBUG
            print("AccountFormViewModel: Error linking account: \(error)")
            #endif
            showLineError(L10n.Common.saveError)
        }
        return false
    }

    /// Desvincular una línea VÁLIDA la hace contar para el límite Free (la tarjeta contaba una vez). Sin hueco no se
    /// ofrece: si no, añadir una línea y desvincularla saltaba el límite sin fin. Una con el enlace roto ya cuenta.
    var unlinkFitsTheFreeLimit: Bool {
        guard isCurrencyLockedAsLine else { return true }
        return FeatureGateService.shared.canCreate(.accounts, currentCount: allAccounts.billableUserAccounts.count)
    }

    /// Devuelve esta cuenta (una línea, o una con el enlace roto) a cuenta suelta, con su historial intacto.
    func unlink() {
        guard let context = modelContextForLines, let account = accountToEdit else { return }
        do {
            try AccountLineService.unlink(account, in: context)
            afterLineChange(context)
        } catch {
            #if DEBUG
            print("AccountFormViewModel: Error unlinking account: \(error)")
            #endif
            showLineError(L10n.Common.saveError, onForm: true)
        }
    }

    // MARK: - Archivar

    /// Archivar una tarjeta con líneas vivas abre la pregunta; desarchivar la olvida.
    func askArchiveLinesIfNeeded(archived: Bool) {
        guard archived else {
            archiveLinesChoice = nil
            isAskingArchiveLines = false
            return
        }
        guard let account = accountToEdit, !account.isArchived, archiveLinesChoice == nil else { return }
        let lines = AccountCardLogic.linesToArchive(principalID: account.shortcutID, nodes: lineNodes)
        if !lines.isEmpty { isAskingArchiveLines = true }
    }

    /// La respuesta a la pregunta. `nil` = cancelar: la cuenta no se archiva.
    func answerArchiveLines(_ choice: Bool?) {
        isAskingArchiveLines = false
        guard let choice else {
            archiveLinesChoice = nil
            isArchived = false
            setArchived(false)
            return
        }
        archiveLinesChoice = choice
    }

    // MARK: - Privado

    /// El motivo de un fallo. Añadir y vincular lo enseñan en su hoja (la del formulario quedaría tapada por ella:
    /// `swiftui-ds.md`); desvincular, en el formulario. Un solo anchor por aviso.
    private func showLineError(_ message: String, onForm: Bool = false) {
        lineActionError = message
        if onForm { isShowingLineActionError = true }
    }

    private func afterLineChange(_ context: ModelContext) {
        loadAccounts()
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }
}
