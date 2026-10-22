//
//  CanonValue.swift
//  Yala
//
//  Valor tipado de UNA columna Postgres para el codec canónico c1 del cable de Modo Nube
//  (incremento I8a). La ENTRADA del codec es `[String: CanonValue]` (nombre de columna Postgres
//  snake_case → valor tipado), NO los `@Model` de SwiftData: la traducción `@Model` → mapa es de I8c.
//
//  Cada case declara implícitamente la REGLA canónica c1 por-tipo (§d.7, bloque S2, `canon_version="c1"`
//  INMUTABLE). En particular la ESCALA del dinero (4) y de la tasa (8) va codificada en el propio case
//  (`.money`/`.rate`) — es el espejo tipado de la escala declarada por-columna en `capability_manifest.json`
//  (SSOT). El test de coherencia manifest↔codec verifica que ambos no diverjan.
//
//  Distinción tri-estado CRÍTICA (§d.1:366 + política C2):
//    - columna AUSENTE del mapa  → "no toqué esta columna" → NO se emite (key ausente en el JSON).
//    - `.null`                    → columna tocada-y-puesta-a-NULL → se emite `key:null`.
//    - `.bool(nil)`               → un `Bool?` tri-estado puesto a NULL → se emite `key:null`.
//  El backend distingue "ausente" (preserva) de "null explícito" (escribe NULL) — el codec representa ambos.
//

import Foundation

/// Valor canónico tipado de una columna Postgres. `nonisolated` + `Sendable`: cruza sin actor.
///
/// La escala de los números va en el propio case (`.money` = 4 decimales, `.rate` = 8), reflejando la
/// escala por-columna del `capability_manifest.json`. El resto de reglas (fechas UTC-ms-floor, UUID
/// lowercase, arrays ordenados+dedup, tri-estado bool, blobs recursivos) las aplica `Canonc1Codec`.
nonisolated enum CanonValue: Sendable, Equatable {
    /// `Double`→NUMERIC dinero (escala FIJA 4). Se emite como STRING JSON decimal HALF_EVEN desde el
    /// binario EXACTO del Double (§d.7 O1/O5). NaN/±Inf o |v|≥10¹⁴ → THROW.
    case money(Double)
    /// `Double`→NUMERIC tasa (escala FIJA 8). Igual que `.money` pero 8 decimales y límite |v|<10¹⁰ (O4/O7).
    case rate(Double)
    /// `Date`→TIMESTAMPTZ. Instante ABSOLUTO: `canonicalIsoMillis(physicalMillis(from:))` (24 chars, ms-floor UTC).
    case timestamp(Date)
    /// Día civil (S9). Se emite `YYYY-MM-DD` (los 10 primeros chars de la T-CANON de la Date). La Date DEBE
    /// venir posicionada por I8c a medianoche UTC desde los componentes del DatePicker (contrato, ver codec).
    case localDay(Date)
    /// UUID/FK. Se emite 36 chars lowercase con guiones (forma `uuid::text` de Postgres).
    case uuid(UUID)
    /// `UUID[]`/`tag_refs`. Array ordenado ascendente por bytes UTF-8 + deduplicado. **Vacío**: columna
    /// SINGLETON → OMITIR la key (O8); columna DENTRO de un grupo de coherencia → `[]` explícito
    /// (DIFERIDOS #25 opción 1 — el grupo viaja entero). El contexto lo pasa el caller del codec
    /// (`groupedColumns`).
    case uuidArray([UUID])
    /// Texto (`name`/`note`/FKs opacas). SIN normalización Unicode/trim/case-fold; escape mínimo RFC-8785.
    case string(String)
    /// `Bool?` tri-estado: `true`/`false`/`null` literal (nunca 0/1, nunca coalesce nil→false).
    case bool(Bool?)
    /// Entero (`sort_order`/`day_of_month`/…). Se emite como número JSON plano.
    case int(Int)
    /// Blob `Data`-JSON (`rates`/`configurationData`→JSONB). Se re-canonicaliza RECURSIVAMENTE (ver codec).
    case dataJSON(Data)
    /// NULL explícito de una columna no-bool tocada (se emite `key:null`; ≠ key ausente).
    case null
}
