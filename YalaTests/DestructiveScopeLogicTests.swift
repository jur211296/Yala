//
//  DestructiveScopeLogicTests.swift
//  YalaTests
//
//  Tabla de la lógica pura de la "hoja de alcance" destructiva (D4, §3.1/§3.3 del estudio
//  MODO-NUBE-GESTION-DATOS-UX; una operación por celda del ADR 2026-09-09 desde el paso 9 del rediseño de
//  sesiones). Verifica la ESTRUCTURA del sheet por operación × etiqueta ☁️ × deuda × huella: 3 filas SIEMPRE
//  (device→cloud→groups) con sus tonos, la etiqueta ☁️ (mata C2), las líneas condicionales (reusando la
//  decisión D5 de `AccountDeletionMessageLogic`), las acciones secundarias, y qué operación toca a cada celda.
//
//  Lógica pura sin estado → `@Suite` sin `.serialized`.
//

import Foundation
import Testing
@testable import Yala

@Suite("Hoja de alcance destructiva — lógica de configuración (D4 + paso 9)")
struct DestructiveScopeLogicTests {

    typealias Op = DestructiveScopeLogic.Operation
    typealias Tone = DestructiveScopeLogic.Tone
    typealias Line = DestructiveScopeLogic.ExtraLine
    typealias Kind = DestructiveScopeLogic.SecondaryKind
    typealias Path = CloudSignOutFlowLogic.Path

    // MARK: - Etiqueta ☁️ (C2)

    @Test func cloudLabel_followsStorageMode() {
        #expect(DestructiveScopeLogic.cloudLabel(storageMode: .cloud) == .cloudAccount)
        #expect(DestructiveScopeLogic.cloudLabel(storageMode: .icloud) == .icloud)
    }

    /// Borrar cuenta habla SIEMPRE de la cuenta de Yala; y en solo-grupos lo que queda a salvo
    /// es la cuenta, no un iCloud que no guarda nada suyo. El resto sigue a `storageMode`.
    @Test func cloudLabelForOperation_accountOperationsAlwaysNameTheAccount() {
        let alwaysAccount: Set<String> = ["deleteAccountCloud", "deleteAccountGroupsOnly",
                                          "deleteAccountGroupsOnlyNoPrivate", "signOutGroupsOnly"]
        for op in Op.allCases {
            for mode in [StorageMode.icloud, .cloud] {
                let expected: DestructiveScopeLogic.CloudLabel = alwaysAccount.contains("\(op)")
                    ? .cloudAccount : DestructiveScopeLogic.cloudLabel(storageMode: mode)
                #expect(DestructiveScopeLogic.cloudLabel(for: op, storageMode: mode) == expected, "\(op) \(mode)")
            }
        }
    }

    // MARK: - Invariante: SIEMPRE 3 filas en orden device→cloud→groups

    @Test func everyOperation_hasExactlyThreeRows_inCanonicalOrder() {
        for op in Op.allCases {
            for label in [DestructiveScopeLogic.CloudLabel.icloud, .cloudAccount] {
                let m = DestructiveScopeLogic.model(operation: op, cloudLabel: label)
                #expect(m.rows.count == 3, "\(op): debe tener 3 filas")
                #expect(m.rows.map(\.location) == [.device, .cloud, .groups], "\(op): orden de filas incorrecto")
                #expect(m.cloudLabel == label, "\(op): la etiqueta ☁️ debe ser eco del parámetro")
            }
        }
    }

    // MARK: - La tabla entera: tonos · nota de conservación · líneas (sin deuda ni huella)

    /// Una fila por operación. Si alguien añade una operación sin decidir su tabla, el `switch` no compila; si
    /// cambia un tono o una línea, esta tabla dice cuál.
    @Test func everyOperation_matchesItsTable() {
        func expected(_ op: Op) -> (tones: [Tone], note: Bool, lines: [Line]) {
            switch op {
            case .wipeDataFull:                   return ([.destructive, .destructive, .preserved], true, [])
            case .wipeDataGroupsOnly:             return ([.destructive, .preserved, .preserved], false, [])
            case .deleteAccountCloud:             return ([.destructive, .destructive, .neutral], false, [.crossRefer, .frozenICloud])
            case .deleteAccountGroupsOnly:        return ([.preserved, .destructive, .neutral], false, [.crossRefer])
            case .deleteAccountGroupsOnlyNoPrivate: return ([.destructive, .destructive, .neutral], false, [.crossRefer])
            case .signOutPrivate:                 return ([.neutral, .preserved, .preserved], true, [])
            case .signOutPrivateNoCopy:           return ([.destructive, .destructive, .preserved], false, [.noICloudCopy])
            case .signOutPrivateWithGroups:       return ([.neutral, .preserved, .neutral], true, [])
            case .signOutPrivateWithGroupsNoCopy: return ([.destructive, .destructive, .neutral], false, [.noICloudCopy])
            case .signOutCloud:                   return ([.neutral, .preserved, .preserved], true, [])
            case .signOutGroupsOnly:              return ([.neutral, .preserved, .neutral], true, [])
            }
        }
        for op in Op.allCases {
            let m = DestructiveScopeLogic.model(operation: op, cloudLabel: .icloud)
            let e = expected(op)
            #expect(m.rows.map(\.tone) == e.tones, "\(op): tonos")
            #expect(m.hasConservationNote == e.note, "\(op): nota de conservación")
            #expect(m.extraLines == e.lines, "\(op): líneas")
        }
    }

    /// Decisión de Jürgen del 2026-09-09: sin copia en iCloud se AVISA de que no existe en ninguna parte, y no
    /// se promete ninguna vuelta atrás. Con copia, la hoja no puede decir que se pierde.
    @Test func noCopySignOuts_warn_andCopySignOuts_dont() {
        for op in Op.allCases {
            let m = DestructiveScopeLogic.model(operation: op, cloudLabel: .icloud)
            let warns = m.extraLines.contains(.noICloudCopy)
            #expect(warns == DestructiveScopeLogic.requiresNoCopyConfirmation(op), "\(op)")
            if warns { #expect(!m.hasConservationNote, "\(op): sin copia no hay vuelta atrás que prometer") }
        }
    }

    // MARK: - Acciones secundarias (steer-away)

    @Test func secondaryActions_perOperationAndDebt() {
        func expected(_ op: Op, debt: Bool) -> [Kind] {
            switch op {
            case .wipeDataFull:       return debt ? [.viewGroups, .exportBefore] : [.exportBefore]
            case .wipeDataGroupsOnly: return debt ? [.viewGroups] : []
            case .deleteAccountCloud, .deleteAccountGroupsOnly, .deleteAccountGroupsOnlyNoPrivate:
                                      return debt ? [.viewGroups] : []
            default:                  return []
            }
        }
        for op in Op.allCases {
            for debt in [false, true] {
                let m = DestructiveScopeLogic.model(operation: op, cloudLabel: .cloudAccount, hasOutstandingDebt: debt)
                #expect(m.secondaryActions == expected(op, debt: debt), "\(op) debt=\(debt)")
            }
        }
    }

    @Test func leaveAllGroups_firstWhenCanLeaveAndNoDebt_inWipeDataFull() {
        let m = DestructiveScopeLogic.model(operation: .wipeDataFull, cloudLabel: .icloud,
                                            hasOutstandingDebt: false, canLeaveAllGroups: true)
        #expect(m.secondaryActions == [.leaveAllGroups, .exportBefore])
        let debt = DestructiveScopeLogic.model(operation: .wipeDataFull, cloudLabel: .icloud,
                                               hasOutstandingDebt: true, canLeaveAllGroups: true)
        #expect(debt.secondaryActions == [.viewGroups, .exportBefore])
        let go = DestructiveScopeLogic.model(operation: .wipeDataGroupsOnly, cloudLabel: .icloud, canLeaveAllGroups: true)
        #expect(!go.secondaryActions.contains(.leaveAllGroups))
    }

    @Test func wipeDataFull_cloud_addsMultiDeviceResidual() {
        let m = DestructiveScopeLogic.model(operation: .wipeDataFull, cloudLabel: .cloudAccount)
        #expect(m.extraLines == [.multiDeviceResidual])
    }

    @Test func deleteAccount_extraLines_matchAccountDeletionMessageLogic_minusBase() {
        for op in [Op.deleteAccountCloud, .deleteAccountGroupsOnly, .deleteAccountGroupsOnlyNoPrivate] {
            let isCloud = op == .deleteAccountCloud
            for debt in [true, false] {
                for footprint in [true, false] {
                    let m = DestructiveScopeLogic.model(operation: op, cloudLabel: .cloudAccount,
                                                        hasOutstandingDebt: debt, hasLegacyCloudKitFootprint: footprint)
                    let expected = AccountDeletionMessageLogic.lines(
                        isCloud: isCloud, hasOutstandingDebt: debt, hasLegacyCloudKitFootprint: footprint)
                        .compactMap { line -> Line? in
                            switch line {
                            case .base:            return nil
                            case .debtWarning:     return .debtWarning
                            case .crossRefer:      return .crossRefer
                            case .frozenICloud:    return .frozenICloud
                            case .legacyFootprint: return .legacyFootprint
                            }
                        }
                    #expect(m.extraLines == expected, "\(op) debt=\(debt) footprint=\(footprint)")
                    #expect(m.extraLines.contains(.frozenICloud) == isCloud,
                            "la copia iCloud congelada del cutover SOLO existe para quien migró a la nube")
                }
            }
        }
    }

    // MARK: - Qué operación toca a cada celda

    @Test func wipeOperation_sinSesiónPrivada_isGroupsOnly_elseFull() {
        #expect(DestructiveScopeLogic.wipeOperation(hasPrivateSession: false, personalMountAttachesMirror: false)
                == .wipeDataGroupsOnly)
        #expect(DestructiveScopeLogic.wipeOperation(hasPrivateSession: true, personalMountAttachesMirror: false)
                == .wipeDataFull)
        #expect(DestructiveScopeLogic.wipeOperation(hasPrivateSession: true, personalMountAttachesMirror: true)
                == .wipeDataFull)
    }

    /// «Vaciar datos» borra FILAS: con el espejo montado, esos borrados salen a iCloud y de ahí a los demás
    /// dispositivos que lean de ese mismo iCloud. Un solo-grupos sobre un store que espeja ve la hoja
    /// completa, cuya fila ☁️ nombra ese cruce;
    /// la de solo grupos le decía «No se tocan» (review adversarial del paso 9).
    @Test func wipeOperation_groupsOnlyOnAMirroredStore_isFull() {
        #expect(DestructiveScopeLogic.wipeOperation(hasPrivateSession: false, personalMountAttachesMirror: true)
                == .wipeDataFull)
    }

    /// Un verbo, cuatro celdas: la operación la decide el camino, y la copia de iCloud solo cambia las dos
    /// privadas. La privada que olvida grupos del canal backend (una sesión de grupos caducada) ve la hoja del
    /// «equipo», la que dice que este dispositivo los olvida; en las demás celdas ese término no cambia nada.
    @Test func signOutOperation_oneVariantPerCell() {
        let table: [(Path, Bool, Bool, Op)] = [
            (.privateSignOut, true, false, .signOutPrivate),
            (.privateSignOut, false, false, .signOutPrivateNoCopy),
            (.privateSignOut, true, true, .signOutPrivateWithGroups),
            (.privateSignOut, false, true, .signOutPrivateWithGroupsNoCopy),
            (.privateWithGroupsSignOut, true, false, .signOutPrivateWithGroups),
            (.privateWithGroupsSignOut, false, false, .signOutPrivateWithGroupsNoCopy),
            (.privateWithGroupsSignOut, true, true, .signOutPrivateWithGroups),
            (.cloudSecureSignOut, true, false, .signOutCloud),
            (.cloudSecureSignOut, false, true, .signOutCloud),
            (.groupsOnlySignOut, true, false, .signOutGroupsOnly),
            (.groupsOnlySignOut, false, true, .signOutGroupsOnly),
        ]
        for (path, copy, forgets, op) in table {
            #expect(DestructiveScopeLogic.signOutOperation(path: path, hasICloudCopy: copy, forgetsBackendGroups: forgets)
                    == op, "\(path) copy=\(copy) forgets=\(forgets)")
        }
    }

    @Test func deleteAccountOperation_perCell() {
        #expect(DestructiveScopeLogic.deleteAccountOperation(storageMode: .cloud, hasPrivateSession: true) == .deleteAccountCloud)
        #expect(DestructiveScopeLogic.deleteAccountOperation(storageMode: .cloud, hasPrivateSession: false) == .deleteAccountCloud)
        #expect(DestructiveScopeLogic.deleteAccountOperation(storageMode: .icloud, hasPrivateSession: true) == .deleteAccountGroupsOnly)
        #expect(DestructiveScopeLogic.deleteAccountOperation(storageMode: .icloud, hasPrivateSession: false)
                == .deleteAccountGroupsOnlyNoPrivate)
    }

    @Test func requiresNoCopyConfirmation_onlyTheTwoNoCopySignOuts() {
        let reinforced = Op.allCases.filter(DestructiveScopeLogic.requiresNoCopyConfirmation)
        #expect(reinforced == [.signOutPrivateNoCopy, .signOutPrivateWithGroupsNoCopy])
    }

    /// La señal de «vaciar» viaja por el iCloud KV del Apple ID y los dispositivos que la reciben borran
    /// filas (y con el espejo, su iCloud). Solo una sesión PRIVADA habla por ese Apple ID: desde la nube o
    /// solo grupos, vaciaba el iPad privado del dueño de un móvil prestado.
    @Test func wipeSignal_onlyFromAPrivateSession() {
        #expect(DestructiveScopeLogic.wipeSignalsAppleIDDevices(confirmedPrivateSession: true, storageMode: .icloud))
        #expect(!DestructiveScopeLogic.wipeSignalsAppleIDDevices(confirmedPrivateSession: true, storageMode: .cloud))
        #expect(!DestructiveScopeLogic.wipeSignalsAppleIDDevices(confirmedPrivateSession: false, storageMode: .icloud))
        #expect(!DestructiveScopeLogic.wipeSignalsAppleIDDevices(confirmedPrivateSession: false, storageMode: .cloud))
    }

    /// El otro extremo del mismo canal (ticket `remote-wipe-signal-honored-by-any-session`). El paso 9
    /// cerró el emisor; el receptor obedecía la señal en cualquier celda. **La tabla es exhaustiva**
    /// —`StorageMode` solo tiene dos casos— y cada fila nombra su celda del ADR 2026-09-09:
    @Test func wipeSignal_onlyObeyedByAPrivateSession() {
        // C · D — sesión privada, el store personal espeja a iCloud: sus datos SON los del Apple ID.
        #expect(DestructiveScopeLogic.wipeSignalObeyedByThisSession(
            confirmedPrivateSession: true, storageMode: .icloud))
        // E — nube completa: obedecer subiría los borrados a SU cuenta.
        #expect(!DestructiveScopeLogic.wipeSignalObeyedByThisSession(
            confirmedPrivateSession: true, storageMode: .cloud))
        // F — solo grupos (el móvil prestado): obedecer borra el perfil de quien lo está usando.
        #expect(!DestructiveScopeLogic.wipeSignalObeyedByThisSession(
            confirmedPrivateSession: false, storageMode: .icloud))
        // Marca apagada Y cuenta en la nube: las dos razones a la vez, por si una tapara a la otra.
        #expect(!DestructiveScopeLogic.wipeSignalObeyedByThisSession(
            confirmedPrivateSession: false, storageMode: .cloud))
    }

    /// **Que el receptor DELEGUE en el emisor es el mecanismo, no un detalle de estilo**, y las ocho
    /// aserciones de arriba no lo pinnean: inlinear el cuerpo (`confirmedPrivateSession && storageMode
    /// == .icloud`) las deja las ocho en verde y deshace la única garantía de que las dos mitades del
    /// canal no puedan divergir. Un receptor más ancho que su emisor borra filas que nadie quiso borrar,
    /// y esa divergencia no la ve ningún test de comportamiento porque cada mitad seguiría siendo
    /// correcta por su cuenta.
    @Test("MUTACIÓN: el receptor delega en el emisor, no copia su cuerpo")
    func theReceiverDelegatesInsteadOfCopying() throws {
        let fuente = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Yala/App/Logic/DestructiveScopeLogic.swift"),
            encoding: .utf8)
        let codigo = fuente.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        #expect(codigo.contains(
            "wipeSignalsAppleIDDevices(confirmedPrivateSession: confirmedPrivateSession, storageMode: storageMode)"), """
            `wipeSignalObeyedByThisSession` dejó de delegar en `wipeSignalsAppleIDDevices`. Si copiaste
            el cuerpo, deshazlo: son las dos mitades del mismo canal —¿los datos de este dispositivo son
            los del Apple ID?— y dos cuerpos iguales que «siempre van juntos» divergen en el commit
            siguiente, en silencio y hacia el lado que borra.
            """)

        // Control: el predicado compartido sigue teniendo UN solo cuerpo en el fichero.
        #expect(codigo.components(separatedBy: "confirmedPrivateSession && storageMode == .icloud").count - 1 == 1,
                "el predicado de la señal de vaciado dejó de tener un cuerpo único")
    }

    // MARK: - A dónde lleva «Vaciar datos»

    @Test func wipeLanding_personalOnboarding_unlessGroupsOnly() {
        #expect(DestructiveScopeLogic.wipeLanding(hasPrivateSession: true) == .personalOnboarding)
        #expect(DestructiveScopeLogic.wipeLanding(hasPrivateSession: false) == .groupsShell)
    }
}

// MARK: - Identifiers: qué escenario retrata cada pantalla de salida

/// **El problema es de PRUEBA, no de usuario.** Desde el paso 9 hay UNA sola fila «Cerrar sesión» en las cuatro
/// celdas (ADR 2026-09-09 §6) — su identifier ya no puede decir qué borrado arma. Lo dice la HOJA: su
/// contenedor nombra la operación, y ahí es donde un XCUITest demuestra de qué celda es la pantalla que ve.
@Suite("Salidas de sesión · la fila es una y la hoja nombra su celda")
struct SignOutRowIdentifiersTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("Ajustes tiene UNA fila de cierre y ninguna de las salidas retiradas")
    func singleSignOutRow() throws {
        let profile = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(profile.components(separatedBy: "\"profile_security_signout\"").count - 1 == 1)
        for retired in ["profile_security_signout_plain", "profile_security_signout_groups",
                        "profile_security_exit_yala_split", "profile_security_exit_yala_legacy",
                        "profile_security_delete_account"] {
            #expect(!profile.contains("\"\(retired)\""), """
                Volvió `\(retired)`: el ADR 2026-09-09 deja dos botones en Ajustes, y «Eliminar mi cuenta» \
                vive dentro de «Tu cuenta de Yala».
                """)
        }
    }

    @Test("la hoja destructiva nombra su escenario, y las once operaciones dan ids únicos")
    func destructiveSheet_namesItsScenario() {
        let ids = DestructiveScopeLogic.Operation.allCases.map {
            DestructiveScopeSheet.Config.scenarioIdentifier(for: $0)
        }
        #expect(ids.count == 11)
        #expect(Set(ids).count == ids.count, "Dos operaciones comparten identifier de escenario: \(ids.sorted()).")
        #expect(ids.allSatisfy { $0.hasPrefix("destructive_scope_sheet_") })
    }

    /// El único call-site que decide si «Vaciar datos» avisa a los otros dispositivos del Apple ID y a dónde
    /// aterriza. Las decisiones puras tienen su tabla arriba; esto fija que la vista las USE. La review
    /// adversarial del paso 9 midió que con `broadcastSignal: true` —el valor por defecto— o sin el
    /// aterrizaje, todo lo demás seguía en verde.
    @Test("«Vaciar datos» usa la señal y el aterrizaje decididos, antes de cualquier espera")
    func userDataReset_usesTheDecidedSignalAndLanding() throws {
        let view = try Self.code("Yala/App/Views/Settings/UserDataResetView.swift")
        #expect(view.contains("personalMountAttachesMirror: CloudSessionSignOut.personalMountAttachesMirror"))
        #expect(view.components(separatedBy: "broadcastSignal: signalsOtherDevices").count - 1 == 1)
        // Sin el paréntesis a propósito: con él, `SharedStateIsolationTests` leería este fichero como uno que
        // EJECUTA el wipe y le exigiría el trait de aislamiento del App Group.
        let wipe = try #require(view.range(of: "try DataWipeService.wipeAllUserData"))
        let landing = try #require(view.range(of: "applyWipeLanding(landing)", range: wipe.upperBound..<view.endIndex))
        let firstAwait = try #require(view.range(of: "await", range: wipe.upperBound..<view.endIndex))
        #expect(landing.lowerBound < firstAwait.lowerBound, """
            El aterrizaje tiene que ir en la misma vuelta del main actor que el wipe: el `onChange` de ContentView \
            leería el estado intermedio que deja el barrido.
            """)
    }
}

// MARK: - El alcance que la hoja de «Vaciar datos» promete

/// **Hasta el 2026-09-14 la fila ☁️ de Vaciar en iCloud decía la verdad, y dejó de decirla sin que nada se
/// pusiera rojo.** Prometía «…y desaparecen también de tu iPad, tu Mac y cualquier dispositivo con este
/// Apple ID»; el mismo día, `wipeSignalObeyedByThisSession` cerró el receptor para que un dispositivo
/// prestado —o con la cuenta de Yala— NO obedeciera la señal. La promesa quedó falsa y **no había una sola
/// aserción sobre el copy de esa fila**: la tabla de arriba mide la ESTRUCTURA (filas, tonos, líneas,
/// secundarias) y nunca el texto.
///
/// Esta suite es esa red, por los dos lados: el camino de producción (`Config.make`, no un grep) y los 16
/// ficheros de strings, para que reponer la promesa en un solo idioma tampoco pase.
@Suite("Vaciar datos · la fila ☁️ no promete lo que el receptor puede no cumplir")
struct WipeCloudRowScopeTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// El literal que ya no debe salir en NINGÚN idioma. Los tres iban en la frase retirada y son los que
    /// afirman alcance por Apple ID; se escriben igual en los 16 locales (`Apple-ID` es la grafía alemana).
    private static let forbidden = ["Apple ID", "Apple-ID", "iPad"]

    @Test("la hoja en iCloud usa el texto acotado, y el acotado es el que se muestra")
    func wipeICloud_cloudRow_usesTheScopedString() {
        let config = DestructiveScopeSheet.Config.make(
            operation: .wipeDataFull, cloudLabel: .icloud, onConfirm: {})

        // Fila 1 = ☁️ (el orden device→cloud→groups lo fija la tabla de arriba).
        #expect(config.rows.count == 3)
        let cloudRow = config.rows[1]
        #expect(cloudRow.label == L10n.Settings.scopeICloudLabel)
        #expect(cloudRow.detail == L10n.Settings.wipeScopeCloudICloudPersonal)

        // Sin esto la aserción de arriba NO PUEDE FALLAR de forma útil: si `ls()` no resolviera en el host
        // de test, los dos lados devolverían la key cruda y serían iguales igualmente.
        #expect(!cloudRow.detail.hasPrefix("settings."), """
            `L10n` devolvió la key cruda («\(cloudRow.detail)»): el host de test no está resolviendo el \
            bundle, así que la comparación de arriba no prueba nada.
            """)
        for literal in Self.forbidden {
            #expect(!cloudRow.detail.contains(literal), """
                Volvió la promesa por Apple ID («\(literal)») a la fila ☁️ de Vaciar en iCloud. Desde el \
                2026-09-14 un dispositivo prestado o con la cuenta de Yala NO obedece la señal de vaciado \
                (`DestructiveScopeLogic.wipeSignalObeyedByThisSession`), así que afirmarlo es falso.
                """)
        }
    }

    /// La `.cloud` es la otra mitad y NO se tocó: ahí el borrado viaja por la cuenta de Yala y sus otros
    /// dispositivos sí lo pierden al sincronizar. Fijarlo impide "arreglar" este ticket suavizando las dos.
    @Test("la hoja en la cuenta de Yala conserva su propio texto")
    func wipeCloudAccount_cloudRow_isUntouched() {
        let config = DestructiveScopeSheet.Config.make(
            operation: .wipeDataFull, cloudLabel: .cloudAccount, onConfirm: {})
        #expect(config.rows[1].detail == L10n.Settings.wipeScopeCloudAccount)
        #expect(config.rows[1].label == L10n.Settings.scopeCloudAccountLabel)
    }

    @Test("ningún locale promete alcance por Apple ID en esa fila")
    func scopedString_promisesNoAppleIDWideScope_inEveryLocale() throws {
        let key = "settings.wipeScopeCloudICloudPersonal"
        let retired = "settings.wipeScopeCloudICloudAllDevices"
        let resources = Self.repoRoot.appendingPathComponent("Yala/Resources")
        let lprojs = try FileManager.default
            .contentsOfDirectory(at: resources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "lproj" }
            .sorted { $0.path < $1.path }

        // Control positivo: sin esto el test pasa en verde leyendo CERO ficheros (falla abierto).
        #expect(lprojs.count == 16, "Se esperaban 16 locales y se leyeron \(lprojs.count).")

        var seen = 0
        for lproj in lprojs {
            let locale = lproj.deletingPathExtension().lastPathComponent
            let content = try String(
                contentsOf: lproj.appendingPathComponent("Localizable.strings"), encoding: .utf8)
            let line = try #require(
                content.split(separator: "\n").first { $0.hasPrefix("\"\(key)\" = ") },
                "\(locale) no tiene `\(key)`.")
            seen += 1
            for literal in Self.forbidden {
                #expect(!line.contains(literal), """
                    \(locale) volvió a prometer alcance por Apple ID («\(literal)») en `\(key)`: \
                    \(line)
                    """)
            }
            #expect(!content.contains("\"\(retired)\""), """
                \(locale) repuso `\(retired)`, la key retirada el 2026-09-14 porque su nombre y su texto \
                afirmaban un alcance que el receptor puede no cumplir.
                """)
        }
        #expect(seen == 16)
    }
}
