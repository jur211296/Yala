//
//  HandoverGroupsDomainTests.swift
//  YalaTests
//
//  Handover de dispositivo (auditoría Modo Nube §4/1 — hallazgos `E2-04` / `NEW-E2-01` / `NEW-E2-03`;
//  el único ALTA que estaba ACTIVO en producción sin depender de ningún flag).
//
//  El escenario, reproducido en simulador antes del fix: el usuario A hace «Cerrar sesión»
//  (`.privateReset`, el cierre privado anterior al paso 9, que no borraba nada) y B elige «Soy nuevo» en el MISMO dispositivo con el MISMO Apple ID.
//  `wipeAllUserData` vaciaba el corpus personal (36 TX → 0) pero el dominio Grupos quedaba intacto
//  (2 grupos, 12 gastos), `groupsBetaUnlocked` sobrevivía —B heredaba la adopción de A, que entonces era
//  el desbloqueo del código beta— y el bridge,
//  ciego a la identidad, volvía a materializar los gastos de A como `TransactionItem`/`InboxDraft`:
//  el Panel de B pasaba de «S/ 1.000 en 1 cuenta» a «S/ 900 en 2 cuentas» con gastos de A.
//
//  El fix NO cambia el alcance de `wipeAllUserData` — «Vaciar datos» de Ajustes sigue conservando Grupos
//  y su copy sigue siendo verdad; eso lo pinnean `DataWipePreservesGroupsTests` y
//  `GroupsSignOutFlowTests.personalWipe_doesNotTouchGroups`, que NO se tocan. Lo que este archivo cubre
//  es el camino NUEVO: la purga local del dominio en «empiezo de cero» + el gate que mantiene los grupos
//  re-descargados fuera de la vida personal.
//
//  **Aislamiento (lección de esta sesión).** NINGÚN test de aquí toca `UserDefaults.standard`: el
//  sello y la adopción del dominio viven en preferencias, y escribirlas en el dominio real CIERRA
//  el bridge para las suites que se interleavan con esta (Swift Testing solapa suites distintas aun
//  con `-parallel-testing-enabled NO`). La primera versión de estos tests usaba snapshot/restore de
//  `UserDefaults.standard` y puso 14 tests ajenos del bridge en rojo — con la variante peor de por
//  medio: una corrida en VERDE por suerte de orden. Por eso `wipeLocalGroupsDomain` y
//  `isDomainOpenForBridge` aceptan `defaults` inyectable y aquí siempre se les pasa
//  `makeIsolatedDefaults()`. `wipeAllUserData` (que sí toca singletons) NO se invoca en este archivo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

/// Doble del iCloud key-value store. Registra el ORDEN y la FORMA de cada escritura, no solo el estado
/// final: la aserción que carga el peso del camino de handover es «al iKV va UNA key y va como `""`» —
/// una key de más propaga a la CUENTA y un `removeObject` le quita el modo a los otros dispositivos del
/// Apple ID. Escribir al `NSUbiquitousKeyValueStore.default` real desde un test tocaría el iCloud del
/// simulador y contaminaría a las suites vecinas.
private final class RecordingKVStore: BeaconKeyValueStore, @unchecked Sendable {
    private(set) var strings: [String: String] = [:]
    private(set) var writtenKeys: [String] = []
    private(set) var removedKeys: [String] = []
    private(set) var synchronizeCalls = 0

    func setBool(_ value: Bool, forKey key: String) { record(key) }
    func setDouble(_ value: Double, forKey key: String) { record(key) }
    func setString(_ value: String, forKey key: String) {
        strings[key] = value
        record(key)
    }

    func bool(forKey key: String) -> Bool { false }
    func string(forKey key: String) -> String? { strings[key] }
    func double(forKey key: String) -> Double { 0 }

    func removeObject(forKey key: String) {
        strings[key] = nil
        removedKeys.append(key)
        record(key)
    }

    @discardableResult func synchronize() -> Bool {
        synchronizeCalls += 1
        return true
    }

    private func record(_ key: String) {
        if !writtenKeys.contains(key) { writtenKeys.append(key) }
    }
}

@MainActor
@Suite(.serialized)
struct HandoverGroupsDomainTests {

    /// Siembra un dominio Grupos completo (los 5 `Split*` + el override del bridge) más una TX
    /// personal bridgeada, que es la forma en que un gasto de grupo llega al Panel.
    private func seedGroupsDomain(in context: ModelContext) throws {
        let group = SplitGroup(name: "Viaje a Cusco")
        context.insert(group)
        let zone = group.cloudKitZoneID
        context.insert(SplitMember(groupZoneID: zone, displayName: "Ana"))
        let expense = SplitExpense(
            groupZoneID: zone, amount: 300, expenseDescription: "Cena secreta de A")
        context.insert(expense)
        context.insert(SplitShare(memberID: "m1", amount: 100, groupZoneID: zone))
        context.insert(SplitSettlement(
            groupZoneID: zone, fromMemberID: "m1", toMemberID: "m2", amount: 100))
        context.insert(GroupBridgePreference(groupZoneID: zone, bridgeOverride: false))
        try context.save()
    }

    // MARK: - Purga del dominio (el corazón del fix)

    @Test func wipeLocalGroupsDomain_deletesAllFiveSplitModelsAndBridgePreference() throws {
        let context = try makeTestContext()
        try seedGroupsDomain(in: context)

        // Sanity: sembrado correcto.
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<GroupBridgePreference>()) == 1)

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: makeIsolatedDefaults(), resetSyncState: {})

        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitMember>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitShare>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitSettlement>()) == 0)
        // `GroupBridgePreference` vive en el `personalSchema` y `wipeAllUserData` NO la nombra:
        // sin esto el bridge del usuario nuevo heredaría los overrides «TX real sí/no» del anterior.
        #expect(try context.fetchCount(FetchDescriptor<GroupBridgePreference>()) == 0)
    }

    /// El reset del estado del motor NO es opcional: borrar las filas dejando los change tokens de
    /// CKSyncEngine intactos deja a CloudKit convencido de que este dispositivo está al día ⇒ esos
    /// records no se reenvían JAMÁS y el mismo humano que vuelve pierde sus grupos de forma
    /// permanente, con los datos vivos en la nube. Un futuro «optimizador» que quite la llamada
    /// convierte el fix en pérdida de datos, y este es el test que lo nombra.
    @Test func wipeLocalGroupsDomain_alwaysPairsRowDeletionWithSyncStateReset() throws {
        let context = try makeTestContext()
        try seedGroupsDomain(in: context)

        var resetSyncStateCalls = 0
        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: makeIsolatedDefaults(),
            resetSyncState: { resetSyncStateCalls += 1 })

        #expect(resetSyncStateCalls == 1)
    }

    /// La purga es del dominio Grupos, no del corpus personal: quien vacía lo personal es
    /// `wipeAllUserData` (que corre justo antes en el mismo camino). Si esta función empezara a
    /// borrar entidades personales, el reseed del onboarding correría sobre un grafo mutilado.
    @Test func wipeLocalGroupsDomain_leavesPersonalCorpusAlone() throws {
        let context = try makeTestContext()
        try seedGroupsDomain(in: context)
        context.insert(Account(
            name: "Efectivo", currencyCode: "PEN", colorHex: "#111111",
            iconName: "banknote", type: "cash"))
        context.insert(Yala.Tag(name: "Comida"))
        try context.save()

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: makeIsolatedDefaults(), resetSyncState: {})

        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Yala.Tag>()) == 1)
    }

    // MARK: - Preferencias del dominio

    @Test func removeGroupsDomainPreferenceKeys_clearsBetaGateAndPerGroupPrefixes() throws {
        let defaults = makeIsolatedDefaults()

        defaults.set(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)
        defaults.set(true, forKey: AppPreferences.Keys.hasShownGroupsOnboarding)
        defaults.set(true, forKey: AppPreferences.Keys.hasSeenGroupsNotificationPrompt)
        defaults.set("acct-1", forKey: "groupPrefs_zone1_settlementAccount_PEN")
        defaults.set(Date.now, forKey: "GroupNotifications.lastNotified.zone1")
        // Vecinas que NO son del dominio Grupos: la purga no debe pasarse de largo.
        defaults.set("keepMe", forKey: "userTheme")
        defaults.set("keepMe", forKey: "groupsSomethingElse")

        DataWipeService.removeGroupsDomainPreferenceKeys(from: defaults)

        // La adopción per-device es LA pieza que cierra la puerta: heredada del usuario anterior,
        // el sello nace neutralizado (`GroupsDomainAdoptionLogic.isDomainOpen`).
        #expect(defaults.object(forKey: AppPreferences.Keys.groupsBetaUnlocked) == nil)
        #expect(defaults.object(forKey: AppPreferences.Keys.hasShownGroupsOnboarding) == nil)
        #expect(defaults.object(forKey: AppPreferences.Keys.hasSeenGroupsNotificationPrompt) == nil)
        #expect(defaults.object(forKey: "groupPrefs_zone1_settlementAccount_PEN") == nil)
        #expect(defaults.object(forKey: "GroupNotifications.lastNotified.zone1") == nil)
        #expect(defaults.string(forKey: "userTheme") == "keepMe")
        #expect(defaults.string(forKey: "groupsSomethingElse") == "keepMe")
    }

    /// `groupsBetaUnlocked` sigue siendo exclusión deliberada del wipe NORMAL (adopción per-device de
    /// «Vaciar datos», pinneado en `DataWipeServiceTests.preservedKeys_surviveReset`). Las dos
    /// direcciones importan: el barrido general la conserva, el del handover se la lleva.
    @Test func generalPreferenceSweep_stillPreservesBetaGate() throws {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)

        DataWipeService.removeUserPreferenceKeys(from: defaults)

        #expect(defaults.bool(forKey: AppPreferences.Keys.groupsBetaUnlocked) == true)
    }

    // MARK: - El eje 1 y el relevo de humano (el segundo término de `isDomainOpen`)

    /// **El escenario completo del bug**, dicho con el eje nuevo: el humano anterior no tenía sesión
    /// privada en este teléfono (entró por invitación o por el alta solo-grupos), así que
    /// `isDomainOpen` daba `true` por su SEGUNDO término y el sello quedaba neutralizado sin ningún
    /// acto deliberado del usuario nuevo. El relevo borra la marca, y con ella ese término.
    @Test func wipeLocalGroupsDomain_clearsThePrivateSessionMark_soTheSealSurvives() throws {
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults()
        PrivateSessionMark.set(false, defaults)

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: defaults, resetSyncState: {})

        // 1. La marca vuelve a AUSENTE, que es como nace un teléfono recién instalado.
        #expect(PrivateSessionMark.raw(defaults) == nil)

        // 2. Y con la marca ausente el sello vuelve a cortar el bridge: la lectura por defecto cae
        //    del lado conservador (`true`), así que el segundo término ya no abre la puerta.
        #expect(GroupsDomainAdoptionLogic.isDomainOpen(
            isUnlocked: defaults.bool(forKey: AppPreferences.Keys.groupsBetaUnlocked),
            hasPrivateSession: PrivateSessionMark.hasPrivateSession(defaults)) == false)
        #expect(GroupsDomainAdoptionLogic.isBridgeAllowed(
            sealedForFreshStart: defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart),
            isUnlocked: defaults.bool(forKey: AppPreferences.Keys.groupsBetaUnlocked),
            hasPrivateSession: PrivateSessionMark.hasPrivateSession(defaults)) == false)
    }

    /// **La invariante del camino**: al iKV del Apple ID no va NADA. Lo que se escriba o se borre ahí
    /// viaja a TODOS los dispositivos de esa persona, y este camino solo declara el relevo de humano
    /// en ESTE dispositivo. Antes iba una sola key —el flag de onboarding, que sí viajaba— y desde que
    /// el eje es un hecho del dispositivo la lista correcta está VACÍA.
    @Test func wipeLocalGroupsDomain_touchesNothingInTheIKV() throws {
        let context = try makeTestContext()
        let iKV = RecordingKVStore()

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: makeIsolatedDefaults(), resetSyncState: {})

        #expect(iKV.writtenKeys.isEmpty)
        #expect(iKV.removedKeys.isEmpty)
    }


    /// El sello es lo que hace que el bridge se cierre; sin él el bridge sigue abierto.
    @Test func wipeLocalGroupsDomain_sealsTheDomainForTheIncomingUser() throws {
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults()
        #expect(defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart) == false)

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: defaults, resetSyncState: {})

        #expect(defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart) == true)
    }

    // MARK: - Gate de dominio (pure logic)

    @Test func isDomainOpen_onlyWithADeliberateActOnThisDevice() {
        #expect(GroupsDomainAdoptionLogic.isDomainOpen(isUnlocked: false, hasPrivateSession: true) == false)
        #expect(GroupsDomainAdoptionLogic.isDomainOpen(isUnlocked: true, hasPrivateSession: true) == true)
        #expect(GroupsDomainAdoptionLogic.isDomainOpen(isUnlocked: false, hasPrivateSession: false) == true)
        #expect(GroupsDomainAdoptionLogic.isDomainOpen(isUnlocked: true, hasPrivateSession: false) == true)
    }

    /// **El test que impide el falso negativo**: sin sello el bridge está SIEMPRE permitido, incluido
    /// el caso `isUnlocked: false` — que es el estado por DEFECTO de cualquier usuario que aún no
    /// abrió Grupos. Un gate general habría convertido este fix en «mis gastos de grupo no aparecen»
    /// para toda esa cohorte, en silencio (14 tests del bridge en rojo lo destaparon durante la
    /// implementación; en producción no habría habido quien avisara).
    @Test func isBridgeAllowed_withoutSeal_alwaysPermits() {
        for unlocked in [true, false] {
            for privada in [true, false] {
                #expect(
                    GroupsDomainAdoptionLogic.isBridgeAllowed(
                        sealedForFreshStart: false, isUnlocked: unlocked, hasPrivateSession: privada)
                        == true)
            }
        }
    }

    /// Con sello, la puerta de Grupos manda: cerrada bloquea, y cualquier acto deliberado de adopción
    /// (entrar al tab, invitación o alta solo-grupos) la reabre sin necesidad de borrar el sello.
    @Test func isBridgeAllowed_withSeal_followsTheGroupsDoor() {
        #expect(
            GroupsDomainAdoptionLogic.isBridgeAllowed(
                sealedForFreshStart: true, isUnlocked: false, hasPrivateSession: true) == false)
        #expect(
            GroupsDomainAdoptionLogic.isBridgeAllowed(
                sealedForFreshStart: true, isUnlocked: true, hasPrivateSession: true) == true)
        #expect(
            GroupsDomainAdoptionLogic.isBridgeAllowed(
                sealedForFreshStart: true, isUnlocked: false, hasPrivateSession: false) == true)
    }

    /// El sello NO es una preferencia de usuario: el wipe normal («Vaciar datos») no debe borrarlo —
    /// hacerlo reabriría el bridge en un dispositivo que ya declaró el relevo.
    @Test func generalPreferenceSweep_preservesTheHandoverSeal() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart)

        DataWipeService.removeUserPreferenceKeys(from: defaults)

        #expect(defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart) == true)
    }

    // El test `gateAndDomain_areExactInverses` vivía aquí y pinneaba que la puerta de la UI y la
    // del bridge eran el MISMO predicado invertido. Se retiró en 2.1 con el gate beta: la pregunta
    // de la UI ya no existe —Grupos se ve siempre— así que no hay dos puertas que puedan discrepar.
    // Lo que sobrevive de esa SSOT son los dos términos de `isDomainOpen`, que pinnean
    // `isDomainOpen_onlyWithADeliberateActOnThisDevice` (aquí) y
    // `GroupsDomainAdoptionTests.isDomainOpen_keepsBothTerms`.

    /// Contrato explícito del adaptador BAJO EL RUNNER: el sello se ignora, así que el bridge nunca
    /// queda cerrado en unit tests. No es un descuido — el host de los tests comparte el
    /// `UserDefaults.standard` del simulador, y verificar el handover a mano ahí dejaría el sello
    /// escrito y cerraría el bridge para las 14 pruebas de comportamiento que lo necesitan abierto.
    /// La rama sellada se cubre en `isBridgeAllowed_withSeal_followsTheGroupsDoor` (pure logic), en el
    /// source-scan del seam, y end-to-end en simulador.
    ///
    /// `SessionState.shared.hasPrivateSession` sí es un singleton compartido: se fija y se restaura en el
    /// `defer` (la suite es `.serialized`). `UserDefaults.standard` no se toca en ningún punto.
    @Test func isDomainOpenForBridge_underTestRunner_ignoresTheSeal() {
        let previousPrivateSession = SessionState.shared.hasPrivateSession
        defer { SessionState.shared.hasPrivateSession = previousPrivateSession }
        SessionState.shared.hasPrivateSession = true
        let defaults = makeIsolatedDefaults()

        #expect(GroupTransactionBridge.isDomainOpenForBridge(defaults: defaults) == true)

        defaults.set(true, forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart)
        #expect(SwiftDataConfiguration.isRunningTests == true)
        #expect(GroupTransactionBridge.isDomainOpenForBridge(defaults: defaults) == true)
    }

    // MARK: - 2.7 · El seam del handover: el outbox MUERE, el cursor SOBREVIVE

    private func makeOutboxRow(group: String, in context: ModelContext) {
        context.insert(GroupSyncOutbox(
            syncID: UUID(), groupID: group, entityType: "SplitExpense",
            op: .upsert, hlc: "hlc", fieldsJSON: "{\"amount\":300}", author: "a",
            rejectedReason: nil))
    }

    /// El corazón de 2.7, y la razón de que NO sea «repuntar el default a `purgeGroupsSyncState`»: los
    /// dos objetos de `syncMetaSchema` tienen signos OPUESTOS en una frontera de usuario.
    ///
    /// El outbox son escrituras PENDIENTES del humano anterior, y el JWT de la sesión Nube sobrevive al
    /// relevo (Keychain propio) ⇒ se subirían firmadas como suyas. El cursor, en cambio, es la BARRERA
    /// que impide que el corpus del anterior BAJE a este device con ese mismo JWT (bug `31dded30`).
    /// Un fix que borre los dos cierra una fuga y abre la otra.
    @Test func wipeLocalGroupsDomain_killsTheOutbox_butKEEPSTheCursor() throws {
        let context = try makeTestContext()
        try seedGroupsDomain(in: context)
        makeOutboxRow(group: "g1", in: context)
        makeOutboxRow(group: "g2", in: context)
        context.insert(GroupSyncCursor(groupCursorsJSON: "{\"g1\":5}"))
        try context.save()

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: makeIsolatedDefaults(), resetSyncState: {})

        #expect(try context.fetchCount(FetchDescriptor<GroupSyncOutbox>()) == 0,
                "Las escrituras pendientes del humano anterior se subirían con su JWT, que sobrevive.")
        #expect(try context.fetchCount(FetchDescriptor<GroupSyncCursor>()) == 1,
                "REGRESIÓN `31dded30`: sin cursor, el corpus del anterior baja al device del nuevo.")
    }

    /// El cursor no solo sobrevive como FILA: conserva su CONTENIDO. Un fix que lo vaciara «para
    /// limpiar» sería indistinguible de borrarlo — un cursor vacío no suprime ningún re-pull.
    @Test func wipeLocalGroupsDomain_cursorKeepsItsContent_notJustItsRow() throws {
        let context = try makeTestContext()
        context.insert(GroupSyncCursor(groupCursorsJSON: "{\"g1\":5}"))
        try context.save()

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: makeIsolatedDefaults(), resetSyncState: {})

        let cursors = try context.fetch(FetchDescriptor<GroupSyncCursor>())
        #expect(cursors.first?.groupCursorsJSON == "{\"g1\":5}")
    }

    // MARK: - El wipe borra, y eso hay que pinearlo

    /// El caso normal, y no es decorativo: un guard demasiado agresivo —que se negara SIEMPRE— rompería
    /// «Empiezo de cero» para todo el mundo sin que nada más lo destapara.
    @Test func wipeLocalGroupsDomain_wipesTheGroupsDomain() throws {
        let context = try makeTestContext()
        try seedGroupsDomain(in: context)

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: makeIsolatedDefaults(), resetSyncState: {})

        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<GroupBridgePreference>()) == 0)
    }
}

/// Cableado de producción (source-scan). El pipeline completo del bridge está en la Lista Negra R8
/// (race de CloudKit con `makeTestContext` en simulador), así que un test de comportamiento no puede
/// cubrir los puntos de corte. Estos scans nombran al culpable si alguien los quita: sin ellos, borrar
/// un `guard` de dos líneas reintroduce la fuga entera con toda la suite en verde.
/// Mismo patrón y misma razón que `SignOutNotificationWiringTests`.
@Suite("Handover · cableado de producción (source-scan)")
struct HandoverGroupsWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Solo las líneas de CÓDIGO. Los scans que CUENTAN ocurrencias tienen que filtrar comentarios, o
    /// documentar el invariante que el test cuenta lo pone en rojo sin que producción cambie — es la regla
    /// de `.claude/rules/testing.md`, y este test cuenta.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de una función, por conteo de llaves desde su firma. Devuelve solo código.
    private static func body(of signature: String, in source: String) throws -> String {
        let code = codeOnly(source)
        let start = try #require(code.range(of: signature), "no está la firma: \(signature)")
        var depth = 0
        var out = ""
        for ch in code[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" {
                if depth == 0 { break }
                depth -= 1
            }
            out.append(ch)
        }
        return out
    }

    /// **Los DOS caminos de «empiezo de cero» purgan el dominio Grupos, y son dos superficies distintas.**
    /// Los otros 3 call-sites de `wipeAllUserData` (Ajustes, wipe remoto, reset de XCUITest) NO deben
    /// purgarlo — ahí es el mismo usuario y el copy promete que sus grupos se conservan.
    ///
    /// **C2 movió el alert de `ContentView` a `ShellDataAlertsModifier`**, y no por gusto: con él
    /// inline el getter de `ContentView.body` tardaba 591 s en type-checkear y la compilación moría. El
    /// escáner apunta al fichero nuevo; los cuerpos son literales, no cambió ninguna decisión.
    ///
    /// **El segundo camino llegó el 2026-09-13, y hasta entonces este test prohibía el literal en
    /// `ContentView` ENTERO.** La prohibición era correcta por su motivo —dos copias del mismo ALERT es
    /// la regla (4) de Presentaciones con un wipe destructivo detrás— pero medía otra cosa: el fichero,
    /// no el alert. Con el mount neutro de una sesión solo-grupos, la rama privada sale por el
    /// relanzamiento y el alert NUNCA se monta, así que su purga tampoco corría; el aviso vive ahora en la
    /// puerta privada, que es un STEP del cover del Welcome, y su borrado
    /// (`ContentView.performDeviceCorpusWipe`) necesita el mismo par. Lo que se conserva es lo que el test
    /// quería decir: **una purga por superficie, y ningún alert duplicado**.
    @Test func bothFreshStartPaths_purgeTheGroupsDomain() throws {
        let src = Self.codeOnly(try Self.source("Yala/App/Views/Shared/ShellDataAlertsModifier.swift"))
        #expect(src.components(separatedBy: "DataWipeService.wipeLocalGroupsDomain(in: modelContext)").count - 1 == 1)

        let contentViewSource = try Self.source("Yala/App/ContentView.swift")
        let contentView = Self.codeOnly(contentViewSource)
        #expect(contentView.components(separatedBy: "DataWipeService.wipeLocalGroupsDomain(in: modelContext)").count - 1 == 2, """
            en `ContentView` la purga del dominio va EXACTAMENTE dos veces, una por cada celda del aviso de
            la puerta privada: el borrado del TELÉFONO (`performDeviceCorpusWipe`) y el de iCloud cuando
            además se lleva las filas locales (`performICloudCorpusWipe`, dentro de su guard). Menos
            significa que una de las dos dejó de sellar el handover —y el corpus de la etapa anterior acaba
            en el iCloud del Apple ID siguiente—; más, que hay un borrador suelto en el fichero.
            """)
        for (funcion, porque) in [
            ("private func performDeviceCorpusWipe() async -> String? {",
             "el borrado del teléfono tiene que llevarse el dominio y sellar en el mismo gesto"),
            ("private func performICloudCorpusWipe(includingLocalRows: Bool = true) async -> String? {",
             "la celda «iCloud con datos» deja los grupos vivos y el bridge abierto sin esto")] {
            let cuerpo = try Self.body(of: funcion, in: contentViewSource)
            #expect(cuerpo.contains("DataWipeService.wipeLocalGroupsDomain(in: modelContext)"),
                    Comment(rawValue: "la purga se salió de `\(funcion)`: \(porque)."))
        }
        // Y el alert sigue sin duplicarse, que es lo que este test vigilaba de origen: la regla (4) de
        // Presentaciones con un wipe destructivo detrás.
        #expect(!contentView.contains(".alert(L10n.Welcome.FreshStart.alertTitle"), """
            el alert de fresh-start volvió a `ContentView` sin salir de `ShellDataAlertsModifier`: hay
            DOS presentaciones del mismo alert destructivo colgando del mismo anchor.
            """)
    }

    /// El wipe de Ajustes («Vaciar datos») JAMÁS purga Grupos: su hoja de alcance promete
    /// explícitamente «Esto no incluye tus grupos».
    @Test func settingsWipe_neverPurgesTheGroupsDomain() throws {
        let src = try Self.source("Yala/App/Views/Settings/UserDataResetView.swift")
        #expect(!src.contains("wipeLocalGroupsDomain"))
    }

    /// Los dos puntos de creación del bridge y la cola de reintentos del boot están gateados por el
    /// dominio. `unbridge*`/`freezeForSoftDelete` NO: cerrar la puerta jamás debe impedir LIMPIAR.
    @Test func bridgeCreationPaths_areGatedByDomain() throws {
        let bridge = try Self.source("Yala/Services/Groups/GroupTransactionBridge.swift")
        #expect(bridge.components(separatedBy: "guard Self.isDomainOpenForBridge() else").count - 1 == 2)

        let bootstrapper = try Self.source("Yala/App/AppBootstrapper.swift")
        #expect(bootstrapper.contains("guard GroupTransactionBridge.isDomainOpenForBridge() else"))
    }

    /// El seam de runner del gate es `isRunningTests` y NADA más ancho: `isUITesting` dejaría el sello
    /// inerte en los XCUITest (que sí deben poder ejercitarlo) y un `#if DEBUG` lo mataría en release,
    /// que es justo donde el fix tiene que actuar.
    @Test func bridgeGate_runnerSeam_isNarrow() throws {
        let src = try Self.source("Yala/Services/Groups/GroupTransactionBridge.swift")
        #expect(src.contains("!SwiftDataConfiguration.isRunningTests"))
        #expect(!src.contains("isUITesting"))
        guard let range = src.range(of: "static func isDomainOpenForBridge") else {
            Issue.record("isDomainOpenForBridge desapareció o cambió de firma")
            return
        }
        #expect(!src[range.lowerBound...].prefix(600).contains("#if DEBUG"))
    }

    /// El detector de datos previos cuenta los grupos y lo bridgeado. Sin eso, un usuario anterior que
    /// venía de «Solo Grupos» (sin cuentas ni categorías propias) daba `false` y «Soy nuevo» no corría
    /// wipe ALGUNO: el usuario nuevo aterrizaba con las transacciones del anterior intactas
    /// (`NEW-E2-03`). El scan resuelve la función contenedora para que el pin no lo satisfaga
    /// cualquier otra mención de `SplitGroup` en el archivo.
    @Test func existingDataCheck_countsGroupsAndBridgedRows() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        guard let start = src.range(of: "private func checkHasExistingData() -> Bool {") else {
            Issue.record("checkHasExistingData desapareció o cambió de firma")
            return
        }
        // Ventana fija desde la firma: el cuerpo lleva closures de `#Predicate`, así que cortar por
        // el primer `}` pararía dentro del primer predicado.
        let body = src[start.upperBound...].prefix(1_200)
        #expect(body.contains("FetchDescriptor<SplitGroup>()"))
        #expect(body.contains("$0.splitExpenseID != nil"))
    }

    /// Las dos mitades que un contexto in-memory no puede ver, y que son justo donde se rompería:
    ///
    ///  1. **El espejo del App Group.** Borrar las filas sin purgarlo es COSMÉTICO:
    ///     `GroupsSyncClient.rehydrateOutboxFromMirror` las re-inserta al próximo boot. Su filtro por
    ///     `userID` no protege aquí — este camino NO cierra la sesión, así que la identidad casa.
    ///  2. **No reusar `purgeGroupsSyncState`.** Es la regresión que haría quien lea el plan de la Fase 2
    ///     (§2.7 decía «repuntar el default a `CloudSessionSignOut.purgeGroupsSyncState`»): esa función
    ///     borra outbox **y** cursor, y su propio docblock acota su uso a «tras el teardown (generación
    ///     cortada)», precondición que este camino no cumple.
    /// El wipe tiene que llamar al borrado del eje 1 y **no puede tocar el iCloud-KV**.
    ///
    /// El seam del iKV se retiró de la firma el 2026-09-13: el eje nuevo no viaja, así que el parámetro
    /// se había quedado sin un solo lector en el cuerpo — una inyección viva hacia el KV del Apple ID que
    /// alguien podía volver a cablear sin releer por qué se quitó. Lo que el test prohíbe ahora es más
    /// fuerte que antes: que la función vuelva a tener por dónde escribir ahí.
    @Test func handoverWipe_clearsThePrivateSessionMark_andWritesNothingToTheIKV() throws {
        let src = try Self.source("Yala/Utils/DataWipeService.swift")
        #expect(!src.contains("iKV: BeaconKeyValueStore"), """
            `wipeLocalGroupsDomain` volvió a aceptar un store del iCloud-KV. El relevo de humano es un
            hecho de ESTE teléfono: lo que se escriba ahí viaja a todos los dispositivos de la persona.
            """)
        #expect(src.contains("clearHandoverPrivateSessionMark(from: defaults)"))
        // El eje 1 es un hecho del DISPOSITIVO y no viaja: escribirlo al iKV se lo impondría a los demás
        // dispositivos del Apple ID, que es justo el daño que el modelo nuevo evita.
        #expect(!src.contains("forKey: PrivateSessionMark.userDefaultsKey)"),
                "La marca no se escribe ni se borra en el iCloud-KV: nunca viaja.")
    }

    @Test func wipeSeam_purgesTheAppGroupMirror_andNeverReusesTheSignOutPurge() throws {
        let src = try Self.source("Yala/Utils/DataWipeService.swift")
        #expect(src.contains("GroupsOutboxMirror()?.purgeAll()"),
                "Sin purgar el espejo, el rehydrate del boot repuebla el outbox del humano anterior.")
        // El `(` es deliberado: ata la aserción a la LLAMADA, no a la mención. El fichero NOMBRA esa
        // función en el comentario que explica por qué no la usa, y una aserción sobre el nombre pelado
        // se pondría roja por su propia documentación.
        #expect(!src.contains("purgeGroupsSyncState("),
                "Borra también el cursor ⇒ reabre `31dded30`. El par correcto es outbox muerto + cursor vivo.")
    }
}
