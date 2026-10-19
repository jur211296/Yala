//
//  UXAudit22Lote04Tests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote decidido 04 (2026-10-19): cuenta, cerrar sesión y modo solo grupos. La lógica pura de cada
//  decisión por tabla, y por source-scan el cableado que ningún test de comportamiento ve (el orden de los botones de un
//  `.alert`, qué filas se ocultan en solo grupos, que dos pantallas lean la MISMA frase).
//
//  Lógica pura y lectura de ficheros, sin estado → sin `.serialized`.
//

import Foundation
import Testing
@testable import Yala

@Suite("UX 2.2 · lote decidido 04 — lógica")
struct UXAudit22Lote04LogicTests {

    typealias Path = CloudSignOutFlowLogic.Path
    static let allPaths: [Path] = [.privateSignOut, .privateWithGroupsSignOut, .cloudSecureSignOut, .groupsOnlySignOut]

    // MARK: - L20-6

    /// Solo la celda privada SIN cuenta de Yala cambia de nombre; con cuenta (D, E, F) sigue «Cerrar sesión».
    @Test func signOutRemovesDeviceData_onlyInThePrivateCellWithoutAccount() {
        for path in Self.allPaths {
            #expect(DestructiveScopeLogic.signOutRemovesDeviceData(path: path) == (path == .privateSignOut),
                    "camino \(path)")
        }
    }

    // MARK: - L20-10

    /// La alerta propia solo en la cuenta de grupos con sesión privada; en las demás la genérica es cierta.
    @Test func deleteAccountFinal_keepsThisDevice_onlyForTheGroupsAccountWithPrivateData() {
        for op in DestructiveScopeLogic.Operation.allCases {
            #expect(DestructiveScopeLogic.deleteAccountFinalKeepsThisDevice(op) == (op == .deleteAccountGroupsOnly),
                    "operación \(op)")
        }
        // Y esa celda es la que la hoja pinta con 📱 conservado: si alguien cambia una, la otra mentiría.
        let model = DestructiveScopeLogic.model(operation: .deleteAccountGroupsOnly, cloudLabel: .cloudAccount)
        #expect(model.rows.first { $0.location == .device }?.tone == .preserved)
    }

    // MARK: - L20-9

    @Test func identity_prefersTheSessionEmail_thenTheCaptured_thenTheName() {
        typealias L = YalaAccountLogic
        #expect(L.identity(sessionEmail: "a@x.com", capturedEmail: "b@x.com", capturedName: "Ana") == .email("a@x.com"))
        #expect(L.identity(sessionEmail: nil, capturedEmail: "b@x.com", capturedName: "Ana") == .email("b@x.com"))
        #expect(L.identity(sessionEmail: "  ", capturedEmail: nil, capturedName: "Ana") == .name("Ana"))
        #expect(L.identity(sessionEmail: "", capturedEmail: " ", capturedName: " \n") == .none)
        #expect(L.identity(sessionEmail: " a@x.com ", capturedEmail: nil, capturedName: nil) == .email("a@x.com"))
    }

    /// La fila abre «Dónde viven tus datos» salvo en solo grupos sin sesión privada, donde L19-15 oculta esa pantalla.
    @Test func dataLocation_opensStorage_exceptGroupsOnlyWithoutPrivateSession() {
        #expect(YalaAccountLogic.dataLocationOpensStorage(.cloud))
        #expect(YalaAccountLogic.dataLocationOpensStorage(.groupsOnly))
        #expect(!YalaAccountLogic.dataLocationOpensStorage(.groupsOnlyNoPrivate))
    }
}

@Suite("UX 2.2 · lote decidido 04 — cableado (source-scan)")
struct UXAudit22Lote04WiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El tramo que empieza en `start` y acaba en la primera aparición de `end` después.
    private static func slice(_ src: String, from start: String, to end: String) throws -> String {
        let a = try #require(src.range(of: start), "no está «\(start)»")
        let b = try #require(src.range(of: end, range: a.upperBound..<src.endIndex), "no está «\(end)» tras «\(start)»")
        return String(src[a.lowerBound..<b.upperBound])
    }

    static let profile = "Yala/App/Views/Profile/ProfileView.swift"

    /// L20-7 · el aviso de los 45 s ofrece primero la salida que no pierde nada, y ningún botón lleva `.cancel` (iOS lo
    /// mandaría al final). Un `contains` suelto no caza un intercambio: se fija el ORDEN de los tres ids.
    @Test func exportNotice_offersExportFirst_waitSecond_discardLast() throws {
        let src = try Self.source(Self.profile)
        let alert = try Self.slice(src, from: ".alert(L10n.Settings.signOutExportPendingTitle, isPresented: $showSignOutExportAlert) {",
                                   to: "} message: {")
        let export = try #require(alert.range(of: "\"signout_export_export\""))
        let wait = try #require(alert.range(of: "\"signout_export_wait\""))
        let discard = try #require(alert.range(of: "\"signout_export_discard\""))
        #expect(export.lowerBound < wait.lowerBound)
        #expect(wait.lowerBound < discard.lowerBound)
        #expect(!alert.contains("role: .cancel"), "un `.cancel` lo manda iOS al final y desordena el aviso")
        #expect(alert.contains("exportEverythingBeforeLosingIt(returningTo: .signOutExportNotice)"))
        // Al cerrar la hoja de compartir vuelve ESTE aviso, no la hoja de alcance.
        let back = try Self.slice(src, from: "case .signOutExportNotice:", to: "syncSignOutUI(from: signOutCoordinator.phase)")
        #expect(back.contains("guard case .blocked(_, .exportUnconfirmed) = signOutCoordinator.phase else { return }"))
    }

    /// L20-7 · la cifra de la tarjeta es un testigo de la ESPERA: se retira al salir de ella pase lo que pase.
    @Test func exportWait_isRetiredWhenTheWaitEnds() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        let gate = try Self.slice(src,
            from: "private func confirmExportOrBlock(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind, credentialsReleased: Bool) async -> Bool {",
            to: "sleep: { seconds in")
        #expect(gate.contains("defer { iCloudExportWait = nil }"))
        #expect(gate.contains("self.iCloudExportWait = ICloudExportWait(pending: lastCounted)"))
    }

    /// L19-15 · en solo grupos no salen ni «Sincronización iCloud» ni «Dónde viven tus datos».
    @Test func groupsOnly_hidesTheICloudRows() throws {
        let src = try Self.source(Self.profile)
        #expect(src.contains("if CloudSyncFlags.storageMode != .cloud && !isGroupsFocusedShell {"))
        #expect(src.contains("if !isGroupsFocusedShell, StorageRowGateLogic.isVisible("))
    }

    /// L20-6 · la fila de salida se construye UNA vez (su id lo cuenta otro test) y va a un sitio u otro por la misma regla.
    @Test func signOutRow_oneConstruction_twoPlaces() throws {
        let src = try Self.source(Self.profile)
        #expect(src.components(separatedBy: "\"profile_security_signout\"").count - 1 == 1)
        #expect(src.contains("if !signOutRowRemovesDeviceData {\n                    SubsectionDivider()\n                    signOutRow"))
        #expect(src.contains("if signOutRowRemovesDeviceData {\n                                removeDeviceDataSection"))
        #expect(src.contains("removesDeviceData: DestructiveScopeLogic.signOutRemovesDeviceData(path: scope.path)"))
    }

    /// L20-9 · las dos pantallas dicen la MISMA frase del método porque leen la misma key.
    @Test func methodSentence_isTheSameKeyOnBothScreens() throws {
        let chooser = try Self.source("Yala/App/Views/Settings/StorageSignInChooserView.swift")
        let account = try Self.source("Yala/App/Views/Profile/YalaAccountView.swift")
        #expect(chooser.contains("Text(L10n.Settings.yalaAccountLinkingNote)"))
        #expect(account.contains("Text(L10n.Settings.yalaAccountLinkingNote)"))
        #expect(!chooser.contains("L10n.Storage.SignIn.note"))
    }

    /// L20-10 · las dos frases que mandan a «Vaciar datos» lo nombran como se llama la fila, en cada idioma.
    @Test func wipeReferences_nameTheRowAsItIsCalled_inEveryLanguage() throws {
        let res = Self.repoRoot.appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: res.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16, "se esperaban 16 idiomas, hay \(locales.count)")
        for lproj in locales {
            let file = res.appendingPathComponent("\(lproj)/Localizable.strings")
            guard let dict = NSDictionary(contentsOf: file) as? [String: String] else {
                Issue.record("\(lproj): no se pudo leer"); continue
            }
            let row = try #require(dict["settings.wipeData"], "\(lproj) sin settings.wipeData")
            for key in ["settings.deleteAccountCrossReferHint", "settings.batchLeaveStoppedBody"] {
                let value = try #require(dict[key], "\(lproj) sin \(key)")
                #expect(value.contains(row), "\(lproj) · \(key) no nombra la fila «\(row)»: \(value)")
            }
        }
    }
}
