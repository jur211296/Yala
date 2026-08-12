//
//  GroupsConsentText.swift
//  Yala
//
//  Versión GLOBAL del texto de consentimiento informado de GRUPOS. Molde de `CloudConsentText`: NO es
//  per-locale — la versión identifica el CONTRATO (qué sale, quién lo lee, dónde se guarda), no su
//  traducción. El copy visible vive en l10n (`groups.consent.*`, 16 locales); esta es la única fuente de
//  la versión que se persiste y se registra contra la cuenta (`groups_consents.text_version`).
//
//  ## Por qué son DOS constantes y no una (chip C1, §8 del spec)
//
//  Hasta hoy la maquinaria existía entera y no se usaba: `GroupsConsentState.textVersion = 1` se escribía
//  y **ningún camino la COMPARABA con lo persistido** — el propio docblock de `CloudConsentText` lo
//  declara medido para su gemelo. Lo que faltaba no era marcar la versión: era compararla.
//
//  Y una sola constante no puede expresar la decisión del owner, que es «re-preguntar SOLO si el cambio es
//  sustantivo». Con una sola, o bumpearla obliga a re-aceptar a todo el parque por una coma, o no bumpearla
//  pierde la trazabilidad de qué texto firmó cada uno. Por eso:
//
//   · `version` — se bumpea SIEMPRE que cambie el texto. Es la trazabilidad de QUÉ se aceptó.
//   · `requiresReacceptanceFrom` — la última versión SUSTANTIVA (cambió qué se trata, quién accede o dónde
//     se guarda). Aceptar una versión ANTERIOR a ésta obliga a volver a preguntar.
//
//  Al bumpear `version` sin tocar `requiresReacceptanceFrom`, quien aceptó la anterior NO vuelve a ver la
//  pantalla; al subir las dos, sí — y la aceptación nueva INSERTA UNA FILA MÁS en `groups_consents` (la PK
//  es `(user_id, text_version)`) sin tocar la anterior, así que la traza queda completa: qué versiones
//  aceptó esa cuenta y cuándo cada una.
//
//  Historial, porque la versión sola no dice qué se aceptó:
//   - **1** — los 4 puntos de `groups.consent.point1…point4` (G4-invites A2). C1 (2026-08-11) NO la bumpea:
//     mueve DÓNDE se guarda el registro (del iKV del Apple ID a la cuenta de Yala) sin cambiar una palabra
//     del texto ni qué datos salen. Bumpear sin cambio de texto habría re-preguntado a todo el parque por
//     un cambio que no le afecta.
//

import Foundation

nonisolated enum GroupsConsentText {

    /// Versión del texto vigente. Bump SIEMPRE que cambie el copy del consent (trazabilidad).
    static let version = 1

    /// Última versión SUSTANTIVA. Un consent aceptado con `textVersion < requiresReacceptanceFrom` se lee
    /// como NO aceptado y la cadena vuelve a presentar la pantalla. Subirla es una decisión de producto con
    /// coste real (todo el parque vuelve a ver el consent): se sube cuando cambia qué se trata, quién
    /// accede o dónde se guarda — nunca por una corrección de redacción.
    static let requiresReacceptanceFrom = 1
}
