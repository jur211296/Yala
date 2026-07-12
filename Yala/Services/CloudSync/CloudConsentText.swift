//
//  CloudConsentText.swift
//  Yala
//
//  Versión GLOBAL del texto de consentimiento informado del Modo Nube (§2.8 / §k.6, nota M1). NO es
//  per-locale: la versión identifica el CONTRATO de privacidad aceptado (qué sale, quién lo lee, dónde
//  se guarda), no su traducción. Se registra junto a `cloudConsentAcceptedAt` al aceptar (P5) para
//  trazabilidad GDPR (§e.6) — si el contrato cambia materialmente, se bumpea y se re-pide el consent.
//
//  El copy visible vive en l10n (`storage.consent.*`, 16 locales). Esta constante es la única fuente de
//  la versión persistida.
//

import Foundation

nonisolated enum CloudConsentText {
    /// Versión del contrato de consentimiento vigente. Bump al cambiar materialmente qué sale / quién lo
    /// lee / dónde se guarda (obliga a re-pedir el consent a quienes aceptaron una versión anterior).
    static let version = 1
}
