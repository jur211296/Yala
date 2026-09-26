//
//  SyncSignInBannerLogicTests.swift
//  YalaTests / CloudSync
//
//  La puerta para volver a entrar en la nube (ticket `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`,
//  2026-09-25). Tres preguntas del ticket, cada una con su prueba:
//   (a) el aviso del cierre NOMBRA la puerta — en los 16 idiomas, con el título y el botón que la pantalla pinta;
//   (b) la puerta SALE con solo cambios de grupos — con un store real de tres configuraciones;
//   (c) no se vuelve ni al «revisa tu conexión» ni a un botón que no entra — la sesión que el servidor rechaza firma, y
//       otra cuenta no reanuda nada (en las dos direcciones).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("La puerta de la nube con la sesión caducada", .serialized)
@MainActor
struct SyncSignInBannerLogicTests {

    // MARK: - (b) La puerta sale con solo cambios de grupos

    @Test("MUTACIÓN: con solo cambios de grupos y el motor parado hasta firmar, sale «Iniciar sesión» con su cifra")
    func onlyGroupChanges_openTheDoor() {
        let banner = SyncSignInBannerLogic.decide(isCloud: true, engineWaitsForSignIn: true,
                                                  personalLive: 0, groupsLive: 2)
        #expect(banner == .init(needsSignIn: true, pendingCount: 2))
    }

    @Test("La cifra suma las dos colas, y sin nada pendiente no hay nada que subir")
    func theCountAddsBothQueues() {
        #expect(SyncSignInBannerLogic.decide(isCloud: true, engineWaitsForSignIn: true,
                                             personalLive: 3, groupsLive: 2) == .init(needsSignIn: true, pendingCount: 5))
        #expect(SyncSignInBannerLogic.decide(isCloud: true, engineWaitsForSignIn: true,
                                             personalLive: 3, groupsLive: 0) == .init(needsSignIn: true, pendingCount: 3))
        #expect(SyncSignInBannerLogic.decide(isCloud: true, engineWaitsForSignIn: true,
                                             personalLive: 0, groupsLive: 0) == .init(needsSignIn: false, pendingCount: 0))
    }

    @Test("MUTACIÓN: una cola que no se deja contar ofrece firmar sin cifra, cualquiera de las dos")
    func anUncountableQueueOffersSignInWithoutANumber() {
        let uncounted = SyncSignInBannerLogic.Banner(needsSignIn: true, pendingCount: nil)
        #expect(SyncSignInBannerLogic.decide(isCloud: true, engineWaitsForSignIn: true,
                                             personalLive: nil, groupsLive: 0) == uncounted)
        #expect(SyncSignInBannerLogic.decide(isCloud: true, engineWaitsForSignIn: true,
                                             personalLive: 0, groupsLive: nil) == uncounted)
    }

    /// El caso PRINCIPAL del ticket, que la primera versión no cubría (lo cazaron tres lentes de la review): el SDK borró la
    /// sesión en un proceso anterior y el motor arrancó sin ella, en `.idleSignedOut`. Con sesión, ese estado es el teardown
    /// de un cierre en curso y no pide firmar.
    @Test("MUTACIÓN: el motor espera a firmar parado hasta firmar, o arrancado SIN sesión tras relanzar; nada más")
    func whichEngineStatesWaitForASignIn() {
        #expect(SyncSignInBannerLogic.engineWaitsForSignIn(state: .stoppedUntilSignIn, hasSession: true))
        #expect(SyncSignInBannerLogic.engineWaitsForSignIn(state: .stoppedUntilSignIn, hasSession: false))
        #expect(SyncSignInBannerLogic.engineWaitsForSignIn(state: .idleSignedOut, hasSession: false))
        #expect(!SyncSignInBannerLogic.engineWaitsForSignIn(state: .idleSignedOut, hasSession: true))
        for state in [CloudSyncRuntime.RuntimeState.idle, .running, .stoppedUntilRelaunch] {
            for hasSession in [true, false] {
                #expect(!SyncSignInBannerLogic.engineWaitsForSignIn(state: state, hasSession: hasSession), "\(state)")
            }
        }
        #expect(!SyncSignInBannerLogic.engineWaitsForSignIn(state: nil, hasSession: false))
    }

    @Test("Fuera de la nube, o con el motor sin parar, no sale: no hay sesión que diga que no sirve")
    func outsideTheStoppedCloudEngine_thereIsNoDoor() {
        let none = SyncSignInBannerLogic.Banner(needsSignIn: false, pendingCount: 0)
        #expect(SyncSignInBannerLogic.decide(isCloud: false, engineWaitsForSignIn: true,
                                             personalLive: 1, groupsLive: 1) == none)
        #expect(SyncSignInBannerLogic.decide(isCloud: true, engineWaitsForSignIn: false,
                                             personalLive: 1, groupsLive: 1) == none)
    }

    // MARK: - (b) con un store real

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "SSB-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "SSB-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "SSB-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func groupRow(rejected: String? = nil) -> GroupSyncOutbox {
        GroupSyncOutbox(syncID: UUID(), groupID: "g1", entityType: "SplitExpense", op: .upsert,
                        hlc: "2023-11-14T22:13:20.000Z-0001-0123456789abcdef", fieldsJSON: "{}", author: "",
                        rejectedReason: rejected)
    }

    /// De punta a punta por el cuerpo que pinta la tarjeta (`CloudMigrationController.syncSignInBanner`, el que llama
    /// `refreshSyncBanner`): con un store real, cero filas personales y dos de grupos vivas, sale «Iniciar sesión para subir
    /// 2 cambios». La fila en dead-letter no cuenta: no es lo que firmar sube.
    @Test("MUTACIÓN: con un store real, solo cambios de grupos encienden la tarjeta, y los rechazados no cuentan")
    func realStore_onlyGroupRows_lightTheCard() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SSB-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: dir) } catch { print("SSB cleanup: \(error)") }
        }
        let context = try makeContext(dir)
        context.insert(groupRow())
        context.insert(groupRow())
        context.insert(groupRow(rejected: "poison"))
        try context.save()
        // Control del escenario: la cola personal está vacía de verdad.
        #expect(try context.fetchCount(FetchDescriptor<SyncOutbox>()) == 0)

        let banner = CloudMigrationController.syncSignInBanner(context: context, isCloud: true,
                                                               runtimeState: .stoppedUntilSignIn, hasSession: true)
        #expect(banner == .init(needsSignIn: true, pendingCount: 2))
        // Tras relanzar con la sesión borrada, la misma puerta.
        #expect(CloudMigrationController.syncSignInBanner(context: context, isCloud: true, runtimeState: .idleSignedOut,
                                                          hasSession: false) == .init(needsSignIn: true, pendingCount: 2))
        // Y con el motor corriendo no sale: la tarjeta no inventa una sesión caducada.
        #expect(CloudMigrationController.syncSignInBanner(context: context, isCloud: true, runtimeState: .running,
                                                          hasSession: true) == .init(needsSignIn: false, pendingCount: 0))
    }

    // MARK: - (c) Al pulsar

    @Test("MUTACIÓN: con la sesión guardada, solo un ciclo que dice «sesión caducada» abre el inicio de sesión")
    func onlyARejectedCycleOpensTheSignIn() {
        #expect(SyncSignInBannerLogic.needsSignIn(afterProbe: .sessionExpired))
        for outcome in [SyncCadencePolicy.CadenceOutcome.completed, .coalesced, .transient, .accountUnavailable] {
            #expect(!SyncSignInBannerLogic.needsSignIn(afterProbe: outcome), "\(outcome)")
        }
    }

    @Test("MUTACIÓN: la firma se ata a la cuenta del motor, en las dos direcciones")
    func theSignInIsTiedToTheEngineOwner() {
        // La misma cuenta: se reanuda y suben las dos colas (el sello no pinta con dueño en memoria).
        #expect(SyncSignInBannerLogic.afterSignIn(ownerUserID: "a", signedInUserID: "a", signedInIsClaimed: false) == .resume)
        // Otra cuenta, en un sentido y en el otro: no se reanuda nada, aunque esa cuenta tenga sello en este teléfono.
        #expect(SyncSignInBannerLogic.afterSignIn(ownerUserID: "a", signedInUserID: "b", signedInIsClaimed: true)
                == .rejectOtherAccount)
        #expect(SyncSignInBannerLogic.afterSignIn(ownerUserID: "b", signedInUserID: "a", signedInIsClaimed: true)
                == .rejectOtherAccount)
        // Sin sesión tras una firma que no lanzó: nada que reanudar.
        #expect(SyncSignInBannerLogic.afterSignIn(ownerUserID: "a", signedInUserID: nil, signedInIsClaimed: true)
                == .rejectOtherAccount)
    }

    /// Tras relanzar sin sesión el motor no tiene dueño en memoria: el ancla es el sello del claim, el gate de `start()`.
    @Test("MUTACIÓN: sin dueño en memoria, solo una cuenta con sello de este teléfono reanuda")
    func withoutAnOwnerTheClaimStampDecides() {
        #expect(SyncSignInBannerLogic.afterSignIn(ownerUserID: nil, signedInUserID: "a", signedInIsClaimed: true) == .resume)
        #expect(SyncSignInBannerLogic.afterSignIn(ownerUserID: nil, signedInUserID: "b", signedInIsClaimed: false)
                == .rejectOtherAccount)
        #expect(SyncSignInBannerLogic.afterSignIn(ownerUserID: nil, signedInUserID: nil, signedInIsClaimed: false)
                == .rejectOtherAccount)
    }

    /// El proveedor de la cuenta del teléfono lo da el faro cuando su hash es el del dueño; `storedProvider()` lo reescribe
    /// cualquier firma, también la de otra cuenta que entró por «Nuevo grupo» (review del 2026-09-25).
    @Test("MUTACIÓN: la puerta firma con el proveedor del faro de la cuenta dueña, no con el último que firmó")
    func theDoorSignsWithTheOwnersProvider() {
        let ownerHash = CloudBeacon.hash("a")
        // Otra cuenta (Google) entró y reescribió el proveedor guardado; el faro de la dueña dice Apple.
        #expect(SyncSignInBannerLogic.provider(stored: "google", beaconProvider: "apple", beaconHash: ownerHash,
                                               ownerUserID: "a") == .apple)
        #expect(SyncSignInBannerLogic.provider(stored: "apple", beaconProvider: "google", beaconHash: ownerHash,
                                               ownerUserID: "a") == .google)
        // El faro de otra cuenta, o sin dueño con el que compararlo: el guardado.
        #expect(SyncSignInBannerLogic.provider(stored: "google", beaconProvider: "apple",
                                               beaconHash: CloudBeacon.hash("b"), ownerUserID: "a") == .google)
        #expect(SyncSignInBannerLogic.provider(stored: "google", beaconProvider: "apple", beaconHash: ownerHash,
                                               ownerUserID: nil) == .google)
        // Un proveedor ilegible en el faro no gana; sin nada, Apple (el residual del claim).
        #expect(SyncSignInBannerLogic.provider(stored: "google", beaconProvider: "x", beaconHash: ownerHash,
                                               ownerUserID: "a") == .google)
        #expect(SyncSignInBannerLogic.provider(stored: nil, beaconProvider: nil, beaconHash: nil, ownerUserID: nil) == .apple)
    }

    // MARK: - (a) El aviso nombra la puerta, en los 16 idiomas

    private static let resources: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Yala/Resources")

    private static func strings(_ locale: String) throws -> [String: String] {
        let url = resources.appendingPathComponent("\(locale).lproj/Localizable.strings")
        let dict = try #require(NSDictionary(contentsOf: url) as? [String: String], "no se pudo leer \(locale)")
        return dict
    }

    private static let locales = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl",
                                  "pt", "pt-BR", "pt-PT", "zh-Hans"]

    /// El aviso cita la pantalla con el MISMO título que la pantalla pinta y el botón con el MISMO texto que el botón. Si
    /// alguien renombra «Dónde viven tus datos» o «Iniciar sesión» en un idioma, el aviso de ese idioma mandaría a buscar algo
    /// que no existe, y aquí se pone rojo.
    @Test("MUTACIÓN: en los 16 idiomas el aviso cita el título de la pantalla y el texto del botón tal como se pintan")
    func theNoticeNamesTheScreenAndTheButton_inEveryLocale() throws {
        let found = try FileManager.default.contentsOfDirectory(atPath: Self.resources.path)
            .filter { $0.hasSuffix(".lproj") }.map { String($0.dropLast(6)) }.sorted()
        #expect(found == Self.locales.sorted(), "control: el catálogo tiene los 16 idiomas que se miden aquí")
        for locale in Self.locales {
            let table = try Self.strings(locale)
            let notice = try #require(table["settings.signOutCloudSessionExpired"], "\(locale): falta el aviso")
            let screen = try #require(table["storage.title"], "\(locale)")
            let button = try #require(table["storage.sync.signInButton"], "\(locale)")
            #expect(notice.contains(screen), "\(locale): el aviso no cita «\(screen)»")
            #expect(notice.contains(button), "\(locale): el aviso no cita «\(button)»")
            #expect(notice != table["settings.signOutBlockedMessage"], "\(locale): volvió el «revisa tu conexión»")
            #expect(table["storage.errors.syncSignInOtherAccount"] != nil, "\(locale): falta el aviso de otra cuenta")
        }
    }

    /// Voseo en es-AR (`BRAND-VOICE` §9.4): los imperativos del aviso son los del vos.
    @Test("es-AR habla de vos")
    func esAR_usesVoseo() throws {
        let table = try Self.strings("es-AR")
        let notice = try #require(table["settings.signOutCloudSessionExpired"])
        for verb in ["abrí", "tocá", "volvé"] { #expect(notice.contains(verb), "falta «\(verb)»") }
        for verb in ["abre ", "toca ", "vuelve "] { #expect(!notice.contains(verb), "sobra «\(verb)»") }
        let other = try #require(table["storage.errors.syncSignInOtherAccount"])
        #expect(other.contains("Volvé") && other.contains("usás"))
    }

    /// La cadena del cierre en la nube de punta a punta: una sesión caducada en cualquiera de las dos colas acaba en el aviso
    /// que nombra la puerta, y no en el genérico ni en el «vuelve a iniciar sesión» sin sitio.
    @Test("MUTACIÓN: la sesión caducada de cualquiera de los dos pasos del cierre en la nube acaba en el aviso con puerta")
    func bothCloudStepsEndInTheNoticeWithADoor() {
        let classified = CloudSignOutFlowLogic.classify(.sessionExpired, channelKilled: false,
                                                        attestUnavailable: false, uploadFailed: false)
        for shown in [CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason(classified),
                      CloudSignOutFlowLogic.personalPushAllShownReason(classified)] {
            #expect(shown == .cloudSessionExpired)
            let message = SignOutBlockedCopy.message(for: shown)
            #expect(message == L10n.Settings.signOutCloudSessionExpired)
            #expect(message != L10n.Settings.signOutBlockedMessage)
            #expect(message != L10n.Groups.Errors.sessionExpired)
        }
        // Las celdas PRIVADAS del cierre no pasan por estas traducciones y conservan su texto: su puerta es otra.
        #expect(SignOutBlockedCopy.message(for: .sessionExpired) == L10n.Groups.Errors.sessionExpired)
    }

    // MARK: - El cableado, leído del fuente (el controller y el coordinador del cierre no se construyen en tests)

    private static let repo: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func source(_ relative: String) throws -> String {
        try String(contentsOf: repo.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Cuerpo entre la llave de `marker` y su cierre, sin comentarios y con los espacios aplastados a uno.
    private static func squashedBody(of marker: String, in relative: String) throws -> String {
        let text = try source(relative)
        let start = try #require(text.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(text[start.upperBound...])
        var depth = 1, i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        let code = String(chars[0..<min(i, chars.count)]).split(separator: "\n").map { line -> String in
            var c = String(line)
            if let comment = c.range(of: "//") { c = String(c[..<comment.lowerBound]) }
            return c
        }.joined(separator: " ")
        return code.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
    }

    private static func squash(_ text: String) -> String {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).joined(separator: " ")
    }

    /// Los DOS pasos del cierre en la nube dejan la puerta encendida ANTES de la fase (que es lo que enciende el aviso), y con
    /// el motivo ya traducido: el que decide si se para el motor es el que la persona va a leer.
    @Test("MUTACIÓN: los dos pasos del cierre en la nube dejan la puerta encendida antes del aviso")
    func bothCloudStepsLeaveTheDoorOpenBeforeTheNotice() throws {
        let body = try Self.squashedBody(of: "private func performCloudSecureSignOut(context: ModelContext) async {",
                                         in: "Yala/Services/CloudSync/CloudSessionSignOut.swift")
        #expect(body.contains(Self.squash("""
            let shown = CloudSignOutFlowLogic.personalPushAllShownReason(reason)
            Self.leaveSignInDoorOpen(ifShown: shown, controller: controller)
            phase = .blocked(pendingCount: pending, reason: shown)
            """)), "paso 1")
        #expect(body.contains(Self.squash("""
            Self.leaveSignInDoorOpen(ifShown: shown, controller: controller)
            phase = .blocked(pendingCount: pending, reason: shown)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
            CloudSyncBreadcrumb.signOutGroupsBlocked(reason: shown.breadcrumbSlug)
            """)), "paso 2")
        let door = try Self.squashedBody(of: "controller: CloudMigrationController) {",
                                         in: "Yala/Services/CloudSync/CloudSessionSignOut.swift")
        #expect(door == Self.squash("""
            guard shown == .cloudSessionExpired else { return }
            CloudSyncRuntime.shared?.stopUntilSignIn()
            controller.refresh()
            """))
    }

    /// La puerta: con la sesión guardada prueba con un ciclo; la firma se ata a la cuenta del motor, y con otra cuenta cierra
    /// esa sesión, repone el proveedor de la del teléfono y NO reanuda.
    @Test("MUTACIÓN: la puerta prueba antes de firmar y, con otra cuenta, cierra esa sesión sin reanudar nada")
    func theDoorProbesAndRejectsAnotherAccount() throws {
        let body = try Self.squashedBody(of: "func signInToResumeSync() async {",
                                         in: "Yala/Services/CloudSync/CloudMigrationController.swift")
        #expect(body.contains(Self.squash("""
            if let runtime, CloudSyncRuntime.canRunDomain() {
            let outcome = await runtime.syncCycle(context: context)
            if !SyncSignInBannerLogic.needsSignIn(afterProbe: outcome) {
            runtime.handleBecameActive()
            refresh()
            return
            }
            """)))
        #expect(body.contains(Self.squash("""
            let beacon = CloudBeacon()
            let provider = SyncSignInBannerLogic.provider(
            stored: CloudAuthService.shared.storedProvider(), beaconProvider: beacon.linkedProvider,
            beaconHash: beacon.accountHash, ownerUserID: runtime?.ownerUserID)
            do {
            try await CloudAuthService.shared.signIn(with: provider)
            let signedIn = CloudAuthService.shared.currentUserID
            switch SyncSignInBannerLogic.afterSignIn(
            ownerUserID: runtime?.ownerUserID, signedInUserID: signedIn,
            signedInIsClaimed: signedIn.map { CloudClaimActionStore.shared.action(forUserID: $0) != nil } ?? false) {
            case .resume:
            if runtime?.state == .stoppedUntilSignIn {
            runtime?.handleBecameActive()
            } else {
            startRuntimeIfStable()
            }
            case .rejectOtherAccount:
            CloudSyncBreadcrumb.syncSignInAccountMismatch()
            _ = await closeSessionIfOpened(true)
            CloudAuthService.shared.restoreStoredProvider(provider)
            lastError = L10n.Storage.Errors.syncSignInOtherAccount
            }
            """)))
        let refresher = try Self.squashedBody(of: "private func refreshSyncBanner() {",
                                              in: "Yala/Services/CloudSync/CloudMigrationController.swift")
        #expect(refresher == Self.squash("""
            let banner = Self.syncSignInBanner(context: context, isCloud: CloudSyncFlags.storageMode == .cloud,
            runtimeState: CloudSyncRuntime.shared?.state,
            hasSession: CloudAuthService.shared.hasSession)
            syncNeedsSignIn = banner.needsSignIn
            pendingUploadCount = banner.pendingCount
            """))
        // El atajo viejo —«hay sesión y hay token ⇒ despierta»— solo sobrevive con el candado del dominio cerrado.
        #expect(Self.squash(body).components(separatedBy: "await CloudAuthService.shared.accessToken() != nil").count == 2)
    }
}
