//
//  GroupsGateLegacyGroupsWipeTests.swift
//  YalaTests / CloudSync
//
//  Ticket `welcome-groups-gate-loops-on-legacy-cloudkit-groups` (caso Pia), decisión A de Jürgen del 2026-10-29: **la
//  vuelta al neutro de la puerta de Grupos del Welcome se lleva también los grupos de la era CloudKit.**
//
//  El bucle: la puerta cuenta TODO `SplitGroup` → pide el neutro → el cierre privado (`.privateOnly`) solo marcaba el
//  store de Grupos con filas del canal backend → el grupo viejo sobrevivía al borrado del arranque → la puerta lo volvía
//  a contar → igual, sin fin.
//
//  Desde la review adversarial del mismo día, solo si el store tiene algún grupo: la marca de grupos retira también el libro
//  de conservados del desasociar y la cuenta asociada, y sin grupos la puerta no tiene nada que volver a contar.
//
//  Dos suites:
//   · la CADENA, con stores reales en disco: siembra un grupo de la era CloudKit, pregunta a las dos puertas, pasa por la
//     fórmula del arm y por el borrado real del arranque (`performSignOutWipeIfArmed`, archivos inyectados en un
//     directorio propio), remonta y vuelve a preguntar. Lleva su control: sin el término de la puerta —lo que sigue
//     haciendo Ajustes— el grupo sobrevive y la puerta vuelve a pedir el neutro, que es el bucle;
//   · el CABLEADO (source-scan): solo la puerta pide el término, el coordinador lo guarda hasta el arm y lo retira.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Puerta de Grupos · el neutro se lleva los grupos de la era CloudKit", .serialized)
@MainActor
struct GroupsGateLegacyGroupsWipeTests {

    enum Gate: String, CaseIterable, Sendable {
        case organizer, invitee
    }

    // MARK: - Infra (stores en disco, como el teléfono)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsGateLegacy-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do { try FileManager.default.removeItem(at: dir) } catch {
            #if DEBUG
            print("GroupsGateLegacyGroupsWipeTests: Error limpiando \(dir.lastPathComponent): \(error)")
            #endif
        }
    }

    /// El archivo de cada store en el directorio del test, por el nombre con que el borrado del arranque lo pide.
    private func storeURL(named name: String, in dir: URL) -> URL? {
        switch name {
        case SwiftDataConfiguration.databaseName: return dir.appendingPathComponent("personal.sqlite")
        case SwiftDataConfiguration.groupsDatabaseName: return dir.appendingPathComponent("groups.sqlite")
        case SwiftDataConfiguration.syncMetaDatabaseName: return dir.appendingPathComponent("syncmeta.sqlite")
        default: return nil
        }
    }

    private func makeContainer(_ dir: URL) throws -> ModelContainer {
        let personal = ModelConfiguration(
            "GGL-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "GGL-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "GGL-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        return try ModelContainer(for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
    }

    /// El detector que leen las dos puertas (`ContentView.checkHasWelcomeDeviceData`; sin la marca del aviso tardío, que el
    /// borrado del arranque retira, es `checkHasExistingData`): cuentas y categorías propias, CUALQUIER `SplitGroup` y filas
    /// puenteadas.
    private func deviceHasData(_ context: ModelContext) throws -> Bool {
        let accounts = try context.fetchCount(FetchDescriptor<Account>(predicate: #Predicate { !$0.isSystemAccount }))
        let categories = try context.fetchCount(FetchDescriptor<Yala.Category>(predicate: #Predicate { !$0.isSystem }))
        let groups = try context.fetchCount(FetchDescriptor<SplitGroup>())
        let bridged = try context.fetchCount(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID != nil }))
        return accounts > 0 || categories > 0 || groups > 0 || bridged > 0
    }

    /// ¿La puerta pide devolver el teléfono al neutro? Sin espejo y con el canal encendido: el único término es el corpus.
    private func asksForNeutral(_ gate: Gate, hasData: Bool) -> Bool {
        switch gate {
        case .organizer:
            return GroupsOrganizerGateLogic.decide(channelEnabled: true, hasExistingData: hasData,
                                                   mountAttachesMirror: false) == .returnsToNeutral
        case .invitee:
            return GroupInviteNeutralGateLogic.decide(hasCompletedPersonalOnboarding: false, hasExistingData: hasData,
                                                      mountAttachesMirror: false,
                                                      personalDataLivesInLiveCloudAccount: false,
                                                      signUpStartedOnCleanStore: false) == .returnsToNeutral
        }
    }

    struct FirstBoot {
        let asksForNeutral: Bool
        let backendRows: Bool
        let anyGroupRows: Bool
    }

    /// Primer arranque: un teléfono que viene de 2.0 con un grupo de la era CloudKit que nunca migró y nada más (o, con
    /// `withLegacyGroup: false`, sin nada). Devuelve lo que la puerta pide y lo que el arm del cierre preguntaría. El
    /// container se suelta dentro del `autoreleasepool`, como el proceso que se reinicia: el borrado real corre antes del
    /// mount, sin nada abierto.
    private func firstBoot(_ gate: Gate, in dir: URL, withLegacyGroup: Bool = true) throws -> FirstBoot {
        try autoreleasepool {
            let context = ModelContext(try makeContainer(dir))
            if withLegacyGroup {
                let legacy = SplitGroup(name: "Viaje 2025")
                #expect(!legacy.isBackendGroup && legacy.movedToBackendAt == nil,
                        "el grupo sembrado tiene que ser de la era CloudKit")
                context.insert(legacy)
                try context.save()
            }
            return FirstBoot(asksForNeutral: asksForNeutral(gate, hasData: try deviceHasData(context)),
                             backendRows: CloudSessionSignOut.hasBackendGroupRows(context: context),
                             anyGroupRows: CloudSessionSignOut.hasAnyGroupRows(context: context))
        }
    }

    /// Arma el borrado como lo deja `armAfterCredentials` en la celda C (`.privateOnly`) —con sus mismas entradas— y corre
    /// el borrado REAL del arranque contra los archivos del directorio. `seed` escribe antes en los defaults del teléfono.
    private func armAndBootWipe(in dir: URL, boot: FirstBoot, fromGroupsGate: Bool,
                                seed: (UserDefaults) -> Void = { _ in }) -> UserDefaults {
        let defaults = makeIsolatedDefaults(prefix: "ggl.\(fromGroupsGate)")
        StorageModePersistence.write(.icloud, defaults: defaults)
        seed(defaults)
        if CloudSignOutFlowLogic.wipeForgetsGroups(kind: .privateOnly, hasBackendGroupRows: boot.backendRows,
                                                   groupsBackendCompiled: true,
                                                   groupsGateWithGroupRows: fromGroupsGate && boot.anyGroupRows) {
            StorageModePersistence.markSignOutWipeIncludesGroups(defaults)
        }
        StorageModePersistence.armSignOutWipe(defaults)
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { name, _ in
                guard let url = self.storeURL(named: name, in: dir) else { return false }
                for path in [url.path, url.path + "-wal", url.path + "-shm"] where FileManager.default.fileExists(atPath: path) {
                    do { try FileManager.default.removeItem(atPath: path) } catch { return false }
                }
                return true
            },
            resetPrefs: {},
            cancelNotifications: {})
        return defaults
    }

    // MARK: - La cadena

    @Test("Tras «Continuar y borrar», la puerta deja pasar al primer arranque", arguments: Gate.allCases)
    func neutralReturnFromTheGate_forgetsLegacyGroups_andTheGateProceeds(gate: Gate) throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let first = try firstBoot(gate, in: dir)
        #expect(first.asksForNeutral, "con el grupo viejo, la puerta tiene que pedir el neutro: si no, el caso no es el de Pia")
        #expect(!first.backendRows, "un grupo de la era CloudKit no es una fila del canal backend")
        #expect(first.anyGroupRows)

        let defaults = armAndBootWipe(in: dir, boot: first, fromGroupsGate: true)
        #expect(!StorageModePersistence.isSignOutWipeArmed(defaults), "el borrado del arranque tiene que completarse")

        let context = ModelContext(try makeContainer(dir))
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0, "el grupo de la era CloudKit sobrevivió al borrado")
        #expect(!asksForNeutral(gate, hasData: try deviceHasData(context)),
                "la puerta volvió a pedir el neutro tras el borrado: el bucle del caso Pia")
    }

    /// El control: el mismo teléfono por el cierre que NO es la puerta (Ajustes, la hoja del cambio de Apple ID). Fija que
    /// la cadena de arriba discrimina —sin el término, el grupo viejo sobrevive y la puerta vuelve a pedir lo mismo— y que
    /// esos cierres conservan su regla de antes (`private-sign-out-keeps-legacy-cloudkit-groups` sigue abierto).
    @Test("Sin el término de la puerta, el grupo viejo sobrevive y la puerta vuelve a pedir el neutro", arguments: Gate.allCases)
    func closeThatIsNotTheGate_keepsLegacyGroups_whichIsTheLoop(gate: Gate) throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let first = try firstBoot(gate, in: dir)
        _ = armAndBootWipe(in: dir, boot: first, fromGroupsGate: false)

        let context = ModelContext(try makeContainer(dir))
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)
        #expect(asksForNeutral(gate, hasData: try deviceHasData(context)))
    }

    // MARK: - Sin grupos, la puerta no marca (review adversarial del 2026-10-29)

    /// La marca de grupos retira además el libro de conservados del desasociar y la cuenta de grupos asociada. Sin un solo
    /// grupo la puerta no tiene nada que volver a contar, así que su vuelta al neutro no se los lleva.
    @Test("MUTACIÓN: sin grupos en el store, la vuelta al neutro de la puerta conserva el libro de conservados y la cuenta asociada")
    func neutralReturnWithoutGroups_keepsTheDetachLedgerAndTheAssociation() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let first = try firstBoot(.organizer, in: dir, withLegacyGroup: false)
        #expect(!first.anyGroupRows)
        let defaults = armAndBootWipe(in: dir, boot: first, fromGroupsGate: true) {
            $0.set(Data([1]), forKey: GroupsDetachedBridgeLedger.userDefaultsKey)
            $0.set(Data([2]), forKey: GroupsAccountAssociation.localKey)
        }
        #expect(!StorageModePersistence.isSignOutWipeArmed(defaults), "el borrado del arranque tiene que completarse")
        #expect(defaults.object(forKey: GroupsDetachedBridgeLedger.userDefaultsKey) != nil)
        #expect(defaults.object(forKey: GroupsAccountAssociation.localKey) != nil)
    }

    /// El control del anterior: con un grupo viejo, la misma vuelta sí se los lleva (es lo que hace la marca de grupos).
    @Test("Con un grupo viejo, la vuelta al neutro de la puerta se lleva también el libro y la cuenta asociada")
    func neutralReturnWithGroups_takesTheDetachLedgerAndTheAssociation() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let first = try firstBoot(.organizer, in: dir)
        let defaults = armAndBootWipe(in: dir, boot: first, fromGroupsGate: true) {
            $0.set(Data([1]), forKey: GroupsDetachedBridgeLedger.userDefaultsKey)
            $0.set(Data([2]), forKey: GroupsAccountAssociation.localKey)
        }
        #expect(defaults.object(forKey: GroupsDetachedBridgeLedger.userDefaultsKey) == nil)
        #expect(defaults.object(forKey: GroupsAccountAssociation.localKey) == nil)
    }
}

// MARK: - Cableado

@Suite("Puerta de Grupos · el neutro se lleva los grupos de la era CloudKit · cableado (source-scan)")
struct GroupsGateLegacyGroupsWipeWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz
    }

    /// El código sin las líneas de comentario: documentar el término no puede cambiar el recuento.
    private static func code(_ relativePath: String) throws -> String {
        try codeOnly(String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8))
    }

    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Desde la firma hasta la siguiente declaración de función del mismo nivel.
    private static func body(of signature: String, in source: String) throws -> String {
        let start = try #require(source.range(of: signature), "no está `\(signature)`")
        let rest = source[start.upperBound...]
        let ends = ["\n    func ", "\n    private func ", "\n    static func ", "\n    private static func "]
            .compactMap { rest.range(of: $0)?.lowerBound }
        return String(rest[..<(ends.min() ?? rest.endIndex)])
    }

    static let signOutPath = "Yala/Services/CloudSync/CloudSessionSignOut.swift"

    @Test("MUTACIÓN: la vuelta al neutro de la puerta pide el término, y nadie más en la app")
    func onlyTheGatePassesTheTerm() throws {
        let gate = try Self.code("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        let neutral = try Self.body(of: "private func returnToNeutral(withoutICloudCopy: Bool) async {", in: gate)
        #expect(neutral.contains("destinationOnArm: purpose.destinationAfterNeutralReturn,\n"
                                 + "            neutralReturnFromGroupsGate: true)"),
                "la puerta dejó de pedir que el borrado se lleve el store de Grupos: vuelve el bucle del caso Pia")

        let root = Self.repoRoot.appendingPathComponent("Yala")
        let files = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var callers: [String] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            let text = Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if text.contains("neutralReturnFromGroupsGate: true") { callers.append(url.lastPathComponent) }
        }
        #expect(callers == ["WelcomeGroupsGateView.swift"],
                "Ajustes y la hoja del cambio de Apple ID esperan su propia decisión; quién lo pide ahora: \(callers)")
    }

    @Test("MUTACIÓN: el coordinador guarda el término al empezar, lo retira al armar y al reconocer un bloqueo")
    func theCoordinatorCarriesTheTermToTheArm() throws {
        let source = try Self.code(Self.signOutPath)
        let signOut = try Self.body(of: "func signOut(context: ModelContext, confirmedPath:", in: source)
        let guardLine = try #require(signOut.range(of: "guard phase == .idle, !freshStartDrainInFlight else { return }"))
        let store = try #require(signOut.range(of: "self.neutralReturnFromGroupsGate = neutralReturnFromGroupsGate"),
                                 "el cierre dejó de guardar quién lo pidió: el arm preguntaría con `false`")
        #expect(guardLine.upperBound <= store.lowerBound, "guardarlo antes del guard pisaría el de un cierre en marcha")

        let arm = try Self.body(of: "private func armAfterCredentials(context: ModelContext,", in: source)
        let formula = try #require(arm.range(of: "groupsGateWithGroupRows: neutralReturnFromGroupsGate && Self.hasAnyGroupRows(context: context)) {"))
        let retire = try #require(arm.range(of: "neutralReturnFromGroupsGate = false"),
                                  "el término sobrevive al arm y el siguiente cierre de Ajustes lo heredaría")
        let armLine = try #require(arm.range(of: "StorageModePersistence.armSignOutWipe()"))
        #expect(formula.upperBound <= retire.lowerBound && retire.upperBound <= armLine.lowerBound)

        let acknowledge = try Self.body(of: "func acknowledgeBlocked() {", in: source)
        #expect(acknowledge.contains("neutralReturnFromGroupsGate = false"),
                "un bloqueo reconocido deja el término puesto para el gesto siguiente")

        // El valor por defecto es `false`: Ajustes y la hoja del cambio de Apple ID lo omiten.
        #expect(source.contains("neutralReturnFromGroupsGate: Bool = false) async {"),
                "con otro valor por defecto, los cierres que no son la puerta se llevarían los grupos viejos")
        // Y nadie más lo escribe: la declaración, el guardado de `signOut`, la retirada del arm y la de `acknowledgeBlocked`.
        // Un `= false` de más entre el guardado y el arm devolvería el bucle; un `= true`, se lo llevaría a otro cierre.
        #expect(source.components(separatedBy: "neutralReturnFromGroupsGate = ").count - 1 == 4,
                "cambió el número de escrituras del término")
        #expect(source.components(separatedBy: "neutralReturnFromGroupsGate = false").count - 1 == 3)
        #expect(source.contains("private var neutralReturnFromGroupsGate = false"))
    }

    @Test("La hoja del cambio de Apple ID cuenta los grupos sin el término de la puerta")
    func appleIDNoticeDoesNotBorrowTheGateTerm() throws {
        let logic = try Self.code("Yala/App/Logic/AppleIDCloseNoticeLogic.swift")
        #expect(logic.contains("groupsGateWithGroupRows: false)"))
    }
}
