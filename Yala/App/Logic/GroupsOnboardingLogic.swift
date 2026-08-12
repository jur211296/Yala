//
//  GroupsOnboardingLogic.swift
//  Yala
//
//  Pure decision logic para el onboarding informativo del tab Grupos. Decide si
//  presentar el sheet en función del estado del user (flag persistida, modo de
//  onboarding global y deeplinks pendientes).
//
//  Extraído como pure-logic para tests sin SwiftData ni UI (sin flake R8 conocido
//  por `makeTestContext()`).
//
//  Patrón análogo a `YalaAIOnboardingLogic`.
//

import Foundation

enum GroupsOnboardingLogic {

    /// **C2 (2026-08-12) · el hecho REAL: «esta persona ya vio UN educativo de Grupos».**
    ///
    /// Sustituye al corte `onboardingMode == .groupInvite` que vivía dentro de `shouldShow`. Aquel corte
    /// era un proxy y estaba MAL en la dirección cara: `.groupInvite` es también lo que escribía la card
    /// «Solo grupos» del onboarding de 8 pasos, así que suprimía el educativo justo para quien entraba por
    /// la puerta que menos contexto daba —y que además no pedía ni sesión ni consent—. Son dos estados
    /// distintos («ya se lo contamos» vs. «está en modo Grupos») y estaban colapsados en uno falso.
    ///
    /// - Parameters:
    ///   - hasShownOnboarding: `AppPreferences.hasShownGroupsOnboarding`. Per-device y permanente. La
    ///     escriben los DOS educativos: el general (`GroupsOnboardingView`, en el tab y en el cover de las
    ///     puertas A/B) y el del invitado (`GroupInviteOnboardingView`, contextual al link) — porque ESE
    ///     es el educativo del invitado, y esa es exactamente la sustitución que el chip pide.
    ///   - onboardingMode / hasCompletedSetup: el término **LEGACY**, y solo eso. Quien completó su alta en
    ///     modo Grupos ANTES de C2 vio su educativo y no dejó marca: sin este término, actualizar la app le
    ///     presentaría un educativo que ya conoce. No hay migración que escribir — la evidencia ya está en
    ///     disco. Para todo alta POSTERIOR a C2 el término es redundante (la marca se pone en el educativo,
    ///     que va antes que el modo) y se puede retirar cuando el parque haya rotado.
    static func hasSeenAnyGroupsEducational(
        hasShownOnboarding: Bool,
        onboardingMode: OnboardingMode,
        hasCompletedSetup: Bool
    ) -> Bool {
        if hasShownOnboarding { return true }
        return onboardingMode == .groupInvite && hasCompletedSetup
    }

    /// Decide si presentar el onboarding del tab Grupos. AND-gating: cualquier
    /// blocker presente bloquea (no OR — el orden de evaluación es irrelevante).
    ///
    /// - Parameters:
    ///   - hasSeenEducational: el resultado de `hasSeenAnyGroupsEducational`. **Es la MISMA señal que
    ///     alimenta a `GroupsGateLogic`**: el tab y las cuatro puertas no pueden discrepar sobre si a esta
    ///     persona ya se le contó qué es un grupo.
    ///   - hasPendingGroupDeeplink: `sessionState.pendingGroupID != nil`. Si hay
    ///     deeplink hacia un grupo específico, abrir el detail tiene prioridad UX
    ///     sobre el onboarding informativo.
    static func shouldShow(
        hasSeenEducational: Bool,
        hasPendingGroupDeeplink: Bool
    ) -> Bool {
        if hasSeenEducational { return false }
        if hasPendingGroupDeeplink { return false }
        return true
    }

    /// ¿El último step del educativo ofrece el CTA de iniciar sesión? (A1 de D-A7, decisión
    /// P1(b) del owner: CTA al cierre ADEMÁS del contextual que ya existe).
    ///
    /// Va en lógica pura y NO como un `if` dentro del `body`: un predicado enterrado en un
    /// `@ViewBuilder` es invisible para los unitarios y se puede borrar con la suite entera en
    /// verde (lección de `965a4d86`, molde exacto de `OnboardingGroupsPurposeGateLogic`). El
    /// CABLEADO —que la vista pase los valores REALES y no literales— lo pinnea el source-scan
    /// de `GroupsOnboardingSignInCTAWiringTests`.
    ///
    /// - Parameters:
    ///   - isLastStep: solo el step de cierre ofrece el CTA; los intermedios siguen con
    ///     "Continuar".
    ///   - flagOn: `CloudSyncFlags.groupsBackendEnabled`. Con el canal APAGADO Grupos sigue
    ///     viviendo en CloudKit y no hay sesión Yala que pedir ⇒ el recorrido queda
    ///     byte-idéntico al de siempre. Es la MISMA señal que gatea el empty state
    ///     (`GroupsEmptyStateLogic.decide`), no una segunda fuente.
    ///   - hasSession: `CloudAuthService.shared.hasSession`, la misma que lee el caller de
    ///     `GroupsEmptyStateLogic.decide` en `GroupsContainerView`. Con sesión viva el CTA
    ///     sería un prompt sin sentido.
    static func shouldShowSignInCTA(
        isLastStep: Bool,
        flagOn: Bool,
        hasSession: Bool
    ) -> Bool {
        isLastStep && flagOn && !hasSession
    }
}

/// Origen del trigger del onboarding — telemetría para distinguir entry points si
/// se añaden futuros launchers (deeplink directo, App Intent, widget, etc.).
enum GroupsOnboardingLauncher: String {
    case groupsTab
}

/// Resultado del onboarding cuando el sheet se cierra. Cada caso define efectos
/// distintos sobre la flag `hasShownGroupsOnboarding` y telemetría.
enum GroupsOnboardingResult: Equatable {
    /// CTA Step 3 "Ir a Grupos": persistir flag + ejecutar seed lazy.
    case complete
    /// CTA Step 3 "Iniciar sesión" (A1, solo sin sesión): mismos efectos que `.complete`
    /// —el usuario TERMINÓ el educativo— más el sign-in de Grupos. El intent se emite con el
    /// sheet YA desmontado (`onDismiss`): emitirlo con el sheet puesto lo dejaría RETENIDO por
    /// peek-first, igual que documenta `GroupsContainerView.requestCreateGroup`.
    case completeAndSignIn
    /// "X" topLeft (cualquier step): NO persistir flag (volverá a aparecer).
    case close
}
