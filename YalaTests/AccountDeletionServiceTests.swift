//
//  AccountDeletionServiceTests.swift
//  YalaTests
//
//  G5-D1b: coordinador de "Eliminar mi cuenta". Verifica el ORDEN CONGELADO de efectos (anti corpus-zombie),
//  la matriz por modo (.cloud vs solo-grupos), el skip de `groups_forget_user` con el flag OFF, y que un fallo
//  en CUALQUIER paso deja el estado local INTACTO + reintentable. Con dependencias inyectadas (mocks) — sin
//  red ni singletons.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct AccountDeletionServiceTests {

    /// Control mutable compartido por los closures mock (permite ejercitar el retry cambiando flags entre
    /// corridas).
    final class Ctrl {
        var events: [String] = []
        var forgetThrows = false
        var deleteOutcome: DeleteOutcome = .success
        var closePrivateResult = true
        /// Encargo S27i · D: la zona de iCloud se borra antes del servidor.
        var wipeICloudResult = true
        var canDelete = true
        var groupsEnabled = false
        var isCloud = true
        var hasPrivateSession = true
        var deleteMarkerThrows = false
        /// Card ypit · el cierre local de la nube cerró en caliente (sin relanzar).
        var closedInPlace = false
        /// Ticket `account-deletion-private-close-has-no-durable-intent`: la marca DURABLE. Vive en el `Ctrl`, no en el
        /// servicio, así que dos instancias del servicio sobre el mismo `Ctrl` son la app antes y después de cerrarse.
        var pendingPrivateClose = false
        /// Qué marca había cuando corrió cada efecto con nombre (para fijar que se escribe ANTES de los revokes).
        var markAtEvent: [String: Bool] = [:]
        /// La marca es de otra cuenta que la sesión viva.
        var markIsForAnotherSession = false
        /// Otro cierre del coordinador (cerrar sesión, «Empezar de cero») está en marcha.
        var anotherCloseInFlight = false
    }

    private func makeService(_ c: Ctrl) -> AccountDeletionService {
        let deps = AccountDeletionService.Dependencies(
            canDelete: { c.canDelete },
            groupsBackendEnabled: { c.groupsEnabled },
            storageModeIsCloud: { c.isCloud },
            hasPrivateSession: { c.hasPrivateSession },
            forgetGroupsUser: {
                c.events.append("forget")
                if c.forgetThrows { throw GroupsRPCError.transient(status: 500) }
            },
            teardown: { c.events.append("teardown") },
            deletePersonalAccount: { c.events.append("delete"); return c.deleteOutcome },
            revokeSIWA: { c.events.append("siwa"); c.markAtEvent["siwa"] = c.pendingPrivateClose },
            revokeGoogle: { c.events.append("google") },
            closeLocalCloud: { c.events.append("closeCloud"); return c.closedInPlace },
            wipePrivateICloud: { c.events.append("wipeICloud"); return c.wipeICloudResult },
            closeLocalPrivate: { _ in c.events.append("closePrivate"); return c.closePrivateResult },
            clearCloudBeacon: { c.events.append("clearBeacon") },
            deleteCloudKitMarker: { _ in
                c.events.append("deleteMarker")
                if c.deleteMarkerThrows { throw GroupsRPCError.transient(status: 500) }
            },
            pendingPrivateClose: { c.pendingPrivateClose },
            markPendingPrivateClose: { c.events.append("markPending"); c.pendingPrivateClose = true },
            clearPendingPrivateClose: { c.events.append("clearPending"); c.pendingPrivateClose = false },
            pendingCloseIsForAnotherLiveSession: { c.markIsForAnotherSession },
            anotherCloseInFlight: { c.anotherCloseInFlight }
        )
        return AccountDeletionService(deps: deps)
    }

    // MARK: - Orden de efectos + matriz por modo

    @Test func cloud_groupsEnabled_ordersEffects_forgetFirst() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.isCloud = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // D7: higiene post-delete (clearBeacon → deleteMarker) entre el delete y los revokes.
        #expect(c.events == [
            "forget", "teardown", "delete", "clearBeacon", "deleteMarker", "siwa", "google", "closeCloud",
        ])
        #expect(sut.phase == .awaitingRelaunch)
    }

    @Test func cloud_groupsDisabled_skipsForget() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = false; c.isCloud = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // groups_forget_user NO se llama (sin datos de grupos en el backend con el flag OFF).
        #expect(c.events == [
            "teardown", "delete", "clearBeacon", "deleteMarker", "siwa", "google", "closeCloud",
        ])
        #expect(sut.phase == .awaitingRelaunch)
    }

    @Test func groupsOnly_usesGroupsOnlyLocalClose() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.isCloud = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // Encargo S27i: con sesión privada (D) la zona de iCloud va PRIMERO, antes de tocar el servidor.
        // La marca durable va justo tras el `200`, y el cierre que arma la retira.
        #expect(c.events == [
            "wipeICloud", "forget", "teardown", "delete", "markPending", "clearBeacon", "deleteMarker", "siwa", "google",
            "closePrivate", "clearPending",
        ])
        #expect(sut.phase == .awaitingRelaunch)
        #expect(!c.pendingPrivateClose)
    }

    /// Encargo S27i: si la zona de iCloud no se puede borrar, el servidor ni se toca —la cuenta sigue viva y la sesión
    /// también— y el reintento repite el gesto entero.
    @Test func privateCell_iCloudZoneFails_stopsBeforeTheServer_andRetries() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.isCloud = false; c.wipeICloudResult = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)
        #expect(c.events == ["wipeICloud"])
        #expect(sut.phase == .failed(step: .personalWipe))

        c.wipeICloudResult = true
        await sut.deleteAccount(context: ctx)
        #expect(sut.phase == .awaitingRelaunch)
        #expect(c.events.filter { $0 == "delete" }.count == 1)
    }

    /// La nube (E) y solo grupos sin sesión privada (F) no tienen zona de iCloud propia que borrar.
    @Test(arguments: [(true, true), (false, false)])
    func noPrivateICloudZone_inTheCloudOrWithoutAPrivateSession(isCloud: Bool, hasPrivateSession: Bool) async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = isCloud; c.hasPrivateSession = hasPrivateSession
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)
        #expect(!c.events.contains("wipeICloud"))
    }

    /// Paso 9: la cuenta de un solo-grupos SIN sesión privada (F) cierra como la nube — su dispositivo no
    /// guarda nada privado que conservar. Con el cierre de solo-grupos quedaría en una shell de grupos sin
    /// sesión ni cuenta.
    @Test func groupsOnlyWithoutPrivateSession_closesLikeTheCloud() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.isCloud = false; c.hasPrivateSession = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(c.events == [
            "forget", "teardown", "delete", "clearBeacon", "deleteMarker", "siwa", "google", "closeCloud",
        ])
        #expect(!c.events.contains("closePrivate"))
        #expect(sut.phase == .awaitingRelaunch)
    }

    // MARK: - Fallos por paso (local intacto + reintentable)

    @Test func forgetFails_stopsBeforeTeardown_failedGroups() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.forgetThrows = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // NADA local tocado: ni teardown ni delete.
        #expect(c.events == ["forget"])
        #expect(sut.phase == .failed(step: .groups))
    }

    @Test func deleteFails_transient_stopsBeforeClose_failedDelete() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = false; c.deleteOutcome = .transient(detail: "500")
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // Teardown corrió (idempotente), pero ni SIWA ni cierre local.
        #expect(c.events == ["teardown", "delete"])
        #expect(sut.phase == .failed(step: .delete))
    }

    @Test func deleteFails_sessionExpired_failedDelete() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = false; c.deleteOutcome = .sessionExpired(detail: "401")
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(c.events == ["teardown", "delete"])
        #expect(sut.phase == .failed(step: .delete))
    }

    @Test func groupsOnlyClose_quiescenceFails_failedLocalClose() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.isCloud = false; c.closePrivateResult = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // El borrado server-side YA ocurrió; el cierre local no cerró la sesión → reintentable.
        #expect(c.events == [
            "wipeICloud", "forget", "teardown", "delete", "markPending", "clearBeacon", "deleteMarker", "siwa", "google",
            "closePrivate",
        ])
        #expect(sut.phase == .failed(step: .localClose))
        #expect(c.pendingPrivateClose, "el cierre no armó: la marca durable se queda")

        // Encargo S27i (review adversarial): el reintento va directo al cierre local, sin volver al servidor —la cuenta ya
        // no existe y el JWT caduca—, y también si el SDK soltó la sesión entre medias.
        c.closePrivateResult = true
        c.canDelete = false
        c.events = []
        await sut.deleteAccount(context: ctx)
        #expect(c.events == ["closePrivate", "clearPending"])
        #expect(sut.phase == .awaitingRelaunch)
    }

    // MARK: - Guards / retry

    @Test func noSession_isNoOp() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.canDelete = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(c.events.isEmpty)
        #expect(sut.phase == .idle)
    }

    @Test func retry_afterFailure_reentersAndCompletes() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.isCloud = true; c.forgetThrows = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)
        #expect(sut.phase == .failed(step: .groups))

        // El usuario reintenta y esta vez forget pasa.
        c.forgetThrows = false
        await sut.deleteAccount(context: ctx)

        #expect(sut.phase == .awaitingRelaunch)
        #expect(c.events == [
            "forget", "forget", "teardown", "delete", "clearBeacon", "deleteMarker", "siwa", "google", "closeCloud",
        ])
    }

    @Test func awaitingRelaunch_isTerminal_noReentry() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl()
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)
        #expect(sut.phase == .awaitingRelaunch)

        c.events.removeAll()
        await sut.deleteAccount(context: ctx)  // no-op en estado terminal
        #expect(c.events.isEmpty)
        #expect(sut.phase == .awaitingRelaunch)
    }

    @Test func acknowledgeFailure_resetsToIdle() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.forgetThrows = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)
        #expect(sut.phase == .failed(step: .groups))

        sut.acknowledgeFailure()
        #expect(sut.phase == .idle)
    }

    // MARK: - D7: higiene post-delete best-effort (faro/marcador)

    /// Si la limpieza del marcador LANZA, el flujo NO se rompe: el borrado se completa igual
    /// (`.awaitingRelaunch`). El faro ya se limpió (crítico para R9) y los revokes + cierre corren después.
    @Test func hygieneMarkerThrows_doesNotBreakFlow() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = false; c.isCloud = true; c.deleteMarkerThrows = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        // El fallo del marcador se traga: clearBeacon + deleteMarker (intentado) + revokes + cierre corren.
        #expect(c.events == [
            "teardown", "delete", "clearBeacon", "deleteMarker", "siwa", "google", "closeCloud",
        ])
        #expect(sut.phase == .awaitingRelaunch)
    }

    /// La higiene NUNCA corre si el borrado server-side no fue exitoso (jamás limpiar el faro/marcador de
    /// una cuenta que sigue viva).
    @Test func hygiene_notRun_whenDeleteFails() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = false; c.deleteOutcome = .transient(detail: "500")
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(!c.events.contains("clearBeacon"))
        #expect(!c.events.contains("deleteMarker"))
        #expect(sut.phase == .failed(step: .delete))
    }

    // MARK: - D7: closure REAL de deleteCloudKitMarker (guard !isEmpty = red del invariante (b))

    /// Store SIN marcador (caso solo-grupos 5b: el personal nunca migró): el `guard !markers.isEmpty`
    /// retorna ANTES de cualquier `save()` — jamás toca el mainContext compartido con el mirror `.icloud`
    /// vivo (invariante de quiescencia (b)). No lanza.
    @Test func liveDeleteMarker_emptyStore_returnsWithoutSaveOrThrow() throws {
        let ctx = try makeTestContext()
        try AccountDeletionService.Dependencies.live.deleteCloudKitMarker(ctx)
        // Sin marcadores antes y después; no hay throw (el guard corta antes del save).
        let count = try ctx.fetchCount(FetchDescriptor<CloudMigrationMarker>())
        #expect(count == 0)
    }

    /// Store CON marcador (caso `.cloud`): la closure lo borra y persiste.
    @Test func liveDeleteMarker_presentMarker_deletesIt() throws {
        let ctx = try makeTestContext()
        ctx.insert(CloudMigrationMarker(accountHash: "abc", serverSeqCut: 42))
        try ctx.save()
        #expect(try ctx.fetchCount(FetchDescriptor<CloudMigrationMarker>()) == 1)

        try AccountDeletionService.Dependencies.live.deleteCloudKitMarker(ctx)

        #expect(try ctx.fetchCount(FetchDescriptor<CloudMigrationMarker>()) == 0)
    }

    // MARK: - La app se cierra a mitad (celda D): la marca durable

    /// Ticket `account-deletion-private-close-has-no-durable-intent`. La marca se escribe con el `200` del servidor y ANTES
    /// de los revokes, que son red: un cierre de la app en esa ventana tiene que poder retomarse al relanzar.
    @Test func privateCell_marksTheDurableIntentRightAfterTheServer_beforeTheRevokes() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = false; c.hasPrivateSession = true; c.closePrivateResult = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        let delete = try #require(c.events.firstIndex(of: "delete"))
        #expect(c.events[delete + 1] == "markPending")
        #expect(c.markAtEvent["siwa"] == true)
    }

    /// La app se cerró entre el servidor y el arm (aquí: tras los revokes, sin llegar al cierre). Al relanzar —otra
    /// instancia, sin nada en memoria y sin sesión— el arranque retoma el cierre local: ni zona, ni grupos, ni servidor, ni
    /// revokes. Solo el cierre, y la marca se retira.
    @Test func appClosedHalfway_relaunchResumesOnlyTheLocalClose() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.groupsEnabled = true; c.isCloud = false; c.hasPrivateSession = true
        c.pendingPrivateClose = true  // lo que dejó el `200` del proceso anterior
        c.canDelete = false           // el servidor se llevó `auth.users`: la sesión ya no se renueva
        let relaunched = makeService(c)

        await relaunched.resumePendingPrivateClose(context: ctx)

        #expect(c.events == ["closePrivate", "clearPending"])
        #expect(relaunched.phase == .awaitingRelaunch)
        #expect(!c.pendingPrivateClose)
    }

    /// El cierre retomado va por la D aunque, tras relanzar, el eje leído en vivo dijera otra cosa: la celda se decidió con
    /// la cuenta viva. Por el cierre de la nube, lo personal de este teléfono no se borraría.
    @Test func resumedClose_staysOnThePrivateCell_evenIfTheLiveAxisChanged() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = false; c.hasPrivateSession = false; c.canDelete = false
        c.pendingPrivateClose = true
        let relaunched = makeService(c)

        await relaunched.resumePendingPrivateClose(context: ctx)

        #expect(c.events == ["closePrivate", "clearPending"])
        #expect(!c.events.contains("closeCloud"))
    }

    /// El proceso entero, con dos instancias: el primero se queda sin quiescencia (`.failed(.localClose)`) y la app se
    /// cierra; el segundo arranca, vuelve a fallar y la marca se queda; a la vuelta a primer plano el cierre llega.
    @Test func resumedCloseThatFailsAgain_keepsTheMark_andTheNextAttemptCompletes() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = false; c.hasPrivateSession = true; c.closePrivateResult = false
        let first = makeService(c)
        await first.deleteAccount(context: ctx)
        #expect(first.phase == .failed(step: .localClose))
        #expect(c.pendingPrivateClose)

        // Relanzamiento: sin sesión y con el cierre que sigue sin quiescencia.
        c.canDelete = false
        c.events = []
        let relaunched = makeService(c)
        await relaunched.resumePendingPrivateClose(context: ctx)
        #expect(c.events == ["closePrivate"])
        #expect(relaunched.phase == .failed(step: .localClose))
        #expect(c.pendingPrivateClose)

        // Vuelta a primer plano con el import ya asentado, pasado el espaciado entre intentos automáticos.
        c.closePrivateResult = true
        c.events = []
        await relaunched.resumePendingPrivateClose(
            context: ctx, now: .now.addingTimeInterval(AccountDeletionService.resumeRetryInterval + 1))
        #expect(c.events == ["closePrivate", "clearPending"])
        #expect(relaunched.phase == .awaitingRelaunch)
        #expect(!c.pendingPrivateClose)
    }

    /// Sin marca, retomar no hace nada: ni con sesión (no lanza un borrado que nadie pidió) ni sin ella.
    @Test(arguments: [true, false])
    func resume_withoutTheMark_isNoOp(hasSession: Bool) async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = false; c.hasPrivateSession = true; c.canDelete = hasSession
        let sut = makeService(c)

        await sut.resumePendingPrivateClose(context: ctx)

        #expect(c.events.isEmpty)
        #expect(sut.phase == .idle)
    }

    /// Con un borrado ya terminado en este proceso, retomar no reentra (el arranque y la vuelta a primer plano pueden
    /// llegar a la vez).
    @Test func resume_afterTheCloseArmed_isNoOp() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = false; c.hasPrivateSession = true
        c.pendingPrivateClose = true; c.canDelete = false
        let sut = makeService(c)
        await sut.resumePendingPrivateClose(context: ctx)
        #expect(sut.phase == .awaitingRelaunch)

        c.pendingPrivateClose = true  // un kill entre el arm y el retiro: la marca sigue en disco
        c.events = []
        // Pasado el espaciado, para que lo que frene sea la fase terminal y no el plazo.
        await sut.resumePendingPrivateClose(
            context: ctx, now: .now.addingTimeInterval(AccountDeletionService.resumeRetryInterval + 1))
        #expect(c.events.isEmpty)
    }

    /// Review adversarial: con otro cierre del coordinador en marcha (la persona tocó «Cerrar sesión»), el cierre retomado
    /// no se pone encima. Cuando ese termina, la vuelta siguiente lo retoma.
    @Test func resume_withAnotherCloseInFlight_waits() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = false; c.hasPrivateSession = true; c.canDelete = false
        c.pendingPrivateClose = true; c.anotherCloseInFlight = true
        let sut = makeService(c)

        await sut.resumePendingPrivateClose(context: ctx)
        #expect(c.events.isEmpty)
        #expect(sut.phase == .idle)

        c.anotherCloseInFlight = false
        await sut.resumePendingPrivateClose(context: ctx)
        #expect(c.events == ["closePrivate", "clearPending"])
    }

    /// Review adversarial: la persona entró con OTRA cuenta tras perder la sesión de la borrada. El cierre retomado no se la
    /// lleva, y borrar esa cuenta va entero (servidor incluido) en vez de creerse ya borrada por la marca vieja.
    @Test func markOfAnotherAccount_neitherResumes_norSkipsTheServerOfTheLiveOne() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = false; c.hasPrivateSession = true; c.canDelete = true
        c.pendingPrivateClose = true; c.markIsForAnotherSession = true
        let sut = makeService(c)

        await sut.resumePendingPrivateClose(context: ctx)
        #expect(c.events.isEmpty)

        await sut.deleteAccount(context: ctx)
        #expect(c.events.contains("wipeICloud"))
        #expect(c.events.contains("delete"))
        #expect(sut.phase == .awaitingRelaunch)
    }

    /// Review adversarial: cada intento automático tapa la app con la capa de borrado hasta que la quiescencia vence, así
    /// que dos intentos automáticos se espacian `resumeRetryInterval`. El primero del proceso (el arranque) no espera.
    @Test func automaticResumes_areSpaced_butTheFirstOneIsNot() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = false; c.hasPrivateSession = true; c.canDelete = false
        c.pendingPrivateClose = true; c.closePrivateResult = false
        let sut = makeService(c)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)

        await sut.resumePendingPrivateClose(context: ctx, now: t0)
        #expect(c.events == ["closePrivate"])

        await sut.resumePendingPrivateClose(context: ctx, now: t0.addingTimeInterval(AccountDeletionService.resumeRetryInterval - 1))
        #expect(c.events == ["closePrivate"], "una vuelta a primer plano antes del plazo no repite el intento")

        c.closePrivateResult = true
        await sut.resumePendingPrivateClose(context: ctx, now: t0.addingTimeInterval(AccountDeletionService.resumeRetryInterval))
        #expect(c.events == ["closePrivate", "closePrivate", "clearPending"])
        #expect(sut.phase == .awaitingRelaunch)
    }

    /// Solo la celda D escribe la marca: la nube (E) y solo grupos sin sesión privada (F) cierran sin ella.
    @Test(arguments: [(true, true), (false, false)])
    func otherCells_neverWriteTheMark(isCloud: Bool, hasPrivateSession: Bool) async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = isCloud; c.hasPrivateSession = hasPrivateSession
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(!c.events.contains("markPending"))
        #expect(!c.pendingPrivateClose)
    }

    /// Si el servidor no contesta `200`, la cuenta sigue viva: nada que retomar.
    @Test func privateCell_serverFails_writesNoMark() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = false; c.hasPrivateSession = true; c.deleteOutcome = .transient(detail: "500")
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(!c.pendingPrivateClose)
        #expect(sut.phase == .failed(step: .delete))
    }

    // MARK: - Card ypit · «Borrar mi cuenta» sin reabrir

    /// Cerrado en caliente, la app ya está en el Welcome: la fase vuelve a reposo. Con `.awaitingRelaunch` el `onAppear` de
    /// Perfil cerraría la hoja al abrirla y un borrado nuevo no arrancaría (`deleteAccount` sale con esa fase).
    @Test(arguments: [true, false])
    func closedInPlace_returnsToIdle_otherwiseWaitsForTheRelaunch(isCloud: Bool) async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = isCloud; c.hasPrivateSession = false; c.closedInPlace = true
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(c.events.last == "closeCloud")
        #expect(sut.phase == .idle)
    }

    @Test func notClosedInPlace_waitsForTheRelaunch() async throws {
        let ctx = try makeTestContext()
        let c = Ctrl(); c.isCloud = true; c.closedInPlace = false
        let sut = makeService(c)

        await sut.deleteAccount(context: ctx)

        #expect(sut.phase == .awaitingRelaunch)
    }
}

@Suite
struct AccountDeletionRowLogicTests {

    /// Paso 9: ya no depende del modo de onboarding — quien solo usa Grupos y tiene sesión TIENE cuenta,
    /// y la App Store (5.1.1 v) exige poder borrarla.
    @Test func shows_withLiveSession() {
        #expect(AccountDeletionRowLogic.shouldShow(hasSession: true))
    }

    @Test func hidden_withoutSession() {
        #expect(!AccountDeletionRowLogic.shouldShow(hasSession: false))
    }
}
