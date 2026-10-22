//
//  GroupInviteSheetAlwaysShownTests.swift
//  YalaTests
//
//  «Al invitado que ya tiene cuenta no le aparece la hoja de Unirme: entra al grupo solo»
//  (device, TF 2.1 build 12). Veredicto del owner: la hoja aparece SIEMPRE.
//
//  Tres mitades, y ninguna cubre a las otras:
//    1. LA REPRODUCCIÓN — `drive` con una invitación sin confirmar presenta la hoja en vez de unir. Es el
//       test que hay que poder poner rojo revirtiendo el fix; si no se pone, no prueba el defecto.
//    2. LA SEÑAL — el sello de la confirmación: quién lo pone, quién no, y que un enlace nuevo no lo hereda.
//    3. EL CABLEADO (source-scan) — que la hoja presentada a quien ya tiene cuenta no le corra el ALTA
//       encima. La decisión puede estar perfecta y sus celdas verdes mientras el CTA le pisa las
//       preferencias vivas y le escala `onboardingMode` al iKV, que es el daño caro.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("La hoja del invitado se presenta SIEMPRE (2026-09-05)", .serialized)
struct GroupInviteSheetAlwaysShownTests {

    /// Caja de captura del `joinProvider` (todo corre en el main actor).
    final class JoinSpy {
        var calls = 0
        var displayName: String?
    }

    /// Molde de `GroupBackendInviteEntryHandlerJoinTests.makeEnv`: `UserDefaults` aislado, providers del
    /// handler restaurados al salir. Añade el router, que aquí SÍ se observa.
    private func makeEnv(_ spy: JoinSpy) -> () -> Void {
        let suite = "test.invitesheet.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        PendingJoinStore.defaults = d
        let savedJoin = GroupBackendInviteEntryHandler.joinProvider
        let savedSession = GroupBackendInviteEntryHandler.hasSessionProvider
        let savedConsent = GroupBackendInviteEntryHandler.isConsentedProvider
        let savedProfile = GroupBackendInviteEntryHandler.profileNameProvider
        let savedReadiness = RouterEntryGate.shared.readinessProvider
        let savedMirror = GroupBackendInviteEntryHandler.mountAttachesMirrorProvider

        // Sesión y consent RESUELTOS: los dos escalones anteriores del flujo encadenado ya pasaron, que es
        // el estado en el que el terminal del invitado decide algo.
        GroupBackendInviteEntryHandler.hasSessionProvider = { true }
        GroupBackendInviteEntryHandler.isConsentedProvider = { true }
        GroupBackendInviteEntryHandler.profileNameProvider = { "Pia" }
        GroupBackendInviteEntryHandler.joinProvider = { _, name, _ in
            spy.calls += 1
            spy.displayName = name
            return JoinGroupResult(groupID: "G1", memberKey: "sub", status: "pendingApproval", rebound: false)
        }
        // **El mount, APAGADO explícitamente, y no es ceremonia: en el host de test el testigo MIENTE.**
        // `SwiftDataConfiguration.personalStoreMountedDecision` se queda en el default de su declaración
        // (`.iCloudMirror`) porque aquí nadie monta el store de producción, así que sin esta línea la
        // puerta del invitado (`GroupInviteNeutralGateLogic`) dispararía en TODAS las celdas y `drive`
        // saldría por el desvío al neutro antes de decidir el terminal — verde o rojo, no estaría midiendo
        // la hoja. `false` es la verdad de un dispositivo sin espejo, que es donde vive este flujo.
        GroupBackendInviteEntryHandler.mountAttachesMirrorProvider = { false }
        // App lista: sin esto el gate DIFIERE el intent al buffer y la cola queda vacía por una razón que
        // no tiene nada que ver con lo que se mide.
        RouterEntryGate.shared.readinessProvider = { (hasCompletedOnboarding: true, isBootstrapInitialized: true) }
        // Canal ENCENDIDO. Los tests que entran por `GroupJoinReconciler` lo necesitan: `decideBackend`
        // lee el flag por su cuenta —no por los providers del handler— y con él apagado devuelve
        // `.skipFlagOff` sin llegar nunca a `drive`. Un verde ahí no diría nada del terminal del invitado.
        CloudSyncFlags.groupsBackendEnabled = true
        AppRouter.shared._testReset()
        GroupBackendInviteEntryHandler.clearInviteTapArms()
        GroupJoinIntentTracker.shared.clear()

        return {
            GroupBackendInviteEntryHandler.joinProvider = savedJoin
            GroupBackendInviteEntryHandler.hasSessionProvider = savedSession
            GroupBackendInviteEntryHandler.isConsentedProvider = savedConsent
            GroupBackendInviteEntryHandler.profileNameProvider = savedProfile
            GroupBackendInviteEntryHandler.mountAttachesMirrorProvider = savedMirror
            RouterEntryGate.shared.readinessProvider = savedReadiness
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            AppRouter.shared._testReset()
            PendingJoinStore.defaults = .standard
            d.removePersistentDomain(forName: suite)
            GroupBackendInviteEntryHandler.clearInviteTapArms()
            GroupJoinIntentTracker.shared.clear()
        }
    }

    private func presentsInviteSheet() -> Bool {
        AppRouter.shared.queueSnapshot.contains {
            if case .presentGroupBackendInviteOnboarding = $0 { return true }
            return false
        }
    }

    // MARK: - 1 · La reproducción

    /// **EL TEST DEL TICKET.** Una invitación sin confirmar: `drive` PRESENTA la hoja y **no llama a
    /// `join_group`**. Antes del fix, con el onboarding del device ya hecho, esto llamaba al RPC sin
    /// presentar nada y el invitado se enteraba de que estaba dentro del grupo por su cuenta, si pasaba
    /// por el tab.
    ///
    /// **Aquí no se monta ningún `hasCompletedOnboarding`, y esa ausencia ES el arreglo**: `drive` ya no
    /// lee esa señal, así que no hay nada que montar. Antes había que fingirla —era el término que
    /// decidía— y por eso el handler llevaba un provider inyectable, hoy retirado. Que la decisión sea la
    /// misma con cuenta y sin ella se fija donde es puro y sin `UserDefaults` de por medio:
    /// `GroupsGateLogicTests.inviteTerminalIgnoresPriorSetup`.
    ///
    /// Las dos aserciones son necesarias: «presenta» sin «no se unió» dejaría pasar un fix que enseña la
    /// hoja DESPUÉS de haber metido a la persona en el grupo, que es el defecto con una pantalla encima.
    @Test func unconfirmedInvite_presentsSheetAndDoesNotJoinYet() async {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        await GroupBackendInviteEntryHandler.drive(groupID: "G1", token: "tok", source: .universalLink)

        #expect(presentsInviteSheet(), "el invitado se saltó la hoja")
        #expect(spy.calls == 0, "se unió al grupo antes de que la persona confirmara")
    }

    /// El «venga de donde venga» del owner: los CUATRO orígenes que no son una acción de la persona
    /// deciden idéntico. Tap con la app viva, arranque en frío, vuelta a primer plano y la continuación
    /// tras el sign-in/consent.
    @Test func everyNonUserOrigin_presentsTheSheet() async {
        for source in [GroupBackendInviteEntryHandler.Source.universalLink, .boot, .foreground, .continuation] {
            let spy = JoinSpy()
            let cleanup = makeEnv(spy); defer { cleanup() }

            GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
            await GroupBackendInviteEntryHandler.drive(groupID: "G1", token: "tok", source: source)

            #expect(presentsInviteSheet(), "origen \(source.rawValue): no presentó la hoja")
            #expect(spy.calls == 0, "origen \(source.rawValue): se unió sin confirmación")
        }
    }

    /// La mitad que evita el sobre-arreglo: el CTA de la propia hoja (`.userAction`) NO la re-presenta —
    /// se uniría a sí mismo en bucle— y sale el join con el nombre que la persona dejó en el intent.
    @Test func userActionFromTheSheet_joinsWithoutRePresenting() async {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        PendingJoinStore.updateDisplayName("Pia la invitada")
        await GroupBackendInviteEntryHandler.drive(groupID: "G1", token: "tok", source: .userAction)

        #expect(!presentsInviteSheet(), "el CTA de la hoja re-presentó la vista que lo emitió")
        #expect(spy.calls == 1)
        #expect(spy.displayName == "Pia la invitada")
    }

    // MARK: - 2 · La señal

    /// El sello lo pone SOLO una acción de la persona, y una vez sellado la hoja no vuelve.
    @Test func onlyUserActionSealsTheConfirmation() async {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        for source in [GroupBackendInviteEntryHandler.Source.universalLink, .boot, .foreground, .continuation] {
            await GroupBackendInviteEntryHandler.drive(groupID: "G1", token: "tok", source: source)
            #expect(PendingJoinStore.entry(zoneName: "G1")?.isInviteConfirmed == false,
                    "\(source.rawValue) confirmó la invitación por la persona")
        }

        await GroupBackendInviteEntryHandler.drive(groupID: "G1", token: "tok", source: .userAction)
        #expect(PendingJoinStore.entry(zoneName: "G1")?.isInviteConfirmed == true)

        // Y con el sello puesto, un trigger de fondo ya no presenta: reintenta el join.
        AppRouter.shared._testReset()
        let callsBefore = spy.calls
        await GroupBackendInviteEntryHandler.drive(groupID: "G1", token: "tok", source: .boot)
        #expect(!presentsInviteSheet(), "la hoja se re-presentó a quien ya había confirmado")
        #expect(spy.calls == callsBefore + 1)
    }

    /// **Un enlace nuevo NO hereda el «sí» del anterior.** Es la única excepción al patrón de preservación
    /// de `persistIntent` (que sí conserva nombre, moneda, llave legacy y marca), y es deliberada: tapear
    /// un enlace es pedir entrar, y heredar la confirmación devolvería el defecto entero — entrar al grupo
    /// sin que nadie enseñe nada.
    @Test func reTappingALink_clearsThePriorConfirmation() async {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        await GroupBackendInviteEntryHandler.drive(groupID: "G1", token: "tok", source: .userAction)
        #expect(PendingJoinStore.entry(zoneName: "G1")?.isInviteConfirmed == true)

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok2")
        #expect(PendingJoinStore.entry(zoneName: "G1")?.isInviteConfirmed == false,
                "el enlace nuevo heredó la confirmación del anterior")
        // Y lo que SÍ se preserva sigue preservándose: el contraste es lo que hace legible la excepción.
        #expect(PendingJoinStore.entry(zoneName: "G1")?.inviteToken == "tok2")
    }

    /// **Confirmar A no puede sellar B, y esto se mide por el CAMINO REAL** — el de abajo mide el store.
    ///
    /// Lo cazó una review adversarial, y es el defecto que este arreglo tenía dentro: `reconcile` barre
    /// TODAS las entries vigentes (hasta 8, 7 días de TTL) y mapeaba `.acceptShare` a `.userAction` para
    /// cada una ⇒ tapear «Unirme» en la hoja de A sellaba B como confirmada, y **la hoja de B no volvía a
    /// presentarse jamás**: exactamente el defecto que este PR existe para cerrar, reintroducido por su
    /// propia señal. `userConfirmedZone` lo acota.
    ///
    /// La aserción que carga el peso es la SEGUNDA: que B siga sin confirmar. La primera solo comprueba
    /// que el camino funciona para quien sí confirmó.
    @Test func confirmingOneInvite_doesNotSealTheOthers() async {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "t1")
        GroupBackendInviteEntryHandler.persistIntent(groupID: "G2", token: "t2")

        // El CTA de la hoja de G1, tal como lo emite la vista: con SU zona.
        await GroupJoinReconciler.reconcile(trigger: .acceptShare, userConfirmedZone: "G1")

        #expect(PendingJoinStore.entry(zoneName: "G1")?.isInviteConfirmed == true)
        #expect(PendingJoinStore.entry(zoneName: "G2")?.isInviteConfirmed == false, """
            confirmar G1 selló también G2. Su hoja ya no se presentará nunca, que es el defecto entero \
            del ticket colado por la puerta de atrás.
            """)
    }

    /// Y el gemelo del anterior: la hoja de la invitación NO confirmada sigue presentándose.
    @Test func theUnconfirmedInvite_stillGetsItsSheet() async {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "t1")
        GroupBackendInviteEntryHandler.persistIntent(groupID: "G2", token: "t2")
        await GroupJoinReconciler.reconcile(trigger: .acceptShare, userConfirmedZone: "G1")

        AppRouter.shared._testReset()
        await GroupBackendInviteEntryHandler.drive(groupID: "G2", token: "t2", source: .boot)
        #expect(presentsInviteSheet(), "la invitación que nadie confirmó perdió su hoja")
    }

    /// Un re-tap del MISMO enlace conserva el «sí» ya dado. Sin esto, reabrir el mensaje de WhatsApp para
    /// releerlo —estando ya en «esperando aprobación»— devolvía a la persona al paso «pon tu nombre», y a
    /// repetir una confirmación que ya había dado: `step(…)` no mira la fase hasta que se tapea el CTA.
    @Test func reTappingTheSameLink_keepsTheConfirmation() async {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy); defer { cleanup() }

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        await GroupBackendInviteEntryHandler.drive(groupID: "G1", token: "tok", source: .userAction)
        #expect(PendingJoinStore.entry(zoneName: "G1")?.isInviteConfirmed == true)

        GroupBackendInviteEntryHandler.persistIntent(groupID: "G1", token: "tok")
        #expect(PendingJoinStore.entry(zoneName: "G1")?.isInviteConfirmed == true,
                "el mismo enlace deshizo una confirmación ya dada")
    }

    /// Confirmar es un acto sobre UN grupo: con dos invitaciones vivas, decir que sí a una no puede colar
    /// la otra. (Al revés que el displayName, que es del perfil y sí se propaga a todas — ver
    /// `PendingJoinStore.updateDisplayName`.)
    @Test func confirmationIsPerZone_andIdempotent() {
        let spy = JoinSpy()
        let cleanup = makeEnv(spy); defer { cleanup() }

        PendingJoinStore.save(PendingJoinEntry(
            zoneName: "G1", zoneOwnerName: "", backendGroupID: "G1", inviteToken: "t1"))
        PendingJoinStore.save(PendingJoinEntry(
            zoneName: "G2", zoneOwnerName: "", backendGroupID: "G2", inviteToken: "t2"))

        let first = Date(timeIntervalSince1970: 1_700_000_000)
        PendingJoinStore.markInviteConfirmed(zoneName: "G1", at: first)
        #expect(PendingJoinStore.entry(zoneName: "G1")?.isInviteConfirmed == true)
        #expect(PendingJoinStore.entry(zoneName: "G2")?.isInviteConfirmed == false,
                "confirmar G1 coló también a G2")

        // Idempotente, y conserva el PRIMER instante: es cuando de verdad lo dijo.
        PendingJoinStore.markInviteConfirmed(zoneName: "G1", at: first.addingTimeInterval(3600))
        #expect(PendingJoinStore.entry(zoneName: "G1")?.inviteConfirmedAt == first)
    }

    /// Back-compat del campo: un intent persistido por la versión ANTERIOR decodifica sin confirmar ⇒ ve la
    /// hoja. El default seguro es el que pide confirmación, nunca el que se une solo. Quien actualice la app
    /// con una invitación a medias es exactamente el caso que no puede saltarse el paso.
    @Test func legacyPersistedIntent_decodesAsUnconfirmed() throws {
        let json = """
        {"zoneName":"G9","zoneOwnerName":"","backendGroupID":"G9","inviteToken":"tok",\
        "createdAt":"2026-09-01T12:00:00Z"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entry = try decoder.decode(PendingJoinEntry.self, from: json)
        #expect(entry.inviteConfirmedAt == nil)
        #expect(entry.isInviteConfirmed == false)
    }

    // MARK: - 3 · El cableado (source-scan)

    /// El escáner lee el CÓDIGO sin líneas de comentario: los docblocks de esta rama nombran a propósito lo
    /// que prohíben, y contar la prosa haría que documentar el invariante lo «cumpliera». Molde de
    /// `GroupsGateWiringTests`.
    private static func code(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let inviteView = "Yala/App/Views/Groups/GroupInviteOnboardingView.swift"

    /// **La aserción que carga el peso del riesgo caro.** Presentar la hoja a quien ya tiene cuenta es
    /// media solución; la otra media es que su CTA no le corra encima el alta de primer arranque. De todo
    /// lo que escribe `performSilentSetup`, lo que no vuelve es `onboardingMode = .groupInvite`: rank 1 > 0
    /// en un merge never-downgrade que viaja al iKV del Apple ID, así que sus OTROS dispositivos quedarían
    /// con la app recortada a Grupos y su única recuperación sería restaurar por iCloud.
    @Test func joinOnlySetup_writesNothingOfTheRegistration() throws {
        let code = try Self.code(Self.inviteView)
        let joinOnly = try #require(
            code.components(separatedBy: "private func performJoinOnlySetup() {").dropFirst().first)
        let body = try #require(joinOnly.components(separatedBy: "\n    private func ").first)

        for prohibido in [
            "onboardingMode = .groupInvite",        // never-downgrade cross-device: el daño que no vuelve
            "AppPreferences.Keys.userName",         // el nombre es para este grupo, no para el perfil
            "defaultCurrencyCode",                  // pisaría la moneda que la persona ya eligió
            "defaultPeriod",
            "seedCategoriesIfNeeded",               // ya tiene sus categorías
            "seedDefaultNotificationsIfNeeded",
            "signalOnboardingCompleted",            // no hay alta nueva que anunciar
            "updateCurrentUserDisplayName",         // DEVICE-WIDE: la renombraría en TODOS sus grupos
            "localRegistrationCompleted",           // contaría un registro por alguien ya registrado
            // Medido el 2026-09-05: marcarla APAGA el educativo de Grupos (3 pantallas) a quien nunca lo
            // ha visto, per-device y para siempre. Esta hoja es UNA pantalla de bienvenida: hace de
            // educativo para quien llega sin app, no para quien ya usa Yala y entra en Grupos hoy.
            "hasShownGroupsOnboarding"
        ] {
            #expect(!body.contains(prohibido), """
                `performJoinOnlySetup` volvió a escribir `\(prohibido)`. Eso es el ALTA, y corrida sobre \
                una cuenta que ya existe le pisa preferencias vivas. Si de verdad hace falta ahí, la \
                pregunta previa es por qué esta persona no pasó por el alta de verdad.
                """)
        }
        // Y lo que SÍ tiene que haber: el nombre para este join.
        #expect(body.contains("PendingJoinStore.updateDisplayName"), """
            `performJoinOnlySetup` dejó de propagar el nombre al join intent. Sin él, quien teclea su \
            nombre en la hoja entra al grupo con el del perfil (o con «Usuario»), y el campo que acaba \
            de rellenar no sirvió para nada.
            """)
    }

    /// El gemelo en la otra dirección: la bifurcación tiene que estar CABLEADA. Sin ella el test de arriba
    /// pasa en verde con `performJoinOnlySetup` muerto y todo el mundo corriendo el alta, que es el estado
    /// anterior al arreglo.
    @Test func theCTAForksOnWhetherThePersonAlreadyHasAnAccount() throws {
        let code = try Self.code(Self.inviteView)
        let tap = try #require(
            code.components(separatedBy: "private func handleJoinTap() {").dropFirst().first)
        let body = try #require(tap.components(separatedBy: "\n    private func ").first)

        #expect(body.contains("if hasCompletedOnboarding {") && body.contains("performJoinOnlySetup()"), """
            el CTA de la hoja dejó de bifurcar: o le corre el alta completa a quien ya tiene cuenta \
            (pisándole las preferencias), o deja sin alta al invitado fresco.
            """)
        #expect(body.contains("performSilentSetup()"),
                "el invitado FRESCO se quedó sin su alta — la hoja es su único camino a tenerla")
    }

    /// **La salida de la hoja, y a quién se le ofrece.** Sin ella, ampliar la audiencia de esta pantalla
    /// convertía su falta de salida —inocua para quien llegaba sin app— en una jaula: el cover es a
    /// pantalla completa, su paso de bienvenida solo tenía «Unirme al grupo», y el reconciler lo vuelve a
    /// montar en cada arranque y cada foreground mientras el intent viva (7 días). Un enlace tapeado por
    /// error le secuestraba la app a quien ya usa Yala hasta que se rindiera y entrara al grupo.
    ///
    /// Y su acotación es la otra mitad: al invitado FRESCO no se le ofrece, porque detrás no tiene app a
    /// la que volver — dejarle salir sería un brick, no una salida.
    @Test func theSheetHasAnExitForWhoeverHasAnAppBehindIt() throws {
        let code = try Self.code(Self.inviteView)

        #expect(code.contains("private var canDecline: Bool { hasCompletedOnboarding }"), """
            desapareció la acotación de la salida. Si se ofrece SIEMPRE, el invitado fresco puede cerrar \
            la hoja y quedarse en una app sin dar de alta; si no se ofrece a NADIE, vuelve la jaula.
            """)
        #expect(code.contains("handleDeclineTap()") && code.contains("invite_decline_button"),
                "la hoja se quedó sin salida: su único control vuelve a ser unirse al grupo")
        // Cerrar sin retirar el intent es la misma jaula con un paso más: el arranque siguiente la remonta.
        #expect(code.contains("PendingJoinStore.clear(zoneName: pendingJoinZone)"), """
            «Más tarde» dejó de retirar la invitación. El cover se vuelve a montar en el próximo arranque \
            y la salida deja de serlo.
            """)
    }

    /// El CTA reconcilia SOLO su zona. Es el cableado del que depende
    /// `confirmingOneInvite_doesNotSealTheOthers`: con el argumento fuera, ese test seguiría verde
    /// llamando al reconciler a mano mientras producción sella de más.
    @Test func theCTAReconcilesOnlyItsOwnZone() throws {
        let code = try Self.code(Self.inviteView)
        #expect(code.contains("reconcile(trigger: .acceptShare, userConfirmedZone: pendingJoinZone)"), """
            el CTA volvió a reconciliar sin decir de qué grupo habla. `reconcile` barre TODAS las \
            invitaciones vigentes y las sellaría como confirmadas: la hoja de las demás no se \
            presentaría nunca.
            """)
    }

    /// La SEGUNDA puerta. Corregir solo la tabla no arregla nada: el intent llega al drain del router y su
    /// `else` lo manda a `continueFlow` → join. Tiene que preguntar lo mismo, y leerlo del mismo sitio.
    @Test func theRouterDrainAsksTheSameQuestionAsTheTable() throws {
        let code = try Self.code("Yala/App/ContentView.swift")
        let drain = try #require(
            code.components(separatedBy: "case .presentGroupBackendInviteOnboarding(let zone):")
                .dropFirst().first)
        let body = try #require(drain.components(separatedBy: "\n        case ").first)

        #expect(body.contains("switch PendingJoinStore.entry(zoneName: zone)?.isInviteConfirmed"), """
            el drain volvió a decidir por su cuenta. Es la puerta gemela de \
            `GroupBackendInviteEntryLogic.nextStep`: si preguntan cosas distintas, una de las dos se \
            salta la hoja — que es exactamente como el defecto sobrevivió a tener la tabla bien.
            """)
        // TRES casos, y el tercero importa: sin entry no hay nada que confirmar, así que no se presenta.
        // Un `?? false` ahí le enseña la hoja a quien YA está dentro del grupo, con un CTA que no puede
        // hacer nada — `reconcile` sale por su `guard !entries.isEmpty`.
        #expect(body.contains("case .none:"), """
            el drain volvió a colapsar «no hay invitación» con «no la confirmó». Son estados distintos: \
            el intent puede morir entre el submit y el drenaje (el pull baja el member y \
            `.correctAndClear` lo limpia mientras un blocker retiene la cola).
            """)
        #expect(!body.contains("if !hasCompletedOnboarding {"), """
            el drain volvió a cortar por el alta. Esa señal responde «¿tiene cuenta?» y la pregunta es \
            «¿confirmó esta invitación?».
            """)
    }
}
