//
//  WipeDataKeepsAccountWiringTests.swift
//  YalaTests
//
//  Encargo S27i (decisión de Jürgen, 2026-10-29): «Vaciar datos» borra el contenido y deja a la persona en el Panel vacío,
//  con su sesión, su cuenta, sus grupos y sus ajustes; «Eliminar cuenta» lo borra todo —también, con iCloud privado, lo
//  personal de este dispositivo y de su iCloud— y termina en el Welcome.
//
//  La decisión pura vive en `DestructiveScopeLogicTests` y lo que borra cada camino en `RemoteWipeCutTests` y
//  `UsageModeFreshStartWipeTests`. Aquí va el CABLEADO que ningún test de comportamiento ve: qué le pasa cada pantalla al
//  borrado, en qué orden escribe la señal las dos marcas del iCloud KV y en qué orden borra el cierre de la cuenta.
//

import Foundation
import Testing
@testable import Yala

@MainActor
struct WipeDataKeepsAccountWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de una función: desde su firma hasta la siguiente declaración del mismo nivel.
    private static func body(of signature: String, in src: String) -> String? {
        guard let start = src.range(of: signature) else { return nil }
        let rest = src[start.upperBound...]
        let ends = ["\n    func ", "\n    private func ", "\n    private static func ", "\n    static func ",
                    "\n    @MainActor\n"]
            .compactMap { rest.range(of: $0)?.lowerBound }
        guard let end = ends.min() else { return String(rest) }
        return String(rest[..<end])
    }

    /// Las posiciones de cada marca, en el orden en que deben aparecer. `nil` si falta alguna.
    private static func offsets(_ marks: [String], in text: String) -> [String.Index]? {
        var result: [String.Index] = []
        for mark in marks {
            guard let r = text.range(of: mark) else { return nil }
            result.append(r.lowerBound)
        }
        return result
    }

    // MARK: - «Vaciar datos» en el origen

    /// La pantalla pasa al borrado lo que decide el aterrizaje, y en el Panel: no resetea el tema, reprograma los
    /// recordatorios que se quedan y arma el aviso. Si `keepsPersonSettings` dejara de viajar, el Panel quedaría con la
    /// bienvenida bajada y sin categorías; si el aviso no se armara, la persona no sabría por dónde seguir.
    @Test func wipeScreen_passesTheLandingToTheWipe_andArmsTheToast() throws {
        let src = try Self.source("Yala/App/Views/Settings/UserDataResetView.swift")
        let handler = try #require(Self.body(of: "private func handleWipeAllData()", in: src))
        let marks = [
            "let keepsPersonSettings = DestructiveScopeLogic.wipeKeepsPersonSettings(landing)",
            "keepsPersonSettings: keepsPersonSettings",
            "applyWipeLanding(landing)",
            "if keepsPersonSettings {",
            "DataWipeService.rescheduleSurvivingReminders(in: modelContext)",
            "themeManager.resetToDefaults()",
            // El aviso se arma pegado a la bajada que lo enseña, solo en el Panel y solo si la capa sigue puesta.
            "sessionState.wipeLandingToastPending = keepsPersonSettings && !sessionState.isGroupsFocusedShell",
            "&& sessionState.isWipingData",
            "sessionState.isWipingData = false",
        ]
        let pos = try #require(Self.offsets(marks, in: handler), "Falta una pieza del vaciado que se queda en el Panel")
        #expect(pos == pos.sorted(), "El orden decisión → borrado → aterrizaje → avisos/tema → bajar la capa se rompió")

        let landing = try #require(Self.body(of: "private func applyWipeLanding(", in: src))
        let panel = try #require(landing.range(of: "case .panel:"))
        let shell = try #require(landing.range(of: "case .groupsShell:"))
        let panelBranch = landing[panel.upperBound..<shell.lowerBound]
        #expect(panelBranch.contains("selectMainTab(.panel)"), "el vaciado ya no deja las ventanas en el Panel")
        #expect(!panelBranch.contains("hasCompletedOnboarding"), "el Panel toca la bienvenida: no hay bienvenida que tocar")
    }

    /// El aviso sale cuando BAJA la capa de borrado, y una sola vez: lo consume quien lo enseña.
    @Test func shell_showsTheToastWhenTheWipeLayerDrops_once() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        #expect(src.contains(".onChange(of: SessionState.shared.isWipingData) { _, _ in wipingDataChanged() }"))
        let handler = try #require(Self.body(of: "private func wipingDataChanged()", in: src))
        let marks = [
            "updateContentViewReadiness()",
            "guard !session.isWipingData, session.wipeLandingToastPending else { return }",
            "session.wipeLandingToastPending = false",
            "showPositiveToast(L10n.Settings.wipeLandingToast",
        ]
        let pos = try #require(Self.offsets(marks, in: handler), "Falta una pieza del aviso tras vaciar")
        #expect(pos == pos.sorted())
    }

    // MARK: - La señal a los otros dispositivos

    /// La marca de que el parque sigue va ANTES que la señal y estrictamente por detrás en el tiempo
    /// (`onboardingAlreadyDone` es `remoteOnboarding > remoteWipe`). Al revés, o con la misma hora, el otro dispositivo
    /// leería «empieza de cero» y se iría al onboarding con sus ajustes reseteados.
    @Test func keepingSignal_writesTheFleetMarkFirst_andLater() throws {
        let src = try Self.source("Yala/App/Services/PreferenceSyncService.swift")
        let signal = try #require(Self.body(of: "func signalWipeKeepingSetup(at date: Date)", in: src))
        let marks = [
            "let onboarding = date.timeIntervalSince1970 + 0.001",
            "iKV.setDouble(onboarding, forKey: WipeKey.remoteOnboarding)",
            "local.set(onboarding, forKey: WipeKey.localOnboarding)",
            "signalWipeInitiated(at: date)",
        ]
        let pos = try #require(Self.offsets(marks, in: signal), "Falta una pieza de la señal que conserva los ajustes")
        #expect(pos == pos.sorted(), "la marca del parque tiene que ir antes que la señal")

        // Y el receptor la lee como siempre: estrictamente mayor.
        #expect(src.contains("let onboardingAlreadyDone = remoteOnboarding > remoteWipe"))
    }

    /// El receptor con el parque en marcha conserva el tema (el reset del tema va solo sin la marca) y dice que se vació
    /// desde otro dispositivo, no «Datos restaurados».
    @Test func receiver_keepsTheTheme_andSaysItWasCleared() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let receiver = try #require(Self.body(of: "private func performLocalWipeForRemoteSync(", in: src))
        #expect(receiver.contains("if !skipOnboarding { themeManager.resetToDefaults() }"))
        #expect(receiver.contains("showPositiveToast(L10n.iCloud.remoteWipeKeptSetup"))
        #expect(!src.contains("remoteRestoreCompleted"))
    }

    // MARK: - «Eliminar cuenta» con iCloud privado

    /// El cierre de la cuenta con sesión privada borra en este orden: quiescencia → grupos → zona de iCloud → filas →
    /// sesión → arm. La zona va antes que las filas (con la zona borrada, lo que el espejo exporta son borrados) y un
    /// fallo de la zona para ANTES de tocar nada del teléfono.
    @Test func privateAccountDeletion_wipesICloudThenRowsThenArms() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        let close = try #require(Self.body(of: "func closeLocalAfterAccountDeletionPrivate(", in: src))
        let marks = [
            "GroupsSyncClient.shared.teardownForSignOut()",
            "session.isWipingData = true",
            "guard await Self.awaitPersonalQuiescenceForGroupsSignOut() else {",
            "Self.purgeGroupsSyncState(context: context)",
            "GroupsConsentState.clear()",
            "DestructiveScopeLogic.wipeSignalsAppleIDDevices(",
            // Sin el paréntesis pegado: con él, `SharedStateIsolationTests` leería este fichero como uno que EJECUTA el wipe.
            "try DataWipeService.wipeAllUserData" + "(in: context, broadcastSignal: signalsOtherDevices,",
            "Self.retireIfSessionSurvived(await CloudAuthService.shared.signOut()",
            "StorageModePersistence.armSignOutWipe()",
            "clearLocalSurfacesForArmedWipe()",
            "phase = .awaitingRelaunch",
            "return true",
        ]
        let pos = try #require(Self.offsets(marks, in: close), "Falta una pieza del borrado de la cuenta con iCloud privado")
        #expect(pos == pos.sorted(), "El orden capa → quiescencia → grupos → filas → sesión → arm se rompió")
        #expect(!close.contains("armGroupsOnlyWipe()"), "volvió el borrado que conservaba lo personal")
        // La zona se borra ANTES del servidor (el servicio) y, aquí, solo una segunda pasada DESPUÉS de las filas: el espejo
        // pudo repoblarla en los segundos de red, y sin filas solo puede subir borrados.
        let rows = try #require(close.range(of: "try DataWipeService.wipeAllUserData"))
        let secondPass = try #require(close.range(of: "if let failure = await ICloudPersonalCorpusProbe.wipe(),"),
                                      "falta la segunda pasada de la zona tras borrar las filas")
        #expect(rows.lowerBound < secondPass.lowerBound, "la segunda pasada de la zona va antes de borrar las filas")
        #expect(close.components(separatedBy: "ICloudPersonalCorpusProbe.wipe()").count - 1 == 1)

        // Entre la quiescencia y el borrado no hay ni un `await`: un `save()` a medio import es un trap no atrapable.
        let quiet = try #require(close.range(of: "guard await Self.awaitPersonalQuiescenceForGroupsSignOut() else {"))
        let afterGuard = try #require(close.range(of: "return false\n        }", range: quiet.upperBound..<close.endIndex))
        let wipe = try #require(close.range(of: "try DataWipeService.wipeAllUserData"))
        #expect(!close[afterGuard.upperBound..<wipe.lowerBound].contains("await"),
                "entre la quiescencia y el borrado de filas hay un `await`: la medida caduca antes de guardar")
    }

    /// La zona de iCloud va ANTES del servidor, y sin cuenta de iCloud no bloquea: fallaría en cada reintento y la cuenta
    /// no se podría eliminar nunca. Cualquier otro fallo (red, iCloud ocupado) sí para, con la cuenta todavía viva.
    @Test func privateAccountDeletion_wipesTheICloudZoneBeforeTheServer() throws {
        let service = try Self.source("Yala/Services/CloudSync/AccountDeletionService.swift")
        let flow = try #require(Self.body(of: "func deleteAccount(context: ModelContext) async", in: service))
        let marks = [
            // La celda se decide con la cuenta viva; con la marca de un cierre a medias es la D (ticket
            // `account-deletion-private-close-has-no-durable-intent`).
            "let privateCell = pendingPrivateClose || (!deps.storageModeIsCloud() && deps.hasPrivateSession())",
            "if privateCell {",
            "guard await deps.wipePrivateICloud() else {",
            "phase = .failed(step: .personalWipe)",
            "try await deps.forgetGroupsUser()",
            "switch await deps.deletePersonalAccount() {",
        ]
        let pos = try #require(Self.offsets(marks, in: flow), "Falta una pieza del orden zona → servidor")
        #expect(pos == pos.sorted(), "la zona de iCloud ya no va antes del servidor")

        #expect(CloudSessionSignOut.accountDeletionProceedsWithoutICloud("CKError.9"), "sin cuenta de iCloud bloquea")
        #expect(CloudSessionSignOut.accountDeletionProceedsWithoutICloud("CKError.32"), "cuenta gestionada bloquea")
        #expect(!CloudSessionSignOut.accountDeletionProceedsWithoutICloud("CKError.4"), "un fallo de red ya no para")
        #expect(!CloudSessionSignOut.accountDeletionProceedsWithoutICloud("CKError.23"), "iCloud ocupado ya no para")
    }

    /// El servicio manda la celda D a ese cierre, y la nube y solo-grupos sin sesión privada al de la nube.
    @Test func accountDeletion_routesThePrivateCellToTheFullClose() throws {
        let src = try Self.source("Yala/Services/CloudSync/AccountDeletionService.swift")
        #expect(src.contains("closeLocalPrivate: { await CloudSessionSignOut.shared.closeLocalAfterAccountDeletionPrivate(context: $0) },"))
        #expect(src.contains("let privateCell = pendingPrivateClose || (!deps.storageModeIsCloud() && deps.hasPrivateSession())"))
        #expect(src.contains("private func closeLocally(context: ModelContext, privateCell: Bool) async {"))
        #expect(src.contains("if !privateCell {"))
        #expect(src.contains("if await deps.closeLocalPrivate(context) {"))
    }
}
