//
//  CloudPersonalAttestSignOutTests.swift
//  YalaTests
//
//  Cerrar sesión en la nube con un teléfono sin App Attest y cambios PERSONALES sin subir (ticket
//  `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`, decisión de Jürgen del 2026-09-15): el aviso ofrece
//  exportar todos los movimientos y, después, salir perdiendo esos cambios con confirmación.
//
//  Desde el 2026-09-28 el mismo aviso lo abre también la sesión caducada (ticket
//  `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit`): la oferta y lo aceptado llevan causa.
//
//  Cuatro suites, y `-only-testing` filtra por TIPO, no por fichero:
//   - `CloudPersonalAttestSignOutLogicTests`: el motivo, lo aceptado y los textos (lógica pura).
//   - `CloudExpiredSessionPersonalLossLogicTests`: la decisión del paso 1 por causa y los textos de la sesión caducada.
//   - `CloudPersonalAttestExportTests`: la exportación de TODOS los movimientos, con SwiftData.
//   - `CloudPersonalAttestSignOutWiringTests`: el cableado por source-scan. El coordinador es privado y su camino exige
//     singletons de red, del espejo y de credenciales, igual que en las suites hermanas de `CloudSignOutFlowLogicTests`.
//  El testigo del motor personal y la racha se prueban con el runtime de verdad en `CloudSyncRuntimeTests`, igual que el
//  push-all del cierre con la sesión caducada y con otra cuenta.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Nube sin App Attest — el motivo personal, la cifra aceptada y los textos")
struct CloudPersonalAttestSignOutLogicTests {

    typealias L = CloudSignOutFlowLogic

    /// La parada terminal de la puerta de attest del motor personal llega como `.accountUnavailable`: con el testigo, el
    /// push-all la lleva a la fase como el teléfono sin attest; sin él sigue siendo el aviso de siempre.
    @Test("MUTACIÓN: el veredicto del push-all lleva el attest a la fase, también desde la parada terminal de la puerta")
    func pushAllVerdictCarriesTheAttestFromTheTerminalStop() {
        #expect(L.pushAllVerdict(livePendingCount: 3, cycleOutcome: .accountUnavailable, channelKilled: false,
                                 attestUnavailable: true, uploadFailed: false, iteration: 1, maxIterations: 20)
                == .blocked(pendingCount: 3, reason: .attestUnavailable))
        #expect(L.pushAllVerdict(livePendingCount: 3, cycleOutcome: .accountUnavailable, channelKilled: false,
                                 attestUnavailable: false, uploadFailed: false, iteration: 1, maxIterations: 20)
                == .blocked(pendingCount: 3, reason: .permanent))
        #expect(L.pushAllVerdict(livePendingCount: 3, cycleOutcome: .transient, channelKilled: false,
                                 attestUnavailable: true, uploadFailed: false, iteration: 1, maxIterations: 20)
                == .blocked(pendingCount: 3, reason: .attestUnavailable))
    }

    @Test("se enseña al momento, tiene su slug y la traducción de grupos no lo recibe")
    func surfacesImmediately_andTheGroupsTranslationNeverReceivesIt() {
        for elapsed in [0.0, 10, 44, 100] {
            #expect(GroupsSignOutRetryDecision.decide(
                elapsedSeconds: elapsed, budgetSeconds: GroupsSignOutRetryDecision.budgetSeconds,
                reason: .personalAttestUnavailable) == .surfacePermanent)
        }
        #expect(L.cloudSignOutGroupsBlockReason(.personalAttestUnavailable) == .permanent)
        #expect(L.BlockReason.personalAttestUnavailable.breadcrumbSlug == "personal-attest-unavailable")
    }

    /// Lo aceptado son las FILAS del aviso: una fila nueva vuelve a avisar aunque la cifra no crezca, y sin aceptación el
    /// cierre nunca descarta nada.
    @Test("MUTACIÓN: lo aceptado de lo personal son las filas de su aviso, no una cifra")
    func acceptedPersonalLossIsByRow() {
        let a = UUID(), b = UUID(), c = UUID()
        #expect(L.continuesWithoutUploading(pendingRows: [a, b], acceptance: .rows([a, b])))
        #expect(!L.continuesWithoutUploading(pendingRows: [a, c], acceptance: .rows([a, b])), "c no estaba en el aviso")
        #expect(!L.continuesWithoutUploading(pendingRows: [a], acceptance: nil), "sin aceptar, el cierre nunca descarta")
        #expect(!L.continuesWithoutUploading(pendingRows: nil, acceptance: .rows([a])), "una fila sin mirar no se descarta")
    }

    /// Al retomar el cierre, lo aceptado solo vale mientras el bloqueo siga siendo el attest. Con el attest recuperado y la
    /// subida fallando por otra cosa, seguir se llevaría cambios que un reintento subiría (review adversarial, 2026-09-15).
    @Test("MUTACIÓN: al retomar, lo aceptado solo cubre un bloqueo que siga siendo el attest")
    func acceptanceOnlyCoversARetryStillBlockedByAttest() {
        let a = UUID()
        #expect(L.continuesAfterBlockedUpload(reason: .attestUnavailable, cause: .attestUnavailable,
                                              pendingRows: [a], acceptance: .rows([a])))
        for otro in L.BlockReason.allCases where otro != .attestUnavailable {
            #expect(!L.continuesAfterBlockedUpload(reason: otro, cause: .attestUnavailable,
                                                   pendingRows: [a], acceptance: .rows([a])),
                    "con \(otro) el attest ya no es la causa: un reintento podría subirlos")
        }
        #expect(!L.continuesAfterBlockedUpload(reason: .attestUnavailable, cause: .attestUnavailable,
                                               pendingRows: [a, UUID()], acceptance: .rows([a])))
        #expect(!L.continuesAfterBlockedUpload(reason: .attestUnavailable, cause: .attestUnavailable,
                                               pendingRows: [a], acceptance: nil))
    }

    @MainActor
    @Test("MUTACIÓN: el aviso de tus datos cuenta lo que se pierde solo con una cifra honesta, y no se confunde con el de grupos")
    func personalLossMessage_countsOnlyAnHonestNumber() {
        #expect(SignOutBlockedCopy.personalAttestLossMessage(pending: 3) == L10n.Settings.signOutAttestMessage(3))
        #expect(SignOutBlockedCopy.personalAttestLossMessage(pending: Int.max) == L10n.Settings.signOutAttestMessageUnknown)
        #expect(SignOutBlockedCopy.personalAttestLossMessage(pending: 0) == L10n.Settings.signOutAttestMessageUnknown)
        #expect(SignOutBlockedCopy.title(for: .personalAttestUnavailable) == L10n.Settings.signOutAttestTitle)
        #expect(SignOutBlockedCopy.message(for: .personalAttestUnavailable) == L10n.Settings.signOutAttestBlocked)
        #expect(SignOutBlockedCopy.title(for: .personalAttestUnavailable) != SignOutBlockedCopy.title(for: .attestUnavailable))
    }

    /// El texto del servicio está en español y habla de filtros: el aviso de error de esta exportación tiene los suyos.
    @MainActor
    @Test("MUTACIÓN: el error de la exportación dice «no hay movimientos» solo cuando no los hay, y si no, que falló")
    func exportFailureMessage_distinguishesNoTransactionsFromAFailure() {
        #expect(SignOutBlockedCopy.personalExportFailureMessage(for: TransactionsExportError.noTransactionsToExport)
                == L10n.Settings.signOutAttestExportEmpty)
        #expect(SignOutBlockedCopy.personalExportFailureMessage(
            for: TransactionsExportError.fileWriteFailed(underlying: NSError(domain: "test", code: 1)))
                == L10n.Settings.signOutAttestExportFailed)
        #expect(SignOutBlockedCopy.personalExportFailureMessage(for: URLError(.cancelled)) == L10n.Settings.signOutAttestExportFailed)
        #expect(L10n.Settings.signOutAttestExportEmpty != L10n.Settings.signOutAttestExportFailed)
    }

    /// Un accessor-función que formatea mal devuelve la key cruda o se come la cifra, y la paridad de los `.strings` no lo ve:
    /// compara `.strings` con `.strings` y nunca abre `L10n.swift`.
    @MainActor
    @Test("los accesores del aviso interpolan la cifra y nunca devuelven la key cruda")
    func accessors_interpolate_neverRawKey() {
        let conCifra = L10n.Settings.signOutAttestMessage(7)
        #expect(!conCifra.contains("settings."))
        #expect(conCifra.contains("7"))
        for texto in [L10n.Settings.signOutAttestTitle, L10n.Settings.signOutAttestMessageUnknown,
                      L10n.Settings.signOutAttestExportButton, L10n.Settings.signOutAttestLossButton,
                      L10n.Settings.signOutAttestBlocked, L10n.Settings.signOutAttestExportEmpty,
                      L10n.Settings.signOutAttestExportFailed] {
            #expect(!texto.contains("settings."), "accessor devolvió la key cruda: \(texto)")
        }
    }
}

@Suite("Nube con la sesión caducada — la decisión del paso 1, por causa, y sus textos")
struct CloudExpiredSessionPersonalLossLogicTests {

    typealias L = CloudSignOutFlowLogic

    /// Solo dos motivos YA TRADUCIDOS abren la salida de tus datos, cada uno con su causa. Un motivo nuevo del `enum` cae en
    /// `nil` hasta que alguien decida lo contrario.
    @Test("MUTACIÓN: exactamente dos motivos abren la salida de tus datos: el attest y la sesión caducada de la nube")
    func exactlyTwoReasonsOpenThePersonalExit() {
        for reason in L.BlockReason.allCases {
            switch reason {
            case .personalAttestUnavailable: #expect(L.personalLossCause(reason) == .attestUnavailable)
            case .cloudSessionExpired: #expect(L.personalLossCause(reason) == .noSession)
            default: #expect(L.personalLossCause(reason) == nil, "\(reason) no debería dejar perder movimientos")
            }
        }
    }

    /// Sin nada aceptado, la decisión traduce el motivo crudo del push-all y ofrece la pérdida solo con los dos de arriba.
    /// La sesión caducada es el caso nuevo: hasta el 2026-09-28 bloqueaba sin salida.
    @Test("MUTACIÓN: sin aceptar nada, la sesión caducada ofrece la pérdida; el resto bloquea con su motivo de siempre")
    func withoutAcceptance_onlyAttestAndExpiredSessionOfferTheLoss() {
        let a = UUID()
        #expect(L.personalUploadBlockDecision(reason: .sessionExpired, pendingRows: [a], acceptance: nil, ownersSessionIsGone: true)
                == .offerLoss(shown: .cloudSessionExpired, cause: .noSession))
        #expect(L.personalUploadBlockDecision(reason: .cloudSessionExpired, pendingRows: [a], acceptance: nil, ownersSessionIsGone: true)
                == .offerLoss(shown: .cloudSessionExpired, cause: .noSession))
        #expect(L.personalUploadBlockDecision(reason: .attestUnavailable, pendingRows: [a], acceptance: nil, ownersSessionIsGone: true)
                == .offerLoss(shown: .personalAttestUnavailable, cause: .attestUnavailable))
        for reason in L.BlockReason.allCases
        where ![.sessionExpired, .cloudSessionExpired, .attestUnavailable].contains(reason) {
            #expect(L.personalUploadBlockDecision(reason: reason, pendingRows: [a], acceptance: nil, ownersSessionIsGone: true)
                    == .block(shown: L.personalPushAllShownReason(reason)), "\(reason)")
        }
        // Sin cifra (el recuento falló) también se ofrece: el aviso sale sin número y lo aceptado cubre cualquiera.
        #expect(L.personalUploadBlockDecision(reason: .sessionExpired, pendingRows: nil, acceptance: nil, ownersSessionIsGone: true)
                == .offerLoss(shown: .cloudSessionExpired, cause: .noSession))
    }

    /// Decisión 2 del encargo: lo aceptado recuerda su causa. Aceptado sin sesión, el cierre retomado sigue solo mientras
    /// siga sin sesión y con esas filas; si la persona volvió a entrar y la subida falla por otra cosa, bloquea como siempre.
    @Test("MUTACIÓN: lo aceptado sin sesión sigue solo sin sesión y con sus filas; con otro fallo, bloquea como siempre")
    func acceptedWithoutSession_onlyCoversTheSameCause() {
        let a = UUID(), b = UUID()
        let sinSesion = L.CausedLossAcceptance(rows: .rows([a, b]), cause: .noSession)
        for reason in [L.BlockReason.sessionExpired, .cloudSessionExpired] {
            #expect(L.personalUploadBlockDecision(reason: reason, pendingRows: [a], acceptance: sinSesion, ownersSessionIsGone: true)
                    == .continueWithAcceptedLoss, "\(reason)")
        }
        // Una fila que no estaba en el aviso vuelve a avisar, con la cifra nueva.
        #expect(L.personalUploadBlockDecision(reason: .sessionExpired, pendingRows: [a, UUID()], acceptance: sinSesion, ownersSessionIsGone: true)
                == .offerLoss(shown: .cloudSessionExpired, cause: .noSession))
        // Volvió a entrar y la red falla: esos cambios ya pueden subir, así que no se pierden.
        #expect(L.personalUploadBlockDecision(reason: .uploadRetryLater, pendingRows: [a], acceptance: sinSesion, ownersSessionIsGone: true)
                == .block(shown: .personalUploadRetryLater))
        #expect(L.personalUploadBlockDecision(reason: .transient, pendingRows: [a], acceptance: sinSesion, ownersSessionIsGone: true)
                == .block(shown: .transient))
        // Y el teléfono sin App Attest es OTRA causa: lo aceptado sin sesión no lo cubre, sale su propio aviso.
        #expect(L.personalUploadBlockDecision(reason: .attestUnavailable, pendingRows: [a], acceptance: sinSesion, ownersSessionIsGone: true)
                == .offerLoss(shown: .personalAttestUnavailable, cause: .attestUnavailable))
        // Al revés tampoco: lo aceptado por el attest no cubre la sesión caducada.
        let porAttest = L.CausedLossAcceptance(rows: .rows([a]), cause: .attestUnavailable)
        #expect(L.personalUploadBlockDecision(reason: .sessionExpired, pendingRows: [a], acceptance: porAttest, ownersSessionIsGone: true)
                == .offerLoss(shown: .cloudSessionExpired, cause: .noSession))
        #expect(L.personalUploadBlockDecision(reason: .attestUnavailable, pendingRows: [a], acceptance: porAttest, ownersSessionIsGone: true)
                == .continueWithAcceptedLoss)
    }

    /// Review adversarial del 2026-09-28: todo 401 del gateway llega como `.sessionExpired`, también con la sesión guardada y
    /// renovable (un deploy roto, un reloj desfasado). Sin la prueba de que la sesión del dueño se fue, el aviso es el de
    /// siempre —«vuelve a entrar»— y no ofrece perder nada; y lo aceptado sin sesión deja de cubrir. El attest no la necesita.
    @Test("MUTACIÓN: con la sesión del dueño aún renovable, la sesión caducada no ofrece perder nada ni deja seguir")
    func withARenewableSession_theExpiredSessionNeverOffersTheLoss() {
        let a = UUID()
        for reason in [L.BlockReason.sessionExpired, .cloudSessionExpired] {
            #expect(L.personalUploadBlockDecision(reason: reason, pendingRows: [a], acceptance: nil, ownersSessionIsGone: false)
                    == .block(shown: .cloudSessionExpired), "\(reason)")
            let sinSesion = L.CausedLossAcceptance(rows: .rows([a]), cause: .noSession)
            #expect(L.personalUploadBlockDecision(reason: reason, pendingRows: [a], acceptance: sinSesion,
                                                  ownersSessionIsGone: false) == .block(shown: .cloudSessionExpired),
                    "lo aceptado sin sesión siguió con la sesión de vuelta: \(reason)")
        }
        // El teléfono sin App Attest no depende de la sesión.
        #expect(L.personalUploadBlockDecision(reason: .attestUnavailable, pendingRows: [a], acceptance: nil,
                                              ownersSessionIsGone: false)
                == .offerLoss(shown: .personalAttestUnavailable, cause: .attestUnavailable))
        let porAttest = L.CausedLossAcceptance(rows: .rows([a]), cause: .attestUnavailable)
        #expect(L.personalUploadBlockDecision(reason: .attestUnavailable, pendingRows: [a], acceptance: porAttest,
                                              ownersSessionIsGone: false) == .continueWithAcceptedLoss)
    }

    @MainActor
    @Test("MUTACIÓN: el aviso de la sesión caducada cuenta lo que se pierde con cifra honesta y no es el del attest")
    func expiredSessionMessage_countsOnlyAnHonestNumber() {
        #expect(SignOutBlockedCopy.personalLossMessage(for: .noSession, pending: 3)
                == L10n.Settings.signOutCloudSessionExpiredPersonalLoss(3))
        #expect(SignOutBlockedCopy.personalLossMessage(for: .noSession, pending: Int.max)
                == L10n.Settings.signOutCloudSessionExpiredPersonalLossUnknown)
        #expect(SignOutBlockedCopy.personalLossMessage(for: .noSession, pending: 0)
                == L10n.Settings.signOutCloudSessionExpiredPersonalLossUnknown)
        // El del attest no cambia.
        #expect(SignOutBlockedCopy.personalLossMessage(for: .attestUnavailable, pending: 3)
                == SignOutBlockedCopy.personalAttestLossMessage(pending: 3))
        #expect(SignOutBlockedCopy.personalLossTitle(for: .attestUnavailable) == L10n.Settings.signOutAttestTitle)
        #expect(SignOutBlockedCopy.personalLossTitle(for: .noSession) == L10n.Settings.signOutBlockedTitle)
        #expect(SignOutBlockedCopy.personalLossMessage(for: .noSession, pending: 3)
                != SignOutBlockedCopy.personalLossMessage(for: .attestUnavailable, pending: 3))
        // Y no es el de grupos: son tus movimientos.
        #expect(SignOutBlockedCopy.personalLossMessage(for: .noSession, pending: 3)
                != L10n.Settings.signOutCloudSessionExpiredGroupsLoss(3))
    }

    @MainActor
    @Test("los accesores de la sesión caducada interpolan la cifra y nunca devuelven la key cruda")
    func expiredSessionAccessors_interpolate_neverRawKey() {
        let conCifra = L10n.Settings.signOutCloudSessionExpiredPersonalLoss(7)
        #expect(!conCifra.contains("settings."))
        #expect(conCifra.contains("7"))
        #expect(!L10n.Settings.signOutCloudSessionExpiredPersonalLossUnknown.contains("settings."))
    }
}

@Suite("Nube sin App Attest — exportar todos los movimientos", .serialized)
@MainActor
struct CloudPersonalAttestExportTests {

    /// «Todos» es todos. `DetailPeriod.allTime` son diez años hasta el final de hoy, así que el mutante que vuelva a él deja
    /// fuera lo antiguo y lo de fecha futura. El control con ese periodo prueba que el caso los distingue.
    @Test("MUTACIÓN: la exportación del aviso lleva también lo de hace más de diez años y lo de fecha futura")
    func exportsEveryTransaction_regardlessOfDate() throws {
        let context = try makeTestContext()
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let antiguo = try #require(calendar.date(byAdding: .year, value: -20, to: now))
        let futuro = try #require(calendar.date(byAdding: .year, value: 1, to: now))
        for date in [antiguo, now, futuro] {
            context.insert(TransactionItem(date: date, amount: -10.0, currencyCode: "USD"))
        }
        try context.save()

        let todos = try TransactionsExportService.export(
            format: .csv, using: .allTransactions, columns: .default, in: context, scheduleTagBackfill: false)
        #expect(todos.exportedCount == 3)

        let periodo = DetailPeriod.allTime.dateInterval()
        var asistente = ExportFilters.allTransactions
        asistente.dateFrom = periodo.start
        asistente.dateTo = periodo.end
        let control = try TransactionsExportService.export(
            format: .csv, using: asistente, columns: .default, in: context, scheduleTagBackfill: false)
        #expect(control.exportedCount == 1, "el control no distingue: el caso no probaría nada")
    }

    /// Rellenar el espejo de etiquetas es un guardado, y en la nube serían cambios por subir que la persona no escribió: el
    /// aviso volvería con otra cifra. La exportación del aviso no lo rellena; la del asistente sí, que es el control.
    @Test("MUTACIÓN: la exportación del aviso no escribe el espejo de etiquetas, y la del asistente sí")
    func rescueExportDoesNotBackfillTheTagMirror() async throws {
        let context = try makeTestContext()
        let tag = Yala.Tag(name: "Viaje")
        context.insert(tag)
        let tx = TransactionItem(date: Date(), amount: -10.0, currencyCode: "USD")
        context.insert(tx)
        tx.tags = [tag]  // sin espejo: el estado que el relleno cura
        try context.save()
        #expect(tx.tagIDs == nil)

        _ = try TransactionsExportService.export(
            format: .csv, using: .allTransactions, columns: .default, in: context, scheduleTagBackfill: false)
        for _ in 0..<5 { await Task.yield() }
        #expect(tx.tagIDs == nil, "la exportación del aviso guardó el espejo de etiquetas")

        _ = try TransactionsExportService.export(
            format: .csv, using: .allTransactions, columns: .default, in: context, scheduleTagBackfill: true)
        for _ in 0..<5 { await Task.yield() }
        #expect(tx.tagIDs != nil, "control: con el relleno activo el espejo se escribe; si no, el caso no mide nada")
    }

    @Test("sin filtros de cuenta, categoría, etiqueta, moneda, monto ni nota, y con todas las columnas")
    func hasNoFilters() {
        let filtros = ExportFilters.allTransactions
        #expect(filtros.selectedAccounts.isEmpty)
        #expect(filtros.selectedCategories.isEmpty)
        #expect(filtros.selectedSubcategories.isEmpty)
        #expect(filtros.selectedTagNames.isEmpty)
        #expect(filtros.selectedCurrencies.isEmpty)
        #expect(filtros.amountCondition == .any)
        #expect(filtros.noteContains == nil)
        #expect(!filtros.isExcludeMode)
        #expect(ExportColumns.default.activeColumns.count == ExportColumn.allCases.count)
    }
}

@Suite("Nube sin App Attest — la salida personal, cableada (source-scan)")
struct CloudPersonalAttestSignOutWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo balanceado por llaves desde un marcador que ACABA en `{`.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no se encontró `\(marker)`")
        var depth = 1
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    /// El tramo entre dos marcadores, para las firmas que ocupan varias líneas y no acaban en `{`.
    private static func slice(from start: String, to end: String, in source: String) throws -> String {
        let s = try #require(source.range(of: start), "no se encontró `\(start)`")
        let e = try #require(source.range(of: end, range: s.upperBound..<source.endIndex), "no se encontró `\(end)`")
        return String(source[s.upperBound..<e.lowerBound])
    }

    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static let signOutPath = "Yala/Services/CloudSync/CloudSessionSignOut.swift"
    private static let profilePath = "Yala/App/Views/Profile/ProfileView.swift"

    private static func cloudSignOut() throws -> String {
        squashed(try body(of: "private func performCloudSecureSignOut(context: ModelContext) async {", in: source(signOutPath)))
    }

    /// El paso 1 no decide nada por su cuenta desde el 2026-09-28: cablea `personalUploadBlockDecision` y sus tres salidas.
    /// El cuerpo del `switch` entero, porque con dos literales sueltos sobrevivían anotar la oferta DESPUÉS de la fase,
    /// perder la causa o enseñar la cifra de un recuento aparte (`testing.md`, «el source-scan de dos literales no es una red»).
    @Test("MUTACIÓN: el paso 1 cablea la decisión pura, anota la oferta con su causa antes de la fase y enseña la cifra de las filas")
    func stepOneWiresThePureDecision() throws {
        let cloud = try Self.cloudSignOut()
        #expect(cloud.contains(Self.squashed("""
            if case .blocked(let pending, let reason) = await controller.pushAllPendingForSignOut() {
                let rows = controller.livePendingUploadRowIDs()
                let ownersSessionIsGone = CloudSyncRuntime.shared?.ownersSessionIsGone ?? false
                switch CloudSignOutFlowLogic.personalUploadBlockDecision(
                    reason: reason, pendingRows: rows, acceptance: acceptedPersonalLoss, ownersSessionIsGone: ownersSessionIsGone) {
                case .continueWithAcceptedLoss:
                    break
                case .block(let shown):
                    acceptedPersonalLoss = nil
                    Self.leaveSignInDoorOpen(ifShown: shown, controller: controller)
                    phase = .blocked(pendingCount: pending, reason: shown)
                    CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
                    return
                case .offerLoss(let shown, let cause):
                    acceptedPersonalLoss = nil
                    personalLossExit = PersonalLossOffer(rows: rows, cause: cause)
                    let shownCount = rows?.count ?? Int.max
                    Self.leaveSignInDoorOpen(ifShown: shown, controller: controller)
                    phase = .blocked(pendingCount: shownCount, reason: shown)
                    CloudSyncBreadcrumb.signOutPushBlocked(pending: shownCount)
                    Self.notePersonalLossOffered(pending: shownCount, cause: cause)
                    return
                }
            }
            """)), """
            El paso 1 dejó de cablear la decisión tal cual: o todo bloqueo personal ofrecería perder datos, o una aceptación \
            dejaría pasar filas que nadie aceptó, o la oferta llegaría tarde o sin su causa.
            """)
    }

    /// La salida de tus datos pregunta por la causa del bloqueo que se ENSEÑA, no solo por el motivo: `.cloudSessionExpired`
    /// lo pone también el paso 2 sobre grupos, con su propia oferta.
    @Test("MUTACIÓN: la salida de tus datos solo está viva con un motivo que la abre y una oferta de esa misma causa")
    func offersPersonalLossExitRequiresTheSameCause() throws {
        let offers = Self.squashed(try Self.body(of: "var offersPersonalLossExit: Bool {", in: Self.source(Self.signOutPath)))
        #expect(offers == Self.squashed("""
            guard case .blocked(_, let reason) = phase, let cause = CloudSignOutFlowLogic.personalLossCause(reason),
                  let offer = personalLossExit else { return false }
            return offer.cause == cause
            """))
    }

    /// Los tres sitios que suben con una pérdida aceptada —los pasos 1 y 2 de la nube y `pushGroupsForSignOut`— exigen que
    /// el bloqueo siga siendo de la causa aceptada (el attest; desde el 2026-09-28 también la sesión que no hay o la otra
    /// cuenta, en grupos). Con la comparación por filas a secas, un 5xx al retomar se llevaba los cambios.
    @Test("MUTACIÓN: los tres sitios que retoman con lo aceptado exigen que el bloqueo siga siendo de su causa")
    func theThreeRetrySitesRequireTheAttest() throws {
        let source = Self.squashed(try Self.source(Self.signOutPath))
        // Dos en el coordinador —el paso 2 de la nube y `pushGroupsForSignOut`—; el tercero, el del paso 1, vive desde el
        // 2026-09-28 dentro de `personalUploadBlockDecision`, que es pura y se prueba en `CloudExpiredSessionPersonalLossLogicTests`.
        #expect(source.components(separatedBy: "CloudSignOutFlowLogic.continuesAfterBlockedUpload(").count - 1 == 2)
        #expect(source.components(separatedBy: "CloudSignOutFlowLogic.personalUploadBlockDecision(").count - 1 == 1)
        #expect(source.components(separatedBy: "CloudSignOutFlowLogic.continuesWithoutUploading(").count - 1 == 4, """
            La comparación por filas a secas solo vale donde no hay subida que contradiga lo aceptado: los recuentos finales \
            tras soltar el canal (el de la nube, con una llamada para lo personal y otra para grupos, y el de \
            `finalizeSessionExit`) y el bloqueo de la celda privada, que no sube grupos (`blockIfGroupsCannotUpload`, que \
            además exige la causa `.noSession`).
            """)
        #expect(source.contains(Self.squashed("""
            case .blocked(_, let reason) where acceptedGroupsLoss.map {
                CloudSignOutFlowLogic.continuesAfterBlockedUpload(
                    reason: reason, cause: $0.cause, pendingRows: groupsLossRowIDs(context: context),
                    acceptance: $0.rows)
            } ?? false:
            """)))
        #expect(source.contains(Self.squashed("""
            case .blocked(_, let reason):
                if CloudSignOutFlowLogic.continuesAfterBlockedUpload(
                    reason: reason, cause: accepted.cause,
                    pendingRows: groupsLossRowIDs(context: context), acceptance: accepted.rows) {
                    return true
                }
            """)))
        #expect(source.contains(Self.squashed("""
            if let accepted = acceptedGroupsLoss, accepted.cause == .noSession,
               CloudSignOutFlowLogic.continuesWithoutUploading(pendingRows: rows, acceptance: accepted.rows) {
                return false
            }
            """)), "la celda privada acepta perder por una causa que no es la suya")
    }

    @Test("MUTACIÓN: la salida personal exige su bloqueo y su oferta, y retoma el cierre en la nube con las filas del aviso")
    func theExitIsGuarded() throws {
        let exit = Self.squashed(try Self.body(
            of: "func exitDiscardingUnsyncedPersonalChanges(context: ModelContext) async {", in: Self.source(Self.signOutPath)))
        #expect(exit.contains(Self.squashed(
            "guard offersPersonalLossExit, case .blocked(let shown, _) = phase, let offer = personalLossExit else { return }")), """
            Sin el guard, «Cerrar sesión y perderlos» descartaría cambios personales sin que ningún aviso lo haya ofrecido.
            """)
        #expect(exit.contains(Self.squashed("""
            acceptedPersonalLoss = CloudSignOutFlowLogic.CausedLossAcceptance(
                rows: offer.rows.map { .rows($0) } ?? .uncounted, cause: offer.cause)
            """)), "lo aceptado perdió la causa del aviso: un reintento que falla por otra cosa se llevaría los cambios")
        #expect(exit.contains("await performCloudSecureSignOut(context: context)"))
    }

    @Test("MUTACIÓN: el recuento final respeta cada aceptación en su outbox, y cuenta la pérdida pegada al arm")
    func theFinalCountRespectsEachAcceptance() throws {
        let cloud = try Self.cloudSignOut()
        #expect(cloud.contains(Self.squashed("""
            guard residualPersonal == 0 || CloudSignOutFlowLogic.continuesWithoutUploading(
                      pendingRows: controller.livePendingUploadRowIDs(), acceptance: acceptedPersonalLoss?.rows),
            """)), "El último recuento dejó de respetar lo aceptado de lo personal: el cierre se pararía tras soltar el canal.")
        let nota = try #require(cloud.range(of: Self.squashed(
            "if let accepted = acceptedPersonalLoss { Self.notePersonalDiscarded(pending: residualPersonal, cause: accepted.cause) }")))
        let arm = try #require(cloud.range(of: "StorageModePersistence.armSignOutWipe()"))
        #expect(nota.lowerBound < arm.lowerBound)
    }

    @Test("MUTACIÓN: «Ahora no», un gesto nuevo y el desasociar retiran lo aceptado de lo personal")
    func personalAcceptanceDoesNotSurviveTheGesture() throws {
        let source = try Self.source(Self.signOutPath)
        let tramos = [
            ("acknowledgeBlocked", try Self.body(of: "func acknowledgeBlocked() {", in: source)),
            ("signOut", try Self.slice(
                from: "func signOut(context: ModelContext, confirmedPath: CloudSignOutFlowLogic.Path? = nil,",
                to: "func detachGroupsAccount(", in: source)),
            ("detachGroupsAccount", try Self.slice(from: "func detachGroupsAccount(", to: "func retryDetachPurge(", in: source)),
        ]
        for (nombre, tramo) in tramos {
            #expect(tramo.contains("personalLossExit = nil"), "`\(nombre)` no retira la oferta personal")
            #expect(tramo.contains("acceptedPersonalLoss = nil"), "`\(nombre)` no retira lo aceptado de lo personal")
        }
    }

    /// «Ahora no» no borra nada: su cuerpo ENTERO, porque es lo único que corre al tocarlo. Una línea más —un arm, una purga,
    /// retomar el cierre— la pondría en rojo.
    @Test("MUTACIÓN: «Ahora no» solo reconoce el bloqueo y retira las ofertas: no arma, no purga, no retoma")
    func notNowOnlyAcknowledges() throws {
        let ack = Self.squashed(try Self.body(of: "func acknowledgeBlocked() {", in: Self.source(Self.signOutPath)))
        #expect(ack == Self.squashed("""
            if case .blocked = phase {
                phase = .idle
                groupsLossExit = nil
                acceptedGroupsLoss = nil
                personalLossExit = nil
                acceptedPersonalLoss = nil
            }
            blockedExit = nil
            """))
    }

    @Test("MUTACIÓN: el push-all personal pregunta el testigo al runtime, y el runtime lo baja antes de cualquier salida del ciclo")
    func theRuntimeWitnessIsAskedAndResetFirst() throws {
        #expect(try Self.source("Yala/Services/CloudSync/CloudMigrationController.swift")
            .contains("attestUnavailable: runtime.stoppedByUnavailableAttest(for: outcome)"))
        let cycle = Self.squashed(try Self.body(
            of: "private func performCycle() async -> SyncCadencePolicy.CadenceOutcome {",
            in: Self.source("Yala/Services/CloudSync/CloudSyncRuntime.swift")))
        // Los DOS testigos del ciclo se bajan antes de cualquier salida: el del attest y, desde el 2026-09-25, el de la subida
        // que no llegó (`cloud-signout-collapses-the-personal-push-all-reason-into-permanent`).
        #expect(cycle.hasPrefix(
            "lastCycleStoppedAtAttestGate = false lastCycleFailedUpload = false guard let context else { return .transient }"))
        #expect(try Self.source("Yala/Services/CloudSync/CloudMigrationController.swift")
            .contains("uploadFailed: runtime.stoppedByFailedUpload(for: outcome),"))
    }

    @Test("MUTACIÓN: Ajustes enciende el aviso de tus datos solo con su oferta, y sus tres botones hacen lo suyo en orden")
    func settingsWiresTheNotice() throws {
        let profile = try Self.source(Self.profilePath)
        let present = Self.squashed(try Self.body(
            of: "private func presentSignOutBlock(_ reason: CloudSignOutFlowLogic.BlockReason) {", in: profile))
        #expect(present.contains(Self.squashed("""
            case .personalAttestUnavailable:
                if signOutCoordinator.offersPersonalLossExit {
                    showSignOutPersonalAttestAlert = true
                } else {
                    showSignOutBlockedAlert = true
                }
            """)))
        // La sesión caducada (2026-09-28): primero el aviso de tus datos, que es el que llega antes (paso 1); después el de
        // grupos; sin ninguna oferta, el bloqueo de siempre, que no pierde nada.
        #expect(present.contains(Self.squashed("""
            case .sessionExpired, .cloudSessionExpired:
                if signOutCoordinator.offersPersonalLossExit {
                    showSignOutPersonalAttestAlert = true
                } else if signOutCoordinator.offersGroupsLossExit {
                    showSignOutAttestLossAlert = true
                } else {
                    showSignOutBlockedAlert = true
                }
            """)), "la sesión caducada con cambios personales no enciende su aviso, o lo tapa el de grupos")
        #expect(present.contains("showSignOutPersonalAttestAlert = false"), "el aviso no se apaga antes de presentar el siguiente")
        #expect(Self.squashed(profile).contains(Self.squashed("""
            .alert(SignOutBlockedCopy.personalLossTitle(for: signOutPersonalLossCause), isPresented: $showSignOutPersonalAttestAlert) {
                Button(L10n.Settings.signOutAttestExportButton) {
                    exportAllTransactionsBeforeLosingThem()
                }
                Button(L10n.Settings.signOutAttestLossButton, role: .destructive) {
                    Task { await CloudSessionSignOut.shared.exitDiscardingUnsyncedPersonalChanges(context: modelContext) }
                }
                Button(L10n.Action.notNow, role: .cancel) {
                    CloudSessionSignOut.shared.acknowledgeBlocked()
                }
            } message: {
                Text(SignOutBlockedCopy.personalLossMessage(for: signOutPersonalLossCause, pending: signOutPersonalAttestPending))
            }
            """)), "el aviso de tus datos cambió: exportar primero, perder destructivo, «Ahora no» sin borrar")
        let sync = Self.squashed(try Self.body(
            of: "private func syncSignOutUI(from phase: CloudSessionSignOut.Phase) {", in: profile))
        #expect(sync.contains(Self.squashed("""
            if let cause = CloudSignOutFlowLogic.personalLossCause(reason), signOutCoordinator.offersPersonalLossExit {
                signOutPersonalAttestPending = pending
                signOutPersonalLossCause = cause
            }
            """)), """
            Ajustes dejó de guardar la cifra del bloqueo: el aviso saldría sin cifra y la persona aceptaría perder cambios sin \
            saber cuántos.
            """)
    }

    /// El cuerpo ENTERO de la exportación: con dos literales sueltos sobrevivían quitar el turno de espera, silenciar el
    /// error, reconocer el bloqueo por el alias del coordinador o apagar el canario (review adversarial, 2026-09-15;
    /// `testing.md`, «el source-scan de dos literales no es una red»).
    @Test("MUTACIÓN: exportar lleva TODOS los movimientos sin tocar el cierre, con indicador y texto propio, y vuelve el aviso")
    func settingsExportsEverythingAndReturnsToTheNotice() throws {
        let profile = try Self.source(Self.profilePath)
        let export = Self.squashed(try Self.body(of: "private func exportAllTransactionsBeforeLosingThem() {", in: profile))
        #expect(export == Self.squashed("""
            isExportingBeforeLosingChanges = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                defer { isExportingBeforeLosingChanges = false }
                do {
                    let result = try TransactionsExportService.export(
                        format: .csv, using: .allTransactions, columns: .default, in: modelContext,
                        scheduleTagBackfill: false)
                    CloudSessionSignOut.notePersonalLossExport(rows: result.exportedCount, cause: signOutPersonalLossCause)
                    signOutRescueExportFile = ExportedFile(urls: [result.fileURL])
                } catch {
                    #if DEBUG
                    print("ProfileView: Error exportando los movimientos antes de cerrar sesión: \\(error)")
                    #endif
                    signOutRescueExportErrorMessage = SignOutBlockedCopy.personalExportFailureMessage(for: error)
                    showSignOutRescueExportError = true
                }
            }
            """), "La exportación del aviso cambió: revisa que siga sin tocar el cierre, con su turno, su indicador y su canario.")
        let vuelta = Self.squashed(try Self.body(of: "private func returnToPersonalAttestNotice() {", in: profile))
        #expect(vuelta == Self.squashed("""
            guard case .blocked(_, let reason) = signOutCoordinator.phase,
                  CloudSignOutFlowLogic.personalLossCause(reason) != nil else { return }
            syncSignOutUI(from: signOutCoordinator.phase)
            """))
        let todo = Self.squashed(profile)
        #expect(todo.contains(".sheet(item: $signOutRescueExportFile, onDismiss: { returnToPersonalAttestNotice() }) { file in"))
        #expect(todo.contains(Self.squashed("""
            .alert(L10n.Export.exportError, isPresented: $showSignOutRescueExportError) {
                Button(L10n.Common.ok, role: .cancel) { returnToPersonalAttestNotice() }
            } message: {
                Text(signOutRescueExportErrorMessage)
            }
            """)))
        #expect(todo.contains("if isExportingBeforeLosingChanges {"), "el indicador de la exportación dejó de pintarse")
    }

    /// Un intercambio de los dos botones en un idioma pondría el rol destructivo sobre «Exportar». Por diseño, el botón de la
    /// pérdida dice en cada idioma lo mismo que el de grupos, así que la comparación lo caza sin leer ningún idioma.
    @Test("MUTACIÓN: en los 16 idiomas el botón de la pérdida dice lo mismo que el de grupos, y el de exportar otra cosa")
    func theButtonsKeepTheirMeaningInEveryLocale() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let locales = ["en", "en-GB", "es", "es-419", "es-AR", "es-ES", "de", "fr", "it", "nl", "pl", "pt", "pt-BR", "pt-PT",
                       "ja", "zh-Hans"]
        for locale in locales {
            let url = root.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "no se pudo leer \(locale)")
            let perder = try #require(table["settings.signOutAttestLossButton"], "\(locale) sin el botón de la pérdida")
            #expect(perder == table["groups.errors.attestUnavailableSignOutLossButton"],
                    "\(locale): el botón destructivo dejó de nombrar la pérdida como el de grupos")
            #expect(table["settings.signOutAttestExportButton"] != perder, "\(locale): exportar y perder dicen lo mismo")
        }
    }
}
