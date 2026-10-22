---
name: el-testigo-global-miente-en-el-host-de-test
description: Un gate nuevo que lee un testigo GLOBAL tiene que comprobar qué vale ese testigo bajo -uitest antes de confiar en él; el 11-sep uno mentía y la puerta nueva volvía SIEMPRE al neutro en XCUITest, armando un borrado real por corrida
metadata:
  type: feedback
---

**Antes de que un gate nuevo lea un testigo global, mide qué vale ese testigo en el HOST DE TEST.** No lo
que debería valer: lo que vale, leyendo el camino que lo escribe.

**Why:** el 2026-09-11 la puerta de «Vengo por un grupo» pasó a consultar
`SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror`. Medido después, y por una
lente: bajo `-uitest` `personalConfiguration` sale por su rama `YalaModel-UITest` **antes** de llamar a
`capturePersonalStoreMountedDecisionOnce`, así que el testigo se queda en el default de su DECLARACIÓN
—`.iCloudMirror`— y el eje da `true` en toda corrida. Consecuencias en cadena, todas reales: `.proceed` era
inalcanzable en XCUITest, un test de control ajeno se caía, y **cada corrida armaba un boot-wipe de verdad**
cuya key (`cloudSync.*`) sobrevive a `-uitest-reset` y a `DataWipeService` ⇒ el siguiente arranque MANUAL
del simulador, donde el ejecutor sí corre, habría borrado el store.

Lo peor no fue el defecto sino que **la consecuencia ya estaba escrita en el repo, para el otro lado**:
`UITestEphemeralDefaults.applySecondarySession` dice literalmente «`capturePersonalStoreMountedDecisionOnce`
tampoco corre». Estaba a un grep.

**How to apply:**

- Cuando cablees un predicado global en un gate, abre su escritor y busca los `return` que salen ANTES de
  la captura. Un default de declaración es una respuesta, y casi nunca la que quieres.
- **El seam va con el default en la VERDAD del host de test, no en una inversión.** Si el store de test no
  espeja, el seam vale `false` y el hook lo enciende; al revés ciega a todos los tests que lo usan.
- **Y desconfía de una purga como red.** La primera corrección fue purgar el arm en `applyUITestHooksEarly`,
  y no servía para nada: el ejecutor corre en `PersonalContainerHost.makeContainer()`, que se construye
  antes, y bajo `-uitest` está apagado de todos modos. La única red real era **no armar**. Una red que no
  cubre su caso es peor que ninguna, porque nadie vuelve a mirarla.

Hermano de [[el-mecanismo-que-reuso-trae-sus-precondiciones]] y de
[[el-source-scan-de-dos-literales-no-es-una-red]].
