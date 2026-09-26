//
//  ShellDataAlertsModifier.swift
//  Yala
//
//  Los CUATRO alerts de DATOS del shell — wipe remoto detectado, el espejo de iCloud que llegó tarde,
//  «empiezo de cero» del Welcome y el aviso de que ese borrado falló.
//
//  (Fueron cinco del 2026-09-14 al 2026-09-15. El quinto, el cierre de la sesión privada por cambio de
//  Apple ID, salió de aquí y es una hoja con fases, `AppleIDCloseNoticeModifier`: como `.alert`, su cierre
//  podía bloquearse sin que nadie lo enseñara, y encadenarle un segundo `.alert` es el molde de brick de
//  `.claude/rules/swiftui-ds.md`.)
//
//  **Extraídos del `body` de `ContentView` por PRESUPUESTO DEL TYPE-CHECKER, y la cifra está medida:** con
//  ellos dentro, el getter de `body` tardaba **591 s** en type-checkear
//  (`-warn-long-function-bodies=800`) y la compilación moría con «unable to type-check this expression in
//  reasonable time». Es el mismo motivo por el que ya existen `WelcomeFlowModifier`,
//  `GroupsBackendInviteModifier`, `GroupInviteModifier` y sus tres vecinos: la cadena de ese `body` está
//  saturada, y cualquier cosa que se le añada la tumba.
//
//  **Movimiento MECÁNICO: no cambia una sola decisión.** Los cuerpos de los cuatro alerts son literales a
//  los que había en `ContentView`, incluidos sus comentarios; lo único nuevo son los `@Binding` y el
//  closure `onCancelWipeGrace`, que reemplaza un acceso directo a estado privado de la vista.
//

import SwiftData
import SwiftUI

struct ShellDataAlertsModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    @Binding var showRemoteWipeAlert: Bool
    @Binding var showICloudRestartAlert: Bool
    @Binding var showFreshStartWipeAlert: Bool
    /// El wipe de cualquiera de los DOS caminos de «empiezo de cero» lanzó. Se presenta en vez de
    /// navegar al onboarding: la app llevaba mintiendo sobre un borrado que no ocurrió.
    @Binding var showFreshStartWipeFailedAlert: Bool
    @Binding var hasCompletedOnboarding: Bool
    @Binding var hasExistingData: Bool
    @Binding var hasPersonalData: Bool
    @Binding var showWelcomeFlow: Bool
    @Binding var showOnboarding: Bool
    @Binding var welcomeFlowInitialStep: WelcomeFlowStep
    /// El `wipeGraceTask` es `@State` privado de `ContentView` y no puede viajar por `@Binding`: los dos
    /// wipes DELIBERADOS tienen que cancelar esa gracia antes de bajar `hasPersonalData`, o el true→false
    /// se lee como wipe REMOTO y apila un alert sobre el onboarding que ellos mismos están abriendo.
    var onCancelWipeGrace: () -> Void
    /// **«Empezar de cero» del aviso de vaciado remoto.** El aterrizaje vive en `ContentView` y no aquí
    /// por lo mismo que `onCancelWipeGrace`: necesita estado que no viaja por `@Binding` (los dos
    /// `@AppStorage` del Welcome) y tiene que quedar al lado del camino hermano —el vaciado que llega
    /// por señal— para que se lea de un vistazo que los dos aterrizan en el mismo sitio.
    var onRemoteWipeStartFresh: () -> Void
    /// **«Ahora no» del aviso de vaciado remoto.** Apaga el aviso y su condición viva; la persona se
    /// queda donde estaba.
    var onRemoteWipeDismiss: () -> Void
    /// Por qué el último «Empezar de cero» no borró, si fue por cambios de grupos sin subir. Lo pone la subida.
    private var freshStartGroupsBlock: CloudSessionSignOut.FreshStartGroupsBlock? {
        CloudSessionSignOut.shared.freshStartGroupsBlock
    }

    func body(content: Content) -> some View {
        content
            // **Las dos ramas dicen a dónde va la persona**, como sus tres vecinos de este fichero. Se
            // quedaron sin ello hasta el 2026-09-14, y el desenlace del botón destructivo era además el
            // camino GENÉRICO de degradación: bajar `hasCompletedOnboarding` y dejar que el `onChange`
            // eligiera destino con lo que hubiera en las preferencias. Ahora los dos aterrizajes están
            // escritos y son los de `ContentView`, al lado del wipe remoto que llega por señal.
            //
            // **La premisa que este aviso YA NO comparte con sus vecinos** (y por eso su «Ahora no» no
            // reabre nada): desde este ticket se presenta por la cola del router, así que sólo monta con
            // el anchor libre — debajo sigue estando la shell de la app. Sus vecinos reabren el Welcome
            // porque el suyo se encendía sobre un cover y lo desmontaba.
            .alert(L10n.iCloud.remoteWipeTitle, isPresented: $showRemoteWipeAlert) {
                Button(L10n.iCloud.remoteWipeConfirm, role: .destructive) {
                    onRemoteWipeStartFresh()
                }
                Button(L10n.iCloud.remoteWipeCancel, role: .cancel) {
                    onRemoteWipeDismiss()
                }
            } message: {
                Text(L10n.iCloud.remoteWipeMessage)
            }
            .alert(L10n.iCloud.mismatchTitle, isPresented: $showICloudRestartAlert) {
                Button(L10n.iCloud.mismatchAction) {}
            } message: {
                Text(L10n.iCloud.mismatchMessage)
            }
            // **PRESENTAR ESTE ALERT DESMONTA EL COVER DEL WELCOME. Medido, no inferido (2026-09-03).**
            //
            // El alert cuelga del anchor de `ContentView`; el Welcome es un `fullScreenCover` del MISMO
            // anchor. Un anchor no puede presentar dos cosas a la vez, así que al encender este alert
            // SwiftUI **dismissa el cover** — y lo hace por su setter, con lo que `showWelcomeFlow`
            // queda en `false` legítimamente. No es un flag pegado: es un dismiss real.
            //
            // Traza del simulador (`-uitest -uitest-reset -uitest-seed grupos`), instrumentando el
            // setter del cover y el log de readiness:
            //
            //     blocked by: freshStartWipeAlert  [freshStartAlert=true  welcomeFlow=true ]
            //     DIAG gated.set: true -> false  (inhibitor=false)      <- SwiftUI tira el cover
            //     blocked by: freshStartWipeAlert  [freshStartAlert=true  welcomeFlow=false]
            //
            // Consecuencia: al cerrar el alert no queda NADA debajo. El usuario se quedaba mirando una
            // pantalla negra, cero elementos interactivos, sin más salida que matar la app — y daba
            // igual el botón, porque el cover ya estaba muerto antes de pulsarlo. Reproducido con
            // `screenHash 1njjbcs`, `count 6`.
            //
            // Es la regla (4) de Presentaciones (`.claude/rules/swiftui-ds.md`) en su forma menos
            // evidente: no son dos anchors compitiendo por un observable, es UN anchor con dos
            // presentaciones. El comentario de la rama Cancel decía que «el usuario queda en el
            // Chooser»: describía la intención, nunca el comportamiento.
            //
            // Por eso las dos ramas son EXPLÍCITAS sobre a dónde va el usuario, en vez de confiar en
            // que quede algo montado debajo: cerrar el alert es sólo la mitad del trabajo.
            .alert(L10n.Welcome.FreshStart.alertTitle, isPresented: $showFreshStartWipeAlert) {
                Button(L10n.Welcome.FreshStart.alertConfirm, role: .destructive) {
                    showFreshStartWipeAlert = false
                    // **Antes de borrar nada, los cambios de grupos** (2026-09-26, ver `refuseWhileGroupsArePending`).
                    // Sin nada pendiente el borrado sigue en ESTE tap, como siempre; con algo pendiente no se borra.
                    if CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: modelContext) {
                        performFreshStartWipe()
                    } else {
                        refuseWhileGroupsArePending()
                    }
                }
                // Cancel: **se REABRE el Welcome en el Chooser**, que es de donde vino el usuario.
                //
                // El cuerpo estaba vacío porque se daba por hecho que el Chooser seguía montado
                // debajo. No seguía: presentarlo lo desmontó (ver la traza de arriba). Reabrirlo aquí
                // no es un parche cosmético — es la única forma de cumplir lo que el copy promete,
                // porque el cover que había ya no existe.
                //
                // `.chooser` y no `.hero`: cancelar devuelve al punto exacto donde se estaba, con las
                // otras dos vías (Restaurar, Vengo por un grupo) a un toque. Mandarlo al Hero le
                // cobraría un paso extra por haber preguntado.
                //
                // El molde se repite en el alert de «el wipe falló», al final de este mismo fichero:
                // también reabre el Chooser, y con el mismo `if !hasCompletedOnboarding`. Este se
                // quedó sin ello hasta que la traza de arriba explicó por qué hacía falta.
                Button(L10n.Action.cancel, role: .cancel) {
                    showFreshStartWipeAlert = false
                    // El guard no es decorativo, y es el mismo que el del alert de abajo: si el
                    // onboarding ya está completo, este alert vino de un camino donde el Welcome NO
                    // estaba montado, y reabrirlo le plantaría el flujo de bienvenida a alguien que
                    // ya usa la app.
                    if !hasCompletedOnboarding {
                        welcomeFlowInitialStep = .chooser
                        showWelcomeFlow = true
                    }
                }
                    .tint(.primary)  // A11Y-DM: el indigo global se pierde sobre el alert del Welcome oscuro
            } message: {
                Text(L10n.Welcome.FreshStart.alertMessage)
            }
            // El wipe lanzó. Sin acción destructiva: el reintento es cerrar y volver a abrir, porque
            // un segundo wipe sobre el mismo store fallaría igual.
            // **Título y mensaje dependen de por qué no se borró** (2026-09-26): si quedaban cambios de grupos sin subir,
            // lo dice con su cifra y su motivo. El botón sigue literal —`.claude/rules/swiftui-ds.md`: lo que puede
            // variar en un `.alert` es el título y el mensaje—.
            .alert(
                freshStartGroupsBlock == nil
                    ? L10n.Welcome.FreshStart.failedTitle : L10n.Groups.FreshStartPending.title,
                isPresented: $showFreshStartWipeFailedAlert
            ) {
                // Mismo problema y mismo remedio que sus dos vecinos: este alert también se presenta
                // desde el anchor de `ContentView`, así que para cuando aparece el cover del Welcome
                // ya está desmontado. Con el cuerpo vacío, pulsar OK dejaba la misma pantalla negra
                // —es el caso 1 de los tres lanzamientos del ticket, el de `-uitest-fail-wipe`—.
                //
                // Y aquí volver al Chooser es ADEMÁS lo correcto de producto: el borrado FALLÓ, los
                // datos siguen ahí, y la persona tiene que poder elegir otra cosa. Mandarla al
                // onboarding sería continuar como si se hubiera borrado, que es justo la mentira que
                // el `do/catch` de arriba existe para evitar.
                Button(L10n.Common.ok, role: .cancel) {
                    showFreshStartWipeFailedAlert = false
                    if !hasCompletedOnboarding {
                        welcomeFlowInitialStep = .chooser
                        showWelcomeFlow = true
                    }
                }
                    .tint(.primary)  // A11Y-DM: el indigo global se pierde sobre el Welcome oscuro
            } message: {
                Text(freshStartGroupsBlock.map { SignOutBlockedCopy.freshStartGroupsPendingMessage($0) }
                     ?? L10n.Welcome.FreshStart.failedMessage)
            }
    }

    /// «Borrar todo y continuar» con cambios de grupos pendientes: **no se borra nada** (ticket
    /// `fresh-start-wipe-kills-unsent-group-writes-silently`). `wipeLocalGroupsDomain` se lleva el outbox, y quien pulsa
    /// aquí puede ser la persona que apuntó esos gastos. El aviso de fallo dice cuántos quedan, y su «OK» devuelve al
    /// Chooser, igual que cualquier otro fallo de este borrado.
    ///
    /// **Síncrono, en el mismo tap, y no subiendo primero como las otras dos pantallas** (review adversarial del
    /// 2026-09-26). Presentar este alert desmontó el cover del Welcome (ver la traza de arriba): mientras una subida
    /// corriera no habría nada montado —pantalla negra, sin salida—, y el aviso lo encendería un `Task`, el productor
    /// asíncrono que `.claude/rules/swiftui-ds.md` manda al router. Aquí se despierta el loop de Grupos para que suban
    /// por su cuenta, y el texto pide volver a intentarlo en un rato.
    private func refuseWhileGroupsArePending() {
        CloudSessionSignOut.shared.noteFreshStartGroupsPending(context: modelContext, reason: .uploadRetryLater)
        GroupsSyncClient.shared.wakeLoopIfSleeping(trigger: "freshStartPending")
        // El título y el mensaje del aviso de fallo leen `freshStartGroupsBlock`, que la línea de arriba acaba de poner.
        showFreshStartWipeFailedAlert = true
    }

    /// El borrado del alert, con el outbox de grupos ya vacío. Es el cuerpo que el botón tenía hasta el 2026-09-26,
    /// literal salvo el cinturón del principio y su `catch`.
    private func performFreshStartWipe() {
        do {
            // El cinturón del escritor, ANTES del primer borrado: si lanzara dentro de `wipeLocalGroupsDomain`, lo
            // personal ya estaría borrado y los grupos enteros.
            try DataWipeService.requireNoUnsentGroupWrites(in: modelContext)
            try DataWipeService.wipeAllUserData(
                in: modelContext,
                broadcastSignal: false
            )
            // La limpieza de prefs residuales vive AQUÍ y no en el disparador del alert:
            // corriendo antes del `if`, «Cancelar» no la deshacía y el usuario perdía
            // `userName` y `defaultCurrencyCode` por preguntar. Se limpia cuando se
            // BORRA. Va DESPUÉS del wipe para que un wipe que lanza no se lleve por
            // delante las prefs de unos datos que siguen ahí.
            OnboardingResetHelper.clearResidualPreferencesForFreshStart()
            // Handover: «empiezo de cero» es la frontera de OTRO usuario en este
            // dispositivo, no un vaciado del mismo. El dominio Grupos, que sobrevive al
            // wipe por diseño, se purga LOCALMENTE aquí — si no, el usuario nuevo hereda
            // los grupos del anterior (mismo Apple ID ⇒ ninguna señal de identidad los
            // distingue) y el bridge le mete sus gastos en Panel, Inbox y presupuestos.
            try DataWipeService.wipeLocalGroupsDomain(in: modelContext)
            hasExistingData = false
            // El wipe es DELIBERADO: cancelar la gracia antes de bajar la señal, para que
            // el true→false no se lea como wipe remoto y se apile un alert sobre el
            // onboarding que este mismo camino está abriendo.
            onCancelWipeGrace()
            hasPersonalData = false
            // La navegación al onboarding cuelga del camino que SÍ borró. Vivía fuera
            // del `do/catch` y corría igual cuando el wipe lanzaba: la app metía a la
            // persona en un onboarding «de cero» sobre sus datos intactos, sin decir
            // una palabra.
            showWelcomeFlow = false
            showOnboarding = true
        } catch is DataWipeService.GroupsDomainWipeError {
            // El cinturón saltó ANTES del primer borrado: no se tocó nada. Lo que hay que decir es «faltan cambios de
            // grupos», no «no pudimos borrar tus datos».
            refuseWhileGroupsArePending()
        } catch {
            // Canario FUERA de `#if DEBUG` a propósito: este fallo era invisible en
            // producción. Sin PII — el detalle es de qué alert vino.
            MetricsService.canary(.freshStartWipeFailed, detail: "welcomeFreshStart")
            showFreshStartWipeFailedAlert = true
        }
    }

}
