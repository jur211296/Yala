//
//  GroupsGateLogicTests.swift
//  YalaTests
//
//  C2 · la tabla ÚNICA de las puertas de Grupos (tres desde el 2026-09-10: la card «Solo grupos» del
//  onboarding se retiró, ADR 2026-09-09 §7), y el source-scan de lo que la tabla no puede fijar.
//
//  Dos mitades y ninguna cubre a la otra:
//    1. La DECISIÓN — el dominio completo (3 entries × 2⁴ estados = 48 celdas), más las tres derivaciones.
//    2. El CABLEADO — quién llama, con qué señales y en qué orden. La tabla puede estar perfecta y sus 48
//       celdas verdes mientras un call-site le pasa un literal, escribe antes de tiempo o mide un snapshot
//       de 6 h. Es la lección de `AttestWiringTests` y de `GroupCreateRoutingWiringTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("GroupsGateLogic · la tabla única de las puertas de Grupos (C2)")
struct GroupsGateLogicTests {

    typealias Entry = GroupsGateLogic.Entry
    typealias Step = GroupsGateLogic.Step

    private func step(_ entry: Entry,
                      educational: Bool = true,
                      session: Bool = true,
                      consent: Bool = true,
                      setup: Bool = true,
                      confirmedInvite: Bool = false,
                      canPresentInvite: Bool = true) -> Step {
        GroupsGateLogic.nextStep(
            entry: entry,
            hasSeenEducational: educational,
            hasSession: session,
            isConsented: consent,
            hasCompletedSetup: setup,
            hasConfirmedInvite: confirmedInvite,
            canPresentInviteOnboarding: canPresentInvite)
    }

    // MARK: - El educativo: el escalón que C2 añade, y las dos puertas que NO lo anteponen

    @Test("la puerta del organizador antepone el educativo a TODO lo demás")
    func organizer_showsEducationalFirst() {
        #expect(step(.organizer, educational: false, session: false, consent: false, setup: false)
                == .presentEducational)
        // Y también cuando ya hay sesión y consent: el educativo es el PRIMER término, no un fallback.
        #expect(step(.organizer, educational: false) == .presentEducational)
    }

    /// La medición que justifica la asimetría, y que el docblock de la tabla explica: el invitado tiene su
    /// propio educativo (`GroupInviteOnboardingView`, contextual al link) y el tab presenta el general al
    /// montarse. Anteponerlo aquí daría dos educativos seguidos, o una segunda presentación compitiendo.
    @Test("las puertas de invitación y del tab NO anteponen el educativo general")
    func inviteAndTab_neverPresentEducational() {
        for entry in [Entry.invite, .tab] {
            for educational in [false, true] {
                for session in [false, true] {
                    for consent in [false, true] {
                        for setup in [false, true] {
                            let s = step(entry, educational: educational, session: session,
                                         consent: consent, setup: setup)
                            #expect(s != .presentEducational,
                                    "\(entry) devolvió educativo con educational=\(educational)")
                        }
                    }
                }
            }
        }
    }

    @Test("`showsEducationalFirst` es exactamente {organizer}")
    func educationalFlagIsExhaustive() {
        let conEducativo = Entry.allCases.filter(\.showsEducationalFirst)
        #expect(Set(conEducativo) == Set([.organizer]),
                "cambió qué puertas anteponen el educativo: \(conEducativo)")
    }

    // MARK: - Precedencia: educativo → sign-in → consent → terminal

    @Test("sin sesión gana el sign-in sobre el consent y sobre el terminal")
    func noSession_alwaysSignIn() {
        for entry in Entry.allCases {
            #expect(step(entry, session: false, consent: false, setup: false) == .presentSignIn)
            // El consent aceptado no adelanta nada: sin sesión no hay a quién atribuirlo.
            #expect(step(entry, session: false, consent: true, setup: true) == .presentSignIn)
        }
    }

    @Test("con sesión y sin consent, consent — en las tres puertas")
    func sessionWithoutConsent_alwaysConsent() {
        for entry in Entry.allCases {
            #expect(step(entry, consent: false, setup: false) == .presentConsent)
            #expect(step(entry, consent: false, setup: true) == .presentConsent)
        }
    }

    // MARK: - Los terminales, uno por puerta

    @Test("terminal de organizer: nombre si falta el alta, formulario si ya está")
    func organizerTerminals() {
        #expect(step(.organizer, setup: false) == .presentName)
        #expect(step(.organizer, setup: true) == .presentGroupForm)
    }

    /// **Contrato NUEVO desde 2026-09-05, y el terminal que este test fijaba antes era el defecto.**
    /// Decía `step(.invite, setup: true) == .join`: con el alta hecha, join directo. Eso es exactamente lo
    /// que hacía que a quien ya tenía cuenta el enlace lo metiera en el grupo sin enseñarle nada. Se
    /// actualiza a propósito —cambia una decisión de producto, no se «arregla» un test— y lo que ahora
    /// decide es si dijo que sí a ESTA invitación.
    @Test("terminal de invite: la hoja hasta que la persona confirme, y entonces join")
    func inviteTerminals() {
        #expect(step(.invite, confirmedInvite: false) == .presentInviteOnboarding)
        #expect(step(.invite, confirmedInvite: true) == .join)
        // El discriminador del CTA del propio onboarding: sin él, el tap de «unirme» re-presentaría la
        // vista que lo emitió.
        #expect(step(.invite, confirmedInvite: false, canPresentInvite: false) == .join)
    }

    /// **La regresión del ticket, en una aserción.** Tener cuenta (`setup: true`) no confirma nada: la
    /// hoja aparece igual. Y su gemelo, que es la mitad que evita el sobre-arreglo: al invitado fresco no
    /// le cambia el recorrido.
    @Test("el alta previa NO decide el terminal de invite — la hoja aparece igual")
    func inviteTerminalIgnoresPriorSetup() {
        for setup in [false, true] {
            #expect(step(.invite, setup: setup, confirmedInvite: false) == .presentInviteOnboarding,
                    "con setup=\(setup) el invitado se saltó la hoja")
            #expect(step(.invite, setup: setup, confirmedInvite: true) == .join,
                    "con setup=\(setup) la hoja se re-presentó a quien ya había confirmado")
        }
    }

    @Test("terminal de tab: siempre el formulario — el tab no da de alta a nadie")
    func tabTerminalIsAlwaysTheForm() {
        #expect(step(.tab, setup: false) == .presentGroupForm)
        #expect(step(.tab, setup: true) == .presentGroupForm)
    }

    // MARK: - Dominio completo

    /// Las 48 celdas decididas, para que añadir un `Entry` o un `Step` sin decidir su celda no pase en
    /// verde por omisión. Y la aserción que carga el peso: **el nombre solo es alcanzable con identidad y
    /// consent**, que es la invariante del chip expresada sobre la tabla.
    ///
    /// Barre el dominio con `confirmedInvite: false`, y no las 96 celdas que la tabla tiene desde que ese
    /// eje existe (2026-09-05): el eje nuevo solo mueve el terminal de `.invite`, que jamás produce
    /// `.presentName` — o sea que la mitad no barrida no puede cambiar lo que aquí se cuenta. El terminal
    /// que sí mueve tiene su propio barrido en `inviteTerminalIgnoresPriorSetup`.
    @Test("las 48 celdas están decididas y `presentName` exige sesión Y consent")
    func fullDomain_isExhaustive_andNameRequiresIdentity() {
        var nombres = 0
        for entry in Entry.allCases {
            for educational in [false, true] {
                for session in [false, true] {
                    for consent in [false, true] {
                        for setup in [false, true] {
                            let s = step(entry, educational: educational, session: session,
                                         consent: consent, setup: setup)
                            if s == .presentName {
                                nombres += 1
                                #expect(session && consent, """
                                    `presentName` es el paso que ESCRIBE el trío \
                                    (`onboardingMode = .groupInvite` es never-downgrade cross-device). \
                                    Alcanzarlo sin sesión o sin consent es exactamente el bug de la card \
                                    «Solo grupos»: entry=\(entry) session=\(session) consent=\(consent)
                                    """)
                            }
                        }
                    }
                }
            }
        }
        // solo organizer × (educativo visto, sesión, consent, setup pendiente) = 1
        #expect(nombres == 1, "cambió el nº de celdas que llegan al alta: \(nombres)")
    }
}

// MARK: - Las tres derivaciones

/// Lo que este chip promete es que las tres tablas **derivan** y no se prometen paridad por docblock. Si
/// alguna volviera a decidir por su cuenta, estas aserciones caen.
@Suite("C2 · las tres tablas derivan de GroupsGateLogic")
struct GroupsGateDerivationTests {

    @Test("GroupsOrganizerFlowLogic espeja la tabla para `.organizer`")
    func organizerFlowMirrorsTheTable() {
        for educational in [false, true] {
            for session in [false, true] {
                for consent in [false, true] {
                    for setup in [false, true] {
                        let derivado = GroupsOrganizerFlowLogic.nextStep(
                            hasSeenEducational: educational, hasSession: session,
                            isConsented: consent, hasCompletedSetup: setup)
                        let esperado: GroupsOrganizerFlowLogic.Step = switch GroupsGateLogic.nextStep(
                            entry: .organizer, hasSeenEducational: educational, hasSession: session,
                            isConsented: consent, hasCompletedSetup: setup) {
                        case .presentEducational: .presentEducational
                        case .presentSignIn:      .presentSignIn
                        case .presentConsent:     .presentConsent
                        case .presentName:        .presentName
                        default:                  .presentGroupForm
                        }
                        #expect(derivado == esperado)
                    }
                }
            }
        }
    }

    @Test("GroupBackendInviteEntryLogic sigue siendo la tabla de `.invite`, sin educativo")
    func inviteEntryMirrorsTheTable() {
        for session in [false, true] {
            for consent in [false, true] {
                for confirmed in [false, true] {
                    for canPresent in [false, true] {
                        let derivado = GroupBackendInviteEntryLogic.nextStep(
                            hasSession: session, isConsented: consent,
                            hasConfirmedInvite: confirmed, canPresentOnboarding: canPresent)
                        // `hasCompletedSetup: true` es lo que la derivada le pasa a la tabla desde que el
                        // alta dejó de decidir este terminal. Fijarlo aquí es parte del espejo: si alguien
                        // devolviera ese término a la decisión, la derivada y la tabla dejarían de coincidir
                        // para la mitad del dominio y esto caería.
                        let tabla = GroupsGateLogic.nextStep(
                            entry: .invite, hasSeenEducational: true, hasSession: session,
                            isConsented: consent, hasCompletedSetup: true,
                            hasConfirmedInvite: confirmed,
                            canPresentInviteOnboarding: canPresent)
                        let esperado: GroupBackendInviteEntryLogic.Step = switch tabla {
                        case .presentSignIn:           .presentSignIn
                        case .presentConsent:          .presentConsent
                        case .presentInviteOnboarding: .presentInviteOnboarding
                        default:                       .join
                        }
                        #expect(derivado == esperado)
                    }
                }
            }
        }
    }

    /// El canal NO se derivó, y esa es la mitad importante: `route` conserva `.channelOff` como PRIMER
    /// término (C4). Si alguien lo moviera detrás de la derivación, el usuario volvería a pedir identidad
    /// para después ser bloqueado.
    @Test("GroupCreateRoutingLogic deriva la identidad pero conserva el canal DELANTE")
    func createRoutingKeepsTheChannelFirst() {
        for session in [false, true] {
            for consent in [false, true] {
                #expect(GroupCreateRoutingLogic.route(
                    flagOn: false, hasSession: session, consentAccepted: consent) == .channelOff,
                    "el canal dejó de ser el primer término de `route`")

                let tabla = GroupsGateLogic.nextStep(
                    entry: .tab, hasSeenEducational: true, hasSession: session,
                    isConsented: consent, hasCompletedSetup: true)
                let esperado: GroupCreateRoutingLogic.Route = switch tabla {
                case .presentSignIn:  .needsSignIn
                case .presentConsent: .needsConsent
                default:              .backend
                }
                #expect(GroupCreateRoutingLogic.route(
                    flagOn: true, hasSession: session, consentAccepted: consent) == esperado)
            }
        }
    }
}

// MARK: - El cableado (source-scan)

/// **Lo que la tabla NO puede fijar: quién la llama, con qué señales y qué escribe antes de tiempo.**
///
/// El escáner lee el CÓDIGO sin líneas de comentario: los docblocks de esta rama nombran a propósito lo que
/// prohíben, y contar la prosa haría que documentar el invariante lo «cumpliera».
@Suite("C2 · cableado de la cadena unificada (source-scan)")
struct GroupsGateWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func count(_ needle: String, in source: String) -> Int {
        source.components(separatedBy: needle).count - 1
    }

    private static let onboardingView = "Yala/App/Views/Onboarding/OnboardingView.swift"
    private static let contentView = "Yala/App/ContentView.swift"
    private static let containerView = "Yala/App/Views/Groups/GroupsContainerView.swift"
    private static let organizerOnboarding = "Yala/Services/Groups/GroupsOrganizerOnboarding.swift"

    // MARK: - LA MUTACIÓN CENTRAL: la card «Solo grupos» ya no escribe nada

    /// La invariante entera del chip en una aserción. `completeGroupsOnlyOnboarding` escribía el trío en el
    /// paso 8 del onboarding, sin sesión y sin consent; `onboardingMode = .groupInvite` es never-downgrade
    /// cross-device, así que viajaba al iKV del Apple ID y **no volvía**.
    @Test("MUTACIÓN (a): `completeGroupsOnlyOnboarding` no vuelve, y OnboardingView no escribe el trío")
    func onboardingViewNoLongerWritesTheTrio() throws {
        let code = try Self.code(Self.onboardingView)

        #expect(!code.contains("func completeGroupsOnlyOnboarding"), """
            resucitarla reabre el bug entero: escribía `userName`, `defaultCurrencyCode`, `defaultPeriod`, \
            `onboardingMode = .groupInvite` EMPUJADO al iKV, `groupsBetaUnlocked` y \
            `hasCompletedOnboarding` sin sesión, sin consent y sin canal comprobado.
            """)

        // Las tres escrituras del trío, nombradas una a una. El escáner es por SÍMBOLO y no por función,
        // así que también caza a quien las devuelva desde una rama nueva con otro nombre.
        #expect(!code.contains("OnboardingMode.groupInvite.rawValue"), """
            OnboardingView volvió a empujar `.groupInvite` al canal sincronizado. Es never-downgrade \
            cross-device: escrito antes de confirmar la ruta, se propaga y no vuelve.
            """)
        #expect(!code.contains("AppPreferences.Keys.groupsBetaUnlocked"),
                "OnboardingView volvió a desbloquear el dominio Grupos sin identidad")
    }

    /// **La rama del organizador se enciende en UN solo sitio: la puerta del Welcome.** Hasta el 2026-09-10
    /// había un segundo —la card «Solo grupos» del onboarding cedía a esta cadena— y se retiró con la card
    /// (ADR 2026-09-09 §7: solo-grupos es una sesión que se abre desde el Welcome). La (c) fija que el alta
    /// tiene un solo call-site; ésta fija que la cadena que lleva hasta él tiene una sola ENTRADA. Es la
    /// mitad que la (c) no ve: una puerta nueva que encendiera la rama y dejara escribir a la pantalla del
    /// nombre pasaría la (c) en verde.
    @Test("MUTACIÓN (b): la rama del organizador se enciende en un solo sitio, la puerta del Welcome")
    func organizerBranchHasOneEntry() throws {
        let root = Self.repoRoot.appendingPathComponent("Yala")
        var sitios: [String] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            // `try` y no `try?`: un fichero que no se pudiera leer contaría cero y dejaría pasar la entrada
            // que viviera en él.
            let stripped = try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            let n = Self.count("groupsOrganizerFlowActive = true", in: stripped)
            if n > 0 { sitios.append("\(url.lastPathComponent)×\(n)") }
        }
        #expect(sitios == ["ContentView.swift×1"], """
            la rama del organizador se enciende desde más de un sitio (o desde ninguno). Su única entrada es \
            «Vengo por un grupo» en el Welcome; una segunda es la puerta a solo-grupos que el rediseño de \
            sesiones retiró. Encontrados: \(sitios.sorted())
            """)

        // Y ese sitio es el arranque del Welcome, no otro que casualmente viva en el mismo fichero.
        let code = try Self.code(Self.contentView)
        let inicio = try #require(code.range(of: "private func startGroupsOrganizerBranch() {"),
                                  "`startGroupsOrganizerBranch` desapareció o cambió de firma")
        let fin = try #require(code.range(of: "\n    }", range: inicio.upperBound..<code.endIndex))
        #expect(code[inicio.upperBound..<fin.lowerBound].contains("groupsOrganizerFlowActive = true"),
                "la rama del organizador ya no se enciende en `startGroupsOrganizerBranch`")
    }

    // MARK: - El alta sigue teniendo UN solo sitio donde escribe

    @Test("MUTACIÓN (c): `completeSetup` se llama SOLO desde detrás de la cadena, en 1 sitio")
    func completeSetupHasExactlyOneCallSite() throws {
        let root = Self.repoRoot.appendingPathComponent("Yala")
        var sitios: [String] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let stripped = ((try? String(contentsOf: url, encoding: .utf8)) ?? "")
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            let n = Self.count("GroupsOrganizerOnboarding.completeSetup(", in: stripped)
            if n > 0 { sitios.append("\(url.lastPathComponent)×\(n)") }
        }
        #expect(Set(sitios) == Set(["GroupsOrganizerNameView.swift×1"]), """
            cambiaron los call-sites del alta. El ÚNICO legítimo está detrás de la cadena completa \
            (educativo → login → consent): la pantalla del nombre de la puerta del Welcome. Hubo un segundo \
            —la card «Solo grupos» del onboarding— hasta el 2026-09-10 (ADR 2026-09-09 §7). Otro es, con \
            casi total seguridad, una escritura del trío adelantada; que la cadena tenga una sola ENTRADA lo \
            fija la (b). Encontrados: \(sitios.sorted())
            """)
    }

    // MARK: - Las señales son las REALES, no literales

    @Test("MUTACIÓN (d): el router le pasa a la tabla las señales vivas")
    func routerPassesLiveSignals() throws {
        let code = try Self.code(Self.contentView)

        #expect(code.contains("hasSession: CloudAuthService.shared.hasSession"),
                "el router dejó de leer la sesión VIVA")
        #expect(code.contains("isConsented: GroupsConsentState.isAccepted"),
                "el router dejó de leer el consent vivo")
        #expect(code.contains("GroupsOnboardingLogic.hasSeenAnyGroupsEducational("), """
            el router dejó de computar «ya vio un educativo» con la lógica compartida. Un literal ahí \
            salta el primer escalón de la cadena con las 48 celdas de la tabla en VERDE.
            """)
        // La lectura que NO puede volver al `@AppStorage`: justo después de un alta el espejo observable
        // puede no haberse refrescado y la cadena repetiría el alta (el caso medido era la card «Solo
        // grupos», retirada el 2026-09-10; la lectura se queda).
        //
        // Y va contra el CAJÓN de la sesión desde 2026-09-05, no contra `.standard`: quien escribe ese
        // trío es `GroupsOrganizerOnboarding`, que ya iba por la puerta (`writer.setLocal`). Leerlo del
        // dominio del dueño preguntaba por otra persona justo después de escribir en el de ésta.
        #expect(code.contains("hasCompletedSetup: UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)"), """
            el router volvió a decidir el alta con el `@AppStorage`, o con el dominio del dueño. El espejo \
            observable se refresca por notificación, así que dentro de la misma vuelta puede seguir diciendo \
            `false` y `.presentName` se ejecutaría dos veces; y `.standard` responde por la dueña cuando \
            quien está dando el alta es la visita.
            """)
    }

    @Test("MUTACIÓN (e): el tab decide su empty state y su educativo con la MISMA señal")
    func tabUsesOneSourceOfTruth() throws {
        let code = try Self.code(Self.containerView)

        // Un solo cómputo del hecho, consumido por los tres sitios (empty state, banner, educativo).
        #expect(Self.count("GroupsOnboardingLogic.hasSeenAnyGroupsEducational(", in: code) == 1, """
            el tab dejó de tener UN solo cómputo de «ya vio el educativo». Con dos, el empty state puede \
            anunciar «ver cómo funciona» y el sheet no presentarse — o al revés.
            """)
        // Tres consumidores: el render del empty state, el gate del sheet educativo y el predicado del
        // banner de re-entrada. Los tres tienen que leer el MISMO cómputo.
        #expect(Self.count("hasSeenEducational: hasSeenGroupsEducational", in: code) == 3,
                "cambió el nº de consumidores de la señal (esperados 3: empty state, sheet y banner)")
        #expect(code.contains("hadSessionEver: GroupsSessionHistoryMarker.hadSessionEver()"), """
            el empty state dejó de leer el latch. Sin él vuelve a decirle «tus grupos están en tu cuenta» \
            a quien nunca tuvo ninguna.
            """)
    }

    // MARK: - El educativo: el `force` no se movió, y el seam existe

    /// El chip avisa por escrito: «el `force: true` NO viaja solo con la puerta». Se midió, y **no hizo
    /// falta moverlo**: el educativo se monta DESPUÉS de `WelcomeGroupsGateView`, que sigue siendo el
    /// primer paso de la rama y donde vive el refresco forzado. Este test lo fija en su sitio.
    @Test("MUTACIÓN (f): el `force: true` sigue en la puerta del Welcome, ANTES del educativo")
    func forcedRefreshStaysInTheGate() throws {
        let gate = try Self.code("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        #expect(gate.contains("refreshIfDue(force: true)"), """
            el refresco forzado salió de la puerta del organizador. Sin él, `refreshIfDue` es un no-op \
            (min-interval de 6 h, ya gastada por el refresh del arranque) y la puerta mide un snapshot \
            rancio — el bug que C4 cerró.
            """)
        let refresh = try #require(gate.range(of: "refreshIfDue(force: true)"))
        let decide = try #require(gate.range(of: "GroupsOrganizerGateLogic.decide("))
        #expect(refresh.upperBound < decide.lowerBound,
                "leer el flag antes del refresh forzado es el no-op que el chip prohíbe")
    }

    @Test("MUTACIÓN (g): el educativo entra en la matriz de readiness y su seam de test existe")
    func educationalBlocksAndHasItsSeam() throws {
        let readiness = try Self.code("Yala/App/Logic/ContentViewReadinessLogic.swift")
        #expect(readiness.contains("if state.showGroupsEducational { return \"groupsEducational\" }"), """
            el cover del educativo dejó de bloquear la matriz. El paso SIGUIENTE de la cadena es un sheet \
            del MISMO anchor (`GroupsSignInView`), así que sin blocker el drain lo monta encima — regla \
            (3) de Presentaciones, y la (4) a un paso.
            """)

        let hooks = try Self.code("Yala/App/UITestHooks.swift")
        #expect(hooks.contains("-uitest-groups-educativo"), """
            desapareció el seam del educativo. Sin él, el PRIMER escalón de las puertas de Grupos vuelve a ser \
            inalcanzable desde XCUITest (`evaluateGroupsOnboarding` hace early-return bajo `-uitest`) y \
            nace sin ninguna red determinista.
            """)

        let container = try Self.code(Self.containerView)
        #expect(container.contains("if UITestHooks.isActive && !UITestHooks.groupsEducativo { return }"), """
            el seam ya no invierte el early-return. Si alguien lo «simplifica» quitando el early-return \
            entero, el sheet del educativo intercepta los taps de TODA la suite de Grupos.
            """)
    }

    // MARK: - El residual declarado

    /// El chip pide «cierra o declara residual» el `setLocal(groupsBetaUnlocked)`. **Declarado**: se queda,
    /// porque `.groupInvite` solo lo implica mientras ese modo dure —el segundo término de
    /// `GroupsDomainAdoptionLogic.isDomainOpen` muere si el usuario activa Yala completo— y sin la key
    /// per-device el organizador que se pase a modo completo perdería el acceso al dominio.
    @Test("el `groupsBetaUnlocked` del alta es residual DECLARADO, no un olvido")
    func betaUnlockedIsADeclaredResidual() throws {
        let code = try Self.code(Self.organizerOnboarding)
        #expect(Self.count("writer.setLocal(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)", in: code) == 1, """
            cambió la escritura de `groupsBetaUnlocked` en el alta. Si se retiró: el organizador que active \
            Yala completo más tarde pierde el segundo término de `GroupsDomainAdoptionLogic.isDomainOpen` \
            y con él el dominio Grupos. Si se duplicó: hay un segundo escritor sin gate.
            """)
        #expect(code.contains("AppPreferences.Keys.groupsBetaUnlocked"),
                "la key salió del inventario `writtenKeys` del alta")
    }
}
