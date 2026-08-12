//
//  GroupsGateLogic.swift
//  Yala
//
//  C2 de la ola del consent · **la SSOT del orden en que se entra a Grupos, para las CUATRO puertas.**
//
//  Antes de C2 había tres tablas que se prometían paridad por docblock —`GroupsOrganizerFlowLogic` declara
//  espejar a `GroupBackendInviteEntryLogic` «a propósito, y respeta su orden»— y una cuarta puerta, la card
//  «Solo grupos» del onboarding de 8 pasos, que no pasaba por ninguna: escribía el trío (`userName`,
//  `onboardingMode = .groupInvite` EMPUJADO AL iKV, `groupsBetaUnlocked`, `hasCompletedOnboarding`) sin
//  sesión, sin consent y sin canal comprobado. Tres funciones que se prometen paridad pasan a ser UNA con
//  un parámetro, y la cuarta puerta entra por ella.
//
//  ## La invariante que esta tabla existe para sostener
//
//  **Nada se persiste hasta saber quién es y a dónde va.** El nombre, el modo y el consent se escriben
//  JUNTOS y al final, en `GroupsOrganizerOnboarding.completeSetup`. `onboardingMode = .groupInvite` es
//  **never-downgrade cross-device** (rank 1 > 0, `PreferenceMergeLogic`) y viaja al iKV del Apple ID:
//  escrito antes de confirmar la ruta, se propaga a los otros dispositivos de esa cuenta —donde el usuario
//  ve una app recortada a Grupos y vacía— y **no vuelve**. Su única recuperación es restaurar por iCloud.
//
//  ## El educativo NO va en las cuatro, y eso es una MEDICIÓN, no un descuido
//
//  | Puerta | Educativo | Dónde se monta |
//  |---|---|---|
//  | `.organizer` (Welcome → «Crear mi primer grupo») | **SÍ, primero** | cover de `ContentView`, tras `WelcomeGroupsGateView` |
//  | `.onboardingCard` («Solo grupos» del onboarding) | **SÍ, primero** | el mismo cover: comparte la cadena entera |
//  | `.invite` (link backend) | NO el general | el suyo es `GroupInviteOnboardingView`, contextual al link y con metadata del grupo, DESPUÉS del consent |
//  | `.tab` (crear grupo desde el tab) | NO aquí | `GroupsContainerView.evaluateGroupsOnboarding` lo presenta al MONTAR el tab, antes de que ninguna CTA de creación sea alcanzable |
//
//  Anteponer el general al invitado le daría **dos educativos seguidos**; anteponerlo en `.tab` sería una
//  segunda presentación compitiendo con el sheet que ya lo monta. En las cuatro el usuario ve un educativo
//  antes de que se le pida identidad — que es el contrato— y en las dos que no lo tenían se añade.
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
        /// Card «Solo grupos» del onboarding de 8 pasos. Comparte cadena y terminal con `.organizer`: la
        /// diferencia es que llega con el nombre y la divisa YA TECLEADOS, que viajan en memoria hasta
        /// `completeSetup` (jamás persistidos antes — es la invariante).
        case onboardingCard
        /// Invitación por link backend.
        case invite
        /// Tab Grupos (empty state, FAB simple, FAB expandible, `pendingNewGroupForm`).
        case tab
    }

    enum Step: Equatable {
        /// El educativo de Grupos (3 steps). Primer escalón de `.organizer` y `.onboardingCard`.
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
    ///     encabezado: solo `.organizer` y `.onboardingCard`).
    ///   - hasSeenEducational: `AppPreferences.hasShownGroupsOnboarding`. **Es el hecho REAL que el corte
    ///     por `onboardingMode == .groupInvite` quería expresar y expresaba mal**: aquel suprimía el
    ///     educativo justo para quien entraba por la card «Solo grupos», o sea la gente que menos contexto
    ///     tenía. Para el invitado la marca la pone `GroupInviteOnboardingView` al completarse, porque ESE
    ///     es su educativo. Son dos estados distintos y estaban colapsados en uno falso.
    ///   - hasSession: `CloudAuthService.shared.hasSession`.
    ///   - isConsented: `GroupsConsentState.isAccepted` (caché SELLADA con el `sub`, C1).
    ///   - hasCompletedSetup: `hasCompletedOnboarding`. Lo marca el propio alta, así que es el testigo de
    ///     que el trío ya está escrito y de que este proceso no debe volver a pedir el nombre.
    ///   - canPresentInviteOnboarding: `false` cuando el paso viene del CTA del PROPIO onboarding del
    ///     invitado (source `.userAction`) — sin este discriminador el tap de «unirme» re-presentaría la
    ///     vista. Solo aplica a `.invite`.
    static func nextStep(
        entry: Entry,
        hasSeenEducational: Bool,
        hasSession: Bool,
        isConsented: Bool,
        hasCompletedSetup: Bool,
        canPresentInviteOnboarding: Bool = true
    ) -> Step {
        if entry.showsEducationalFirst && !hasSeenEducational { return .presentEducational }
        if !hasSession { return .presentSignIn }
        if !isConsented { return .presentConsent }

        switch entry {
        case .organizer, .onboardingCard:
            return hasCompletedSetup ? .presentGroupForm : .presentName
        case .invite:
            return (!hasCompletedSetup && canPresentInviteOnboarding) ? .presentInviteOnboarding : .join
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
        case .organizer, .onboardingCard: return true
        case .invite, .tab: return false
        }
    }
}
