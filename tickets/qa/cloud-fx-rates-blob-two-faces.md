---
id: cloud-fx-rates-blob-two-faces
status: qa
created: 2026-07-18
updated: 2026-08-26
source: YalaWiki/Bugs/qa_cloud-fx-rates-blob-dos-caras.md
---

> Sync 18 ago (Iris, Mac SSOT). Cola B B1: Yala PR 17 MERGED a `2.0.5` merge `51d25e68` (18 ago 07:29 Lima). Corte 2.1. HOLD del vault stale. No reabrir. QA device del AC original: desconocido. No rename `ok_`.


# Blob FX `rates` ilegible tras round-trip por el canal nube — decode estricto perdía TODAS las tasas de la fecha

## Síntoma (device, 2026-07-18)

`ExchangeRate: Error decoding rates for <fecha>: DecodingError.typeMismatch: Expected Double... Path: ILS`
repetido para las fechas 2026-07-12..18. Toda fila FX que hizo round-trip por el canal nube quedaba
ilegible localmente: `decodedRates()` devolvía `[:]` → se perdían **todas** las tasas de esa fecha
(ILS solo era donde el decoder tropezaba primero).

## Cadena causal (verificada en código)

1. **PUSH**: `Canonc1Codec.canonicalizeBlobValue` canonicaliza TODO número anidado de un blob
   `.dataJSON` como STRING JSON escala-8 (regla de tasa, por diseño del canon c1) → el jsonb `rates`
   del backend queda con valores string (`"3.61230000"`).
2. **PULL/APPLY**: el applier de `rates` (`EntityApplyMap.exchangeRate:369`) re-serializa el objeto
   wire verbatim vía `WireValueDecoder.jsonData` → el blob LOCAL queda con strings.
3. **LECTURA**: `ExchangeRate.decodedRates()` decodificaba estricto `[String: Double]` → typeMismatch
   → `[:]`.

Atenuante que enmascaraba el bug: `persistRate` de la API sobrescribe con doubles, pero cada pull
re-contaminaba. Pariente del hallazgo FX de la corrida device de I11 (2026-07-11) — misma familia
"clase-FX", mecanismo distinto.

## Implementación

### 2026-07-18 — `56233a1f`

**Resumen:** `decodedRates()` tolerante a las DOS caras del blob (doubles nativos + strings decimales
escala-8) con skip por-key (un valor basura ya no tumba la fecha entera) + guard `isFinite`.

**Archivos modificados:**
- `Yala/Models/ExchangeRate.swift` — decode tolerante vía JSONSerialization; doc-comment con el
  contrato (NUNCA volver al decode estricto ni normalizar en el apply).
- `YalaTests/CloudSync/Canonc1CodecTests.swift` — test `blob_rateStringsPostPull_projectIdenticalToNativeDoubles`
  PINNEA el invariante Merkle: la cara post-pull (strings escala-8) proyecta byte-idéntico a la nativa (doubles).
- `YalaTests/ExchangeRateServiceTests.swift` — 6 tests `decodedRates_*` (regresión del blob exacto
  post-pull, mixto, skip por-key, no-finitos, vacío/malformado).
- `qa/coverage-index.json` — áreas `cloud-sync-pull-apply` (+`ExchangeRate.swift` en globs) y
  `cloud-sync-canon-codec` actualizadas, `lastVerified` 2026-07-18.

**Decisiones técnicas:**
- **Opción (a) read-side elegida sobre (b) normalizar-en-apply**: (a) sana las filas YA contaminadas
  del device de inmediato (el dato está, solo era ilegible) y no toca blob ni proyección — Merkle
  trivialmente intacto. (b) solo arreglaría pulls futuros y el roundtrip parse/format arriesgaba
  divergencia clase-FX (una tasa cercana a 10¹⁰ con 8 decimales no round-trippea por double).
- Invariante verificado en los DOS codecs: Swift (`canonicalizeBlobValue` pasa strings verbatim) y
  gateway TS (`canon.ts:26-27` lo documenta explícitamente).
- **Barrido del patrón (regla del proyecto)**: `rates` es el ÚNICO `jsonb` del manifest; los `text[]`
  (`aliases`, `needs_user_input`, `newly_created_tag_names`) son solo strings; `configurationData` NO
  viaja como blob (se descompone en 2 columnas string). Los 4 consumidores de `rates` pasan por
  `decodedRates()`; el widget target no lo toca.

**Gates:** 73 tests / 7 suites (unit + goldens del codec intactos) · e2e staging **7/7** con Merkle
estricto `diverged == ["tx_items"]` (el primer run falló 5/7 por drift de staging AJENO al fix: los
goldens del gateway habían re-creado 10 budgets parciales del user A → re-tombstoneados con el remedio
documentado, gotcha `0ca248e8` de qa/cloud/README) · build prod (scheme Yala) limpio · validate-coverage OK.

## QA en device

Verificación trivial (fix read-side puro, sin migración):
1. Instalar el build en el device afectado.
2. Abrir una vista con conversión de divisas (ej. widget de tasas o una TX en divisa extranjera de las fechas 07-12..18).
3. ✅ Las tasas de esas fechas vuelven a resolverse; ❌ NO deben aparecer más `typeMismatch: ILS` en Console.
4. Opcional: forzar un pull (el blob seguirá llegando con strings — es la forma canónica esperada — y debe leerse bien).

migrated from YalaWiki Bugs/qa_cloud-fx-rates-blob-dos-caras.md @ 1934e8ad
