//
//  AppleIDCloseNoticeTests.swift
//  YalaTests
//
//  La hoja «Cambiaste de cuenta de iCloud» (ticket `apple-id-close-blocked-has-no-visible-outcome`).
//
//  Tres suites, y cada una mira un lado distinto del cable. **Van en un fichero que no se llama como
//  ninguna**: al acotar con `-only-testing`, nómbralas por su TIPO (`.claude/rules/testing.md`).
//   1. `AppleIDCloseNoticeLogicTests`: la tabla pura —qué se ve, qué hace cada botón y qué hace la red—.
//   2. `SignOutBlockedCopyTests`: el copy del bloqueo, que comparten Ajustes y la hoja.
//   3. `AppleIDCloseNoticeWiringTests` (source-scan): que la hoja CONSUME la tabla, que el `.alert` no vuelve
//      y que la matriz cuelga de la condición viva. La tabla sola no prueba nada de eso.
//
//  Lo que ninguna de las tres ve —que la hoja se presenta, enseña el bloqueo y deja al coordinador en
//  `.idle`— lo prueba `YalaUITests/Flows/AppleIDCloseNoticeUITests`.
//

import Foundation
import Testing

@testable import Yala

// MARK: - 1 · La tabla

@MainActor
@Suite("Hoja del cambio de Apple ID · la tabla")
struct AppleIDCloseNoticeLogicTests {

    private typealias Logic = AppleIDCloseNoticeLogic

    private static let blocked: CloudSessionSignOut.Phase = .blocked(pendingCount: 1, reason: .sessionExpired)
    private static let allPhases: [CloudSessionSignOut.Phase] = [.idle, .working, blocked, .awaitingRelaunch]

    @Test("Preguntando se ve la pregunta, esté como esté el coordinador")
    func askingShowsTheQuestion() {
        for phase in Self.allPhases {
            #expect(Logic.stage(notice: .asking, phase: phase) == .asking)
        }
    }

    @Test("MUTACIÓN: en vuelo manda la fase — el bloqueo se ve con SU motivo, nunca como progreso")
    func closingFollowsTheCoordinator() {
        #expect(Logic.stage(notice: .closing, phase: .idle) == .working)
        #expect(Logic.stage(notice: .closing, phase: .working) == .working)
        #expect(Logic.stage(notice: .closing, phase: .awaitingRelaunch) == .working)
        for reason in CloudSignOutFlowLogic.BlockReason.allCases {
            #expect(Logic.stage(notice: .closing, phase: .blocked(pendingCount: 2, reason: reason)) == .blocked(reason))
        }
    }

    @Test("MUTACIÓN: vuelto el cierre, sin bloqueo que enseñar se ve «un momento más» y NO un progreso eterno")
    func aStoppedCloseNeverShowsAStuckProgress() {
        // El bug que cazó la review: Ajustes, montado debajo, reconoce el bloqueo y la fase pasa a `.idle`.
        // Con la hoja pintando progreso ahí, se quedaba sin botones y reteniendo el router.
        #expect(Logic.stage(notice: .stopped, phase: .idle) == .busy)
        #expect(Logic.stage(notice: .stopped, phase: .working) == .busy)
        #expect(Logic.stage(notice: .stopped, phase: .awaitingRelaunch) == .working)
        for reason in CloudSignOutFlowLogic.BlockReason.allCases {
            #expect(Logic.stage(notice: .stopped, phase: .blocked(pendingCount: 2, reason: reason)) == .blocked(reason))
        }
    }

    @Test("Si el cierre no arrancó se ve «un momento más», no un progreso sin salida")
    func couldNotStartIsBusy() {
        for phase in Self.allPhases {
            #expect(Logic.stage(notice: .couldNotStart, phase: phase) == .busy)
        }
    }

    @Test("Confirmar solo arranca un cierre en las dos celdas que el aviso describe")
    func onlyThePrivateCellsClose() {
        #expect(Logic.closeRequest(cell: .privateSignOut, phase: .idle) == .start(acknowledgingBlockedFirst: false))
        #expect(Logic.closeRequest(cell: .privateWithGroupsSignOut, phase: .idle)
                == .start(acknowledgingBlockedFirst: false))
        // La nube cerraría la CUENTA de Yala bajo un texto que habla de iCloud, y solo-grupos borraría un
        // store que no es de este Apple ID. En las dos, el estado que motivó la pregunta ya no existe.
        #expect(Logic.closeRequest(cell: .cloudSecureSignOut, phase: .idle) == .release)
        #expect(Logic.closeRequest(cell: .groupsOnlySignOut, phase: .idle) == .release)
    }

    @Test("MUTACIÓN: con el coordinador bloqueado, confirmar lo reconoce ANTES de arrancar")
    func aBlockIsAcknowledgedBeforeStarting() {
        for reason in CloudSignOutFlowLogic.BlockReason.allCases {
            let phase: CloudSessionSignOut.Phase = .blocked(pendingCount: 0, reason: reason)
            #expect(Logic.closeRequest(cell: .privateSignOut, phase: phase)
                    == .start(acknowledgingBlockedFirst: true))
            #expect(Logic.closeRequest(cell: .privateWithGroupsSignOut, phase: phase)
                    == .start(acknowledgingBlockedFirst: true))
        }
    }

    @Test("Con otro gesto trabajando no arranca; con el borrado ya armado, suelta")
    func busyAndArmedCoordinator() {
        #expect(Logic.closeRequest(cell: .privateSignOut, phase: .working) == .couldNotStart)
        #expect(Logic.closeRequest(cell: .privateSignOut, phase: .awaitingRelaunch) == .release)
        // La celda manda antes que la fase: fuera de C y D se suelta aunque el coordinador esté ocupado.
        #expect(Logic.closeRequest(cell: .cloudSecureSignOut, phase: .working) == .release)
    }

    @Test("MUTACIÓN: tras el await, `.idle` y `.working` son un cierre que NO corrió; lo demás, uno que volvió")
    func whatIsLeftAfterTheClose() {
        #expect(Logic.noticeAfterClose(phaseAfter: .idle) == .couldNotStart)
        #expect(Logic.noticeAfterClose(phaseAfter: .working) == .couldNotStart)
        #expect(Logic.noticeAfterClose(phaseAfter: Self.blocked) == .stopped)
        #expect(Logic.noticeAfterClose(phaseAfter: .awaitingRelaunch) == .stopped)
    }

    @Test("MUTACIÓN: «Ahora no» reconoce el bloqueo de ESTE cierre —en vuelo o vuelto—, y solo ese")
    func laterAcknowledgesOnlyItsOwnBlock() {
        #expect(Logic.laterAcknowledgesBlocked(notice: .closing, phase: Self.blocked))
        #expect(Logic.laterAcknowledgesBlocked(notice: .stopped, phase: Self.blocked))
        // Quien no pidió cerrar no toca el cierre: un bloqueo ajeno guarda la decisión pendiente de su pantalla.
        #expect(!Logic.laterAcknowledgesBlocked(notice: .asking, phase: Self.blocked))
        #expect(!Logic.laterAcknowledgesBlocked(notice: .couldNotStart, phase: Self.blocked))
        #expect(!Logic.laterAcknowledgesBlocked(notice: nil, phase: Self.blocked))
        for phase: CloudSessionSignOut.Phase in [.idle, .working, .awaitingRelaunch] {
            #expect(!Logic.laterAcknowledgesBlocked(notice: .closing, phase: phase))
            #expect(!Logic.laterAcknowledgesBlocked(notice: .stopped, phase: phase))
        }
    }

    @Test("MUTACIÓN: con el borrado armado la hoja NO se presenta — el anchor es del cover terminal")
    func presentationStandsDownForTheRelaunchCover() {
        for notice: AppleIDCloseNotice in [.asking, .closing, .stopped, .couldNotStart] {
            #expect(Logic.presentationArmed(notice: notice, phase: .idle))
            #expect(Logic.presentationArmed(notice: notice, phase: .working))
            #expect(Logic.presentationArmed(notice: notice, phase: Self.blocked))
            #expect(!Logic.presentationArmed(notice: notice, phase: .awaitingRelaunch))
        }
        for phase in Self.allPhases {
            #expect(!Logic.presentationArmed(notice: nil, phase: phase))
        }
    }

    @Test("Solo `.awaitingRelaunch` suelta el aviso por un cambio de fase")
    func onlyTheArmedWipeReleasesByPhase() {
        #expect(Logic.releasesOnPhaseChange(notice: .closing, phase: .awaitingRelaunch))
        #expect(Logic.releasesOnPhaseChange(notice: .asking, phase: .awaitingRelaunch))
        for phase: CloudSessionSignOut.Phase in [.idle, .working, Self.blocked] {
            #expect(!Logic.releasesOnPhaseChange(notice: .closing, phase: phase))
        }
        #expect(!Logic.releasesOnPhaseChange(notice: nil, phase: .awaitingRelaunch))
    }

    @Test("MUTACIÓN: el onDismiss solo re-arma una hoja que HABÍA aparecido")
    func onlyARealDismissRearms() {
        #expect(Logic.rearmsOnDismiss(wasPresented: true, notice: .closing, phase: Self.blocked))
        // El toggle de la red sobre una hoja que nunca montó: re-armar ahí reiniciaría el cap para siempre.
        #expect(!Logic.rearmsOnDismiss(wasPresented: false, notice: .closing, phase: Self.blocked))
        #expect(!Logic.rearmsOnDismiss(wasPresented: true, notice: nil, phase: .idle))
        #expect(!Logic.rearmsOnDismiss(wasPresented: true, notice: .closing, phase: .awaitingRelaunch))
    }

    @Test("MUTACIÓN: al agotarse la red se suelta el aviso, y el bloqueo de este cierre se reconoce")
    func exhaustionReleasesAndAcknowledges() {
        #expect(Logic.onPresentationExhausted(notice: .closing, phase: Self.blocked)
                == .release(acknowledgingBlocked: true))
        #expect(Logic.onPresentationExhausted(notice: .stopped, phase: Self.blocked)
                == .release(acknowledgingBlocked: true))
        #expect(Logic.onPresentationExhausted(notice: .stopped, phase: .working)
                == .release(acknowledgingBlocked: false))
        #expect(Logic.onPresentationExhausted(notice: .asking, phase: .idle) == .release(acknowledgingBlocked: false))
        #expect(Logic.onPresentationExhausted(notice: .asking, phase: Self.blocked)
                == .release(acknowledgingBlocked: false))
        #expect(Logic.onPresentationExhausted(notice: .couldNotStart, phase: .working)
                == .release(acknowledgingBlocked: false))
        #expect(Logic.onPresentationExhausted(notice: .closing, phase: .idle)
                == .release(acknowledgingBlocked: false))
    }

    @Test("Con el cierre EN VUELO y trabajando la red sigue: soltar no libera el router y dejaría su bloqueo sin pantalla")
    func exhaustionKeepsTryingWhileWorking() {
        #expect(Logic.onPresentationExhausted(notice: .closing, phase: .working) == .keepTrying)
    }
}

// MARK: - 2 · El copy

@MainActor
@Suite("Cierre bloqueado · una tabla de copy para Ajustes y la hoja")
struct SignOutBlockedCopyTests {

    @Test("MUTACIÓN: cada motivo con causa propia dice la suya")
    func eachReasonSaysItsOwn() {
        #expect(SignOutBlockedCopy.message(for: .sessionExpired) == L10n.Groups.Errors.sessionExpired)
        #expect(SignOutBlockedCopy.message(for: .channelPaused) == L10n.Groups.Errors.channelPaused)
        #expect(SignOutBlockedCopy.message(for: .uploadRetryLater) == L10n.Groups.Errors.uploadRetryLater)
        #expect(SignOutBlockedCopy.message(for: .transient) == L10n.Settings.signOutPendingMessage)
        #expect(SignOutBlockedCopy.message(for: .attestUnavailable) == L10n.Groups.Errors.attestUnavailable)
        #expect(SignOutBlockedCopy.message(for: .personalAttestUnavailable) == L10n.Settings.signOutAttestBlocked)
    }

    @Test("Lo que no tiene causa que nombrar cae al genérico, `nil` incluido")
    func theRestIsGeneric() {
        let generic: [CloudSignOutFlowLogic.BlockReason?] = [.permanent, .exportUnconfirmed, .bridgeUnreadable,
                                                             .detachBusy, nil]
        for reason in generic {
            #expect(SignOutBlockedCopy.message(for: reason) == L10n.Settings.signOutBlockedMessage)
        }
    }

    @Test("«Un momento más» solo para lo pasajero, el teléfono sin App Attest el suyo, y el resto «No pudimos cerrar tu sesión»")
    func titles() {
        for reason in CloudSignOutFlowLogic.BlockReason.allCases {
            let expected: String
            switch reason {
            case .transient: expected = L10n.Settings.signOutPendingTitle
            case .attestUnavailable: expected = L10n.Groups.Errors.attestUnavailableTitle
            case .personalAttestUnavailable: expected = L10n.Settings.signOutAttestTitle
            default: expected = L10n.Settings.signOutBlockedTitle
            }
            #expect(SignOutBlockedCopy.title(for: reason) == expected)
        }
    }

    @Test("Control del instrumento: los textos que se distinguen son DISTINTOS entre sí")
    func theTextsAreDistinct() {
        // Sin esto, si dos claves resolvieran al mismo texto —una traducción vacía, un catálogo que no
        // carga—, las aserciones de arriba pasarían con los motivos intercambiados.
        let messages = [L10n.Groups.Errors.sessionExpired, L10n.Groups.Errors.channelPaused,
                        L10n.Groups.Errors.uploadRetryLater, L10n.Settings.signOutPendingMessage,
                        L10n.Settings.signOutBlockedMessage, L10n.Groups.Errors.attestUnavailable,
                        L10n.Settings.signOutAttestBlocked]
        #expect(Set(messages).count == messages.count)
        #expect(L10n.Settings.signOutPendingTitle != L10n.Settings.signOutBlockedTitle)
        #expect(L10n.Groups.Errors.attestUnavailableTitle != L10n.Settings.signOutBlockedTitle)
        #expect(L10n.Settings.signOutAttestTitle != L10n.Settings.signOutBlockedTitle)
        #expect(L10n.Settings.signOutAttestTitle != L10n.Groups.Errors.attestUnavailableTitle)
    }
}

// MARK: - 3 · El cableado

/// **Por qué source-scan.** Los dos lados de la decisión viven en vistas SwiftUI —la hoja y `ContentView`— y
/// ninguno es invocable desde aquí. El XCUITest prueba el recorrido; esto fija que la vista CONSUME la tabla
/// en vez de recomponerla, y lo que el recorrido no puede distinguir: un «Reintentar» que no hace nada en una
/// celda que se bloquea en el mismo turno, la fase de progreso que dura un parpadeo, el cap de la red.
@Suite("Hoja del cambio de Apple ID · cableado (source-scan)")
struct AppleIDCloseNoticeWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Sin líneas de comentario: el porqué de cada pieza la nombra, y leer prosa haría que documentar el
    /// invariante lo satisficiera solo.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo balanceado por llaves desde un marcador que acaba en `{`.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no encuentro `\(marker)`")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var index = 0
        while index < chars.count {
            if chars[index] == "{" { depth += 1 }
            if chars[index] == "}" { depth -= 1; if depth == 0 { break } }
            index += 1
        }
        return String(chars[0..<min(index, chars.count)])
    }

    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static let noticePath = "Yala/App/Views/Shared/AppleIDCloseNoticeView.swift"
    private static let contentViewPath = "Yala/App/ContentView.swift"

    private static func noticeCode() throws -> String {
        codeOnly(try source(noticePath))
    }

    /// Todos los `.swift` de producción, sin comentarios, con su ruta relativa.
    private static func productionFiles() throws -> [(path: String, code: String)] {
        let root = repoRoot.appendingPathComponent("Yala")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        var files: [(path: String, code: String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let relative = String(url.path.dropFirst(repoRoot.path.count + 1))
            files.append((relative, codeOnly(try String(contentsOf: url, encoding: .utf8))))
        }
        return files
    }

    @Test("MUTACIÓN: el aviso ya no es un `.alert`, y su título y su botón destructivo viven en UNA vista")
    func theAlertDoesNotComeBack() throws {
        let files = try Self.productionFiles()
        // Control del instrumento: un recorrido roto daría cero ficheros y todo en verde.
        #expect(files.count > 100, "el recorrido de `Yala/` encontró \(files.count) ficheros")
        // Por el TÍTULO y no por la forma de la llamada: `.alert(Text(…))` o un `.alert` partido en varias
        // líneas se colarían por un literal.
        let titled = files.filter { $0.code.contains("L10n.iCloud.appleIDChangedTitle") }.map(\.path)
        #expect(titled == [Self.noticePath], """
            el aviso del cambio de Apple ID tiene que vivir en la hoja y solo ahí; su título aparece en \(titled). \
            Un `.alert` con él vuelve a dejar el cierre bloqueado sin nadie que lo enseñe.
            """)
        let confirmers = files.filter { $0.code.contains("L10n.iCloud.appleIDChangedConfirm") }.map(\.path)
        #expect(confirmers == [Self.noticePath], "«Cerrar sesión y quitarlos» vive en \(confirmers)")
        #expect(!(try Self.noticeCode()).contains(".alert("), """
            la hoja del cambio de Apple ID presenta un `.alert`: dos presentaciones encadenadas del mismo anchor.
            """)
    }

    @Test("MUTACIÓN: la celda se resuelve en el tap con la capacidad COMPILADA de Grupos, la del coordinador")
    func theTapReadsTheCoordinatorsGetter() throws {
        let request = Self.squashed(try Self.body(of: "private func requestClose() {", in: Self.noticeCode()))
        #expect(request.contains("groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability"), """
            la hoja dejó de resolver la celda con el getter del coordinador. Con el compuesto, un kill remoto de \
            Grupos con sesión viva resuelve C en el tap y D en `signOut`: `confirmedPath` no casa y el botón no \
            hace nada.
            """)
        #expect(!request.contains("CloudSyncFlags.groupsBackendEnabled,"))
    }

    @Test("MUTACIÓN: pedir el cierre recorre las TRES ramas de la tabla y marca la vuelta del cierre")
    func requestCloseWalksEveryBranch() throws {
        let request = Self.squashed(try Self.body(of: "private func requestClose() {", in: Self.noticeCode()))
        #expect(request.contains(Self.squashed("""
            switch AppleIDCloseNoticeLogic.closeRequest(cell: cell, phase: coordinator.phase) {
            case .release:
                notice = nil
            case .couldNotStart:
                notice = .couldNotStart
            case .start(let acknowledgingBlockedFirst):
                if acknowledgingBlockedFirst { coordinator.acknowledgeBlocked() }
                notice = .closing
                let context = modelContext
                let pending = $notice
                Task { @MainActor in
                    await CloudSessionSignOut.shared.signOut(
                        context: context, confirmedPath: cell, confirmedWithoutICloudCopy: true)
                    if pending.wrappedValue == .closing {
                        pending.wrappedValue = AppleIDCloseNoticeLogic.noticeAfterClose(
                            phaseAfter: CloudSessionSignOut.shared.phase)
                    }
                }
            }
            """)), """
            `requestClose` cambió de forma. Cada rama tiene un motivo: `.release` suelta sin cerrar nada, \
            `.couldNotStart` deja la hoja con salida, el bloqueo se reconoce ANTES de pedir el cierre, y la vuelta \
            del `await` saca al aviso de «en vuelo» — sin eso, un bloqueo que otra pantalla reconociera dejaba la \
            hoja en un progreso eterno.
            """)
    }

    @Test("MUTACIÓN: «Ahora no» reconoce el bloqueo de su cierre antes de soltar el aviso")
    func laterAcknowledgesBeforeReleasing() throws {
        let later = Self.squashed(try Self.body(of: "private func later() {", in: Self.noticeCode()))
        #expect(later == Self.squashed("""
            if AppleIDCloseNoticeLogic.laterAcknowledgesBlocked(notice: notice, phase: coordinator.phase) {
                coordinator.acknowledgeBlocked()
            }
            notice = nil
            """), """
            «Ahora no» cambió de forma. Sin reconocer el bloqueo, el coordinador se queda en `.blocked` y tapia \
            `signOut`, el desasociar y la puerta del invitado el resto del lanzamiento.
            """)
    }

    @Test("MUTACIÓN: cada etapa tiene su pantalla — progreso, bloqueo con SU motivo y ocupado con salidas")
    func everyStageHasItsScreen() throws {
        let content = Self.squashed(try Self.body(of: "private var content: some View {", in: Self.noticeCode()))
        #expect(content.contains("switch liveStage ?? lastStage {"), """
            la hoja dejó de pintar la etapa congelada al retirarse: «Ahora no» sobre un bloqueo vuelve a enseñar \
            un progreso durante la animación de salida.
            """)
        #expect(content.contains(Self.squashed("""
            ProgressView()
                .controlSize(.large)
            """)), "la fase de progreso dejó de enseñar progreso (criterio 1 del ticket)")
        #expect(content.contains(#".accessibilityIdentifier("apple_id_close_working")"#))
        #expect(content.contains(Self.squashed("""
            case .blocked(let reason):
                blockedBody(reason: reason)
            case .losingGroupChanges(let pending):
                attestLossBody(pending: pending)
            case .busy:
                blockedBody(reason: .transient, identifierOverride: "apple_id_close_busy")
            """)), """
            el bloqueo tiene que pintarse con SU motivo y la etapa ocupada con el texto de lo pasajero, las dos \
            por `blockedBody`, que es donde viven «Reintentar» y «Ahora no».
            """)

        let blocked = Self.squashed(try Self.body(
            of: "private func blockedBody(reason: CloudSignOutFlowLogic.BlockReason,", in: Self.noticeCode()))
        #expect(blocked.contains(Self.squashed(#"""
            noticeBody(
                icon: "exclamationmark.triangle",
                title: SignOutBlockedCopy.title(for: reason),
                message: SignOutBlockedCopy.message(for: reason),
                identifier: identifierOverride ?? "apple_id_close_blocked_\(reason.breadcrumbSlug)") {
                YalaPrimaryButton(L10n.Action.retry) { requestClose() }
                    .accessibilityIdentifier("apple_id_close_retry")
                YalaSecondaryButton(L10n.iCloud.appleIDChangedLater) { later() }
                    .accessibilityIdentifier("apple_id_close_later")
            }
            """#)), """
            `blockedBody` cambió de forma. El texto y el identificador salen del MISMO motivo (el XCUITest mira el \
            identificador), «Reintentar» vuelve a pedir el cierre y «Ahora no» reconoce y suelta. Un «Reintentar» \
            vacío pasaría el XCUITest: la celda C se bloquea en el mismo turno.
            """)
    }

    @Test("MUTACIÓN: la red cuenta sus intentos, suelta el aviso al agotarse y reconoce el bloqueo que diga la tabla")
    func theNetIsBoundedAndReleases() throws {
        let net = Self.squashed(try Self.body(of: "private func verifyPresentation() async {", in: Self.noticeCode()))
        #expect(net.contains("switch RelaunchNetLogic.verdict(armed: armed, coverDidAppear: sheetDidAppear, attempt: attempt) {"))
        #expect(net.contains(Self.squashed("""
            guard !Task.isCancelled, !sheetDidAppear else { return }
            attempt += 1
            showSheet = false
            """)), """
            la red dejó de contar sus intentos: sin `attempt += 1` nunca llega a `.exhausted` y la condición viva \
            no se suelta — el brick del criterio 4.
            """)
        #expect(net.contains(Self.squashed("""
            guard AppleIDCloseNoticeLogic.presentationArmed(
                notice: notice, phase: CloudSessionSignOut.shared.phase) else { return }
            showSheet = true
            """)))
        #expect(net.contains(Self.squashed("""
            case .exhausted:
                switch AppleIDCloseNoticeLogic.onPresentationExhausted(
                    notice: notice, phase: CloudSessionSignOut.shared.phase) {
                case .keepTrying:
                    attempt = 0
                case .release(let acknowledgingBlocked):
                    if acknowledgingBlocked { CloudSessionSignOut.shared.acknowledgeBlocked() }
                    MetricsService.canary(.appleIDCloseNoticeNotPresented)
                    notice = nil
                    showSheet = false
                    return
                }
            """)), """
            el desarme de la red cambió de forma. Al agotarse el cap tiene que soltar la condición viva —o el \
            router se queda retenido el resto de la sesión— y reconocer el bloqueo de su cierre.
            """)
    }

    @Test("MUTACIÓN: el relevo al cover mira la fase REAL, y el re-armado solo atiende un desmontaje real")
    func theModifierConsumesTheNetDecisions() throws {
        let code = Self.squashed(try Self.noticeCode())
        #expect(code.contains(
            "private var coordinatorPhase: CloudSessionSignOut.Phase { CloudSessionSignOut.shared.phase }"), """
            el modifier dejó de observar la fase real del coordinador: con `.awaitingRelaunch` la hoja se quedaría \
            en el progreso y el cover del relanzamiento no podría presentar.
            """)
        #expect(code.contains(
            "if AppleIDCloseNoticeLogic.releasesOnPhaseChange(notice: notice, phase: newPhase) { notice = nil }"))
        #expect(code.contains(
            "let wasPresented = sheetDidAppear sheetDidAppear = false if AppleIDCloseNoticeLogic.rearmsOnDismiss( wasPresented: wasPresented,"),
            "el `onDismiss` tiene que leer si la hoja HABÍA aparecido antes de ponerlo a `false`")
        #expect(code.contains(".onChange(of: liveStage, initial: true) { _, stage in if let stage { lastStage = stage } }"))
        #expect(code.contains(".interactiveDismissDisabled()"), "la hoja no puede irse por swipe")
    }

    @Test("MUTACIÓN: la matriz cuelga de la CONDICIÓN VIVA en los dos sitios que la construyen")
    func theMatrixReadsTheLiveCondition() throws {
        let contentView = Self.codeOnly(try Self.source(Self.contentViewPath))
        #expect(contentView.components(separatedBy: "appleIDCloseNoticePending: appleIDCloseNotice != nil,").count - 1
                == 2, """
            la matriz de readiness se construye en dos sitios de `ContentView` y los dos tienen que leer la \
            condición viva del aviso; si uno lee otra cosa, el router drena por debajo de la hoja.
            """)
        #expect(contentView.components(
            separatedBy: ".modifier(AppleIDCloseNoticeModifier(notice: $appleIDCloseNotice))").count - 1 == 1)
        #expect(Self.squashed(contentView).contains(
            "case .appleIDChangedClosePrivate: if appleIDCloseNotice == nil { appleIDCloseNotice = .asking }"), """
            el drenaje enciende el aviso con un cinturón: con uno pendiente, la matriz ya no deja drenar este \
            intent, y si algún día lo hiciera, volver a `.asking` enseñaría la pregunta sobre un cierre que corre.
            """)
    }

    @Test("La tabla del copy no tiene `default`: un motivo nuevo tiene que pronunciarse en título y mensaje")
    func theCopyTableHasNoDefault() throws {
        let copy = Self.codeOnly(try Self.source("Yala/App/Views/Shared/SignOutBlockedCopy.swift"))
        #expect(copy.contains("static func title(for reason: CloudSignOutFlowLogic.BlockReason) -> String {"))
        #expect(copy.contains("static func message(for reason: CloudSignOutFlowLogic.BlockReason?) -> String {"))
        #expect(!copy.contains("default:"))
    }

    @Test("Los seams del XCUITest: purga del outbox, hoja que no se encola sin su fila, y el MISMO nombre de arg a los dos lados")
    func theUITestSeamsAreHermetic() throws {
        let reset = try Self.body(of: "static func reset(in context: ModelContext) {",
                                  in: Self.codeOnly(try Self.source("Yala/Seed/DevSeedGroups.swift")))
        #expect(reset.contains("deleteAll(GroupSyncOutbox.self, in: context)"), """
            `-uitest-reset` dejó de purgar el outbox de Grupos: la fila del seam bloquearía los cierres de las \
            corridas siguientes.
            """)
        let bootstrapper = Self.squashed(Self.codeOnly(try Self.source("Yala/App/AppBootstrapper.swift")))
        #expect(bootstrapper.contains(Self.squashed("""
            if UITestHooks.showAppleIDChangedNotice,
               !UITestHooks.seedPendingGroupsOutboxRow
                || CloudSessionSignOut.liveGroupsPendingCount(context: context) > 0 {
            """)), """
            la hoja del XCUITest se encola aunque la fila pedida no exista: confirmar cerraría DE VERDAD y \
            armaría un boot-wipe real en el simulador.
            """)
        // **La paridad del nombre del arg**, que es lo que la guarda de arriba NO cubre: con un typo a un lado,
        // el seam del outbox vale `false`, la hoja se encola igual y el test confirma un cierre que termina bien.
        let launcher = try Self.source("YalaUITests/Support/XCUIApplication+Yala.swift")
        let hooks = try Self.source("Yala/App/UITestHooks.swift")
        for arg in ["-uitest-apple-id-changed", "-uitest-groups-outbox-pending"] {
            #expect(launcher.contains("args.append(\"\(arg)\")"), "el lanzador del XCUITest no pasa `\(arg)`")
            #expect(hooks.contains("hasArg(\"\(arg)\")"), "`UITestHooks` no lee `\(arg)`")
        }
    }
}

// MARK: - 4 · El teléfono sin App Attest (ticket `groups-phone-that-never-attests-is-told-to-retry-forever`)

@MainActor
@Suite("Hoja del cambio de Apple ID · el teléfono sin App Attest")
struct AppleIDCloseNoticeAttestLossTests {

    typealias L = AppleIDCloseNoticeLogic

    @Test("MUTACIÓN: con la salida de ESTE cierre, el bloqueo del attest se ve como la pérdida con su cifra")
    func theLossStageNeedsTheExit() {
        let bloqueado = CloudSessionSignOut.Phase.blocked(pendingCount: 4, reason: .attestUnavailable)
        for notice in [AppleIDCloseNotice.closing, .stopped] {
            #expect(L.stage(notice: notice, phase: bloqueado, offersGroupsLossExit: true) == .losingGroupChanges(pending: 4))
            #expect(L.stage(notice: notice, phase: bloqueado, offersGroupsLossExit: false) == .blocked(.attestUnavailable))
        }
        // Otro motivo, u otra etapa, es la tabla de siempre aunque la salida estuviera ofrecida.
        let otro = CloudSessionSignOut.Phase.blocked(pendingCount: 4, reason: .transient)
        #expect(L.stage(notice: .closing, phase: otro, offersGroupsLossExit: true) == .blocked(.transient))
        #expect(L.stage(notice: .asking, phase: bloqueado, offersGroupsLossExit: true) == .asking)
        #expect(L.stage(notice: .couldNotStart, phase: bloqueado, offersGroupsLossExit: true) == .busy)
        #expect(L.stage(notice: .closing, phase: .working, offersGroupsLossExit: true) == .working)
    }

    @Test("MUTACIÓN: el aviso cuenta lo que se pierde con su cifra, y sin ella cuando no hay número honesto")
    func theLossMessageCountsHonestly() {
        #expect(SignOutBlockedCopy.attestLossMessage(pending: 7) == L10n.Groups.Errors.attestUnavailableSignOutLoss(7))
        #expect(SignOutBlockedCopy.attestLossMessage(pending: Int.max)
                == L10n.Groups.Errors.attestUnavailableSignOutLossUnknown)
        #expect(SignOutBlockedCopy.welcomeAttestLossMessage(pending: 7) == L10n.Welcome.Groups.neutralAttestLossBody(7))
        #expect(SignOutBlockedCopy.welcomeAttestLossMessage(pending: Int.max)
                == L10n.Welcome.Groups.neutralAttestLossBodyUnknown)
        // Control del instrumento: los cuatro textos son distintos, así que las aserciones de arriba discriminan.
        let textos = [L10n.Groups.Errors.attestUnavailableSignOutLoss(7),
                      L10n.Groups.Errors.attestUnavailableSignOutLossUnknown,
                      L10n.Welcome.Groups.neutralAttestLossBody(7),
                      L10n.Welcome.Groups.neutralAttestLossBodyUnknown]
        #expect(Set(textos).count == textos.count)
    }

    @Test("MUTACIÓN: la hoja congela la salida con la etapa, y su botón exige la salida viva y retoma el cierre")
    func theSheetWiresTheLossExit() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let raw = try String(contentsOf: root.appendingPathComponent("Yala/App/Views/Shared/AppleIDCloseNoticeView.swift"),
                             encoding: .utf8)
        func squashed(_ text: String) -> String { text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
        let code = squashed(raw.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n"))
        #expect(code.contains(squashed("""
            AppleIDCloseNoticeLogic.stage(notice: $0, phase: coordinator.phase,
                                          offersGroupsLossExit: coordinator.offersGroupsLossExit)
            """)), "la hoja lee la salida aparte de la etapa: la animación de salida pintaría el bloqueo sin salida")
        #expect(code.contains(squashed("""
            guard coordinator.offersGroupsLossExit else { return }
            notice = .closing
            """)))
        #expect(code.contains("await CloudSessionSignOut.shared.exitDiscardingUnsyncedGroups(context: context)"))
        #expect(code.contains(squashed("""
            case .losingGroupChanges(let pending):
                attestLossBody(pending: pending)
            """)))
        // **El cuerpo entero, con su orden y su botón** (lente de la review, 2026-09-15). Con `requestClose()` en el botón,
        // «Cerrar sesión y perderlos» reconocía el bloqueo, volvía a arrancar el cierre y paraba en el mismo aviso, en
        // bucle y sin perder nada; con el mensaje de `message(for:)`, ofrecía perder cambios sin decir cuántos.
        #expect(code.contains(squashed(#"""
            private func attestLossBody(pending: Int) -> some View {
                noticeBody(
                    icon: "exclamationmark.triangle",
                    title: SignOutBlockedCopy.title(for: .attestUnavailable),
                    message: SignOutBlockedCopy.attestLossMessage(pending: pending),
                    identifier: "apple_id_close_losing_group_changes") {
                    YalaPrimaryButton(L10n.iCloud.appleIDChangedLater) { later() }
                        .accessibilityIdentifier("apple_id_close_later")
                    Button(role: .destructive) {
                        discardUnsyncedGroups()
                    } label: {
                        Text(L10n.Groups.Errors.attestUnavailableSignOutLossButton)
            """#)), "el cuerpo de la pérdida en la hoja cambió de forma: orden, mensaje con cifra o acción del botón")
    }
}
