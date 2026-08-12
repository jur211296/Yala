//
//  GroupsGateLogicTests.swift
//  YalaTests
//
//  C2 · la tabla ÚNICA de las cuatro puertas de Grupos, y el source-scan de lo que la tabla no puede fijar.
//
//  Dos mitades y ninguna cubre a la otra:
//    1. La DECISIÓN — el dominio completo (4 entries × 2⁴ estados = 64 celdas), más las tres derivaciones.
//    2. El CABLEADO — quién llama, con qué señales y en qué orden. La tabla puede estar perfecta y sus 64
//       celdas verdes mientras un call-site le pasa un literal, escribe antes de tiempo o mide un snapshot
//       de 6 h. Es la lección de `AttestWiringTests` y de `GroupCreateRoutingWiringTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("GroupsGateLogic · la tabla única de las cuatro puertas (C2)")
struct GroupsGateLogicTests {

    typealias Entry = GroupsGateLogic.Entry
    typealias Step = GroupsGateLogic.Step

    private func step(_ entry: Entry,
                      educational: Bool = true,
                      session: Bool = true,
                      consent: Bool = true,
                      setup: Bool = true,
                      canPresentInvite: Bool = true) -> Step {
        GroupsGateLogic.nextStep(
            entry: entry,
            hasSeenEducational: educational,
            hasSession: session,
            isConsented: consent,
            hasCompletedSetup: setup,
            canPresentInviteOnboarding: canPresentInvite)
    }

    // MARK: - El educativo: el escalón que C2 añade, y las dos puertas que NO lo anteponen

    @Test("las puertas A y B anteponen el educativo a TODO lo demás")
    func organizerAndCard_showEducationalFirst() {
        for entry in [Entry.organizer, .onboardingCard] {
            #expect(step(entry, educational: false, session: false, consent: false, setup: false)
                    == .presentEducational)
            // Y también cuando ya hay sesión y consent: el educativo es el PRIMER término, no un fallback.
            #expect(step(entry, educational: false) == .presentEducational)
        }
    }

    /// La medición que justifica la asimetría, y que el docblock de la tabla explica: el invitado tiene su
    /// propio educativo (`GroupInviteOnboardingView`, contextual al link) y el tab presenta el general al
    /// montarse. Anteponerlo aquí daría dos educativos seguidos, o una segunda presentación compitiendo.
    @Test("las puertas C y D NO anteponen el educativo general")
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

    @Test("`showsEducationalFirst` es exactamente {organizer, onboardingCard}")
    func educationalFlagIsExhaustive() {
        let conEducativo = Entry.allCases.filter(\.showsEducationalFirst)
        #expect(Set(conEducativo) == Set([.organizer, .onboardingCard]),
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

    @Test("con sesión y sin consent, consent — en las cuatro puertas")
    func sessionWithoutConsent_alwaysConsent() {
        for entry in Entry.allCases {
            #expect(step(entry, consent: false, setup: false) == .presentConsent)
            #expect(step(entry, consent: false, setup: true) == .presentConsent)
        }
    }

    // MARK: - Los terminales, uno por puerta

    @Test("terminal de organizer/onboardingCard: nombre si falta el alta, formulario si ya está")
    func organizerTerminals() {
        for entry in [Entry.organizer, .onboardingCard] {
            #expect(step(entry, setup: false) == .presentName)
            #expect(step(entry, setup: true) == .presentGroupForm)
        }
    }

    @Test("terminal de invite: onboarding del invitado si es fresco, si no join")
    func inviteTerminals() {
        #expect(step(.invite, setup: false) == .presentInviteOnboarding)
        #expect(step(.invite, setup: true) == .join)
        // El discriminador del CTA del propio onboarding: sin él, el tap de «unirme» re-presentaría la
        // vista que lo emitió.
        #expect(step(.invite, setup: false, canPresentInvite: false) == .join)
    }

    @Test("terminal de tab: siempre el formulario — el tab no da de alta a nadie")
    func tabTerminalIsAlwaysTheForm() {
        #expect(step(.tab, setup: false) == .presentGroupForm)
        #expect(step(.tab, setup: true) == .presentGroupForm)
    }

    // MARK: - Dominio completo

    /// Las 64 celdas decididas, para que añadir un `Entry` o un `Step` sin decidir su celda no pase en
    /// verde por omisión. Y la aserción que carga el peso: **el nombre solo es alcanzable con identidad y
    /// consent**, que es la invariante del chip expresada sobre la tabla.
    @Test("las 64 celdas están decididas y `presentName` exige sesión Y consent")
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
        // organizer y onboardingCard × (educativo visto) × (setup pendiente) = 2
        #expect(nombres == 2, "cambió el nº de celdas que llegan al alta: \(nombres)")
    }
}

// MARK: - Las tres derivaciones

/// Lo que este chip promete es que las tres tablas **derivan** y no se prometen paridad por docblock. Si
/// alguna volviera a decidir por su cuenta, estas aserciones caen.
@Suite("C2 · las tres tablas derivan de GroupsGateLogic")
struct GroupsGateDerivationTests {

    @Test("GroupsOrganizerFlowLogic espeja la tabla para `.organizer` y `.onboardingCard`")
    func organizerFlowMirrorsTheTable() {
        for entry in [GroupsGateLogic.Entry.organizer, .onboardingCard] {
            for educational in [false, true] {
                for session in [false, true] {
                    for consent in [false, true] {
                        for setup in [false, true] {
                            let derivado = GroupsOrganizerFlowLogic.nextStep(
                                hasSeenEducational: educational, hasSession: session,
                                isConsented: consent, hasCompletedSetup: setup, entry: entry)
                            let esperado: GroupsOrganizerFlowLogic.Step = switch GroupsGateLogic.nextStep(
                                entry: entry, hasSeenEducational: educational, hasSession: session,
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
    }

    @Test("GroupBackendInviteEntryLogic sigue siendo la tabla de `.invite`, sin educativo")
    func inviteEntryMirrorsTheTable() {
        for session in [false, true] {
            for consent in [false, true] {
                for onboarded in [false, true] {
                    for canPresent in [false, true] {
                        let derivado = GroupBackendInviteEntryLogic.nextStep(
                            hasSession: session, isConsented: consent,
                            hasCompletedOnboarding: onboarded, canPresentOnboarding: canPresent)
                        let tabla = GroupsGateLogic.nextStep(
                            entry: .invite, hasSeenEducational: true, hasSession: session,
                            isConsented: consent, hasCompletedSetup: onboarded,
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

        // Y lo que SÍ tiene que haber: la cesión a la cadena.
        #expect(Self.count("onGroupsOnlyComplete(GroupsOnlyOnboardingPayload(", in: code) == 1, """
            la card «Solo grupos» ya no cede a la cadena. Sin este callback la rama o no completa, o \
            —peor— alguien le devuelve un camino que escribe.
            """)
    }

    /// El gemelo del anterior en la otra dirección: la card tiene que estar CABLEADA. Sin esto, quitar el
    /// callback del call-site deja `completeOnboarding` haciendo `return` en silencio y la card muerta,
    /// con el test de arriba en VERDE.
    @Test("MUTACIÓN (b): ContentView cablea `onGroupsOnlyComplete` y arranca la cadena sin escribir")
    func contentViewWiresTheCard() throws {
        let code = try Self.code(Self.contentView)

        #expect(Self.count("onGroupsOnlyComplete:", in: code) == 1,
                "ContentView dejó de cablear la card «Solo grupos» a la cadena")
        #expect(code.contains("func startGroupsOnlyBranch(payload: GroupsOnlyOnboardingPayload)"),
                "desapareció el arranque de la rama de la card")
        // El payload viaja en `@State`, no en `UserDefaults`: es lo que hace comprobable el «nada se
        // persiste hasta saber quién es».
        #expect(code.contains("@State private var pendingGroupsOnlyPayload: GroupsOnlyOnboardingPayload?"), """
            el payload de la card dejó de vivir en memoria. Persistirlo es escribir antes de tiempo con \
            otro nombre.
            """)
    }

    // MARK: - El alta sigue teniendo UN solo sitio donde escribe

    @Test("MUTACIÓN (c): `completeSetup` se llama SOLO desde detrás de la cadena, en 2 sitios")
    func completeSetupHasExactlyTwoCallSites() throws {
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
        #expect(Set(sitios) == Set(["GroupsOrganizerNameView.swift×1", "ContentView.swift×1"]), """
            cambiaron los call-sites del alta. Los DOS legítimos están detrás de la cadena completa \
            (educativo → login → consent): la pantalla del nombre (puerta A) y el caso `.presentName` con \
            payload del router (puerta B). Un tercero es, con casi total seguridad, una escritura del trío \
            adelantada. Encontrados: \(sitios.sorted())
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
            salta el primer escalón de la cadena con las 64 celdas de la tabla en VERDE.
            """)
        // La lectura que NO puede volver al `@AppStorage`: cuando la card B escribe el trío y re-submitea,
        // el espejo observable puede no haberse refrescado y la cadena repetiría el alta.
        #expect(code.contains("hasCompletedSetup: UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)"), """
            el router volvió a decidir el alta con el `@AppStorage`. Se refresca por notificación, así que \
            dentro de la misma vuelta puede seguir diciendo `false` y `.presentName` se ejecutaría dos veces.
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
            desapareció el seam del educativo. Sin él, el PRIMER escalón de las cuatro puertas vuelve a ser \
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
