---
name: el-seam-que-usa-el-camino-de-produccion
description: Mi seam de QA escribía el estado por el camino de producción — que es lo correcto — y por eso mismo ensuciaba el UserDefaults real del simulador. La purga simétrica en el `else` no basta: hay que desviar el almacén.
metadata:
  type: feedback
---

**Un seam de QA que escribe por el camino de PRODUCCIÓN hereda su persistencia. La purga simétrica cubre
al seam; lo que ensucia el simulador es cualquier escritura de la corrida.**

**Why:** el 2026-09-15 sembré el veredicto de App Attest llamando tres veces a
`GroupsAttestStreakStore.recordRejection(now:)` con relojes separados, en vez de forzar el predicado. Eso
está bien y es lo que pide `testing.md`. Pero esa función escribe en `UserDefaults.standard`, y la clave
**no** está en `DataWipeService.removeUserPreferenceKeys` a propósito —describe al TELÉFONO, y cerrar
sesión no arregla el attest— así que `-uitest-reset` no la borra. Puse una purga en el `else` del seam y la
di por cerrada. Una lente adversarial midió lo que faltaba: **todo arranque manual del simulador** posterior
a la corrida, y el host de unit tests que comparte bundle, leían el veredicto terminal — y los gestos de
cierre y de salir de un grupo ofrecen entonces «perder los cambios» sobre un teléfono que atesta bien.

**How to apply:**

- **La purga simétrica es una red del seam, no del almacén.** Cubre «se pidió / no se pidió»; no cubre a los
  clientes de producción que escriban ese mismo estado durante la corrida.
- **Si el estado tiene un seam de almacén, úsalo:** apuntar `X.defaults` a una suite propia bajo `-uitest`
  —vaciada en cada arranque— saca de en medio **toda** la corrida, no solo la siembra. El molde vecino es
  `UITestEphemeralDefaults`, y su mecanismo habitual (el dominio de REGISTRO) **no sirve aquí**: `set(_:forKey:)`
  va al dominio persistente.
- **La purga del almacén real va igual, y no es cinturón:** es lo único que limpia los simuladores que ya
  corrieron la versión anterior del seam.
- **La pregunta que lo destapa:** «tras esta corrida, ¿qué lee un arranque SIN `-uitest`?». Si la respuesta
  no es «lo mismo que antes», el seam persiste.

Relacionado: [[el-reparador-tan-reejecutable-como-el-destructor]] · [[el-prefijo-que-elegi-tiene-dos-efectos]] ·
[[el-testigo-global-miente-en-el-host-de-test]].
