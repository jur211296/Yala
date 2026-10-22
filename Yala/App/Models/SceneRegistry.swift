//
//  SceneRegistry.swift
//  Yala
//
//  Las ventanas vivas de Yala, cuál es la líder y a cuál va lo que llega de fuera (fase 4 del carril adaptativo).
//

import Foundation
import UIKit

/// Registro de las ventanas de Yala en este proceso.
///
/// **Tres preguntas, y solo estas:**
/// 1. **¿Qué ventana es la líder?** La viva más antigua. Es la única que monta `ContentView`, el shell de proceso
///    (arranque, Welcome, borrados remotos, cierre de sesión, alertas de sistema). Si se cierra, asciende la siguiente.
/// 2. **¿A qué ventana va un intent?** `routingTargetID`: la que recibió lo último de fuera (enlace, notificación) o la
///    que el usuario puso al frente, y si ya no existe, la líder. `AppRouter` sella cada intent con ella al encolar.
/// 3. **¿Qué navegación tiene cada una?** `navigation(for:)`, para el código que no es una vista.
///
/// Sin ventanas registradas (host de unit tests antes de montar) todo devuelve `nil` y el router se comporta como con
/// una sola ventana.
@Observable @MainActor
final class SceneRegistry {

    static let shared = SceneRegistry()

    /// Una ventana viva. `scene` llega después de registrarse (la sonda de ventana lo resuelve al montar) y es `weak`:
    /// quien manda sobre su vida es UIKit.
    final class Entry {
        let navigation: SceneNavigation
        weak var scene: UIWindowScene?
        /// `persistentIdentifier` de la sesión de la escena, guardado aparte porque `scene` puede soltarse antes
        /// de que llegue la notificación de desconexión.
        var sessionID: String?

        init(navigation: SceneNavigation) {
            self.navigation = navigation
        }

        var id: UUID { navigation.id }
    }

    /// Ventanas vivas, en orden de registro: la primera es la líder.
    private(set) var entries: [Entry] = []

    /// La ventana que recibió lo último de fuera o se puso al frente. Puede apuntar a una ya cerrada: se valida al
    /// leerla (`routingTargetID`).
    private(set) var focusedID: UUID?

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    /// Escenas que la sonda resolvió antes del alta. Débiles: si la ventana se cierra antes, no se retiene la escena.
    @ObservationIgnored private var scenesAwaitingRegistration: [UUID: WeakScene] = [:]

    struct WeakScene {
        weak var scene: UIWindowScene?
    }

    private init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIScene.didDisconnectNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let scene = note.object as? UIScene else { return }
            let sessionID = scene.session.persistentIdentifier
            MainActor.assumeIsolated {
                self?.sceneDidDisconnect(sessionID: sessionID)
            }
        })
        observers.append(center.addObserver(
            forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let sessionID = (note.object as? UIWindow)?.windowScene?.session.persistentIdentifier else { return }
            MainActor.assumeIsolated {
                self?.noteFocused(sessionID: sessionID)
            }
        })
    }

    // MARK: - Lecturas

    /// La líder: la ventana viva más antigua.
    var leaderID: UUID? { entries.first?.id }

    var leaderNavigation: SceneNavigation? { entries.first?.navigation }

    func isAlive(_ id: UUID) -> Bool {
        entries.contains { $0.id == id }
    }

    func navigation(for id: UUID) -> SceneNavigation? {
        entries.first { $0.id == id }?.navigation
    }

    var allNavigations: [SceneNavigation] { entries.map(\.navigation) }

    var aliveIDs: [UUID] { entries.map(\.id) }

    /// La ventana a la que va lo que no trae destino propio. Ver `SceneRoutingLogic.routingTarget`.
    var routingTargetID: UUID? {
        SceneRoutingLogic.routingTarget(focused: focusedID, alive: entries.map(\.id))
    }

    /// Navegación de la ventana que está delante. Para el código que no es una vista (arranque, comandos de teclado).
    var routingNavigation: SceneNavigation? {
        routingTargetID.flatMap(navigation(for:))
    }

    /// La escena de UIKit de una ventana, si la sonda ya la resolvió.
    func windowScene(for id: UUID) -> UIWindowScene? {
        entries.first { $0.id == id }?.scene
    }

    /// La sesión de escena de la líder, para traerla al frente desde una seguidora.
    var leaderSceneSession: UISceneSession? { entries.first?.scene?.session }

    // MARK: - Cierre de sesión con varias ventanas

    /// La ventana que lanzó el cierre de sesión en curso: la que estaba delante al entrar en `.working`. `nil` fuera
    /// de `.working`. Es del PROCESO y no de cada ventana: si la que lo lanzó se cierra, las demás siguen sabiendo que
    /// no fueron ellas (review adversarial, 2026-10-02).
    private(set) var signOutDriverID: UUID?

    func signOutPhaseDidChange(from old: CloudSessionSignOut.Phase, to new: CloudSessionSignOut.Phase) {
        signOutDriverID = SignOutDriverLogic.driver(
            previous: signOutDriverID, oldPhase: old, newPhase: new, focused: requestedSignOutDriverID ?? routingTargetID)
        if new != .working, old == .working { requestedSignOutDriverID = nil }
    }

    /// Un cierre que tarda en llegar a `.working` (el borrado de cuenta pasa antes por varias llamadas de red) anota
    /// aquí la ventana que lo pidió EN EL TOQUE; si no, para cuando entra el usuario pudo poner otra al frente y los
    /// papeles saldrían al revés.
    @ObservationIgnored private var requestedSignOutDriverID: UUID?

    func noteSignOutRequested() {
        requestedSignOutDriverID = routingTargetID
    }

    /// ¿Debe la ventana `id` dejar de operar por un cierre de sesión que lanzó otra?
    func isBusyBySignOut(_ id: UUID) -> Bool {
        SignOutDriverLogic.windowIsBusy(
            windowID: id,
            driverID: signOutDriverID,
            aliveCount: entries.count,
            signOutWorking: CloudSessionSignOut.shared.phase == .working)
    }

    // MARK: - Lo que corre una vez por proceso

    /// Generación del contenedor cuyos chequeos de arranque (`ContentView.runReturningUserPostChecks`) ya corrieron.
    /// Una ventana que asciende a líder monta un `ContentView` nuevo; sin esto repetiría a mitad de sesión la oferta
    /// de prueba, Novedades y la reanudación de borrados pendientes, con el de la líder anterior quizá aún en vuelo.
    @ObservationIgnored private var bootChecksGeneration: Int?

    /// `true` la primera vez por generación de contenedor; después, `false`.
    func claimBootChecks(generation: Int) -> Bool {
        guard bootChecksGeneration != generation else { return false }
        bootChecksGeneration = generation
        return true
    }

    /// Cuántas veces el PROCESO volvió a primer plano. Lo observa `ContentView` para sus chequeos de foreground: el
    /// `scenePhase` de su vista es el de su ventana, y con varias el usuario puede volver por otra.
    private(set) var appActivations = 0

    @ObservationIgnored private var lastHandledAppPhase: ScenePhaseKey?

    enum ScenePhaseKey { case active, inactive, background }

    /// El ciclo de vida del proceso cuelga de los dos `WindowGroup` (si solo queda abierta una ventana de
    /// `WindowRoute`, el primero puede no tener ninguna). Con los dos vivos los dos avisan del mismo cambio: el
    /// segundo aviso se descarta aquí.
    func shouldHandleAppPhase(_ phase: ScenePhaseKey) -> Bool {
        guard lastHandledAppPhase != phase else { return false }
        lastHandledAppPhase = phase
        if phase == .active { appActivations &+= 1 }
        return true
    }

    // MARK: - Escrituras

    /// La pestaña con la que debe abrir la primera ventana. La pone código que corre antes de que exista ninguna
    /// (los seams de XCUITest en `YalaApp.init`); la consume el primer alta.
    @ObservationIgnored var firstWindowMainTab: AppTab?

    /// Da de alta una ventana. Idempotente: el remonte de la raíz no la vuelve a poner al final.
    func register(_ navigation: SceneNavigation) {
        guard !isAlive(navigation.id) else { return }
        if entries.isEmpty, let tab = firstWindowMainTab {
            navigation.selectedMainTab = tab
            firstWindowMainTab = nil
        }
        entries.append(Entry(navigation: navigation))
        if let scene = scenesAwaitingRegistration.removeValue(forKey: navigation.id)?.scene {
            attach(scene, to: navigation.id)
        }
        // La primera ventana que aparece es la que está delante.
        if !(focusedID.map(isAlive) ?? false) {
            focusedID = navigation.id
        }
        AppRouter.shared.sceneTopologyDidChange()
    }

    /// Asocia la escena de UIKit a la ventana (lo resuelve la sonda al montar).
    func attach(_ scene: UIWindowScene, to id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else {
            // La sonda puede llegar antes que el alta: se guarda y la aplica `register`. Sin escena, la ventana no se
            // daría de baja nunca al cerrarse y, si fuera la líder, nadie ascendería.
            scenesAwaitingRegistration[id] = WeakScene(scene: scene)
            return
        }
        entry.scene = scene
        entry.sessionID = scene.session.persistentIdentifier
        // Si esta ventana ya es la principal (key) cuando llega la sonda, la notificación de key ya pasó.
        if scene.keyWindow != nil, scene.activationState == .foregroundActive {
            focusedID = id
        }
        #if DEBUG
        discardRestoredWindowsForUITestReset(keeping: scene.session)
        #endif
    }

    #if DEBUG
    @ObservationIgnored private var didDiscardRestoredWindows = false

    /// `-uitest-reset` empieza de cero también en ventanas: el iPad RESTAURA las que quedaron abiertas en la corrida
    /// anterior (medido: la ventana de un registro reaparecía al relanzar), y un test que cuenta ventanas dependería
    /// del orden de los anteriores. Se descartan todas menos la primera que se asocia, una vez por proceso.
    private func discardRestoredWindowsForUITestReset(keeping kept: UISceneSession) {
        guard UITestHooks.isActive, UITestHooks.shouldReset, !didDiscardRestoredWindows else { return }
        didDiscardRestoredWindows = true
        for session in UIApplication.shared.openSessions where session.persistentIdentifier != kept.persistentIdentifier {
            UIApplication.shared.requestSceneSessionDestruction(session, options: nil) { error in
                print("SceneRegistry: Error: no se pudo descartar una ventana restaurada: \(error)")
            }
        }
    }
    #endif

    /// Da de baja una ventana. Lo llama la desconexión de su escena y, como red, la desaparición de su raíz.
    func unregister(_ id: UUID) {
        scenesAwaitingRegistration[id] = nil
        guard isAlive(id) else { return }
        entries.removeAll { $0.id == id }
        SceneBusyWindows.set(false, for: id)
        // Si se cerró la que estaba delante, lo está ahora la ventana `key` que quede; sin ninguna, la líder.
        if focusedID == id {
            focusedID = entries.first { $0.scene?.keyWindow != nil && $0.scene?.activationState == .foregroundActive }?.id
        }
        AppRouter.shared.sceneTopologyDidChange()
    }

    /// Un intent del shell de proceso (`.contentView`) solo lo presenta la líder. Si lo pidió el usuario desde OTRA
    /// ventana —crear un grupo sin sesión, activar Yala completo—, sin esto el botón parecería muerto con la líder
    /// tapada o detrás: se trae la líder al frente. Con una sola ventana, o con la líder ya delante, no hace nada.
    func bringLeaderForwardIfAnotherWindowIsFocused() {
        guard entries.count > 1, let leaderID, let focusedID, focusedID != leaderID,
              UIApplication.shared.applicationState == .active,
              let session = leaderSceneSession
        else { return }
        UIApplication.shared.activateSceneSession(for: UISceneSessionActivationRequest(session: session)) { error in
            #if DEBUG
            print("SceneRegistry: Error: no se pudo traer la ventana líder: \(error)")
            #endif
        }
    }

    /// Lo último de fuera llegó a esta ventana (un enlace en su `onOpenURL`), o el usuario la puso al frente.
    func noteFocused(_ id: UUID) {
        guard isAlive(id), focusedID != id else { return }
        focusedID = id
    }

    /// Variante por escena de UIKit: la notificación tocada trae `targetScene`, y la ventana principal se sabe por su
    /// `UIWindow`.
    func noteFocused(scene: UIScene?) {
        guard let sessionID = scene?.session.persistentIdentifier else { return }
        noteFocused(sessionID: sessionID)
    }

    func noteFocused(sessionID: String) {
        guard let entry = entries.first(where: { $0.sessionID == sessionID }) else { return }
        noteFocused(entry.id)
    }

    private func sceneDidDisconnect(sessionID: String) {
        guard let entry = entries.first(where: { $0.sessionID == sessionID }) else { return }
        unregister(entry.id)
    }

    /// Red ante una desconexión que no llegó a notificarse: quita las ventanas cuya escena ya se resolvió y ya no
    /// está entre las conectadas. Las que aún no tienen escena (montando) se quedan.
    func pruneDisconnected() {
        let connected = Set(UIApplication.shared.connectedScenes.map(\.session.persistentIdentifier))
        let stale = entries.filter { entry in
            guard let sessionID = entry.sessionID else { return false }
            return !connected.contains(sessionID)
        }
        for entry in stale { unregister(entry.id) }
    }

    #if DEBUG
    /// Deja el registro vacío para los unit tests.
    func _testReset() {
        entries.removeAll()
        focusedID = nil
    }
    #endif
}

/// Decisión pura de a qué ventana va lo que no trae destino propio.
enum SceneRoutingLogic {

    /// La enfocada si sigue viva; si no, la líder (la primera viva); sin ventanas, `nil`.
    static func routingTarget(focused: UUID?, alive: [UUID]) -> UUID? {
        if let focused, alive.contains(focused) { return focused }
        return alive.first
    }

    /// A qué ventana va un intent SELLADO con `target`: la suya si sigue viva; si se cerró, la que está delante ahora.
    static func effectiveTarget(sealed target: UUID?, focused: UUID?, alive: [UUID]) -> UUID? {
        if let target, alive.contains(target) { return target }
        return routingTarget(focused: focused, alive: alive)
    }

    /// ¿Puede el consumidor de la ventana `consumerScene` drenar un intent sellado con `target`?
    ///
    /// - Consumidor sin ventana (`nil`): solo los unit tests de `AppRouter`, que no montan ventanas. Drena todo, como
    ///   antes de la fase 4.
    /// - Sin ventanas vivas no hay a quién más dárselo: drena.
    /// - Si no, solo la ventana efectiva.
    static func canDrain(sealed target: UUID?, consumerScene: UUID?, focused: UUID?, alive: [UUID]) -> Bool {
        guard let consumerScene else { return true }
        guard let effective = effectiveTarget(sealed: target, focused: focused, alive: alive) else { return true }
        return effective == consumerScene
    }
}
