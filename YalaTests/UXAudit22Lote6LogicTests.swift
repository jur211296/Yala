//
//  UXAudit22Lote6LogicTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 6 (primera vez con datos previos o en la nube): lo que se implementó de las cards
//  L6-1 … L6-13. La lógica nueva es pura y se prueba de frente; el cableado que solo vive en vistas SwiftUI se fija
//  con escáneres acotados al cuerpo que importa (`.claude/rules/testing.md`).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Auditoría UX 2.2 · lote 6 · lógica nueva")
struct UXAudit22Lote6LogicTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo entre la llave que sigue al marcador y la que la cierra.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1, i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    private static func summary(accounts: Int = 0, transactions: Int = 0, budgets: Int = 0, groups: Int = 0,
                                categories: Int = 0) -> ICloudAccountSummary {
        ICloudAccountSummary(userName: nil, accountsCount: accounts, transactionsCount: transactions,
                             budgetsCount: budgets, groupsCount: groups, primaryCurrencyCode: "PEN",
                             categoriesCount: categories)
    }

    // MARK: - L6-5 · «Encontramos tus datos» como recibo

    @Test("L6-5: una fila por cifra mayor que cero, registros primero y los grupos al final")
    func foundRows_filterAndOrder() {
        let rows = RestoreFoundRowsLogic.rows(
            for: Self.summary(accounts: 3, transactions: 248, budgets: 2, groups: 1, categories: 14))
        #expect(rows.map(\.kind) == [.transactions, .accounts, .categories, .budgets, .groups])
        #expect(rows.map(\.count) == [248, 3, 14, 2, 1])
        let onlyAccounts = RestoreFoundRowsLogic.rows(for: Self.summary(accounts: 1))
        #expect(onlyAccounts == [.init(kind: .accounts, count: 1)])
    }

    /// La invariante de la pantalla: si `hasAnyData` dice que hay algo, la lista no sale vacía. Cada término del
    /// predicado, solo, tiene que producir su fila.
    @Test("L6-5: toda cifra que enciende `hasAnyData` tiene su fila")
    func foundRows_coverEveryTermOfHasAnyData() {
        let singles = [Self.summary(accounts: 1), Self.summary(transactions: 1),
                       Self.summary(budgets: 1), Self.summary(categories: 1)]
        for s in singles {
            #expect(s.hasAnyData)
            #expect(!RestoreFoundRowsLogic.rows(for: s).isEmpty, "\(s) enciende hasAnyData y no pinta fila")
        }
    }

    @Test("L6-5: la fila dice la palabra sola y VoiceOver oye la cifra con su plural")
    func foundRows_nameAndSpokenCountDiffer() {
        for kind in RestoreFoundRowsLogic.Kind.allCases {
            #expect(!kind.name.isEmpty)
            #expect(kind.spokenCount(3).contains("3"), "\(kind): VoiceOver no lee la cifra")
            #expect(!kind.name.contains("3"))
        }
    }

    // MARK: - L6-2 · sin iCloud no se reabre antes de mirar

    @Test("L6-2: solo «Restaurar» y solo sin iCloud sale del Welcome sin relanzar")
    func skipsRelaunch_onlyRestoreWithoutICloud() {
        #expect(WelcomeRestoreRelaunchLogic.skipsRelaunch(destination: .restoreICloud, iCloudAvailable: false))
        #expect(!WelcomeRestoreRelaunchLogic.skipsRelaunch(destination: .restoreICloud, iCloudAvailable: true))
        for destination in [WelcomeMirrorRelaunchLogic.Destination.privateOnboarding, .inviteRecovery] {
            #expect(!WelcomeRestoreRelaunchLogic.skipsRelaunch(destination: destination, iCloudAvailable: false),
                    "\(destination) no le pregunta nada a iCloud: no puede saltarse el relanzamiento")
        }
    }

    @Test("L6-2: Restaurar pide reabrir solo con iCloud ya encendido y el store neutro")
    func needsRelaunchToSearch_onlyWithICloudOnANeutralMount() {
        #expect(WelcomeRestoreRelaunchLogic.needsRelaunchToSearch(iCloudAvailable: true, mountedDecision: .neutralNoMirror))
        #expect(!WelcomeRestoreRelaunchLogic.needsRelaunchToSearch(iCloudAvailable: false, mountedDecision: .neutralNoMirror),
                "sin iCloud la pantalla es «Activa iCloud»: reabrir no cambiaría nada")
        #expect(!WelcomeRestoreRelaunchLogic.needsRelaunchToSearch(iCloudAvailable: true, mountedDecision: .iCloudMirror),
                "con el espejo puesto se busca en este proceso")
    }

    /// El portal del Welcome consulta la excepción DENTRO de su guard: si se mueve fuera, alguna salida a Restaurar
    /// volvería a pedir reabrir antes de saber si hay iCloud.
    @Test("MUTACIÓN L6-2: el portal del Welcome consulta `skipsRelaunch` con iCloud vivo")
    func portal_consultsTheRestoreException() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let portal = try Self.body(
            of: "private func leaveWelcome(to destination: WelcomeMirrorRelaunchLogic.Destination,", in: src)
        #expect(portal.contains("WelcomeRestoreRelaunchLogic.skipsRelaunch("))
        #expect(portal.contains("iCloudAvailable: iCloudSyncService.shared.isAccountAvailable"))
        let guardRange = try #require(portal.range(of: "guard WelcomeMirrorRelaunchLogic.shouldRelaunch("))
        let skip = try #require(portal.range(of: "WelcomeRestoreRelaunchLogic.skipsRelaunch("))
        let elseRange = try #require(portal.range(of: "else {"))
        #expect(guardRange.lowerBound < skip.lowerBound && skip.lowerBound < elseRange.lowerBound,
                "la excepción tiene que ser un término del guard, no una rama aparte")
    }

    /// Restaurar pide reabrir ANTES de encender la señal y de mirar el wipe: si fuera después, buscaría sobre un
    /// store sin espejo y diría «no hay datos» a quien sí los tiene.
    @Test("MUTACIÓN L6-2: Restaurar pide reabrir antes de buscar, y solo si se lo piden")
    func restoreScreen_asksToRelaunchBeforeSearching() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomeRestoreView.swift")
        let search = try Self.body(of: "private func startSearch() {", in: src)
        let ask = try #require(search.range(of: "onNeedsMirrorRelaunch()"))
        let wiped = try #require(search.range(of: "RestoreOfferGate.wasWiped("))
        let started = try #require(search.range(of: "ICloudRestoreSessionSignal.noteRestoreStarted("))
        #expect(ask.lowerBound < wiped.lowerBound && ask.lowerBound < started.lowerBound)
        #expect(search.contains("if let onNeedsMirrorRelaunch,"), "sin consumidor que relance, no se pide")
        let content = try Self.code("Yala/App/ContentView.swift")
        let cover = try Self.body(of: "private var welcomeRestoreCover: some View {", in: content)
        let relaunch = try Self.body(of: "onNeedsMirrorRelaunch: {", in: cover)
        #expect(relaunch.contains("WelcomePendingDestinationStore.set(.restoreICloud)"))
        #expect(relaunch.contains("step: .mirrorRelaunch"))
    }

    // MARK: - L6-3 y L6-11 · volver a «¡Hola de nuevo!»

    @Test("L6-11: «Volver» lleva a «¡Hola de nuevo!» salvo con bypass")
    func existingBranchOrigin_followsTheBypass() {
        #expect(WelcomeBackStepLogic.existingBranchOrigin(options: [.restoreICloud]) == .chooser)
        #expect(WelcomeBackStepLogic.existingBranchOrigin(options: [.cloudSignIn, .restoreICloud]) == .existingChooser)
        #expect(WelcomeBackStepLogic.existingBranchOrigin(options: [.cloudSignIn, .googleSignIn, .restoreICloud])
                == .existingChooser)
    }

    @Test("L6-3: cancelar el consentimiento sale de la entrada solo si se pidió y no se ha firmado nada")
    func consentCancel_truthTable() {
        #expect(WelcomeBackStepLogic.consentCancelReturnsBack(requested: true, isAtIntro: true))
        #expect(!WelcomeBackStepLogic.consentCancelReturnsBack(requested: true, isAtIntro: false))
        #expect(!WelcomeBackStepLogic.consentCancelReturnsBack(requested: false, isAtIntro: true))
        #expect(!WelcomeBackStepLogic.consentCancelReturnsBack(requested: false, isAtIntro: false))
    }

    /// Las dos cards de «¡Hola de nuevo!» abren el consentimiento y marcan su origen; la puerta de Grupos, que
    /// también arranca en el consentimiento, NO lo marca (allí cancelar deja el intro).
    @Test("MUTACIÓN L6-3: las dos cards arrancan en el consentimiento y la puerta de Grupos no hereda el origen")
    func existingChooserCards_startAtTheConsent() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        for provider in [".apple)", ".google)"] {
            let marker = "welcomeCloudEntry = .reentry(\(provider)"
            let start = try #require(src.range(of: marker))
            let window = String(src[start.upperBound...].prefix(600))
            let end = window.range(of: "showWelcomeCloudSignIn = true").map { String(window[..<$0.lowerBound]) } ?? window
            #expect(end.contains("adoptStartsAtConsent = true"), "\(provider): no arranca en el consentimiento")
            #expect(end.contains("cloudSignInFromExistingChooser = true"), "\(provider): no marca su origen")
        }
        let groups = try Self.body(of: "private func adoptCompleteAccountFromGroups() {", in: src)
        #expect(groups.contains("cloudSignInFromExistingChooser = false"))
    }

    // MARK: - L6-4 · el botón del consentimiento dice lo que pasa

    @Test("L6-4: un verbo por contexto, y ninguno pide «activar la nube»")
    func consentAcceptTitle_perPath() {
        let titles = [CloudConsentCopyLogic.acceptTitle(for: .adopt),
                      CloudConsentCopyLogic.acceptTitle(for: .bornCloud),
                      CloudConsentCopyLogic.acceptTitle(for: .migration)]
        #expect(Set(titles).count == 3, "dos contextos comparten botón: \(titles)")
        for title in titles { #expect(!title.isEmpty) }
    }

    @Test("MUTACIÓN L6-4: la pantalla toma el botón de la lógica y la clave vieja ya no existe")
    func consentView_usesTheContextualTitle() throws {
        let src = try Self.code("Yala/App/Views/Settings/CloudConsentView.swift")
        #expect(src.contains("CloudConsentCopyLogic.acceptTitle(for: path)"))
        #expect(!src.contains("Consent.accept"))
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            #expect(strings["storage.consent.accept"] == nil, "«Entiendo y quiero activar la nube» sigue en \(locale.code)")
        }
    }

    // MARK: - L6-6 · las cifras del aviso tardío

    /// Las píldoras cuentan el mismo hecho que la línea de la puerta del Welcome: unidas, son esa línea. Si una cifra
    /// nueva entra en una y no en la otra, este test lo dice.
    @Test("L6-6: las píldoras unidas con « · » son la línea de cifras de la puerta")
    func lateChips_matchTheGateCountsLine() {
        let date = Date(timeIntervalSince1970: 1_756_684_800) // sep 2025
        let corpora = [
            ICloudPersonalCorpus(transactions: 248, accounts: 3, categories: 14, budgets: 2,
                                 oldestTransactionDate: date, truncated: false),
            ICloudPersonalCorpus(transactions: 500, accounts: 0, categories: 0, budgets: 0,
                                 oldestTransactionDate: nil, truncated: true),
            ICloudPersonalCorpus(transactions: 0, accounts: 0, categories: 0, budgets: 0,
                                 oldestTransactionDate: nil, truncated: true),
            ICloudPersonalCorpus(transactions: 0, accounts: 1, categories: 0, budgets: 0,
                                 oldestTransactionDate: nil, truncated: false),
        ]
        for corpus in corpora {
            let chips = ICloudCorpusChipsLogic.chips(for: corpus) { WelcomePrivateICloudGateView.monthYearText($0) }
            #expect(chips.map(\.text).joined(separator: " · ") == WelcomePrivateICloudGateView.countsLine(corpus))
            #expect(!chips.isEmpty, "un aviso que ofrece borrar no sale sin cifras")
        }
    }

    @Test("MUTACIÓN L6-6: «Juntarlos» es `onKeep` y borrar pasa por su «¿seguro?»")
    func lateNotice_keepsItsExits() throws {
        let src = try Self.code("Yala/App/Views/Shared/LateICloudMirrorNoticeView.swift")
        let notice = try Self.body(of: "private var lateNotice: some View {", in: src)
        let merge = try Self.body(of: "YalaPrimaryButton(L10n.UXLote6.lateMerge) {", in: notice)
        #expect(merge.trimmingCharacters(in: .whitespacesAndNewlines) == "onKeep(); dismiss()")
        let wipe = try Self.body(of: "Button(role: .destructive) {", in: notice)
        #expect(wipe.trimmingCharacters(in: .whitespacesAndNewlines) == "phase = .confirming",
                "el botón rojo tiene que pedir confirmación, no borrar en el acto")
    }

    // MARK: - L6-9 · las pantallas sin salida

    @Test("L6-9: solo «Tu cuenta ya tiene finanzas personales» lleva a cerrar sesión")
    func blockExit_onlyForPersonalData() {
        #expect(FullModeActivationBlockExitLogic.offersSignOut(for: .accountAlreadyHasPersonalData))
        #expect(!FullModeActivationBlockExitLogic.offersSignOut(for: .anotherDeviceIsMoving))
        #expect(!FullModeActivationBlockExitLogic.offersSignOut(for: .sessionExpired))
        #expect(!FullModeActivationBlockExitLogic.offersSignOut(for: .accountUnavailable))
    }

    @Test("L6-9: el correo a soporte lleva destinatario y asunto codificado")
    func supportMail_hasRecipientAndSubject() throws {
        let url = try #require(SupportMailLinkLogic.url(to: "admin@yala-app.pe", subject: "Yala: mi cuenta no está disponible"))
        #expect(url.scheme == "mailto")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "admin@yala-app.pe")
        #expect(components.queryItems?.first(where: { $0.name == "subject" })?.value == "Yala: mi cuenta no está disponible")
    }

    // MARK: - L6-7 · una sola pantalla de «reabre Yala»

    @Test("MUTACIÓN L6-7: la entrada a la nube pinta el mismo mensaje que el Welcome")
    func cloudRelaunch_usesTheSharedMessage() throws {
        let src = try Self.code("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        let relaunch = try Self.body(of: "private var relaunchContent: some View {", in: src)
        #expect(relaunch.contains("WelcomeRelaunchMessage(kind: .cloudAccount)"))
        #expect(!src.contains("L10n.Storage.Relaunch."), "volvió el «Ya casi está — reinicia Yala» de la migración")
        let mirror = try Self.code("Yala/App/Views/Onboarding/WelcomeMirrorRelaunchView.swift")
        #expect(mirror.contains("WelcomeRelaunchMessage(kind: .iCloudPrivate)"))
    }

    // MARK: - Textos

    @Test("los textos nuevos del lote existen y no están vacíos en los 16 idiomas")
    func newKeys_existInEveryLocale() {
        let keys = [
            "welcome.existing.dontRemember", "welcome.cloud.beaconTitle", "welcome.cloud.createAnotherNote",
            "welcome.cloud.accountBlockedWrite", "welcome.cloud.accountBlockedMailSubject",
            "welcome.relaunch.bodyCloseFully", "welcome.restore.bringBack",
            "welcome.restore.row.transactions", "welcome.restore.row.accounts", "welcome.restore.row.categories",
            "welcome.restore.row.budgets", "welcome.restore.row.groups",
            "storage.consent.lead", "storage.consent.serversTitle", "storage.consent.photosTitle",
            "storage.consent.accessTitle", "storage.consent.acceptEnter", "storage.consent.acceptCreate",
            "storage.consent.acceptMove", "welcome.privateICloud.lateLead", "welcome.privateICloud.lateMerge",
            "welcome.privateICloud.lateWipe", "welcome.privateICloud.lateMergeExplainer",
            "groups.fullActivation.blockedGoToSignOut", "groups.fullActivation.historyExample",
        ]
        var scanned = 0
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            guard !strings.isEmpty else { continue }
            scanned += 1
            for key in keys {
                #expect(!(strings[key] ?? "").isEmpty, "'\(key)' falta o está vacía en \(locale.code)")
            }
        }
        #expect(scanned == 16, "se esperaban 16 locales con strings, se leyeron \(scanned)")
    }

    /// L6-10: la frase tiene que decir que entra la PARTE de la persona, no el total — es una cifra que mueve sus
    /// totales. En los dos idiomas de referencia.
    @Test("L6-10: «¿Traemos tus gastos de grupo?» dice que trae solo tu parte")
    func historyBody_saysOnlyYourShare() {
        #expect(StringsFileParser.parseStrings(forLocale: "es-419")["groups.fullActivation.historyBody"]?
            .contains("solo tu parte") == true)
        #expect(StringsFileParser.parseStrings(forLocale: "en")["groups.fullActivation.historyBody"]?
            .contains("only your share") == true)
    }

    /// L6-12: el icono del aviso ya dice «hecho»; el «✓» del texto lo duplicaba.
    @Test("L6-12: los avisos positivos no repiten el ✓ en el texto")
    func positiveToasts_dropTheCheckmarkGlyph() {
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            for key in ["icloud.remoteOnboardingCompleted", "icloud.remoteRestoreCompleted"] {
                #expect(strings[key]?.hasPrefix("✓") == false, "\(key) en \(locale.code) sigue empezando por ✓")
            }
        }
    }
}
