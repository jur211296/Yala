//
//  GroupBackendInviteEntryLogic.swift
//  Yala
//
//  Pure-logic del flujo de entrada del invite backend (G4-invites, DARK). Gobierna el paso
//  encadenado sign-in → consent → join (contrato §A1 pasos 3-4) y las reglas de displayName
//  (R1 — nunca vacío + corrección posterior). Sin SwiftData/CloudKit/UI — tabla completa en
//  GroupBackendInviteEntryLogicTests. Lo consumen el handler (warm tap) y el reconciler (boot/
//  foreground) para decidir idéntico.
//

import Foundation

nonisolated enum GroupBackendInviteEntryLogic {

    /// El siguiente paso del flujo encadenado. Cada llamada re-evalúa condiciones VIVAS (no one-shots
    /// quemados en el productor — regla del repo): sin sesión → sign-in; con sesión sin consent →
    /// consent; usuario FRESCO (sin onboarding) → invite onboarding (captura el nombre ANTES del join,
    /// paridad con `inviteRouteDecision.acceptAndShowInviteOnboarding`); listo → join.
    enum Step: Equatable {
        case presentSignIn
        case presentConsent
        /// A2 (paso 6 de A1): usuario fresco — presentar `GroupInviteOnboardingView` (metadata nil,
        /// visual genérico); el JOIN lo dispara su CTA vía el reconciler (source `.userAction`).
        case presentInviteOnboarding
        case join
    }

    /// - Parameters:
    ///   - hasCompletedOnboarding: señal de routing actual (UserDefaults) — un fresco pasa por el
    ///     invite onboarding para capturar su nombre antes del join (R1: jamás join con placeholder
    ///     si podemos capturar el real primero).
    ///   - canPresentOnboarding: `false` cuando el paso viene del CTA del PROPIO onboarding
    ///     (source `.userAction`) — sin este discriminador el tap de "unirme" re-presentaría la vista.
    static func nextStep(
        hasSession: Bool,
        isConsented: Bool,
        hasCompletedOnboarding: Bool = true,
        canPresentOnboarding: Bool = true
    ) -> Step {
        if !hasSession { return .presentSignIn }
        if !isConsented { return .presentConsent }
        if !hasCompletedOnboarding && canPresentOnboarding { return .presentInviteOnboarding }
        return .join
    }

    /// C2/R4: la rama backend del entry point solo se toma con el flag ENCENDIDO Y un link backend
    /// parseable. Flag OFF → nunca (byte-idéntico al camino CKShare actual).
    ///
    /// ⚠️ **YA NO ES LA SSOT DEL ENRUTADO, y su docblock describe una premisa REFUTADA en device el
    /// 2026-07-31.** No tiene —ni tuvo nunca— un call-site de producción: solo tests. Y la promesa
    /// «flag OFF → byte-idéntico al camino CKShare» es FALSA, porque `InviteLinkService.extractShareURL`
    /// **acepta** un link backend (su `s` decodifica a una URL válida y el guard valida el URL
    /// exterior) ⇒ con el flag OFF el invite se colaba al canal CKShare y moría sin UI. El enrutado
    /// vive ahora en `GroupInviteChannelRoutingLogic.route`, que enruta por la FORMA DEL LINK y usa
    /// el flag para decidir QUÉ hacer (incluido forzar un refresh del remote-config y reintentar).
    /// Se conserva solo para no tocar sus tests en el commit del fix.
    static func routesToBackend(flagEnabled: Bool, backendInviteParsed: Bool) -> Bool {
        flagEnabled && backendInviteParsed
    }

    /// R1 (CORRECTNESS): el `p_display_name` del join JAMÁS puede ser vacío (`join_group` hace
    /// `btrim=''` → `yala_bad_input` permanente y el invitado nunca entra). Precedencia:
    /// nombre del intent (tecleado en onboarding) → nombre del perfil → `defaultName`. Trimmea y
    /// garantiza no-vacío.
    static func resolveJoinDisplayName(
        intentName: String?,
        profileName: String,
        defaultName: String
    ) -> String {
        for candidate in [intentName, profileName] {
            let trimmed = (candidate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return defaultName
    }

    /// R1 (corrección posterior): cuando el silent-setup captura el nombre REAL (`intentName`) y el
    /// member ya existe con el placeholder enviado al join, se corrige vía `update_member_display_name`
    /// UNA vez. Guard anti-pisado: solo si el nombre actual del member es el default/vacío (no pisa un
    /// rename manual), el intent trae un nombre real distinto.
    static func shouldCorrectMemberDisplayName(
        intentName: String?,
        currentMemberDisplayName: String,
        defaultName: String
    ) -> Bool {
        let intent = (intentName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !intent.isEmpty else { return false }
        let current = currentMemberDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard intent != current else { return false }
        return current.isEmpty || current == defaultName
    }
}
