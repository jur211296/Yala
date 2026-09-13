//
//  GroupsGateLogic.swift
//  Yala
//
//  C2 de la ola del consent · **la SSOT del orden en que se entra a Grupos, para las TRES puertas.**
//
//  Antes de C2 había tres tablas que se prometían paridad por docblock —`GroupsOrganizerFlowLogic` declara
//  espejar a `GroupBackendInviteEntryLogic` «a propósito, y respeta su orden»— y una cuarta puerta, la card
//  «Solo grupos» del onboarding de 8 pasos, que no pasaba por ninguna: escribía el alta entera
//  (`userName`, el eje 1 apagado, `groupsBetaUnlocked`, `hasCompletedOnboarding`) sin
//  sesión, sin consent y sin canal comprobado. Tres funciones que se prometen paridad pasan a ser UNA con
//  un parámetro, y la cuarta puerta entra por ella.
//
//  **Esa cuarta puerta ya no existe (2026-09-10, ADR 2026-09-09 §7).** La card se retiró del onboarding
//  porque solo-grupos es una sesión que se abre desde el Welcome («Vengo por un grupo»), no un propósito
//  de quien ya eligió llevar sus finanzas personales. Quedan tres: organizador, invitación y tab.
//
//  ## La invariante que esta tabla existe para sostener
//
//  **Nada se persiste hasta saber quién es y a dónde va.** El nombre, el eje 1 y el consent se escriben
//  JUNTOS y al final, en `GroupsOrganizerOnboarding.completeSetup`. Escribirlos antes de confirmar la ruta
//  deja a la persona con la app recortada a Grupos y sin grupo que enseñar.
//
//  **La lección que dejó la versión anterior de esta regla:** hasta el 2026-09-13 ese eje era un flag de
//  onboarding sincronizado por el iKV del Apple ID con merge never-downgrade, así que una escritura
//  prematura se propagaba a los OTROS dispositivos de esa cuenta y **no volvía** (única recuperación:
//  restaurar por iCloud). Hoy el eje 1 es un hecho del DISPOSITIVO y no viaja, pero el orden no cambia.
//
//  ## El educativo NO va en todas, y eso es una MEDICIÓN, no un descuido
//
//  | Puerta | Educativo | Dónde se monta |
//  |---|---|---|
//  | `.organizer` (Welcome → «Crear mi primer grupo») | **SÍ, primero** | cover de `ContentView`, tras `WelcomeGroupsGateView` |
//  | `.invite` (link backend) | NO el general | el suyo es `GroupInviteOnboardingView`, contextual al link y con metadata del grupo, DESPUÉS del consent |
//  | `.tab` (crear grupo desde el tab) | NO aquí | `GroupsContainerView.evaluateGroupsOnboarding` lo presenta al MONTAR el tab, antes de que ninguna CTA de creación sea alcanzable |
//
//  Anteponer el general al invitado le daría **dos educativos seguidos**; anteponerlo en `.tab` sería una
//  segunda presentación compitiendo con el sheet que ya lo monta. En las tres el usuario ve un educativo
//  antes de que se le pida identidad —que es el contrato—, y en la que no lo tenía (`.organizer`) C2 lo
//  añadió.
//
//  ## La hoja del invitado se presenta SIEMPRE (2026-09-05) — y por qué esto cambió
//
//  El terminal de `.invite` cortaba por `hasCompletedSetup`: sin alta, la hoja; con alta, join directo. Era
//  correcto bajo su propia premisa —la hoja es el educativo Y el alta del invitado, y a quien ya tiene
//  nombre no hay que pedírselo— y **falso en device**: a quien ya tenía cuenta, tapear un enlace lo metía
//  en el grupo solo, sin ver de qué grupo se trataba, sin elegir con qué nombre lo verían los demás y sin
//  confirmar nada. Se enteraba después, si pasaba por el tab Grupos. Veredicto del owner: la hoja aparece
//  siempre, venga de primer plano, de segundo plano o estando ya dentro de la app.
//
//  **`hasCompletedSetup` era un PROXY, y ese es el error que conviene no repetir.** Funcionaba para el
//  invitado fresco solo porque la propia hoja marcaba su alta al terminar, así que «ya está dado de alta»
//  acababa significando «ya pasó por aquí». La pregunta real siempre fue la segunda, y ahora se pregunta
//  directamente: `hasConfirmedInvite` (`PendingJoinEntry.inviteConfirmedAt`, sellado por
//  `GroupBackendInviteEntryHandler.drive` cuando el paso viene de una acción de la persona). Es el mismo
//  género de arreglo que `hasSeenEducational` frente al corte por «esta persona entró por un grupo», dos
//  párrafos más arriba: sustituir un testigo prestado por el hecho que de verdad se quería medir.
//
//  Lo que NO cambia: `canPresentInviteOnboarding` sigue siendo el discriminador del CTA de la propia hoja,
//  y el invitado fresco conserva su recorrido intacto. Lo que la hoja ESCRIBE sí depende de si la persona
//  ya tenía cuenta —el alta completa le pisaría preferencias vivas, y `userName`, `defaultCurrencyCode` y
//  `defaultPeriod` van por `PreferenceSyncService` ⇒ el daño le llega a sus otros dispositivos—, pero eso
//  se decide en la vista, no aquí.
//
//  ## Lo que esta tabla NO decide, y por qué no puede
//
//  El **canal** (`CloudSyncFlags.groupsBackendEnabled`) no entra aquí: vive en `GroupCreateRoutingLogic`
//  (`.channelOff`, C4) y en `GroupsOrganizerGateLogic` (`.blockedChannelOff`, G3), y en los dos casos es el
//  PRIMER término porque sin canal no hay nada que crear y pedir identidad para después bloquear sería
//  pedirla en vano. Y el `refreshIfDue(force: true)` que precede a esa lectura vive en las VISTAS
//  (`WelcomeGroupsGateView.evaluate`, `GroupsContainerView.requestCreateGroup`): esta tabla es pura y
//  recibe todo ya leído, así que puede estar perfecta y sus tests verdes mientras un llamador mide un
//  snapshot de hasta 6 h. Lo que fija ese orden son los source-scan de los call-sites.
//
//  **Cada llamada re-evalúa condiciones VIVAS** (regla del repo): el drenaje del router vuelve aquí después
//  de cada sheet en vez de recordar en qué paso iba, así que un sign-in ya hecho, un consent aceptado en
//  otra pantalla o un kill-and-relaunch a mitad no dejan la máquina desalineada.
//

import Foundation

nonisolated enum GroupsGateLogic {

    /// Por dónde entró el usuario. El terminal de la cadena depende de esto; los tres primeros escalones,
    /// no.
    enum Entry: Equatable, CaseIterable {
        /// Welcome → «Crear mi primer grupo». Su puerta (`GroupsOrganizerGateLogic`) ya corrió.
        case organizer
        /// Invitación por link backend.
        case invite
        /// Tab Grupos (empty state, FAB simple, FAB expandible, `pendingNewGroupForm`).
        case tab
    }

    enum Step: Equatable {
        /// El educativo de Grupos (3 steps). Primer escalón de `.organizer`.
        case presentEducational
        /// Sin sesión de nube → `GroupsSignInView` (el de GRUPOS, jamás una hermana de
        /// `WelcomeCloudSignInView`: su docblock prohíbe instanciarla en paralelo).
        case presentSignIn
        /// Con sesión y sin consent → `GroupsConsentView`, reusada LITERAL (un solo parámetro, sin ramas:
        /// epoch y `textVersion` intactos, append-only).
        case presentConsent
        /// Falta el alta: la pantalla mínima de nombre, que es donde se escribe el trío.
        case presentName
        /// Invitado FRESCO: `GroupInviteOnboardingView` (captura el nombre ANTES del join, R1).
        case presentInviteOnboarding
        /// Invitado listo → unirse.
        case join
        /// Todo listo → el formulario de grupo, directo.
        case presentGroupForm
    }

    /// El siguiente paso pendiente. Precedencia: educativo → sign-in → consent → terminal por `entry`.
    ///
    /// - Parameters:
    ///   - entry: por dónde entró. Decide el terminal y si el educativo se antepone (ver la tabla del
    ///     encabezado: solo `.organizer`).
    ///   - hasSeenEducational: `AppPreferences.hasShownGroupsOnboarding`. **Es el hecho REAL que el corte
    ///     por «esta persona entró por un grupo» quería expresar y expresaba mal**: aquel suprimía el
    ///     educativo justo para quien entraba por la card «Solo grupos», o sea la gente que menos contexto
    ///     tenía. Para el invitado la marca la pone `GroupInviteOnboardingView` al completarse, porque ESE
    ///     es su educativo. Son dos estados distintos y estaban colapsados en uno falso.
    ///   - hasSession: `CloudAuthService.shared.hasSession`.
    ///   - isConsented: `GroupsConsentState.isAccepted` (caché SELLADA con el `sub`, C1).
    ///   - hasCompletedSetup: `hasCompletedOnboarding`. Lo marca el propio alta, así que es el testigo de
    ///     que el trío ya está escrito y de que este proceso no debe volver a pedir el nombre. **No decide
    ///     el terminal de `.invite`** — ver `hasConfirmedInvite`.
    ///   - hasConfirmedInvite: `PendingJoinEntry.isInviteConfirmed` — ¿esta persona ya dijo que sí a ESTA
    ///     invitación? Solo aplica a `.invite`.
    ///   - canPresentInviteOnboarding: `false` cuando el paso viene del CTA del PROPIO onboarding del
    ///     invitado (source `.userAction`) — sin este discriminador el tap de «unirme» re-presentaría la
    ///     vista. Solo aplica a `.invite`.
    static func nextStep(
        entry: Entry,
        hasSeenEducational: Bool,
        hasSession: Bool,
        isConsented: Bool,
        hasCompletedSetup: Bool,
        hasConfirmedInvite: Bool = false,
        canPresentInviteOnboarding: Bool = true
    ) -> Step {
        if entry.showsEducationalFirst && !hasSeenEducational { return .presentEducational }
        if !hasSession { return .presentSignIn }
        if !isConsented { return .presentConsent }

        switch entry {
        case .organizer:
            return hasCompletedSetup ? .presentGroupForm : .presentName
        case .invite:
            // 2026-09-05 · **el terminal del invitado ya no lo decide `hasCompletedSetup`.** Ver el bloque
            // «La hoja del invitado se presenta SIEMPRE» del encabezado: la pregunta es si dijo que sí a
            // esta invitación, no si tiene cuenta.
            return (!hasConfirmedInvite && canPresentInviteOnboarding) ? .presentInviteOnboarding : .join
        case .tab:
            return .presentGroupForm
        }
    }
}

extension GroupsGateLogic.Entry {
    /// ¿El educativo GENERAL se antepone al sign-in en esta puerta? Ver la tabla del encabezado: las dos
    /// que dicen `false` no es que se lo salten — es que su educativo se monta en otro sitio del recorrido.
    ///
    /// `nonisolated` explícito: el `nonisolated` del `enum` contenedor NO se hereda en una `extension` del
    /// tipo anidado, así que sin él esta property queda aislada al MainActor y `nextStep` —que sí es
    /// nonisolated— no puede leerla.
    nonisolated var showsEducationalFirst: Bool {
        switch self {
        case .organizer: return true
        case .invite, .tab: return false
        }
    }
}
