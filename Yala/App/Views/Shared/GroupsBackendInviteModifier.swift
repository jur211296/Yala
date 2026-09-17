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
//  «Solo grupos», retirada el 2026-09-10): antes las dos pedían identidad —o, la card B, escribían el trío
//  entero— sin haberle contado nunca al usuario qué es un grupo ni dónde viven sus gastos.
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
    /// [I] · el bloqueo «esa cuenta ya tiene Yala completo». Es un `@Binding` y no un `@State` propio
    /// porque `ContentView` necesita verlo para la matriz de readiness: un sheet de este anchor que no
    /// bloquee deja que el drain monte el siguiente intent encima (regla 3 de Presentaciones).
    @Binding var showGroupsAccountIsCompleteBlock: Bool
    /// C2 · el educativo, paso 0 de la rama del organizador (puerta A; la B se retiró el 2026-09-10).
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
    var onGroupsOrganizerCancelled: () -> Void
    /// **Bloque [I]** · el backend dijo que esta cuenta lleva Yala completo y no hay sesión privada que
    /// respetar: se adopta y se aterriza en Grupos. Lo ejecuta `ContentView` reencaminando al cover del
    /// Welcome con la sesión ya viva — la pantalla de adopt vive allí y su docblock prohíbe instanciarla
    /// en paralelo, así que este modifier no la monta.
    var onAdoptCompleteAccount: () -> Void

    /// One-shots de resultado del sheet: se arman en el callback de éxito y se consumen en
    /// `onDismiss` (dismiss sin éxito = cancel ⇒ sin continuación).
    @State private var signInAuthenticated = false
    /// [I] · one-shot del bloqueo: la persona pidió «usar otra cuenta». Se consume en el `onDismiss`, que
    /// es el único punto por el que pasan sus cuatro salidas (botón, «Entendido», «X» y swipe).
    @State private var blockRetriesSignIn = false
    /// [I] · el destino que decidió la tabla, armado junto a `signInAuthenticated` y consumido con él.
    @State private var signInDestination: CloudIdentityRoutingLogic.Destination?
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
                let destino = signInDestination
                signInDestination = nil
                routeIdentityDestination(destino)
            }) {
                GroupsSignInView { destino, origen in
                    signInAuthenticated = true
                    signInDestination = destino
                    showGroupsSignIn = false

                    // [I] · **el bloqueo no escribe NADA.** Los efectos de abajo son los de una sesión de
                    // grupos que se acepta; con la cuenta rechazada, cada uno de ellos dejaría rastro de
                    // una sesión que no va a existir: el latch de historial cambiaría el empty state del
                    // tab para siempre (es monotónico y nadie lo repone), el desarme del boot-wipe dejaría
                    // vivos unos grupos que un cierre previo mandó borrar, y el registro del
                    // consent atribuiría a esta cuenta un consentimiento dado para otra cosa.
                    guard destino != .blockedAccountIsComplete else { return }
                    // D2 (§3.3.3): re-firmar sesión de grupos DESARMA un boot-wipe de grupos que hubiera quedado
                    // colgado — sin esto, un cold boot posterior borraría los grupos recién re-sincronizados — y
                    // quema el banner de re-entrada stale. Idempotente/no-op si nada estaba armado. Desde el
                    // paso 9 del rediseño (2026-09-11) el único armador que queda es el cierre local tras borrar
                    // la cuenta de grupos de una sesión privada, que termina en el cover terminal ⇒ el wipe corre
                    // antes de cualquier re-sign-in; los cierres de sesión arman el wipe PERSONAL, no este.
                    StorageModePersistence.clearGroupsOnlyWipeArm()
                    GroupsSignOutBannerMarker.clear()
                    // C2 · el latch «este device tuvo sesión de Grupos alguna vez». Es lo que separa el
                    // empty state de re-entrada («tus grupos están en tu cuenta») del de alta («crea tu
                    // cuenta»): sin él, quien cierra sesión lee que le esperan unos grupos que nunca creó,
                    // o al revés. Monotónico y sin `clear()` a propósito — solo lo retira el handover.
                    GroupsSessionHistoryMarker.markSessionSeen()
                    // Paso 10 · **la asociación se escribe AQUÍ y no en el `onDismiss`, y el orden es lo
                    // único que la hace útil**: `startIfEligible`, tres líneas más abajo, arranca el canal
                    // en el acto, y su primer ciclo puede bajar el corpus entero y llamar al puente. El
                    // guard del libro de conservados pregunta por la cuenta asociada; si todavía no
                    // estuviera escrita, leería `nil`, no frenaría nada, y cada gasto que el usuario
                    // decidió conservar aparecería DOS VECES en su Panel. El `onDismiss` corre después de
                    // la animación de cierre, que es demasiado tarde.
                    // El origen de la sesión viaja al escritor: en un teléfono que empezó desde cero, la sesión que ya
                    // estaba abierta puede ser de la persona anterior, y no se apunta como cuenta de grupos de nadie.
                    if destino == .associateGroupsAccount {
                        GroupsAccountAssociation.shared.associate(
                            sub: CloudAuthService.shared.currentUserID,
                            provider: CloudAuthService.shared.storedProvider(),
                            email: CloudAuthService.shared.capturedEmail(),
                            kind: AccountKindService.shared.current,
                            sessionOpenedByThisSignIn: origen == .signedInHere)
                    }
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
            // [I] · el bloqueo. Sheet del MISMO anchor que los tres de arriba (este tipo es su dueño
            // único) y sin continuación en `onDismiss`: cerrarlo no avanza nada, porque el recorrido se
            // detuvo a propósito. El intent del invitado sigue vivo en `PendingJoinStore` con su TTL,
            // así que la invitación no se pierde — se retoma cuando entre con una cuenta que sí valga.
            .sheet(isPresented: $showGroupsAccountIsCompleteBlock, onDismiss: {
                // **La sesión rechazada se suelta AQUÍ, en el `onDismiss`, y no en cada botón.** Es la
                // corrección de un defecto que una lente adversarial cazó: la primera versión solo la
                // soltaba en «usar otra cuenta», así que «Entendido», la «X» y el swipe dejaban viva la
                // cuenta que la app acababa de rechazar — y toda la cadena de Grupos decide por
                // `hasSession` (`GroupsGateLogic:145`). El bloqueo **se deshacía solo**: al volver a
                // foreground, el reconciler saltaba el sign-in y unía a la persona al grupo con esa
                // cuenta, sin que tocara nada. El `onDismiss` es el único punto por el que pasan las
                // cuatro salidas, incluido el swipe — que además es la razón de la regla (1) de
                // Presentaciones: un binding sin `onDismiss:` de respaldo pierde la dismissal interactiva.
                let reofrecerSignIn = blockRetriesSignIn
                blockRetriesSignIn = false
                // La zona se captura ANTES del `await`: la readiness ya se reabrió y el drain puede
                // escribir otra, así que leerla después mandaría el sign-in a un grupo distinto.
                let zona = pendingGroupsJoinZone
                Task { @MainActor in
                    await CloudAuthService.shared.signOut()
                    guard reofrecerSignIn else {
                        // Igual que un cancel: no-op para el invitado —su intent sobrevive en
                        // `PendingJoinStore`— y vuelta al Welcome para el organizador, que si no se queda
                        // mirando una pantalla muerta.
                        return handleCancel()
                    }
                    // Se re-ofrece por el router y no a pelo para que este sheet acabe de irse antes
                    // (contrato C7), y **siempre por `.presentGroupsSignIn`**, con zona o sin ella.
                    //
                    // La alternativa —mandar `.presentGroupsOrganizerStep` cuando no hay zona— era un
                    // camino MUERTO: ese intent sale por el `guard groupsOrganizerFlowActive` de
                    // `advanceGroupsOrganizerFlow`, y ese flag está apagado en el caso dominante del
                    // bloqueo (sesión privada + tab Grupos, que no pasa por el Welcome). La persona
                    // tapeaba «Usar otra cuenta» y no ocurría nada.
                    //
                    // El `?? ""` es inocuo porque `continueFlow` descarta la zona vacía explícitamente.
                    RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: zona ?? ""))
                }
            }) {
                GroupsAccountIsCompleteBlockView(
                    onUseAnotherAccount: {
                        blockRetriesSignIn = true
                        showGroupsAccountIsCompleteBlock = false
                    },
                    onDismiss: { showGroupsAccountIsCompleteBlock = false })
                .environment(SessionState.shared)
            }
    }

    /// **Bloque [I]** · qué se hace con el destino que decidió la tabla.
    ///
    /// `nil` cae con el camino de siempre y es deliberado: significa que el sheet se cerró con éxito sin
    /// que el descubrimiento dejara destino —una versión anterior de esta vista, o un `Task` cancelado— y
    /// ahí lo correcto es el comportamiento de HOY, no detener el recorrido de alguien que ya firmó.
    private func routeIdentityDestination(_ destino: CloudIdentityRoutingLogic.Destination?) {
        switch destino {
        case .continueGroupsSetup, .associateGroupsAccount, .none:
            // El camino de HOY, byte-idéntico. **La asociación NO se escribe aquí**, aunque
            // `.associateGroupsAccount` sea su destino: este `onDismiss` corre tras la animación de
            // cierre y el canal ya lleva un rato arrancado. Se escribe en el callback de éxito del
            // sign-in, antes de `startIfEligible` — ver allí el porqué completo.
            continueFlow()
        case .adoptAsCompleteAndOpenGroups:
            onAdoptCompleteAccount()
        case .blockedAccountIsComplete:
            showGroupsAccountIsCompleteBlock = true
        case .some(let otro):
            // Inalcanzables por esta puerta, y lo afirma `elEjeCompletoTieneSuBorde` en los tests de la
            // tabla —recorre los CUATRO estados del dispositivo por esta puerta y exige que ninguno salga
            // del conjunto de arriba—. Si algún día sale otro, cae al camino de hoy: no-regresión.
            #if DEBUG
            print("GroupsBackendInviteModifier: destino [I] inesperado por la puerta de Grupos: \(otro)")
            #endif
            continueFlow()
        }
    }

    /// Cancel: para el invitado es un no-op (su intent persiste, TTL 7 d); para el organizador es la
    /// vuelta al Welcome.
    private func handleCancel() {
        guard groupsOrganizerFlowActive else { return }
        groupsOrganizerFlowActive = false
        onGroupsOrganizerCancelled()
    }

    private func continueFlow() {
        // G3 primero: la rama organizador no tiene zona, así que el `guard` de abajo la dejaría muda.
        // Vuelve al router en vez de decidir aquí — el paso se RE-DECIDE con condiciones vivas, y así la
        // presentación siguiente espera a que este sheet haya terminado de irse.
        if groupsOrganizerFlowActive {
            RouterEntryGate.shared.submit(.presentGroupsOrganizerStep)
            return
        }
        // `!isEmpty` además de `let`: el intent de re-ofrecer el sign-in tras el bloqueo puede llegar sin
        // zona (crear un grupo desde el tab), y el drain la asigna tal cual ⇒ `pendingGroupsJoinZone` pasa
        // de `nil` a `""`. Sin este término, la continuación llamaría al handler con una zona vacía.
        guard let zone = pendingGroupsJoinZone, !zone.isEmpty else { return }
        Task { @MainActor in
            await GroupBackendInviteEntryHandler.continueFlow(zoneName: zone)
        }
    }
}
