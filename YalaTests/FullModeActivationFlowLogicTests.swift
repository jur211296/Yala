//
//  FullModeActivationFlowLogicTests.swift
//  YalaTests
//
//  Paso 8 del rediseño de sesiones · «Activar Yala completo» pregunta dónde viven los datos personales.
//
//  Tres suites. La primera fija la lógica pura (`FullModeActivationFlowLogic`): qué pantalla abre, qué deshace
//  cancelar, en qué ORDEN se escribe cada cosa y qué hace cada desenlace de la promoción. La segunda, la
//  reanudación tras relanzar y las marcas de `UserDefaults` que la acompañan, con defaults aislados. La
//  tercera fija el CABLEADO que no se puede ejercitar sin montar la app. Un source-scan prueba que el cambio se
//  APLICÓ, no lo que HACE: por eso cada uno nombra el daño que evita, fija el EMPAREJAMIENTO y el orden (no la
//  mera presencia), y el comportamiento vive en las dos primeras y en `GroupsBridgeRestoreConvergenceTests`.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Paso 8 · la activación de Yala completo: pantallas, cancelar, orden del cierre y promoción")
struct FullModeActivationFlowLogicTests {

    typealias Logic = FullModeActivationFlowLogic
    typealias Option = WelcomeAccountChoiceLogic.NewOption

    private static let both: [Option] = [.privateAccount, .cloudAccount]
    private static let privateOnly: [Option] = [.privateAccount]
    private static let summary = ICloudAccountSummary(
        userName: "Ana", accountsCount: 2, transactionsCount: 40, budgetsCount: 0,
        groupsCount: 0, primaryCurrencyCode: "PEN", categoriesCount: 12)

    /// La primera pantalla, con los valores de una activación solo-grupos corriente por defecto: sin
    /// reanudación, sin espejo heredado y con las dos cards.
    private static func screen(
        groupsOnly: Bool = true,
        resume: FullModeActivationResumeStore.Step? = nil, legacy: Bool = false,
        // Literal y no `both`: un argumento por defecto se evalúa fuera del actor de la suite.
        options: [Option] = [.privateAccount, .cloudAccount]
    ) -> Logic.Screen {
        Logic.initialScreen(isGroupsOnlySession: groupsOnly,
                            resume: resume, isLegacyMirroredInstall: legacy, visibleOptions: options)
    }

    // MARK: - La primera pantalla

    @Test("solo-grupos con las dos cards visibles: el chooser va ANTES de cualquier onboarding")
    func groupsOnly_opensTheChooser() {
        #expect(Self.screen() == .chooser)
    }

    /// El criterio 1 del ticket, recorrido entero: ninguna combinación del gate abre el onboarding sin haber
    /// pasado por la elección —o por la puerta de iCloud, que es la elección cuando solo hay una card—.
    @Test("ninguna combinación del gate abre el onboarding en solo-grupos sin reanudación")
    func groupsOnly_neverStartsAtTheOnboarding() {
        for options in [Self.both, Self.privateOnly, [.cloudAccount]] as [[Option]] {
            for legacy in [false, true] {
                let screen = Self.screen(legacy: legacy, options: options)
                if case .onboarding = screen {
                    Issue.record("con \(options) legacy=\(legacy) la activación abre el onboarding sin preguntar")
                }
                #expect(screen != .legacyOnboarding, "con \(options) cae en el recorrido de antes")
            }
        }
    }

    @Test("con una sola card visible, bypass a SU rama, como en el Welcome")
    func singleCard_bypassesToItsBranch() {
        #expect(Self.screen(options: Self.privateOnly) == .privateGate)
        #expect(Self.screen(options: [.cloudAccount]) == .consent)
    }

    @Test("reanudar tras relanzar va a lo que se eligió antes de relanzar")
    func resume_goesToTheChosenStep() {
        #expect(Self.screen(resume: .privateOnboarding) == .onboarding(.freshPrivate))
        #expect(Self.screen(resume: .restore) == .restore)
    }

    /// El eje de sesión va ANTES que la reanudación (review adversarial): si otro dispositivo del mismo Apple ID
    /// terminó la activación, `.completed` llega por el iCloud-KV y la marca de ESTE abriría un onboarding a
    /// alguien ya completo — y su cancelación le armaría el neutro y le apagaría el espejo.
    @Test("precedencia: eje de sesión > reanudación > instalación antigua > gate")
    func precedence() {
        #expect(Self.screen(groupsOnly: false, resume: .restore) == .legacyOnboarding,
                "una marca que sobrevive a su sesión no abre nada")
        #expect(Self.screen(resume: .restore, legacy: true) == .restore,
                "el espejo de una activación relanzada lo puso ella misma")
        #expect(Self.screen(legacy: true) == .reinstallNotice)
        #expect(Self.screen(legacy: true, options: Self.privateOnly) == .reinstallNotice,
                "el bypass de una sola card no salta el aviso")
    }

    /// Quien tiene sesión privada ve la misma fila de Perfil, pero su «dónde» ya está decidido: ofrecerle
    /// privado / nube sería ofrecerle una elección que no puede hacer.
    @Test("con sesión privada se conserva el recorrido de antes")
    func notGroupsOnly_keepsTheLegacyPath() {
        #expect(Self.screen(groupsOnly: false) == .legacyOnboarding)
    }

    /// Una sesión solo-grupos dada de alta antes del paso 5 ya espeja iCloud, y sobre ese store ninguna rama es
    /// segura. Cada término que lo descarta, uno por uno: con cualquiera invertido, el aviso de reinstalar se lo
    /// llevaría quien no lo necesita, o no se lo llevaría quien sí.
    @Test("instalación antigua con espejo: solo con los cinco términos en la dirección peligrosa")
    func legacyMirroredInstall_everyTermMatters() {
        func legacy(groupsOnly: Bool = true, mirror: Bool = true, armed: Bool = false,
                    resume: Bool = false, uiTest: Bool = false) -> Bool {
            Logic.isLegacyMirroredInstall(isGroupsOnlySession: groupsOnly, mountAttachesMirror: mirror,
                                          groupsOnlyNeutralArmed: armed, hasResume: resume, isUITesting: uiTest)
        }
        #expect(legacy())
        #expect(!legacy(groupsOnly: false), "fuera de solo-grupos no hay activación que parar")
        #expect(!legacy(mirror: false), "sin espejo, el store no trae nada de iCloud")
        #expect(!legacy(armed: true), "con el neutro armado es un alta del paso 5 en adelante")
        #expect(!legacy(resume: true), "el espejo lo adjuntó la propia activación")
        #expect(!legacy(uiTest: true), "en XCUITest el testigo del mount dice espejo sin haberlo")
    }

    @Test("cada card abre su rama")
    func eachCardOpensItsBranch() {
        #expect(Logic.screen(for: .privateAccount) == .privateGate)
        #expect(Logic.screen(for: .cloudAccount) == .consent)
    }

    @Test("volver desde una rama: al chooser si lo hubo; cancelar si fue bypass")
    func backFromABranch() {
        #expect(Logic.originScreen(visibleOptions: Self.both) == .chooser)
        #expect(Logic.originScreen(visibleOptions: Self.privateOnly) == nil)
    }

    @Test("volver en Restaurar: a la puerta sin relanzamiento; tras relanzar, cancelar")
    func backFromRestore() {
        #expect(Logic.screenBeforeRestore(hasResume: false) == .privateGate)
        #expect(Logic.screenBeforeRestore(hasResume: true) == nil)
    }

    // MARK: - Cancelar

    /// La tabla entera. La celda cara es Restaurar ya relanzado en solo-grupos: el espejo está bajando el corpus,
    /// y volver a solo-grupos lo dejaría debajo de un bridge que borra las transacciones reales que re-puentea.
    @Test("qué deshace cancelar, según la reanudación y el eje de sesión")
    func cancelTable() {
        let table: [(FullModeActivationResumeStore.Step?, Bool, Logic.CancelEffect)] = [
            (nil, true, .nothing),
            (nil, false, .nothing),
            (.privateOnboarding, true, .revertToGroupsOnly),
            (.restore, true, .keepPending),
            (.privateOnboarding, false, .dropStaleMark),
            (.restore, false, .dropStaleMark),
        ]
        for (resume, groupsOnly, expected) in table {
            #expect(Logic.cancelEffect(resume: resume, isGroupsOnlySession: groupsOnly) == expected,
                    "resume=\(String(describing: resume)) groupsOnly=\(groupsOnly)")
        }
    }

    // MARK: - El orden del cierre

    /// Decisión de Jürgen: la promoción es el ÚLTIMO paso del recorrido y va antes de CUALQUIER escritura. Y
    /// el almacenamiento nube se activa ANTES de persistir [P], porque `PreferenceSyncService` decide el destino
    /// de cada preferencia por el `behavior` del instante: con `.icloud` irían al iCloud-KV y nunca a la cuenta.
    @Test("nube: promoción primero; almacenamiento nube antes de persistir; la activación al final")
    func cloudPlan_order() throws {
        let plan = Logic.commitPlan(for: .freshCloud)
        #expect(plan.first == .promote, "nada se escribe antes de que el servidor diga que la cuenta es completa")
        let activate = try #require(plan.firstIndex(of: .activateCloudStorage))
        let persist = try #require(plan.firstIndex(of: .persistOnboarding))
        let history = try #require(plan.firstIndex(of: .applyHistoryChoice))
        #expect(activate < persist, "las preferencias de [P] acabarían en el iCloud-KV y no en la cuenta")
        #expect(activate < history, "los toggles de visibilidad, idem")
        #expect(plan.last == .completeActivation)
        #expect(!plan.contains(.convergeGroupsBridge), "sin restaurar no hay nada duplicado que converger")
    }

    @Test("privado: sin servidor que tocar")
    func privatePlan() {
        #expect(Logic.commitPlan(for: .freshPrivate) == [.persistOnboarding, .applyHistoryChoice, .completeActivation])
    }

    /// Sin sesión privada todavía, el bridge BORRA la transacción real de cada gasto que re-puentea: las
    /// que el usuario había clasificado en su vida anterior y acaban de volver de iCloud. Medido contra el bridge
    /// real en `GroupsBridgeRestoreConvergenceBehaviourTests`.
    @Test("restaurado: la activación va ANTES del re-puenteo, y no se pregunta por el historial")
    func restoredPlans_completeBeforeConverging() throws {
        for plan in [Logic.commitPlan(for: .restored(Self.summary)), Logic.restoredWithoutOnboardingPlan] {
            let complete = try #require(plan.firstIndex(of: .completeActivation))
            let converge = try #require(plan.firstIndex(of: .convergeGroupsBridge))
            #expect(complete < converge, "re-puentear sin sesión privada borra las transacciones reales restauradas")
            #expect(!plan.contains(.promote))
            #expect(!plan.contains(.applyHistoryChoice), "tras restaurar gana lo restaurado: no hay pregunta")
        }
    }

    @Test("todo plan cierra la activación exactamente una vez")
    func everyPlanCompletesExactlyOnce() {
        let plans = [Logic.commitPlan(for: .freshPrivate), Logic.commitPlan(for: .freshCloud),
                     Logic.commitPlan(for: .restored(Self.summary)), Logic.restoredWithoutOnboardingPlan]
        for plan in plans {
            #expect(plan.filter { $0 == .completeActivation }.count == 1, "plan=\(plan)")
        }
    }

    @Test("solo lo restaurado deja la convergencia como intención durable")
    func durableConvergence_onlyForRestoredPlans() {
        #expect(Logic.needsDurableConvergence(Logic.commitPlan(for: .restored(Self.summary))))
        #expect(Logic.needsDurableConvergence(Logic.restoredWithoutOnboardingPlan))
        #expect(!Logic.needsDurableConvergence(Logic.commitPlan(for: .freshPrivate)))
        #expect(!Logic.needsDurableConvergence(Logic.commitPlan(for: .freshCloud)))
    }

    // MARK: - La promoción

    @Test("la tabla de la promoción: solo `.seeded` sigue al commit")
    func promotionTable() {
        let exits = ProviderMismatchLogic.Exits(accountProvider: .apple, signInWith: .apple, createWith: .google)
        let table: [(BornCloudSignUpOutcome, Logic.PromotionStep)] = [
            (.seeded, .commit),
            (.routeReturningUser, .blocked(.accountAlreadyHasPersonalData)),
            (.waitForLeader, .blocked(.anotherDeviceIsMoving)),
            (.sessionExpired(detail: "401"), .blocked(.sessionExpired)),
            (.accountUnavailable(detail: "403"), .blocked(.accountUnavailable)),
            (.providerMismatch(exits), .blocked(.accountUnavailable)),
            (.transient(detail: "network"), .retry),
        ]
        for (outcome, expected) in table {
            #expect(Logic.promotionStep(for: outcome) == expected, "outcome=\(outcome)")
        }
    }

    // MARK: - El historial de grupos

    @Test("se pregunta por el historial solo en los onboardings nuevos, y solo si hay algo puenteado")
    func historyQuestion() {
        for source in [Logic.OnboardingSource.freshPrivate, .freshCloud] {
            #expect(Logic.shouldAskHistory(source: source, bridgedGroupExpenseCount: 3))
            #expect(!Logic.shouldAskHistory(source: source, bridgedGroupExpenseCount: 0),
                    "sin nada puenteado no hay nada que decidir")
        }
        #expect(!Logic.shouldAskHistory(source: .restored(Self.summary), bridgedGroupExpenseCount: 3),
                "la decisión de Jürgen ata la pregunta al onboarding; restaurar es la vida anterior tal cual")
    }

    /// Los dos caminos existen y son OPUESTOS en las cuatro superficies: si una coincidiera, «No» dejaría pasar
    /// los gastos de grupo por ella —o «Sí» los escondería—. Los presupuestos entran porque no tienen toggle
    /// global: sin ellos, «No» dejaba que el gasto de grupo consumiera el presupuesto recién creado.
    @Test("«Sí» enciende las cuatro superficies y «No» las apaga, presupuestos incluidos")
    func historyChoice_togglesAllFourSurfaces() {
        #expect(Logic.groupVisibility(for: .showInPersonal)
                == Logic.GroupVisibility(feed: true, panelTotal: true, stats: true, budgets: true))
        #expect(Logic.groupVisibility(for: .keepInGroups)
                == Logic.GroupVisibility(feed: false, panelTotal: false, stats: false, budgets: false))
    }
}

@MainActor
@Suite("Paso 8 · la reanudación de la activación tras relanzar, y las marcas que la acompañan")
struct FullModeActivationResumeStoreTests {

    typealias Store = FullModeActivationResumeStore
    typealias Destination = WelcomeMirrorRelaunchLogic.Destination

    private static let activationDestinations: [Destination] = [.fullActivationPrivate, .fullActivationRestore]
    private static let currents: [Store.Step?] = [nil, .privateOnboarding, .restore]
    /// Sin destino, o con uno del Welcome: los que el arranque de un returning user NO consume.
    private static var otherPendings: [Destination?] {
        [nil] + Destination.allCases.filter { Store.step(for: $0) == nil }
    }

    @Test("exactamente dos destinos del relanzamiento son de la activación, y van y vuelven")
    func onlyTheActivationDestinationsMap() {
        let mapped = Destination.allCases.filter { Store.step(for: $0) != nil }
        #expect(Set(mapped) == Set(Self.activationDestinations))
        for step in Store.Step.allCases {
            #expect(Store.step(for: Store.destination(for: step)) == step)
        }
    }

    /// La kill-safety del relanzamiento: con un destino de la activación, se escribe la marca, se consume el
    /// destino (si no, `exit(0)` en cada paso a segundo plano) y se reabre la sheet. Sin destino, manda la
    /// marca: es lo que reabre la sheet tras un kill a mitad del onboarding reanudado. Los destinos del Welcome
    /// los consume `presentNextOnboardingScreen`, que es la población contraria.
    @Test("solo-grupos: el arranque retoma la activación y solo consume sus propios destinos")
    func boot_groupsOnly_resumes() {
        for destination in Self.activationDestinations {
            for current in Self.currents {
                #expect(Store.resolveAtBoot(pending: destination, current: current,
                                            isGroupsOnlySession: true)
                        == .init(consumesPendingDestination: true, writesResume: Store.step(for: destination),
                                 clearsResume: false, presentsActivation: true))
            }
        }
        for pending in Self.otherPendings {
            for current in Self.currents {
                #expect(Store.resolveAtBoot(pending: pending, current: current,
                                            isGroupsOnlySession: true)
                        == .init(consumesPendingDestination: false, writesResume: nil,
                                 clearsResume: false, presentsActivation: current != nil),
                        "pending=\(String(describing: pending)) current=\(String(describing: current))")
            }
        }
    }

    /// Fuera de solo-grupos —otro dispositivo terminó la activación, o se vaciaron los datos— lo pendiente se
    /// RETIRA sin reabrir nada. El destino se consume igual: si no, `exit(0)` en cada paso a segundo plano.
    @Test("fuera de solo-grupos: se retira lo pendiente y no se reabre nada")
    func boot_notGroupsOnly_retires() {
        for destination in Self.activationDestinations {
            for current in Self.currents {
                #expect(Store.resolveAtBoot(pending: destination, current: current,
                                            isGroupsOnlySession: false)
                        == .init(consumesPendingDestination: true, writesResume: nil,
                                 clearsResume: current != nil, presentsActivation: false))
            }
        }
        for pending in Self.otherPendings {
            for current in Self.currents {
                #expect(Store.resolveAtBoot(pending: pending, current: current,
                                            isGroupsOnlySession: false)
                        == .init(consumesPendingDestination: false, writesResume: nil,
                                 clearsResume: current != nil, presentsActivation: false))
            }
        }
    }

    /// Lo que cierra el bridge: con esto en `true`, la sesión sigue siendo solo-grupos y el espejo puede
    /// estar bajando un corpus restaurado cuyas transacciones reales el bridge borraría al re-puentear.
    @Test("activación privada a medias: con su destino pedido o con su marca, y con nada más")
    func inFlight_table() {
        for destination in Self.activationDestinations {
            #expect(Store.isPrivateActivationInFlight(pending: destination, current: nil))
        }
        for pending in Self.otherPendings {
            #expect(Store.isPrivateActivationInFlight(pending: pending, current: nil) == false,
                    "pending=\(String(describing: pending))")
            #expect(Store.isPrivateActivationInFlight(pending: pending, current: .restore))
        }
    }

    @Test("la marca se escribe, se lee y se retira; un valor desconocido se lee como ninguno")
    func roundTrip() {
        let defaults = makeIsolatedDefaults()
        #expect(Store.peek(defaults) == nil)
        Store.set(.privateOnboarding, defaults: defaults)
        #expect(Store.peek(defaults) == .privateOnboarding)
        Store.clear(defaults)
        #expect(Store.peek(defaults) == nil)
        defaults.set("algo-de-otra-versión", forKey: Store.key)
        #expect(Store.peek(defaults) == nil)
    }

    /// Armar el neutro solo-grupos es EMPEZAR una sesión solo-grupos: la marca sobrevive a un cierre de sesión
    /// y a vaciar los datos, y sin esto quien vuelve por «Vengo por un grupo» retomaría una activación vieja.
    @Test("armar el neutro solo-grupos retira una activación a medias")
    func armingGroupsOnly_dropsAnActivationInFlight() {
        let defaults = makeIsolatedDefaults()
        Store.set(.restore, defaults: defaults)
        StorageModePersistence.armGroupsOnlyNeutralMount(defaults)
        #expect(StorageModePersistence.isGroupsOnlyNeutralMountArmed(defaults))
        #expect(Store.peek(defaults) == nil)
    }

    /// El borrado de iCloud armado por la puerta privada NO puede sobrevivir a la activación: el arranque
    /// siguiente lo reanudaría a ciegas, con el borrado local incluido, sobre el corpus recién elegido.
    @Test("retirar el borrado de iCloud armado se lleva también su neutro")
    func wipeArmClear_alsoClearsItsNeutralMount() {
        let defaults = makeIsolatedDefaults()
        StorageModePersistence.armICloudCorpusWipe(defaults)
        #expect(StorageModePersistence.isICloudCorpusWipeArmed(defaults))
        #expect(StorageModePersistence.isNeutralMountArmed(defaults))
        StorageModePersistence.clearICloudCorpusWipeArm(defaults)
        #expect(!StorageModePersistence.isICloudCorpusWipeArmed(defaults))
        #expect(!StorageModePersistence.isNeutralMountArmed(defaults))
    }
}

// MARK: - El cableado

@MainActor
@Suite("Paso 8 · cableado de la activación (source-scan)")
struct FullModeActivationWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func code(_ path: String) throws -> String {
        try code(at: repoRoot.appendingPathComponent(path))
    }

    /// El fichero sin las líneas de comentario entero: los docblocks de estas vistas NOMBRAN las llamadas que
    /// los tests buscan, y sin este filtro documentar un invariante lo cumpliría.
    private static func code(at url: URL) throws -> String {
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(!text.isEmpty, "el escáner no pudo leer `\(url.lastPathComponent)`")
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de la función que abre `marker`, contando llaves desde su primera `{`.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no se encontró `\(marker)`")
        let open = try #require(source[start.lowerBound...].firstIndex(of: "{"))
        var depth = 0
        var index = open
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 { return String(source[open...index]) }
            }
            index = source.index(after: index)
        }
        Issue.record("llaves desbalanceadas tras `\(marker)`")
        return ""
    }

    /// El tramo entre `from` y la primera aparición de `to` que venga DETRÁS: lo que fija un emparejamiento
    /// (esta rama hace esto) y no la mera presencia, que pasaría con las dos ramas intercambiadas.
    private static func segment(from: String, to: String, in source: String) throws -> String {
        let start = try #require(source.range(of: from), "no se encontró `\(from)`")
        let end = try #require(source.range(of: to, range: start.upperBound..<source.endIndex),
                               "no se encontró `\(to)` detrás de `\(from)`")
        return String(source[start.lowerBound..<end.lowerBound])
    }

    /// `first` aparece antes que `second`, y las dos aparecen.
    private static func expectOrder(_ first: String, before second: String, in text: String, _ why: String) throws {
        let a = try #require(text.range(of: first), "no se encontró `\(first)`")
        let b = try #require(text.range(of: second), "no se encontró `\(second)`")
        #expect(a.lowerBound < b.lowerBound, "\(why)")
    }

    /// Cuántas veces aparece `call` como identificador completo: el carácter anterior no puede ser letra,
    /// dígito ni `_`, que es lo que separa `OnboardingView(` de `GroupInviteOnboardingView(`.
    private static func exactCalls(of call: String, in text: String) -> Int {
        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        while let found = text.range(of: call, range: searchRange) {
            let isWhole = found.lowerBound == text.startIndex || {
                let previous = text[text.index(before: found.lowerBound)]
                return !(previous.isLetter || previous.isNumber || previous == "_")
            }()
            if isWhole { count += 1 }
            searchRange = found.upperBound..<text.endIndex
        }
        return count
    }

    private static let view = "Yala/App/Views/Groups/FullModeActivationView.swift"
    private static let contentView = "Yala/App/ContentView.swift"

    // MARK: - Relanzar y cancelar

    /// La kill-safety del relanzamiento. Con el destino DETRÁS de levantar la marca, un kill en medio deja el
    /// espejo puesto sobre una sesión solo-grupos sin nada que lo retome — el bug del paso 5.
    @Test("antes de relanzar: primero el destino durable, luego el anti-bucle, y al final se levanta la marca")
    func relaunch_writesTheDestinationFirst() throws {
        let proceed = try Self.body(of: "private func proceed(", in: try Self.code(Self.view))
        try Self.expectOrder("WelcomePendingDestinationStore.set(destination)",
                             before: "appPreferences.hasShownWelcomeChooser = true", in: proceed,
                             "sin el destino primero, un kill deja el espejo puesto sin nada que lo retome")
        try Self.expectOrder("appPreferences.hasShownWelcomeChooser = true",
                             before: "StorageModePersistence.clearGroupsOnlyNeutralMount()", in: proceed,
                             "sin el anti-bucle, la marca R4 vuelve a montar neutro y «reabre Yala» no termina")
        try Self.expectOrder("StorageModePersistence.clearGroupsOnlyNeutralMount()",
                             before: "go(to: .relaunch)", in: proceed, "el terminal va al final")
    }

    /// Cada efecto hace SU cosa. Un swap entre ramas pasaría un `contains` suelto y sería el daño entero: armar
    /// el neutro a quien ya no es solo-grupos le apaga el espejo, y retirar la marca de un Restaurar relanzado
    /// abre el bridge sobre el corpus que está bajando.
    @Test("cancelar: nada con un plan en vuelo, y cada efecto hace SU cosa y no la de otro")
    func cancel_eachEffectDoesItsOwnThing() throws {
        let cancel = try Self.body(of: "private func cancelActivation() {", in: try Self.code(Self.view))
        try Self.expectOrder("guard !isRunningPlan else { return }", before: "FullModeActivationFlowLogic.cancelEffect(",
                             in: cancel, "con el claim contestado, cerrar dejaría la cuenta completa sin nada detrás")
        #expect(cancel.contains("resume: FullModeActivationResumeStore.peek()"))
        #expect(cancel.contains("isGroupsOnlySession: !sessionState.hasPrivateSession"))

        let untouched = try Self.segment(from: "case .nothing, .keepPending:", to: "case .revertToGroupsOnly:", in: cancel)
        #expect(untouched.contains("break"))
        #expect(!untouched.contains("StorageModePersistence"), "un Restaurar relanzado no vuelve a solo-grupos")
        #expect(!untouched.contains("FullModeActivationResumeStore"), "su marca es lo que mantiene el bridge cerrado")

        let revert = try Self.segment(from: "case .revertToGroupsOnly:", to: "case .dropStaleMark:", in: cancel)
        #expect(revert.contains("StorageModePersistence.armGroupsOnlyNeutralMount()"))
        #expect(revert.contains("FullModeActivationResumeStore.clear()"))

        let stale = try Self.segment(from: "case .dropStaleMark:", to: "onComplete()", in: cancel)
        #expect(stale.contains("FullModeActivationResumeStore.clear()"))
        #expect(!stale.contains("armGroupsOnlyNeutralMount"), "le apagaría el espejo a quien ya no es solo-grupos")
    }

    // MARK: - El cierre

    /// Lo que [P] tenía en memoria solo se escribe desde el plan: si se escribiera fuera, la promoción dejaría de
    /// ir antes que cualquier escritura.
    @Test("el commit de [P] se ejecuta en UN solo sitio, dentro del plan")
    func theOnboardingCommitRunsOnlyInsideThePlan() throws {
        let src = try Self.code(Self.view)
        #expect(src.components(separatedBy: "pendingCommit?()").count - 1 == 1)
        let execute = try Self.body(of: "private func execute(", in: src)
        #expect(execute.contains("pendingCommit?()"))
        #expect(src.contains("FullModeActivationFlowLogic.commitPlan(for:"))
        #expect(src.contains("FullModeActivationFlowLogic.restoredWithoutOnboardingPlan"))
    }

    /// Un desenlace que no es `.seeded` para el plan ANTES de la primera escritura: sin el `return`, el bucle
    /// seguiría y escribiría [P] sobre una cuenta que el servidor no ha promocionado.
    @Test("la promoción que no sale para el plan antes de escribir nada")
    func promotion_stopsBeforeAnyWrite() throws {
        let execute = try Self.body(of: "private func execute(", in: try Self.code(Self.view))
        let promote = try Self.segment(from: "case .promote:", to: "case .activateCloudStorage:", in: execute)
        let blocked = try Self.segment(from: "finale = .blocked(block)", to: "case .retry:", in: promote)
        #expect(blocked.contains("return"))
        let retry = try Self.segment(from: "finale = .failed", to: "}", in: promote)
        #expect(retry.contains("return"))
        #expect(execute.contains("guard let promotion else { return }"), "sin promoción no se escribe el par `.cloud`")
    }

    /// Las marcas que cambian el arranque siguiente salen ANTES del eje: con el borrado armado vivo y la sesión
    /// privada ya declarada, ese arranque borraría a ciegas el corpus recién elegido. La reanudación sale
    /// DESPUÉS: un kill en medio deja el eje puesto con la marca, y el arranque la retira sola.
    @Test("al completar: borrado y neutro fuera antes del eje; la reanudación, después")
    func completion_ordersTheMarksAroundTheMode() throws {
        let complete = try Self.body(of: "private func completeFullActivation() {", in: try Self.code(Self.view))
        let eje = "sessionState.hasPrivateSession = true"
        try Self.expectOrder("StorageModePersistence.clearICloudCorpusWipeArm()", before: eje,
                             in: complete, "el arranque siguiente reanudaría el borrado sobre el corpus nuevo")
        try Self.expectOrder("StorageModePersistence.clearGroupsOnlyNeutralMount()", before: eje,
                             in: complete, "el arranque siguiente montaría sin espejo a un usuario completo")
        try Self.expectOrder(eje, before: "FullModeActivationResumeStore.clear()", in: complete,
                             "un kill en medio dejaría solo-grupos sin nada que retome la activación")
    }

    /// El prefill de la activación ES el nombre y la divisa de sus grupos: borrarlos al vaciar iCloud le quitaría
    /// justo lo que el onboarding le ahorra. En el Welcome sí se limpian (son restos de otra persona).
    @Test("la puerta privada de la activación no limpia el prefill; la del Welcome, sí")
    func privateGate_keepsThePrefillOnlyInTheActivation() throws {
        #expect(try Self.code(Self.view).contains("clearsResidualPreferencesOnWipe: false"))
        #expect(!(try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift"))
            .contains("clearsResidualPreferencesOnWipe"))
    }

    /// Decisión de Jürgen: al restaurar gana lo restaurado. Y el `init` de `OnboardingView` fija su primer paso
    /// con el prefill que recibe: montado antes de tenerlo, arrancaba en «Nombre» y perdía la divisa del grupo.
    @Test("tras restaurar gana lo restaurado, y el onboarding no se monta sin su prefill")
    func prefill_restoredWins_andOnboardingWaitsForIt() throws {
        let src = try Self.code(Self.view)
        let prefill = try Self.body(of: "private func prefill(for source:", in: src)
        #expect(prefill.contains("case .restored(let summary): return summary"))
        #expect(prefill.contains("case .freshPrivate, .freshCloud: return prefilledSummary"))
        let onboarding = try Self.body(of: "private func onboarding(_ source:", in: src)
        try Self.expectOrder("if let prefill = prefill(for: source)", before: "OnboardingView(", in: onboarding,
                             "sin prefill el onboarding arranca en el paso equivocado")
        #expect(onboarding.contains("prefilledData: prefill,"))
    }

    /// Las cuatro superficies, cada una con SU campo: un swap dejaría una visible con «No».
    @Test("la respuesta del historial llega a los tres ajustes y a los presupuestos que acaba de crear [P]")
    func historyChoice_reachesEverySurface() throws {
        let apply = try Self.body(of: "private func applyHistoryChoice() {", in: try Self.code(Self.view))
        #expect(apply.contains("appPreferences.includeGroupTransactionsInFeed = visibility.feed"))
        #expect(apply.contains("appPreferences.includeGroupsInPanelTotal = visibility.panelTotal"))
        #expect(apply.contains("appPreferences.includeGroupTransactionsInStats = visibility.stats"))
        #expect(apply.contains("budget.includeSharedExpenses = visibility.budgets"))
    }

    /// Con el espejo puesto, el store puede traer cuentas de iCloud cuyas transacciones todavía no han bajado:
    /// la limpieza se las llevaría y el espejo exportaría el borrado.
    @Test("la limpieza de la cuenta General residual no corre con el espejo puesto")
    func cleanup_neverRunsOverTheMirror() throws {
        let cleanup = try Self.body(of: "private func cleanupResidualGeneralAccount() {", in: try Self.code(Self.view))
        try Self.expectOrder("|| !SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror else { return }",
                             before: "modelContext.delete(account)", in: cleanup, "el guard va antes del borrado")
    }

    /// Tapado es tapado también para VoiceOver y para el dedo: una vista cubierta en un `ZStack` sigue entera en
    /// el árbol de accesibilidad, y la X del onboarding cerraba la sheet con el plan en vuelo.
    @Test("lo que tapa el onboarding lo tapa para VoiceOver y el dedo, y la sheet no se desliza con trabajo en vuelo")
    func finale_coversForVoiceOverAndTouch() throws {
        let body = try Self.body(of: "var body: some View {", in: try Self.code(Self.view))
        #expect(body.contains(".accessibilityHidden(finale != nil)"))
        #expect(body.contains(".allowsHitTesting(finale == nil)"))
        #expect(body.contains(".interactiveDismissDisabled(screen != .chooser || finale != nil)"))
    }

    // MARK: - Los borrados

    /// **Las DOS puertas de la activación y sus DOS borrados**, que no son intercambiables.
    ///
    ///  · `.privateGate` se alcanza ANTES del relanzamiento: el store no espeja, lo local es de quien
    ///    activa, y el borrado local resetearía además `hasCompletedOnboarding` (restricción del paso 8) —
    ///    solo la zona.
    ///  · `.restoreDiscardGate` se alcanza DESPUÉS: el store espeja y lo local ES el corpus importado, que
    ///    sin borrar se re-exporta a la zona recién creada. Filas sí, preferencias y Grupos no.
    @Test("cada puerta de la activación recibe SU borrado, y el corte va antes del borrado local")
    func activationWipes_areScopedPerGate() throws {
        let src = try Self.code(Self.contentView)
        #expect(src.contains("performICloudZoneWipe: { await performICloudCorpusWipe(.zoneOnly) }"), """
            la puerta privada de la activación dejó de borrar SOLO la zona. Con filas se lleva las
            categorías, las cuentas y las bridgeadas de quien está activando.
            """)
        #expect(src.contains("await performICloudCorpusWipe(.importedRows)"), """
            «Restaurar → Empezar desde cero» dejó de borrar las filas que el espejo importó: el corpus
            descartado se re-exporta a la zona recién creada, que es el bug entero.
            """)
        // **El scope de la puerta nueva NO es `.handover`**, y el swap compila: se llevaría por delante
        // las preferencias (⇒ al Welcome a mitad de la activación) y el dominio de Grupos (⇒ el daño que
        // la decisión 2.2A prohíbe).
        let wrapper = try Self.body(of: "performICloudZoneAndImportedRowsWipe: {", in: src)
        #expect(!wrapper.contains(".handover"), """
            el borrado de «Empezar desde cero» pasó al scope del handover: resetea `hasCompletedOnboarding`
            —Welcome a mitad de la activación— y purga el dominio de Grupos, que es justo lo que la
            activación existe para conservar. Cuerpo leído: \(wrapper)
            """)
        let wipe = try Self.body(
            of: "private func performICloudCorpusWipe(_ scope: ICloudWipeScope) async -> String? {",
            in: src)
        try Self.expectOrder("guard scope.deletesLocalRows", before: "DataWipeService.wipeAllUserData", in: wipe,
                             "el corte tiene que ir antes del borrado local")
    }

    /// **La gracia del wipe remoto se cancela ANTES de borrar, y las señales se RE-MIDEN después.**
    ///
    /// Las dos mitades tienen un daño medido detrás. `wipeAllUserData` guarda por lotes, así que un
    /// borrado que lance a media lista deja el `hasPersonalData` cayendo igual: con la gracia viva eso se
    /// lee como wipe REMOTO y levanta un alert que, colgando del anchor de `ContentView`, **desmonta la
    /// sheet de la activación**. Y `hasExistingData` cuenta también los grupos, que este borrado conserva:
    /// ponerlo a `false` en vez de re-medirlo le miente a toda la app.
    @Test("el borrado de «Empezar desde cero» cancela la gracia antes, y re-mide las señales después")
    func activationDiscardWipe_cancelsGraceFirstAndRemeasures() throws {
        let src = try Self.code(Self.contentView)
        let wrapper = try Self.body(of: "performICloudZoneAndImportedRowsWipe: {", in: src)
        try Self.expectOrder("wipeGraceTask?.cancel()", before: "await performICloudCorpusWipe(.importedRows)",
                             in: wrapper, """
            la gracia se cancela DESPUÉS del borrado, o no se cancela: un borrado que lanza a media lista
            levanta el alert de wipe remoto, que desmonta la sheet de la activación.
            """)
        try Self.expectOrder("guard failure == nil else { return failure }",
                             before: "hasExistingData = checkHasExistingData()", in: wrapper, """
            el corte del fallo se movió detrás de las señales: un borrado que FALLÓ no borró nada, y
            re-medir ahí no daña, pero saltarse el corte deja seguir a la puerta como si hubiera borrado.
            """)
        for (senal, fetch) in [("hasExistingData", "checkHasExistingData()"),
                               ("hasPersonalData", "checkHasPersonalData()")] {
            #expect(wrapper.contains("\(senal) = \(fetch)"), """
                `\(senal)` dejó de re-medirse con su fetch vivo. Bajarlo a `false` sería mentir:
                `hasExistingData` cuenta también los grupos, y este borrado los conserva a propósito.
                Cuerpo leído: \(wrapper)
                """)
            #expect(!wrapper.contains("\(senal) = false"), """
                `\(senal)` se está bajando a `false` en vez de re-medirse.
                """)
        }
    }

    /// La reanudación de un borrado a medias pone `hasCompletedOnboarding = false`: en un solo-grupos que
    /// estaba activando, lo mandaría al Welcome.
    @Test("el aviso del espejo tardío sale ANTES de reanudar un borrado si la sesión es solo-grupos")
    func lateMirror_skipsGroupsOnlyBeforeResumingAWipe() throws {
        let late = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: try Self.code(Self.contentView))
        try Self.expectOrder("guard SessionState.shared.hasPrivateSession else { return }",
                             before: "isICloudCorpusWipeArmed()", in: late, "el guard va antes de mirar el arm")
    }

    // MARK: - El arranque

    /// Sin este consumidor, el destino del relanzamiento se quedaría puesto para siempre en un device
    /// solo-grupos, y de él cuelga la salida al pasar a segundo plano: `exit(0)` en cada background. Cada
    /// resolución con SU escritura: un swap entre ramas pasaría un `contains` suelto.
    @Test("el arranque de un returning user retoma la activación con la tabla, y cada rama hace lo suyo")
    func boot_resumesTheActivation() throws {
        let src = try Self.code(Self.contentView)
        let checks = try Self.body(of: "private func runReturningUserPostChecks() {", in: src)
        #expect(checks.contains("resumeFullModeActivationIfPending()"))
        let resume = try Self.body(of: "private func resumeFullModeActivationIfPending() {", in: src)
        #expect(resume.contains("isGroupsOnlySession: !SessionState.shared.hasPrivateSession"),
                "sin el eje, una marca vieja abriría un onboarding a alguien ya completo")
        let write = try Self.segment(from: "if let step = resolution.writesResume {", to: "}", in: resume)
        #expect(write.contains("FullModeActivationResumeStore.set(step)"))
        let clear = try Self.segment(from: "if resolution.clearsResume {", to: "}", in: resume)
        #expect(clear.contains("FullModeActivationResumeStore.clear()"))
        let consume = try Self.segment(from: "if resolution.consumesPendingDestination {", to: "}", in: resume)
        #expect(consume.contains("WelcomePendingDestinationStore.consume()"))
        let present = try Self.segment(from: "if resolution.presentsActivation {", to: "}", in: resume)
        #expect(present.contains("RouterEntryGate.shared.submit(.presentFullModeActivation)"))
        try Self.expectOrder("FullModeActivationResumeStore.set(step)", before: "WelcomePendingDestinationStore.consume()",
                             in: resume, "un kill en medio perdería la activación a mitad")
    }

    /// La convergencia tras restaurar es una INTENCIÓN: se marca antes de empezar el plan —un kill entre el modo
    /// `.completed` y la convergencia dejaría cada gasto dos veces— y el arranque la reintenta DENTRO del retome
    /// del bridge, que tiene el gate del store listo con la salida del store vacío.
    @Test("la convergencia: intención durable antes del plan, y reintento en el arranque tras los dos gates")
    func convergence_isDurableAndRetriedAtBoot() throws {
        let src = try Self.code(Self.view)
        let run = try Self.body(of: "private func run(_ plan:", in: src)
        try Self.expectOrder("GroupsBridgeRestoreConvergenceStore.markPending()", before: "Task { @MainActor in",
                             in: run, "un kill entre el modo y la convergencia dejaría cada gasto dos veces")
        let execute = try Self.body(of: "private func execute(", in: src)
        #expect(execute.contains("GroupsBridgeRestoreConvergence.runAfterActivation(context:"))

        let boot = try Self.body(of: "func retryPendingBridges(context: ModelContext) async {",
                                 in: try Self.code("Yala/App/AppBootstrapper.swift"))
        let converge = "GroupsBridgeRestoreConvergence.convergeIfPending(context: context)"
        try Self.expectOrder("guard await awaitPersonalStoreReady() else", before: converge, in: boot,
                             "un `save()` durante el import es el SIGTRAP del gate de quiescencia")
        try Self.expectOrder("guard GroupTransactionBridge.isDomainOpenForBridge() else", before: converge, in: boot,
                             "con el dominio cerrado no se re-puentea nada")
    }

    /// Dentro de la convergencia: nada se escribe en solo-grupos ni con el bridge cerrado, y lo que el bridge no
    /// atendió pasa a la intención durable ANTES de retirar la propia.
    @Test("la convergencia no escribe en solo-grupos ni con el bridge cerrado, y no suelta lo no atendido")
    func convergence_guardsBeforeWriting() throws {
        let src = try Self.code("Yala/Services/Groups/GroupsBridgeRestoreConvergence.swift")
        let converge = try Self.body(of: "static func convergeIfPending(", in: src)
        try Self.expectOrder("guard SessionState.shared.hasPrivateSession else { return }",
                             before: "bridgeRemoteExpenses(ids:", in: converge,
                             "sin sesión privada el bridge borra las transacciones reales que re-puentea")
        try Self.expectOrder("guard GroupTransactionBridge.isDomainOpenForBridge(defaults: defaults) else { return }",
                             before: "bridgeRemoteExpenses(ids:", in: converge, "el dominio cerrado no se toca")
        try Self.expectOrder("GroupsPendingBridgeIntent.arm(expenseIDs: unattended, settlementIDs: [], channel: .backend)",
                             before: "GroupsBridgeRestoreConvergenceStore.clear(defaults)", in: converge,
                             "retirar la intención antes de entregar lo pendiente lo perdería")
        let after = try Self.body(of: "static func runAfterActivation(", in: src)
        try Self.expectOrder("waitForImportQuiescence", before: "convergeIfPending(", in: after,
                             "recién restaurado, el import puede seguir en curso")
    }

    /// Con una activación privada a medias el bridge no crea nada, y lee las marcas del `defaults` que le pasan:
    /// leerlas de `.standard` a pelo dejaría el gate sin forma de probarse con defaults aislados.
    @Test("con una activación privada a medias el bridge está cerrado")
    func bridge_closedWhileActivationInFlight() throws {
        let gate = try Self.body(of: "static func isDomainOpenForBridge(defaults: UserDefaults = .standard) -> Bool {",
                                 in: try Self.code("Yala/Services/Groups/GroupTransactionBridge.swift"))
        #expect(gate.contains("pending: WelcomePendingDestinationStore.peek(defaults)"))
        #expect(gate.contains("current: FullModeActivationResumeStore.peek(defaults))"))
        try Self.expectOrder("guard !activationInFlight else { return false }",
                             before: "return GroupsDomainAdoptionLogic.isBridgeAllowed(", in: gate,
                             "el cierre por activación va antes de la decisión de siempre")
    }

    // MARK: - La oferta y la puerta única

    /// ADR §7, fila «Primera vez → nube» con una cuenta solo-grupos: entra solo-grupos Y se le ofrece activar.
    /// Los dos destinos de [I] comparten rama en el Welcome; lo único que los separa es este argumento, y si se
    /// perdiera, la oferta no llegaría nunca y nada lo notaría.
    @Test("la oferta de «Activar Yala completo» viaja desde [I] hasta que la sesión solo-grupos queda montada")
    func offer_travelsFromTheIdentityBlockToTheShell() throws {
        let welcome = try Self.code("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        #expect(welcome.contains("onEnterGroupsOnly(destino == .enterGroupsOnlyOfferingFullActivation)"))

        let src = try Self.code(Self.contentView)
        #expect(src.contains("offersFullActivationAfterGroupsEntry = offersFullActivation"))
        let onChange = try Self.body(of: ".onChange(of: hasCompletedOnboarding) {", in: src)
        try Self.expectOrder("offersFullActivationAfterGroupsEntry = false",
                             before: "!PrivateSessionMark.hasPrivateSession()", in: onChange,
                             "la oferta se consume una vez, se ofrezca o no")
        try Self.expectOrder("!PrivateSessionMark.hasPrivateSession()",
                             before: "RouterEntryGate.shared.submit(.presentFullModeActivation)", in: onChange,
                             "sin comprobar el eje, la oferta abriría la activación en una sesión sin chooser")
    }

    /// El criterio «ningún empujón lleva a un onboarding sin chooser» se cumple por construcción: todos los
    /// productores van por `.presentFullModeActivation`, ese intent abre SOLO esta sheet, y el onboarding de la
    /// activación solo existe dentro de ella. Si alguien monta `OnboardingView` en otro sitio, esto salta.
    @Test("una sola puerta: la sheet se construye en un sitio y el onboarding solo en dos")
    func singleFunnel() throws {
        var activationSheets: [String] = []
        var onboardings: [String: Int] = [:]
        let base = Self.repoRoot.appendingPathComponent("Yala")
        let walker = try #require(FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil))
        var scanned = 0
        for case let url as URL in walker where url.pathExtension == "swift" {
            scanned += 1
            // Por URL y no recomponiendo una ruta relativa: en el árbol principal la raíz ya se llama `Yala`, y
            // partir la ruta por `/Yala/` leía `Yala/Yala/...`, que no existe.
            let text = try Self.code(at: url)
            if url.lastPathComponent != "FullModeActivationView.swift", text.contains("FullModeActivationView(") {
                activationSheets.append(url.lastPathComponent)
            }
            // Con el tipo EXACTO y no como substring: `GroupInviteOnboardingView(` también contiene
            // `OnboardingView(`, y contarlo mezclaría la cadena de Grupos con el onboarding personal.
            let count = Self.exactCalls(of: "OnboardingView(", in: text)
            if count > 0 { onboardings[url.lastPathComponent] = count }
        }
        #expect(scanned >= 500, "el escáner solo leyó \(scanned) ficheros — no mide el árbol real")
        #expect(activationSheets == ["ContentView.swift"])
        #expect(onboardings == ["ContentView.swift": 1, "FullModeActivationView.swift": 2], """
            `OnboardingView` se monta en el Welcome (ContentView) y en la activación (su onboarding y el \
            recorrido de antes). Encontrado: \(onboardings)
            """)
    }
}
