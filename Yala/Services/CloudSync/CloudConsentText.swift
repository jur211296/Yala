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
    ///
    /// Historial, porque la versión sola no dice qué se aceptó:
    /// - **1** — los 7 puntos de §k.6 (I14 P5). El cambio de `storage.consent.point6` de `7906c1fa`
    ///   («Apple o Google» en vez de solo Apple) NO la bumpeó a propósito: tocaba la redacción del
    ///   método de login, no el contrato.
    /// - **2** — W3 (2026-08-11): el texto se PODA a tres puntos + un pie. Sale del contrato lo que
    ///   viaja al proveedor de IA (queda en el consent de IA, que ya lo decía) y la ubicación de los
    ///   servidores (queda en la política de privacidad). Eso es qué-sale y dónde-se-guarda ⇒ bump.
    ///
    /// **Medido, y conviene saberlo antes de razonar sobre el bump:** ningún camino COMPARA esta
    /// constante con lo persistido — la pantalla del consent se presenta siempre antes de firmar, así
    /// que nadie queda con una versión vieja sin volver a aceptar. Lo que la versión hace es dejar
    /// registrado QUÉ texto se aceptó (trazabilidad), no gatear una re-petición.
    static let version = 2
}
