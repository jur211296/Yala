//
//  OnboardingPrefillResolver.swift
//  Yala
//
//  Decide qué valor inicial usar para `userName` y `defaultCurrencyCode` al
//  abrir el OnboardingView. Resuelve bug #9c: cuando rama B llega con un
//  `ICloudAccountSummary` desde iCloud, el read posterior de UserDefaults
//  pisaba el valor de `summary` con un residuo del KV-Store (caso típico:
//  `summary.userName="Juan"` + `UserDefaults.userName="Test"` → ganaba "Test").
//
//  Regla: si `prefilled != nil` (rama B activa), devolver SOLO el valor de
//  `prefilled` — incluso si es `nil`, no caer en defaults. Si `prefilled == nil`
//  (rama A o entry point sin restore), leer de defaults con los guards
//  habituales (`!isEmpty`, `!= "Usuario"` sentinel).
//

import Foundation

@MainActor
enum OnboardingPrefillResolver {

    /// `prefilled` activo (Rama B): respeta `summary.userName` aunque sea `nil`.
    /// `prefilled` ausente (Rama A): aplica guards de UserDefaults.
    static func resolveUserName(prefilled: ICloudAccountSummary?, defaultsName: String?) -> String? {
        if let prefilled {
            return prefilled.userName
        }
        guard let candidate = defaultsName,
              !candidate.isEmpty,
              candidate != "Usuario" else { return nil }
        return candidate
    }

    /// Misma semántica: rama B respeta `summary.primaryCurrencyCode`; rama A
    /// lee defaults. La conversión a `CurrencyCode` queda en el caller — este
    /// resolver solo elige qué raw string usar.
    static func resolveCurrencyCode(prefilled: ICloudAccountSummary?, defaultsCode: String?) -> String? {
        if let prefilled {
            return prefilled.primaryCurrencyCode
        }
        guard let candidate = defaultsCode, !candidate.isEmpty else { return nil }
        return candidate
    }
}
