//
//  WelcomeKeptGroupsTests.swift
//  YalaTests / CloudSync
//
//  Ticket `groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start`, decisión A de Jürgen (2026-10-04).
//
//  «Encontramos datos tuyos en iCloud» → «Empezar de cero» conserva los grupos y devuelve a la persona al onboarding. Si
//  ahí tocaba «Cancelar» y volvía a elegir «Es mi primera vez → privado», el Welcome contaba esos grupos como datos de
//  OTRA persona y le ofrecía el borrado del handover: grupos, sesión de Grupos y sello. Ahora el aviso deja una marca
//  (`LateNoticeKeptGroupsMark`, atada a la sesión de Grupos de ese momento) y el Welcome sigue el camino de la misma
//  persona. Sin la marca —el handover real— todo sigue como antes.
//
//  Dos caminos que fija este fichero, con control positivo en los dos sentidos:
//   · misma persona tras el aviso → sin alert, sin retirar la sesión, sin borrado que purgue;
//   · handover real (sin aviso previo) → el alert y el borrado de siempre.
//
//  Mutantes que matan (medidos, ver el PR):
//   (1) `deviceDataForWelcome` ignorando la marca → la tabla.
//   (2) `deviceDataForWelcome` ignorando lo personal con la marca → la tabla.
//   (3) `freshStartRetiresThePreviousPerson` devolviendo `true` siempre → la tabla.
//   (4) `welcomeICloudWipeScope` devolviendo `.handover` siempre → la tabla.
//   (5) la marca sin atarse a la sesión (`vouches` = «hay marca»), o caída al perder la sesión → su vida.
//   (6) `retireIfOnboardingCompleted` sin mirar el onboarding → su vida.
//   (7) `wipeLocalGroupsDomain` sin retirar la marca → el borrado del dominio.
//   (8) el aviso tardío sin escribir la marca, o escribiéndola fuera de la rama que conserva → el cableado.
//   (9) `startFreshPrivateOnboarding` preguntando con el detector entero → el cableado.
//   (10) las cuatro limpiezas de la persona anterior fuera del `if` → el cableado.
//   (11) el portal del relanzamiento armando el retiro de la sesión con la marca → el cableado.
//   (12) el borrado del Welcome con `.handover` fijo → el cableado.
//   (13) la transición del onboarding sin retirar la marca → el cableado.
//   (14) el borrado del teléfono o el del alert purgando con la marca → el cableado.
//   (15) `groupsKeptForThisPersonNow` cableado a `{ false }`, o el detector de grupos sin las puenteadas → el cableado.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized, .wipeAppGroupMirrorIsolated)
struct WelcomeKeptGroupsTests {

    // MARK: - La tabla

    @Test("el Welcome cuenta los grupos como de otro SOLO sin la marca del aviso tardío",
          arguments: [false, true], [false, true])
    func deviceData_table(_ personal: Bool, _ groups: Bool) {
        let withoutMark = WelcomeKeptGroupsLogic.deviceDataForWelcome(
            hasPersonalData: personal, hasGroupsData: groups, groupsKeptForThisPerson: false)
        #expect(withoutMark == (personal || groups), """
            sin la marca el Welcome tiene que preguntar como siempre por cualquier dato del teléfono —es el handover real—: \
            personal=\(personal) grupos=\(groups)
            """)
        let withMark = WelcomeKeptGroupsLogic.deviceDataForWelcome(
            hasPersonalData: personal, hasGroupsData: groups, groupsKeptForThisPerson: true)
        #expect(withMark == personal, """
            con la marca, los grupos son de quien está delante y solo cuenta lo personal: \
            personal=\(personal) grupos=\(groups)
            """)
    }

    @Test("el caso del ticket: solo los grupos conservados no levantan el alert; sin la marca sí")
    func deviceData_theTicketCase() {
        #expect(!WelcomeKeptGroupsLogic.deviceDataForWelcome(
            hasPersonalData: false, hasGroupsData: true, groupsKeptForThisPerson: true), """
            quien conservó sus grupos en el aviso, canceló el onboarding y vuelve a elegir privado ve el alert del handover
            """)
        #expect(WelcomeKeptGroupsLogic.deviceDataForWelcome(
            hasPersonalData: false, hasGroupsData: true, groupsKeptForThisPerson: false), """
            sin aviso previo, los grupos de otra persona dejarían de pedir el borrado del handover
            """)
    }

    @Test("«Es mi primera vez» retira a la persona anterior solo sin la marca")
    func freshStartRetires_table() {
        #expect(WelcomeKeptGroupsLogic.freshStartRetiresThePreviousPerson(groupsKeptForThisPerson: false))
        #expect(!WelcomeKeptGroupsLogic.freshStartRetiresThePreviousPerson(groupsKeptForThisPerson: true), """
            con los grupos que conservó el aviso, retirar la sesión de Grupos y su asociación es el handover que la \
            decisión A le quitó a este camino
            """)
    }

    @Test("los borrados del teléfono del Welcome purgan el dominio solo sin la marca")
    func deviceWipePurges_table() {
        #expect(WelcomeKeptGroupsLogic.deviceWipePurgesTheGroupsDomain(groupsKeptForThisPerson: false), """
            el handover real dejaría de purgar y sellar los grupos de la persona anterior al borrar el teléfono
            """)
        #expect(!WelcomeKeptGroupsLogic.deviceWipePurgesTheGroupsDomain(groupsKeptForThisPerson: true), """
            con datos personales de vuelta, el alert o la puerta purgarían los grupos que el aviso acaba de conservar
            """)
    }

    @Test("el borrado de «Encontramos datos» del Welcome es `.handover` sin la marca e `.importedRows` con ella")
    func welcomeICloudWipeScope_table() {
        let without = WelcomeKeptGroupsLogic.welcomeICloudWipeScope(groupsKeptForThisPerson: false)
        #expect(without == .handover)
        #expect(without.purgesGroupsDomain, "el handover real dejaría de purgar y sellar el dominio de la persona anterior")
        let with = WelcomeKeptGroupsLogic.welcomeICloudWipeScope(groupsKeptForThisPerson: true)
        #expect(with == .importedRows)
        #expect(!with.purgesGroupsDomain, "la misma persona perdería los grupos que el aviso acababa de conservar")
        #expect(with.deletesLocalRows, "sin borrar las filas, el espejo re-exportaría a la zona recién vaciada")
    }

    // MARK: - La vida de la marca

    @Test("sin marca no avala nada")
    func mark_absent_vouchesNothing() {
        let defaults = makeIsolatedDefaults()
        #expect(!LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: nil, defaults))
        #expect(!LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: "abc", defaults))
    }

    @Test("la marca deja de valer con OTRA cuenta de Grupos delante; con la misma, o sin ninguna, vale")
    func mark_isBoundToTheSession() {
        let defaults = makeIsolatedDefaults()
        LateNoticeKeptGroupsMark.record(sessionSub: "sub-a", defaults)
        #expect(LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: "sub-a", defaults))
        #expect(!LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: "sub-b", defaults), """
            con otra cuenta de Grupos delante, la marca le daría los grupos de la primera
            """)
        #expect(LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: nil, defaults), """
            que la sesión se vaya no prueba que haya otra persona: el guard cross-cuenta del Welcome cierra la que la \
            propia persona acaba de abrir, y perder la marca ahí devolvía el handover (review adversarial)
            """)
    }

    @Test("sin sesión al conservarlos, vale mientras siga sin haberla")
    func mark_withoutSession() {
        let defaults = makeIsolatedDefaults()
        LateNoticeKeptGroupsMark.record(sessionSub: nil, defaults)
        #expect(LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: nil, defaults))
        #expect(!LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: "sub-a", defaults), """
            una sesión de Grupos que aparece después es de alguien que entró: la marca no la cubre
            """)
    }

    @Test("`clear` la retira")
    func mark_clear() {
        let defaults = makeIsolatedDefaults()
        LateNoticeKeptGroupsMark.record(sessionSub: "sub-a", defaults)
        LateNoticeKeptGroupsMark.clear(defaults)
        #expect(!LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: "sub-a", defaults))
    }

    @Test("el barrido del arranque la retira con el onboarding completo y la deja sin él", arguments: [false, true])
    func mark_bootSweep(_ onboardingDone: Bool) {
        let defaults = makeIsolatedDefaults()
        defaults.set(onboardingDone, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        LateNoticeKeptGroupsMark.record(sessionSub: "sub-a", defaults)
        LateNoticeKeptGroupsMark.retireIfOnboardingCompleted(defaults)
        #expect(LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: "sub-a", defaults) == !onboardingDone, """
            onboarding=\(onboardingDone): con él completo la marca ya no describe a nadie del Welcome; sin él, es la que \
            el Welcome tiene que leer
            """)
    }

    // MARK: - El borrado del dominio se la lleva

    @Test("el borrado del dominio de Grupos retira la marca, y sin él sigue")
    func groupsDomainWipe_retiresTheMark() throws {
        let context = try makeTestContext()
        let group = SplitGroup(name: "Viaje")
        context.insert(group)
        try context.save()

        let defaults = makeIsolatedDefaults()
        LateNoticeKeptGroupsMark.record(sessionSub: nil, defaults)
        // Control del montaje: la marca está puesta y vale antes del borrado.
        #expect(LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: nil, defaults))
        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: defaults, retireCloudSession: {}, resetSyncState: {}, witness: .quiet)
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0)
        #expect(!LateNoticeKeptGroupsMark.vouches(forCurrentSessionSub: nil, defaults), """
            los grupos que describía la marca ya no están; viva, avalaría los de quien entre después
            """)
    }

    // MARK: - El cableado

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Fuente sin líneas de comentario: documentar un invariante no puede hacer que se «cumpla».
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo entre llaves balanceadas a partir de un marcador.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    /// Lo que va desde un `case` del `switch` hasta el siguiente `case .` (o el final): el cuerpo de ESE caso.
    private static func caseBody(_ marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let rest = source[start.upperBound...]
        let end = rest.range(of: "\n            case .")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    /// Normalizado: líneas trimmeadas y unidas por un espacio, para fijar una expresión que ocupa varias líneas.
    private static func normalized(_ text: String) -> String {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    @Test("el aviso tardío escribe la marca en la rama que conserva los grupos, detrás del corte del fallo")
    func lateWipe_recordsTheMarkWhenItKeepsGroups() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let wipe = try Self.body(of: "private func performLateICloudWipe(finishingPendingWipe: Bool) async -> String? {",
                                 in: src)
        let kept = try Self.body(of: "if !scope.purgesGroupsDomain {", in: wipe)
        #expect(kept.contains("LateNoticeKeptGroupsMark.recordNow()"), """
            el aviso conserva los grupos y no lo apunta: al cancelar el onboarding, el Welcome los vuelve a ver como de otro
            """)
        #expect(Self.normalized(wipe).components(separatedBy: "LateNoticeKeptGroupsMark.").count == 2, """
            la marca se escribe fuera de la rama que conserva: un `.handover` la dejaría puesta sobre un dominio vacío
            """)
        let guardRange = try #require(wipe.range(of: "guard failure == nil else { return failure }"))
        let markRange = try #require(wipe.range(of: "LateNoticeKeptGroupsMark.recordNow()"))
        #expect(guardRange.upperBound <= markRange.lowerBound, "la marca se escribe aunque el borrado haya fallado")
    }

    @Test("«Es mi primera vez» pregunta con el detector del Welcome y retira a la persona anterior solo sin la marca")
    func startFresh_wiring() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let fresh = try Self.body(of: "private func startFreshPrivateOnboarding() {", in: src)
        #expect(fresh.contains("if welcomeDeviceDataNow() {"), """
            el alert vuelve a preguntar con el detector entero: cuenta los grupos que el aviso conservó como de otro
            """)
        #expect(!fresh.contains("hasLocalDataNow()"), "queda una lectura del detector entero dentro de la decisión")
        let elseBranch = try Self.body(of: "} else {", in: fresh)
        let retires = try Self.body(
            of: "if WelcomeKeptGroupsLogic.freshStartRetiresThePreviousPerson( groupsKeptForThisPerson: groupsKeptForThisPerson) {",
            in: Self.normalized(elseBranch))
        for cleanup in ["OnboardingResetHelper.clearResidualPreferencesForFreshStart()",
                        "CloudSessionRetirement.retireForHandover()",
                        "UserDefaults.standard.removeObject(forKey: GroupsAccountAssociation.localKey)",
                        "UserDefaults.standard.removeObject(forKey: GroupsSessionHistoryMarker.key)"] {
            #expect(retires.contains(cleanup), "«\(cleanup)» salió del `if` de la persona anterior")
            #expect(Self.normalized(elseBranch).components(separatedBy: cleanup).count == 2,
                    "«\(cleanup)» corre también fuera del `if`: se lo hace a quien conservó sus grupos")
        }
        // El resto de la rama sigue siendo de todos: la navegación y el «a medias».
        #expect(elseBranch.contains("StorageModePersistence.clearICloudCorpusWipeLeftHalfway()"))
        #expect(!retires.contains("showOnboarding = true"), "la persona del aviso se queda sin onboarding")
        #expect(elseBranch.contains("showOnboarding = true"))
    }

    @Test("el portal del relanzamiento arma el retiro de la sesión solo sin la marca")
    func mirrorRelaunch_wiring() throws {
        let src = Self.normalized(try Self.code("Yala/App/ContentView.swift"))
        let marker = "if destination == .privateOnboarding, "
            + "WelcomeKeptGroupsLogic.freshStartRetiresThePreviousPerson( "
            + "groupsKeptForThisPerson: groupsKeptForThisPersonNow()) {"
        let branch = try Self.body(of: marker, in: src)
        #expect(branch.contains("OnboardingResetHelper.clearResidualPreferencesForFreshStart()"))
        #expect(branch.contains("CloudSessionRetirement.arm(defaults: .standard)"), """
            sin armar el retiro, el mount neutro llega al onboarding con la sesión de la persona anterior
            """)
        #expect(src.components(separatedBy: "CloudSessionRetirement.arm(defaults: .standard)").count == 2,
                "el arm del retiro se escribe también fuera del `if`")
    }

    @Test("el borrado de «Encontramos datos» del Welcome elige el alcance con la marca y repone lo puenteado")
    func welcomeWipe_wiring() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let wrapper = Self.normalized(try Self.body(of: "performICloudCorpusWipe: {\n                cancelWipeGrace()",
                                                    in: src))
        #expect(wrapper.contains("let scope = WelcomeKeptGroupsLogic.welcomeICloudWipeScope( "
                                 + "groupsKeptForThisPerson: LateNoticeKeptGroupsMark.vouchesNow())"))
        #expect(wrapper.contains("let failure = await performICloudCorpusWipe(scope)"), """
            el borrado del Welcome vuelve a un alcance fijo: con `.handover` se lleva los grupos que el aviso conservó
            """)
        let kept = try Self.body(of: "} else {", in: wrapper)
        #expect(kept.contains("GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending() "
                              + "GroupsBridgeRestoreConvergenceStore.markPending() settleSignalsAfterDeliberateWipe()"), """
            con los grupos conservados, sus filas puenteadas se van con el borrado y nadie las repone, o las señales \
            bajan a ciegas con los grupos vivos
            """)
    }

    @Test("el borrado del teléfono decide antes del primer `await` y, con la marca, no sube, no purga ni resetea")
    func deviceWipe_wiring() throws {
        let src = try Self.code("Yala/App/ContentView.swift")
        let wipe = Self.normalized(try Self.body(of: "private func performDeviceCorpusWipe() async -> String? {", in: src))
        let decide = "let purgesGroups = WelcomeKeptGroupsLogic.deviceWipePurgesTheGroupsDomain( "
            + "groupsKeptForThisPerson: LateNoticeKeptGroupsMark.vouchesNow())"
        let decideRange = try #require(wipe.range(of: decide), "el borrado del teléfono no consulta la marca")
        let firstAwait = try #require(wipe.range(of: "await "))
        #expect(decideRange.upperBound <= firstAwait.lowerBound, "decide después de un `await`: no es lo que se confirmó")
        let drain = try Self.body(of: "if purgesGroups {", in: wipe)
        #expect(drain.contains("switch await drainGroupsBeforeFreshStart(accepted: acceptedInGesture)"), """
            con la marca sube los cambios de grupos antes de un borrado que no los toca, o sin ella dejó de subirlos
            """)
        #expect(wipe.contains("if purgesGroups { try DataWipeService.requireNoUnsentGroupWrites("))
        #expect(wipe.contains("try DataWipeService.wipeAllUserData(in: modelContext, broadcastSignal: false, "
                              + "resetsPreferences: purgesGroups)"))
        #expect(wipe.contains("if purgesGroups { try DataWipeService.wipeLocalGroupsDomain("), """
            con la marca el borrado del teléfono purga y sella los grupos que el aviso conservó
            """)
        #expect(wipe.contains("} else { GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending() "
                              + "GroupsBridgeRestoreConvergenceStore.markPending() settleSignalsAfterDeliberateWipe() }"))
    }

    @Test("el alert de «Es mi primera vez» con la marca no espera a subir grupos y su borrado no los purga")
    func freshStartAlertWipe_wiring() throws {
        let alerts = Self.normalized(try Self.code("Yala/App/Views/Shared/ShellDataAlertsModifier.swift"))
        #expect(alerts.contains("if !Self.purgesGroupsDomainNow() "
                                + "|| CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: modelContext) {"))
        let decide = try Self.body(of: "private static func purgesGroupsDomainNow() -> Bool {", in: alerts)
        #expect(decide.contains("WelcomeKeptGroupsLogic.deviceWipePurgesTheGroupsDomain( "
                                + "groupsKeptForThisPerson: LateNoticeKeptGroupsMark.vouchesNow())"))
        let wipe = try Self.body(of: "private func performFreshStartWipe() {", in: alerts)
        #expect(wipe.contains("let purgesGroups = Self.purgesGroupsDomainNow()"))
        #expect(wipe.contains("if purgesGroups { try DataWipeService.requireNoUnsentGroupWrites(in: modelContext) }"))
        #expect(wipe.contains("broadcastSignal: false, resetsPreferences: purgesGroups )"))
        #expect(wipe.contains("if purgesGroups { try DataWipeService.wipeLocalGroupsDomain(in: modelContext)"), """
            con la marca el alert purga y sella los grupos que el aviso conservó
            """)
        #expect(wipe.contains("} else { GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending() "
                              + "GroupsBridgeRestoreConvergenceStore.markPending() onSettleSignalsAfterWipeKeepingGroups() }"))
        let content = try Self.code("Yala/App/ContentView.swift")
        #expect(content.contains("onSettleSignalsAfterWipeKeepingGroups: { settleSignalsAfterDeliberateWipe() }"))
    }

    @Test("la transición del onboarding y el barrido del arranque retiran la marca; el cierre de sesión también")
    func markRetirement_wiring() throws {
        let content = Self.normalized(try Self.code("Yala/App/ContentView.swift"))
        let observer = try Self.body(of: ".onChange(of: hasCompletedOnboarding) { _, newValue in", in: content)
        #expect(observer.contains("if newValue { LateNoticeKeptGroupsMark.clear() }"), """
            con el onboarding completo la marca sigue puesta: la persona que llegue al Welcome otro día heredaría los grupos
            """)
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        #expect(boot.contains("LateNoticeKeptGroupsMark.retireIfOnboardingCompleted()"))
        let config = try Self.code("Yala/Utils/SwiftDataConfiguration.swift")
        let hook = try Self.body(of: "PrivateSessionMark.clear(defaults)", in: "{" + config)
        #expect(hook.contains("LateNoticeKeptGroupsMark.clear(defaults)"))
    }

    @Test("las puertas del Welcome leen el detector del Welcome; el guard cross-cuenta y el borrado decidido, el entero")
    func gates_wiring() throws {
        let content = try Self.code("Yala/App/ContentView.swift")
        #expect(content.contains("GroupBackendInviteEntryHandler.hasLocalDataProvider = { checkHasWelcomeDeviceData() }"),
                "la puerta del invitado vuelve a ver los grupos conservados como datos de otro")
        // Los dos closures del Welcome y la lectura del gesto: con `{ false }` vuelven las cuatro limpiezas sin alert.
        #expect(content.contains("welcomeDeviceDataNow: { checkHasWelcomeDeviceData() },"))
        #expect(content.contains("groupsKeptForThisPersonNow: { LateNoticeKeptGroupsMark.vouchesNow() },"))
        #expect(content.contains("let groupsKeptForThisPerson = groupsKeptForThisPersonNow()"))
        // La mitad de grupos del detector: las mismas dos entidades que `checkHasExistingData`, y falla CERRADO.
        let groups = Self.normalized(try Self.body(of: "private func checkHasGroupsData() -> Bool {", in: content))
        #expect(groups.contains("let groupDescriptor = FetchDescriptor<SplitGroup>()"))
        #expect(groups.contains("predicate: #Predicate<TransactionItem> { $0.splitExpenseID != nil }"), """
            sin las filas puenteadas, el handover real deja de ver al dueño anterior que venía de «Solo Grupos»
            """)
        #expect(groups.contains("return groupCount > 0 || bridgedCount > 0"))
        #expect(groups.hasSuffix("return true }"), "un fetch fallido se lee como «no hay grupos»: falla abierto")
        let detector = Self.normalized(try Self.body(of: "private func checkHasWelcomeDeviceData() -> Bool {",
                                                     in: content))
        #expect(detector == "WelcomeKeptGroupsLogic.deviceDataForWelcome( hasPersonalData: checkHasPersonalData(), "
                + "hasGroupsData: checkHasGroupsData(), groupsKeptForThisPerson: LateNoticeKeptGroupsMark.vouchesNow())")

        let container = try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        let groupsGate = try Self.caseBody("case .groupsGate(let purpose):", in: container)
        #expect(groupsGate.contains("hasLocalDataNow: { welcomeDeviceDataNow() },"),
                "la puerta del organizador vuelve a ver los grupos conservados como datos de otro")
        let deviceGate = try Self.body(of: "private var deviceCorpusGate: WelcomePrivateICloudGateView.DeviceCorpus? {",
                                       in: container)
        #expect(deviceGate.contains("return .init(hasData: { welcomeDeviceDataNow() },"))
        let decided = try Self.caseBody("case .freshStartDeviceWipe:", in: container)
        #expect(decided.contains("deviceCorpus: .init(hasData: { hasLocalDataNow() },"), """
            el borrado del teléfono ya decidido en el alert pregunta qué queda con el detector entero
            """)
        // La puerta privada del Welcome sigue limpiando nombre y divisa al borrar: es «Empezar de cero» de un corpus.
        let privateGate = try Self.caseBody("case .privateICloudGate:", in: container)
        #expect(!privateGate.contains("clearsResidualPreferencesOnWipe"))
    }

    @Test("el seam de XCUITest, su lanzador y su limpieza nombran la misma marca")
    func uitestSeam_parity() throws {
        let hooks = try Self.code("Yala/App/UITestHooks.swift")
        #expect(hooks.contains(
            "nonisolated static var lateNoticeKeptGroups: Bool { hasArg(\"-uitest-late-notice-kept-groups\") }"))
        let launcher = try Self.code("YalaUITests/Support/XCUIApplication+Yala.swift")
        #expect(launcher.contains("if lateNoticeKeptGroups { args.append(\"-uitest-late-notice-kept-groups\") }"),
                "el lanzador y el seam divergen: el caso de la misma persona correría sin la marca")
        let boot = Self.normalized(try Self.code("Yala/App/AppBootstrapper.swift"))
        #expect(boot.contains("if UITestHooks.lateNoticeKeptGroups { LateNoticeKeptGroupsMark.recordNow() }"), """
            con «sin sesión» apuntado, una sesión real guardada en el llavero del simulador dejaría la marca sin valer
            """)
        #expect(boot.contains("GroupsGateWipeFailureMarker.clear() LateNoticeKeptGroupsMark.clear()"), """
            sin limpiarla en `-uitest-reset`, la marca de una corrida sobrevive en el simulador (`cloudSync.*`, fuera del \
            barrido) y el control del handover real deja de ver su alert
            """)
    }
}
