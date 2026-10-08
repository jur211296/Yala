---
id: upload-order-sorts-by-hlc-test-fails-in-ci
status: done
priority: medium
area: testing
created: 2026-10-08
updated: 2026-10-08
source: encargo 2026-10-08-upload-order-sorts-by-hlc-test-fails-in-ci (único rojo de 9 029 tests en la QA de 2.1)
---

# El test del orden de subida por HLC sale rojo en el CI de 2.1

## Qué se vio

`YalaTests/UploadOrderTests/pure_sortsByHLC_notByCreatedAt_andMalformedLast()` (suite «Orden de subida · por HLC, no
por la hora de drenado», `YalaTests/CloudSync/ClockAheadServerCapTests.swift`) sale rojo en el CI desde que entró con
el PR #382 (tope del servidor a un HLC del futuro):

- Run 37644787793 (QA programada sobre `beed3a2`, merge del PR #384): rojo 3 de 3 vueltas, con el mismo mensaje:
  `ClockAheadServerCapTests.swift:192:9: Expectation failed: (ordered → ["nuevo", "viejo", "malformado-a", "malformado-b"]) == ["viejo", "nuevo", "malformado-a", "malformado-b"]`
- Run 37615876262 (push de `beed3a2`) y run 37657178403 (push de `806dd7b`, merge del PR #385): «sigue en rojo tras 3
  vuelta(s)». En el run 37648007282 (`fd52c0479`) no aparece.

## Causa raíz: el test, no el producto

«Nuevo» y «viejo» se construían con `remoteHLC(offset:counter:)`, que lee `Date()` en cada llamada. El test quiere
dos HLC con la misma física (ahora + 1 día) que solo difieren en el contador (viejo 0, nuevo 1). «Nuevo» se construía
primero; si entre las dos lecturas del reloj cambiaba el milisegundo, «viejo» salía con más física que «nuevo» y era
el HLC MAYOR. `HLC.uploadOrder` lo ordenaba bien: el orden esperado del test era el que estaba mal.

La prueba, del log del run 37644787793 (job 112872675425):

- vuelta 1 (suite entera): `failed after 0.075 seconds`; vueltas 2 y 3 (solo ese test): `failed after 0.013 seconds`.
  Un test de ordenación pura que tarda 13-75 ms en el runner cruza casi siempre la frontera del milisegundo entre las
  dos lecturas. En una Mac rápida casi nunca la cruza, y por eso en local pasaba.
- El mensaje es exactamente el orden inverso entre «nuevo» y «viejo», con los malformados en su sitio: el producto
  ordenó por HLC y puso los no parseables al final, como promete.
- `personalPush_uploadsInHLCOrder` y `groupsPush_uploadsInHLCOrder_notInDrainOrder` usan el mismo constructor pero
  construyen «viejo» ANTES que «nuevo», así que un milisegundo de más hace a «nuevo» aún mayor: pasaban por el orden
  de las líneas, no porque el dato fuera determinista.

## Arreglo

`YalaTests/CloudSync/ClockAheadServerCapTests.swift`:

- `remoteHLC` acepta una `base: Date` (por defecto `Date()`, el comportamiento de antes para los demás tests).
- `UploadOrderTests` fija un único `now` por prueba; «viejo» y «nuevo» comparten física (`now` + 1 día) y difieren
  solo en el contador. Los `createdAt` también salen de `now`.
- Los tres tests de la suite usan esa base. Ninguna aserción cambió.

Los demás tests del fichero (`HLCObservePulledTests`, `PersonalPullIntegratesTheCappedClockTests`,
`GroupsPullIntegratesTheClockTests`, `PrefsPullIntegratesTheClockTests`) comparan HLC con márgenes de 50 s a un día:
un milisegundo no les cambia el veredicto, y se dejan como estaban.

## Verificación (Mini, Xcode 27.0, iPhone 17 Pro iOS 27.0)

- **El rojo, forzado de forma determinista.** Un test temporal (no commiteado) construyó las filas como el test viejo
  pero con las dos lecturas del reloj fijadas a 1 ms de distancia: `HLC.uploadOrder` devolvió
  `["nuevo", "viejo", "malformado-a", "malformado-b"]`, el orden exacto del CI. Con una sola base, el esperado.
- **Estable:** `UploadOrderTests` con `-test-iterations 50`: 150 de 150 verdes. Las seis suites del fichero juntas:
  21 tests en 7 suites (con la temporal), verdes.
- **Sigue cazando el bug que protege.** Dos mutantes de `HLC.uploadOrder`, los dos rojos en los tres tests (exit 65):
  (A) ordenar por `createdAt`, el orden de antes de #382; (B) comparar solo la física e ignorar el contador. El B es
  el que el test viejo no podía cazar de forma fiable: con un milisegundo de diferencia decidía la física.
- Builds `Yala` y `Yala Dev` verdes, sin warnings en el fichero tocado.

## El timeout de 110 min de los UI tests del mismo run

No es este rojo. Lo medido va a `nightly-ui-suite-hits-its-110-minute-cap-every-night`.
