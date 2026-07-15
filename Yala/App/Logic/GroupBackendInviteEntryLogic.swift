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
    /// quemados en el productor — regla del repo): sin sesión → sign-in; con sesión sin consent → consent;
    /// listo → join.
    enum Step: Equatable {
        case presentSignIn
        case presentConsent
        case join
    }

    static func nextStep(hasSession: Bool, isConsented: Bool) -> Step {
        if !hasSession { return .presentSignIn }
        if !isConsented { return .presentConsent }
        return .join
    }

    /// C2/R4: la rama backend del entry point solo se toma con el flag ENCENDIDO Y un link backend
    /// parseable. Flag OFF → nunca (byte-idéntico al camino CKShare actual).
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
