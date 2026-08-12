//
//  GroupsBackendInviteModifier.swift
//  Yala
//
//  Sheets del flujo de invite BACKEND (G4-invites A2): sign-in solo-grupos y consent de grupos,
//  drenados de `.presentGroupsSignIn` / `.presentGroupsConsent` por ContentView (dueño ÚNICO del
//  anchor — jamás un segundo anchor). ViewModifier separado para el presupuesto del type-checker.
//
//  Encadenado (contrato C7): cada paso re-evalúa condiciones VIVAS — la continuación corre en
//  `onDismiss:` (la dismissal ya terminó ⇒ el siguiente sheet del MISMO anchor no se descarta) y va
//  por `GroupBackendInviteEntryHandler.continueFlow`, que re-lee el intent persistido y decide el
//  siguiente paso (consent → onboarding-fresco → join). Un cancel (toolbar/swipe) NO continúa: el
//  intent persiste en `PendingJoinStore` y el próximo trigger del reconciler re-evalúa (TTL 7d).
//
//  DARK: con `groupsBackendEnabled` OFF los intents jamás se submitean ⇒ estos sheets no se
//  presentan nunca.
//
//  ## C2 · el EDUCATIVO vive aquí, y no en un modifier propio
//
//  El chip lo añade como PRIMER escalón de las puertas A (Welcome → «Crear mi primer grupo») y B (card
//  «Solo grupos»): antes las dos pedían identidad —o, la card B, escribían el trío entero— sin haberle
//  contado nunca al usuario qué es un grupo ni dónde viven sus gastos.
//
//  **Está en este modifier por dos razones, y la primera es medida:** un `.modifier(...)` más en la cadena
//  del `body` de `ContentView` la tumba con «unable to type-check this expression in reasonable time»
//  (verificado). Y la segunda es que es el sitio conceptualmente correcto: este tipo ya es el DUEÑO ÚNICO
//  del anchor de esta cadena, y el educativo es su paso 0. Un anchor aparte para el escalón anterior a
//  `GroupsSignInView` sería justo la regla (4) de Presentaciones —dos anchors ante el mismo flujo— con el
//  agravante de que el paso siguiente se monta desde aquí.
//
//  Cover y no sheet, como su hermano `GroupsOrganizerNameView`: es un paso de una cadena que ya salió del
//  Welcome, así que debajo no hay shell. Su blocker `groupsEducational` está en la matriz de readiness.
//

import SwiftData
import SwiftUI

struct GroupsBackendInviteModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    /// C2 · el educativo marca `hasShownGroupsOnboarding` por el espejo observable y no por `UserDefaults`
    /// directo: el tab lee esa property para decidir su empty state y su sheet, y escribir por debajo
    /// dejaría el valor en memoria stale hasta la siguiente recarga por notificación.
    @Environment(AppPreferences.self) private var appPreferences
    @Binding var showGroupsConsent: Bool
    @Binding var showGroupsSignIn: Bool
    /// C2 · el educativo, paso 0 de las puertas A y B.
    @Binding var showGroupsEducational: Bool
    @Binding var pendingGroupsJoinZone: String?
    /// G3: la rama ORGANIZADOR del Welcome reusa estos dos sheets —este modifier es el dueño ÚNICO de su
    /// anchor y un segundo sería la regla (4) de Presentaciones— pero su continuación es otra: no hay zona
    /// a la que unirse, hay un alta que terminar. Este flag es el discriminador, y va explícito en vez de
    /// derivarse de `pendingGroupsJoinZone == nil`: ese `nil` también es el estado de «nadie lo puso».
    @Binding var groupsOrganizerFlowActive: Bool
    /// G3: el usuario canceló un sheet de la rama organizador (toolbar/swipe). El invitado puede quedarse
    /// donde está —su intent sobrevive en `PendingJoinStore` y el reconciler re-evalúa— pero el
    /// organizador acaba de SALIR del Welcome y debajo no hay shell que usar: sin esto, cancelar deja una
    /// pantalla muerta, que es lo que la invariante (2) del chip prohíbe. `ContentView` lo devuelve al
    /// step de los dos caminos.
    /// C2 · lo que la card «Solo grupos» arrastra sin persistir (nombre y divisa). Se descarta al cancelar:
    /// un payload superviviente haría que el siguiente intento saltara la pantalla del nombre con datos de
    /// una sesión abandonada.
    @Binding var pendingGroupsOnlyPayload: GroupsOnlyOnboardingPayload?
    var onGroupsOrganizerCancelled: () -> Void

    /// One-shots de resultado del sheet: se arman en el callback de éxito y se consumen en
    /// `onDismiss` (dismiss sin éxito = cancel ⇒ sin continuación).
    @State private var signInAuthenticated = false
    @State private var consentAccepted = false
    /// C2 · el mismo molde para el educativo. Sin él, cerrar con la «X» —que NO marca la preferencia, por
    /// diseño del educativo— haría que `GroupsGateLogic` devolviera `.presentEducational` otra vez, y otra:
    /// bucle sin salida en el primer escalón de la cadena.
    @State private var educationalCompleted = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showGroupsEducational, onDismiss: {
                guard groupsOrganizerFlowActive else { return }
                // Cancel: la rama se apaga y el usuario vuelve al Welcome, igual que en `handleCancel()` y
                // por lo mismo — pero aquí además es lo que rompe el bucle descrito arriba.
                guard educationalCompleted else {
                    pendingGroupsOnlyPayload = nil
                    return handleCancel()
                }
                educationalCompleted = false
                // Contrato C7: la continuación corre con la dismissal YA terminada, o SwiftUI se traga la
                // presentación siguiente (que es el sign-in, de este mismo anchor).
                RouterEntryGate.shared.submit(.presentGroupsOrganizerStep)
            }) {
                GroupsOnboardingView { result in
                    switch result {
                    case .complete, .completeAndSignIn:
                        // Los dos casos son el MISMO aquí, y no por descuido: el paso siguiente de ESTA
                        // cadena ya es el sign-in, así que `.completeAndSignIn` no tiene nada extra que
                        // pedir. Es en el tab —donde el educativo se abre suelto— donde ese caso emite su
                        // propio intent.
                        educationalCompleted = true
                        appPreferences.hasShownGroupsOnboarding = true
                    case .close:
                        break
                    }
                    showGroupsEducational = false
                }
                .environment(SessionState.shared)
            }
            .sheet(isPresented: $showGroupsSignIn, onDismiss: {
                guard signInAuthenticated else { return handleCancel() }  // cancel → sin continuación
                signInAuthenticated = false
                continueFlow()
            }) {
                GroupsSignInView {
                    signInAuthenticated = true
                    showGroupsSignIn = false
                    // D2 (§3.3.3): re-firmar sesión de grupos DESARMA un boot-wipe de grupos colgado por un
                    // "Salir de Yala" in-session previo (`exitYalaOnThisDevice`) — sin esto, un cold boot
                    // posterior borraría los grupos recién re-sincronizados — y quema el banner de re-entrada
                    // stale. Idempotente/no-op si nada estaba armado; el sign-out normal exit(0) antes de este
                    // seam (jamás interfiere). Los otros armadores (`.groupsOnlySignOut`/borrado de cuenta)
                    // hacen relaunch inmediato ⇒ el wipe ya corrió antes de cualquier re-sign-in.
                    StorageModePersistence.clearGroupsOnlyWipeArm()
                    GroupsSignOutBannerMarker.clear()
                    // C2 · el latch «este device tuvo sesión de Grupos alguna vez». Es lo que separa el
                    // empty state de re-entrada («tus grupos están en tu cuenta») del de alta («crea tu
                    // cuenta»): sin él, quien cierra sesión lee que le esperan unos grupos que nunca creó,
                    // o al revés. Monotónico y sin `clear()` a propósito — solo lo retira el handover.
                    GroupsSessionHistoryMarker.markSessionSeen()
                    // H-2026-07-18-4: un sign-in solo-grupos IN-SESSION no arrancaba el canal (startIfEligible
                    // solo corría en cold boot) → arrancarlo aquí cubre crear-grupo / invite / futuro CTA del
                    // empty state. D8-safe por el guard de mount-mismatch; no-op temprano con el flag OFF.
                    GroupsSyncClient.shared.startIfEligible(context: modelContext, trigger: "post-sign-in")
                    // C1: la sesión acaba de nacer, y es el instante en que (a) un consent aceptado sin red
                    // por fin tiene cuenta a la que atribuirse, (b) el consent LEGACY de este device —el
                    // que vivía en el iKV del Apple ID y nunca llegó a Yala— se sella y se registra, y (c)
                    // el consent que esta persona ya dio en OTRO device baja y evita volver a preguntarle.
                    Task { @MainActor in await GroupsConsentRegistrar.shared.handleSignIn() }
                }
                .environment(SessionState.shared)
            }
            .sheet(isPresented: $showGroupsConsent, onDismiss: {
                guard consentAccepted else { return handleCancel() }  // cancel → sin continuación
                consentAccepted = false
                continueFlow()
            }) {
                GroupsConsentView(path: groupsOrganizerFlowActive ? "organizer" : "invite") {
                    consentAccepted = true
                    showGroupsConsent = false
                }
                .environment(SessionState.shared)
            }
    }

    /// Cancel: para el invitado es un no-op (su intent persiste, TTL 7 d); para el organizador es la
    /// vuelta al Welcome.
    private func handleCancel() {
        guard groupsOrganizerFlowActive else { return }
        groupsOrganizerFlowActive = false
        onGroupsOrganizerCancelled()
    }

    // Nota: el descarte de `pendingGroupsOnlyPayload` NO se centralizó aquí sino en
    // `ContentView.returnToGroupsChooser`, que es el choke-point de TODAS las cancelaciones de la cadena
    // (educativo, sign-in, consent y el cover del nombre pasan por él). Ponerlo solo en `handleCancel`
    // dejaría fuera la del cover del nombre, que no llama a este tipo.

    private func continueFlow() {
        // G3 primero: la rama organizador no tiene zona, así que el `guard` de abajo la dejaría muda.
        // Vuelve al router en vez de decidir aquí — el paso se RE-DECIDE con condiciones vivas, y así la
        // presentación siguiente espera a que este sheet haya terminado de irse.
        if groupsOrganizerFlowActive {
            RouterEntryGate.shared.submit(.presentGroupsOrganizerStep)
            return
        }
        guard let zone = pendingGroupsJoinZone else { return }
        Task { @MainActor in
            await GroupBackendInviteEntryHandler.continueFlow(zoneName: zone)
        }
    }
}
