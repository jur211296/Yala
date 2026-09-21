//
//  ReverseUploadControllerWiringTests.swift
//  YalaTests / CloudSync
//
//  Cableado de `CloudMigrationController` para la espera de «Volver a iCloud» (ticket
//  `reverse-upload-has-no-ceiling-and-no-exit`, segunda pasada de review). Va por source-scan, como
//  `AdoptEngineInSessionTests`: el controller tiene `init` privado, vive como singleton sobre el `mainContext` y su
//  pre-espera lee `iCloudSyncService.shared`, así que ninguno de estos tres comportamientos se puede observar desde
//  un test de unidad. Lo que decide cada uno —`ReverseExitPending` y el runner— sí tiene tests de comportamiento;
//  estos fijan que el controller los consulta donde toca.
//

import Foundation
import Testing

@testable import Yala

@Suite("Vuelta a iCloud: cableado del controller (source-scan)")
struct ReverseUploadControllerWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func controllerSource() throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("Yala/Services/CloudSync/CloudMigrationController.swift"),
            encoding: .utf8)
    }

    /// Cuerpo de un `func`, de su llave de apertura a la de cierre, sin líneas de comentario: nombrar un símbolo en
    /// un comentario no puede pintar el test de verde.
    private static func body(of marker: String) throws -> String {
        let source = try controllerSource()
        let start = try #require(source.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func storageView() throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("Yala/App/Views/Settings/StorageSettingsView.swift"),
            encoding: .utf8)
    }

    private static func occurrences(of needle: String, in text: String) -> Int {
        codeOnly(text).components(separatedBy: needle).count - 1
    }

    /// Fuera las líneas de comentario antes de CONTAR (`.claude/rules/testing.md`): sin esto, documentar el
    /// invariante que el scan cuenta lo pone en rojo sin que producción cambie — y este repo documenta mucho.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El aviso «Aún no podemos volver a iCloud» sale justo con un efecto pendiente, que es lo que dispara el re-kick
    /// de 30 s de la pantalla. Si ese re-kick borra `lastError`, el aviso se cierra solo entre 0 y 30 s después de
    /// aparecer. Solo lo borra una acción de la persona.
    @Test func backgroundRekick_doesNotClearTheError() throws {
        let rekick = try Self.body(of: "func rekickIfParked() async {")
        #expect(rekick.contains("resumeIfNeeded(clearingError: false)"))
        #expect(Self.occurrences(of: "resumeIfNeeded(", in: rekick) == 1, "ninguna otra llamada que borre el aviso")

        let ifNeeded = try Self.body(of: "func resumeIfNeeded(clearingError: Bool = true) async {")
        #expect(ifNeeded.contains("resume(clearingError: clearingError)"))
        #expect(ifNeeded.contains("pollLeader(clearingError: clearingError)"))

        for marker in ["func resume(clearingError: Bool = true) async {",
                       "func pollLeader(clearingError: Bool = true) async {"] {
            let fn = try Self.body(of: marker)
            #expect(fn.contains("if clearingError { lastError = nil }"), "\(marker)")
            #expect(Self.occurrences(of: "lastError = nil", in: fn) == 1, "\(marker): sin otro borrado incondicional")
        }
    }

    /// El aviso habla de reactivar la nube, así que solo sale con ESA salida pendiente. Con otro pendiente el runner
    /// empieza la vuelta igual, y el aviso mentiría.
    @Test func pendingExitNotice_onlyWithTheExitPending() throws {
        let start = try Self.body(of: "func startReverse() async {")
        #expect(start.contains("if hasPendingReverseExit, MigrationRuntimeGate.isDomainStablePhase(journaledPhase) {"))
        #expect(!start.contains("pendingEffectCount"), "el recuento de pendientes no distingue la salida")

        let snapshot = try Self.body(of: "private func readJournalSnapshot() -> (phase: MigrationPhase, pendingCount: Int) {")
        #expect(snapshot.contains("hasPendingReverseExit = ReverseExitPending.isPending(pending)"))
        #expect(Self.occurrences(of: "hasPendingReverseExit = false", in: snapshot) == 2,
                "sin fila y con el fetch fallido no queda un aviso de la lectura anterior")
    }

    /// La alerta de una salida del claim (ticket `reverse-claim-rejection-has-no-way-out-in-the-client`, D3 y D8) sale
    /// solo si la salida es NUEVA: la foto de `lastReverseClaimExit` se toma ANTES de llamar al runner y se compara
    /// después. Tomada después, la alerta no saldría nunca; sin comparar, saldría también por la nota de un intento
    /// anterior. Y el texto sale del motivo de la salida, no del journal releído, con la misma función que la nota de la
    /// tarjeta. Los dos caminos que conducen el claim la usan: el toque (`startReverse`, donde el aviso de la salida
    /// pendiente manda porque con él no hubo claim) y `resume`, que es «Retomar» y el re-kick.
    @Test func claimExitAlert_onlyForANewExit_fromTheTapAndFromResume() throws {
        let helper = try Self.body(of: "private func announceReverseClaimExit(since before: ReverseClaimExit?) {")
        let helperLines = helper.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #expect(helperLines == [
            "guard let exit = _runner?.lastReverseClaimExit, exit != before else { return }",
            "lastError = L10n.Storage.ReverseAbort.note(for: exit.reason)",
        ], "el cuerpo entero: comparar con la foto y traducir el motivo de ESA salida")

        let start = try Self.body(of: "func startReverse() async {")
        let snapshot = try #require(start.range(of: "let claimExitBefore = r.lastReverseClaimExit"))
        let activated = try #require(start.range(of: "await r.submit(.reverseActivated)"))
        let confirmed = try #require(start.range(of: "await r.submit(.reverseConfirmed)"))
        let refreshed = try #require(start.range(of: "refresh()"))
        let pendingNotice = try #require(start.range(
            of: "if hasPendingReverseExit, MigrationRuntimeGate.isDomainStablePhase(journaledPhase) {"))
        let otherwise = try #require(start.range(of: "} else {"))
        let announce = try #require(start.range(of: "announceReverseClaimExit(since: claimExitBefore)"))
        #expect(snapshot.lowerBound < activated.lowerBound, "la foto va antes de emitir nada")
        #expect(activated.lowerBound < confirmed.lowerBound)
        #expect(confirmed.lowerBound < refreshed.lowerBound)
        #expect(refreshed.lowerBound < pendingNotice.lowerBound)
        #expect(pendingNotice.lowerBound < otherwise.lowerBound, "el aviso de la salida pendiente manda")
        #expect(otherwise.lowerBound < announce.lowerBound)
        #expect(Self.occurrences(of: "lastReverseClaimExit", in: start) == 1, "una foto; la lectura es del helper")

        let resume = try Self.body(of: "func resume(clearingError: Bool = true) async {")
        let preWait = try #require(resume.range(of: "awaitImportQuiescenceForResume()"))
        let resumeSnapshot = try #require(resume.range(of: "let claimExitBefore = runner.lastReverseClaimExit"))
        let cancelCall = try #require(resume.range(of: "await runner.cancelReverse()"))
        let resumeCall = try #require(resume.range(of: "await runner.resume()"))
        let resumeRefresh = try #require(resume.range(of: "refresh()", range: resumeCall.upperBound..<resume.endIndex))
        let resumeAnnounce = try #require(resume.range(of: "announceReverseClaimExit(since: claimExitBefore)"))
        #expect(preWait.lowerBound < resumeSnapshot.lowerBound, "tras la pre-espera: nada del runner corre antes")
        #expect(resumeSnapshot.lowerBound < cancelCall.lowerBound, "la foto va antes de cualquier llamada al runner")
        #expect(resumeCall.lowerBound < resumeRefresh.lowerBound)
        #expect(resumeRefresh.lowerBound < resumeAnnounce.lowerBound)
    }

    /// La alerta del techo de las cuatro fases previas al montaje (ticket
    /// `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`, decisión de Jürgen). Misma forma que
    /// la del claim y por el mismo motivo —la foto ANTES de llamar al runner, porque el porqué journaleado no
    /// distingue esta salida de la de un intento anterior—, con UNA diferencia que este test es el único que fija:
    /// el motivo pasa por `ReverseUploadWaitingCopyLogic.abortNote` antes de traducirse.
    ///
    /// Sin ese filtro, «Cancelar y seguir en la nube» desde una de estas cuatro fases journalea `cancelled`, y
    /// `L10n.Storage.ReverseAbort.note(for:)` agrupa ese motivo con `stalled`: la persona que decide cancelar se
    /// llevaría una alerta de error diciéndole que no se pudo. El cuerpo entero está fijado porque quitar el filtro
    /// deja el resto del test en verde.
    @Test func preMountExitAlert_filtersTheReasonThePersonChose_fromTheTapAndFromResume() throws {
        let helper = try Self.body(of: "private func announceReversePreMountExit(since before: ReversePreMountExit?) {")
        let helperLines = helper.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #expect(helperLines == [
            "guard let exit = _runner?.lastReversePreMountExit, exit != before,",
            "let reason = ReverseUploadWaitingCopyLogic.abortNote(exit.reason) else { return }",
            "lastError = L10n.Storage.ReverseAbort.note(for: reason)",
        ], "el cuerpo entero: comparar con la foto, filtrar lo que la persona pidió, y traducir con la MISMA función")

        // Y el filtro dice lo que este test cree que dice: sin esto, la aserción de arriba fija un nombre, no un
        // comportamiento.
        #expect(ReverseUploadWaitingCopyLogic.abortNote(.cancelled) == nil)
        #expect(ReverseUploadWaitingCopyLogic.abortNote(.preMountStalled) == .preMountStalled)

        let start = try Self.body(of: "func startReverse() async {")
        let snapshot = try #require(start.range(of: "let preMountExitBefore = r.lastReversePreMountExit"))
        let activated = try #require(start.range(of: "await r.submit(.reverseActivated)"))
        #expect(snapshot.lowerBound < activated.lowerBound, "la foto va antes de emitir nada")
        #expect(Self.occurrences(of: "lastReversePreMountExit", in: start) == 1,
                "una foto; la lectura es del helper")
        // El orden aviso-pendiente ⟶ aviso-del-techo NO se afirma aquí: la línea del `if` va antes del cuerpo de su
        // `else` por construcción del lenguaje, así que la aserción no podría fallar. Lo que sí lo fija es el cuerpo
        // entero pinneado en `startReverseAndResume_wholeBodiesArePinned`. Medido en la review del 2026-09-21.

        let resume = try Self.body(of: "func resume(clearingError: Bool = true) async {")
        let resumeSnapshot = try #require(resume.range(of: "let preMountExitBefore = runner.lastReversePreMountExit"))
        let cancelCall = try #require(resume.range(of: "await runner.cancelReverse()"))
        let resumeCall = try #require(resume.range(of: "await runner.resume()"))
        let resumeAnnounce = try #require(resume.range(of: "announceReversePreMountExit(since: preMountExitBefore)"))
        #expect(resumeSnapshot.lowerBound < cancelCall.lowerBound,
                "la foto va antes de cualquier llamada al runner, y `cancelReverse` también produce salida")
        #expect(resumeCall.lowerBound < resumeAnnounce.lowerBound)
        // Que el aviso no viva dentro de un `if clearingError` —sería mudo justo con la pantalla delante, que es el
        // caso del ticket— tampoco se afirma aquí: un `contains` de UNA grafía exacta lo esquiva cualquier mutante
        // escrito en dos líneas o con otro espaciado. Lo caza el cuerpo entero normalizado del test de al lado.
    }

    /// Los dos cuerpos ENTEROS, normalizados (segunda pasada de review). El orden de arriba no caza dos mutantes que
    /// dejan la alerta muda con todo en verde: envolver el aviso de `resume` en `if clearingError { … }` —el re-kick con
    /// la pantalla delante ya no avisaría— y bajar un `lastError = nil` por debajo del aviso —se asigna y se borra en el
    /// mismo turno, y `onChange` solo ve `nil`—. Cambiar cualquiera de las dos funciones obliga a mirar este test.
    @Test func startReverseAndResume_wholeBodiesArePinned() throws {
        func lines(_ body: String) -> [String] {
            body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        #expect(lines(try Self.body(of: "func startReverse() async {")) == [
            "isWorking = true",
            "defer { isWorking = false }",
            "lastError = nil",
            "cancelReverseRequested = false",
            "let r = runner",
            "let claimExitBefore = r.lastReverseClaimExit",
            "let preMountExitBefore = r.lastReversePreMountExit",
            "await r.submit(.reverseActivated)    // done/notStarted → reverseConfirm(origin)",
            "await r.submit(.reverseConfirmed)    // → reverseClaimLeader → drive",
            "refresh()",
            "if hasPendingReverseExit, MigrationRuntimeGate.isDomainStablePhase(journaledPhase) {",
            "lastError = L10n.Storage.Errors.reversePendingExit",
            "} else {",
            "announceReverseClaimExit(since: claimExitBefore)",
            "announceReversePreMountExit(since: preMountExitBefore)",
            "}",
        ])
        #expect(lines(try Self.body(of: "func resume(clearingError: Bool = true) async {")) == [
            "guard !isWorking else { return }",
            "isWorking = true",
            "defer { isWorking = false }",
            "if clearingError { lastError = nil }",
            "guard await awaitImportQuiescenceForResume() else {",
            "refresh()",
            "return",
            "}",
            "let claimExitBefore = runner.lastReverseClaimExit",
            "let preMountExitBefore = runner.lastReversePreMountExit",
            "let forwardRefusalBefore = runner.lastForwardClaimRefusal",
            "if cancelReverseRequested {",
            "cancelReverseRequested = false",
            "await runner.cancelReverse()",
            "}",
            "await runner.resume()",
            "refresh()",
            "announceReverseClaimExit(since: claimExitBefore)",
            // Ticket `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`: el techo de las cuatro
            // fases previas al montaje sale SIN efectos, así que sin este aviso la pantalla cambiaba muda.
            "announceReversePreMountExit(since: preMountExitBefore)",
            // Ticket `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`: un claim de «Migrar» aparcado por
            // la red puede contestar `existing_stable` al retomar. Su aviso lo fija `MigrationIdentityGateWiringTests`.
            "await announceForwardClaimRefusal(since: forwardRefusalBefore)",
            "startRuntimeIfStable()",
        ])
    }

    /// La nota de la tarjeta, la de relanzar y la alerta dicen lo mismo porque salen de UNA función. La vista ya no
    /// tiene su propia traducción del motivo.
    @Test func reverseAbortNote_hasASingleTranslation() throws {
        let view = try Self.storageView()
        #expect(Self.occurrences(of: "L10n.Storage.ReverseAbort.note(for: reason)", in: view) == 2,
                "la nota de «Volver a iCloud» y la de relanzar")
        for stray in ["L10n.Storage.ReverseAbort.icloudFull", "L10n.Storage.ReverseAbort.icloudUnavailable",
                      "L10n.Storage.ReverseAbort.stalled", "L10n.Storage.ReverseAbort.claim",
                      "L10n.Storage.ReverseAbort.otherDeviceReverting"] {
            #expect(!view.contains(stray), "la vista no traduce motivos por su cuenta: \(stray)")
        }
    }

    /// **Firmar para CONTINUAR retira un «Cancelar» apuntado.** Hasta el 2026-09-21 los dos botones no podían
    /// coexistir —«Volver a entrar» solo sale en las cuatro fases previas al montaje y «Cancelar» solo salía en la
    /// espera de la subida—, así que la pregunta no se planteaba. Con el botón ofrecido también en esas cuatro sí:
    /// un «sí» que la pre-espera del import no dejó pasar lo ejecutaba el `resume()` con el que este método
    /// termina, y la persona que acababa de rescatar la vuelta se la encontraba abandonada, en silencio y sin nota
    /// (`cancelled` no la deja a propósito). El orden importa tanto como la línea: con la retirada DESPUÉS del
    /// `resume()` no serviría de nada.
    @Test func signInToResumeReverse_withdrawsAQueuedCancel() throws {
        let body = try Self.body(of: "func signInToResumeReverse() async {")
        let withdrawal = try #require(body.range(of: "cancelReverseRequested = false"),
                                      "firmar para continuar no puede dejar puesto un «Cancelar»")
        let resumeCall = try #require(body.range(of: "await resume()"))
        #expect(withdrawal.lowerBound < resumeCall.lowerBound, "se retira ANTES de retomar")
    }

    /// El «sí» se apunta ANTES del spin que espera a que el runner suelte, no después. Un re-kick en vuelo puede
    /// cruzar las cuatro fases previas al montaje en una sola pasada —cada una es una llamada de red, no una
    /// espera—, y con el flag puesto después el `resume()` que viniera detrás no lo veía: el gesto se perdía tras
    /// haber prometido lo contrario.
    @Test func cancelReverse_flagsTheRequestBeforeWaitingForTheRunner() throws {
        let body = try Self.body(of: "func cancelReverse() async {")
        let flagged = try #require(body.range(of: "cancelReverseRequested = true"))
        let spin = try #require(body.range(of: "while isWorking {"))
        let preWait = try #require(body.range(of: "awaitImportQuiescenceForResume()"))
        #expect(flagged.lowerBound < spin.lowerBound, "antes del spin, no solo antes de la pre-espera")
        #expect(flagged.lowerBound < preWait.lowerBound)
        #expect(Self.occurrences(of: "cancelReverseRequested = true", in: body) == 1, "un solo sitio lo apunta")
    }

    /// Un «sí» de «Cancelar» que la pre-espera no deja pasar queda apuntado, y lo ejecuta el siguiente `resume()`
    /// ANTES de retomar: al revés, el runner podía observar, drenar y terminar la vuelta que la persona canceló.
    @Test func queuedCancel_runsBeforeTheResume() throws {
        let cancel = try Self.body(of: "func cancelReverse() async {")
        let flagged = try #require(cancel.range(of: "cancelReverseRequested = true"))
        let preWait = try #require(cancel.range(of: "awaitImportQuiescenceForResume()"))
        #expect(flagged.lowerBound < preWait.lowerBound, "se apunta antes de que la pre-espera pueda vencer")

        let resume = try Self.body(of: "func resume(clearingError: Bool = true) async {")
        let resumePreWait = try #require(resume.range(of: "awaitImportQuiescenceForResume()"))
        let queued = try #require(resume.range(of: "if cancelReverseRequested {"))
        let cancelCall = try #require(resume.range(of: "await runner.cancelReverse()"))
        let resumeCall = try #require(resume.range(of: "await runner.resume()"))
        #expect(resumePreWait.lowerBound < queued.lowerBound, "solo tras la pre-espera")
        #expect(queued.lowerBound < cancelCall.lowerBound)
        #expect(cancelCall.lowerBound < resumeCall.lowerBound, "cancela antes de retomar")

        let start = try Self.body(of: "func startReverse() async {")
        #expect(start.contains("cancelReverseRequested = false"), "una vuelta nueva no hereda un «Cancelar» viejo")
    }
    // MARK: - Volver a entrar para retomar la vuelta (`reverse-before-mount-stays-stuck-with-an-expired-session`)

    /// **El rescate es una renovación FORZADA, no `accessToken()`, y esto es load-bearing.** La observación que
    /// enciende la tarjeta la produce sobre todo un 401 del gateway **con la sesión del SDK intacta**: ahí
    /// `hasSession` es `true` y `accessToken()` devuelve el MISMO JWT que el servidor acaba de rechazar (solo
    /// auto-refresca con menos de 30 s de margen, `CloudAuthService`). Un belt escrito con ese par —el molde del
    /// hermano `signInToResumeSync`— saltaba la firma, retomaba con el token rechazado y recibía el mismo 401: el
    /// botón que ofrece entrar no entraba, en el caso PRINCIPAL del ticket. Lo cazó una lente adversarial, y sin
    /// este scan nada impide que alguien "unifique" los dos métodos y lo reintroduzca: el defecto no se ve en
    /// ninguna suite, porque el controller es un singleton sobre el `mainContext` con `init` privado.
    @Test func signInToResumeReverse_rescuesWithAForcedRefresh_notWithAPlainAccessToken() throws {
        let body = try Self.body(of: "func signInToResumeReverse() async {")
        #expect(body.contains("forceRefreshAccessToken()"),
                "el rescate previo a la firma tiene que ROTAR el token, no releer el que el gateway rechazó")
        #expect(Self.occurrences(of: "accessToken()", in: body) == 0,
                "un `accessToken()` aquí devuelve el JWT ya rechazado y salta la firma que la tarjeta ofrece")
    }

    /// **La firma va atada al `sub`.** Este camino no hereda el gate de identidad de su hermano: `signInToResumeSync`
    /// termina en `CloudSyncRuntime.handleBecameActive()`, cuyo gate deja el motor `.idle` si la cuenta no es la del
    /// device; aquí se conduce el runner directo —la fase de la vuelta no es estable, así que ese gate no corre— y
    /// `reverseDrainOnce` sube el outbox entero, que no lleva dueño. Con Google el chooser sale siempre (`hint: nil`),
    /// así que sin esto elegir la cuenta de al lado escribía el corpus de una persona bajo el `sub` de otra.
    @Test func signInToResumeReverse_refusesToResumeWithAnotherAccount() throws {
        let body = try Self.body(of: "func signInToResumeReverse() async {")
        #expect(body.contains("let subBefore = CloudAuthService.shared.currentUserID"),
                "el `sub` de origen se captura ANTES de firmar: después ya es el de la cuenta nueva")
        #expect(body.contains("if let subBefore, CloudAuthService.shared.currentUserID != subBefore"),
                "y se compara tras firmar")
        // El orden importa tanto como la comparación: con el `return` después del `resume()`, comparar no serviría
        // de nada. Se fija midiendo que la salida cae ANTES.
        let mismatch = try #require(body.range(of: "CloudAuthService.shared.currentUserID != subBefore"))
        let resume = try #require(body.range(of: "await resume()"))
        #expect(mismatch.lowerBound < resume.lowerBound,
                "la comprobación del `sub` va ANTES de retomar, o la vuelta ya subió con la cuenta equivocada")
        #expect(body.contains("L10n.Storage.Errors.reverseSignInOtherAccount"), "y se dice, en vez de callar")
    }

    /// **`isWorking` se toma ANTES del primer `await`.** El re-kick de 30 s de la pantalla mira ese flag para decidir
    /// si empuja (`MigrationForegroundRekick.shouldRekick`), así que con el candado suelto durante la ida y vuelta de
    /// red se colaba su propio `resume()` — y el `isWorking = false` de aquí lo soltaba con ese pase aún en vuelo.
    @Test func signInToResumeReverse_takesTheLockBeforeTheFirstAwait() throws {
        let body = try Self.body(of: "func signInToResumeReverse() async {")
        let lock = try #require(body.range(of: "isWorking = true"))
        let firstAwait = try #require(body.range(of: "await "))
        #expect(lock.lowerBound < firstAwait.lowerBound,
                "el candado va antes del primer `await`, como en `signInToResumeSync`")
        #expect(body.contains("guard !isWorking else { return }"), "y no se entra dos veces")
    }

    // MARK: - La salida antes del montaje (`reverse-before-mount-has-no-way-to-abandon-the-return`)

    /// El botón cuelga de `canCancelReverse`, no de `isWaitingReverseUpload`. Esa línea ERA el hueco del ticket: al
    /// 15/30/50/62 % la tarjeta solo ofrecía «Retomar». El scan fija además que el predicado viejo no ha quedado
    /// gateando el botón en ningún otro sitio de la vista.
    @Test func cancelButton_isGatedByCanCancelReverse_notByTheUploadWait() throws {
        let view = try Self.storageView()
        // El PAR gate↔botón, no el gate suelto: `isWaitingReverseUpload` sigue vivo en la vista —decide el caption
        // de la espera y el cuerpo del diálogo— así que buscarlo a secas no distingue nada.
        #expect(view.contains(
            "if reverse && controller.canCancelReverse {\n                cancelReverseButton(controller)"),
                "el botón se pinta en las CINCO fases que ofrecen salida")
        #expect(!view.contains(
            "if reverse && controller.isWaitingReverseUpload {\n                cancelReverseButton(controller)"),
                "el gate viejo dejaba fuera las cuatro fases previas al montaje")
        // El auto-cierre del diálogo también: si se quedara con el predicado viejo, una confirmación abierta en una
        // fase previa al montaje sobreviviría al avance y reaparecería sola en la espera de la subida.
        #expect(view.contains(".onChange(of: controller?.canCancelReverse) { _, cancellable in"))
    }

    /// El cuerpo del diálogo depende de la fase. El de la espera promete un relanzamiento («Yala te pedirá cerrarla
    /// y volver a abrirla») porque ahí el espejo ESTÁ montado; antes del montaje esa frase sería falsa. Un mutante
    /// que reuse un solo cuerpo deja a la persona esperando un relanzamiento que nunca llega.
    @Test func cancelDialog_bodyDependsOnWhetherTheMirrorIsMounted() throws {
        let view = try Self.storageView()
        // El discriminante va en POSITIVO. «¿No es la espera de la subida?» falla ABIERTO: le daría el texto «no hay
        // relanzamiento» a cualquier fase POST-montaje que mañana entre en `canCancelReverse`, donde el espejo está
        // vivo y sí hay que relanzar.
        #expect(view.contains("Text(controller.isBeforeReverseMount"))
        #expect(view.contains("? L10n.Storage.Confirm.cancelReverseBeforeMountBody"))
        #expect(view.contains(": L10n.Storage.Confirm.cancelReverseBody)"))
        #expect(!view.contains("Text(controller.isWaitingReverseUpload"), "el discriminante en negativo, no")
        // Y el «no» del diálogo se ramifica con el mismo predicado: «Seguir esperando» describe la espera de la
        // subida, y en las cuatro fases previas la vuelta está avanzando.
        #expect(view.contains("Button(controller.isBeforeReverseMount"))
        #expect(view.contains("? L10n.Storage.Confirm.cancelReverseKeepBeforeMount"))
    }

    /// `canCancelReverse` es el cuerpo ENTERO, no «contiene reverseUpload»: el término que añade las cuatro fases
    /// es el que un mutante borraría, y con el `||` cortocircuitando, borrar el SEGUNDO deja el primero funcionando
    /// y toda la pantalla en verde.
    @Test func canCancelReverse_coversTheUploadWaitAndTheFourPreMountPhases() throws {
        let body = try Self.body(of: "var canCancelReverse: Bool {")
        let lines = body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #expect(lines == ["journaledPhase == .reverseUpload || isBeforeReverseMount"])
        let beforeMount = try Self.body(of: "var isBeforeReverseMount: Bool {")
        #expect(beforeMount.trimmingCharacters(in: .whitespacesAndNewlines)
            == "ReversePreMountPhase(phase: journaledPhase) != nil")
    }

    /// Un solo gesto para las cinco fases: la pantalla llama a `cancelReverse()` y el runner decide por la fase. Con
    /// dos entradas, el botón de una fase acabaría cableado al camino de la otra — «el otro control va al mismo
    /// sitio», que es como se cuelan las salidas a medias.
    @Test func cancelReverse_isASingleEntryPoint() throws {
        let view = try Self.storageView()
        #expect(Self.occurrences(of: "await controller.cancelReverse()", in: view) == 1)
        let controller = try Self.controllerSource()
        #expect(Self.occurrences(of: "await runner.cancelReverse()", in: controller) == 2,
                "el toque y el «sí» apuntado que ejecuta el resume siguiente")
    }

}
