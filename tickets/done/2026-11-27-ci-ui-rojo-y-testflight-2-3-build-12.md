---
id: 2026-11-27-ci-ui-rojo-y-testflight-2-3-build-12
status: done
priority: high
area: "ci, release, testflight"
created: 2026-11-27
updated: 2026-11-28
source: "Encargo de Jürgen (27-nov, Lima): revisar el CI de interfaz de 2.3 en rojo (tandas 1, 8, 9 y 12), arreglarlo, esperar el verde y subir la build 12"
---

# CI de interfaz de 2.3 al día y Yala 2.3 (12) a TestFlight

## Qué estaba en rojo y por qué

| Prueba | Causa | Arreglo |
|---|---|---|
| Tandas 8 y 12: Bienvenida 2.3, bienvenida de Grupos con la X, las cinco de la barra personalizada | La pestaña Grupos se llama «Compartido» desde el 26-nov | La etiqueta en el ayudante de pestañas y en las pruebas |
| Tanda 9: bienvenida con iCloud privado y cuenta nueva | «Solo gastos» ya no crea la cuenta de gastos (25-nov) | Espera el Panel con «Crea tu primera cuenta» |
| Tanda 1: edición masiva de cuenta | Dependía del día: la transferencia de los días 10 y 25 de la semilla apagaba «Aplicar» la noche siguiente | Elige filas que no son transferencia |
| Tanda 1 (inestable): asistente de pago compartido | Espera de 5 s corta en el runner | 10 s |
| Unitaria de `2.3`: la carga del Panel por tramos | Con Eficiencia 8, «listo» llega después de los movimientos | La prueba espera también a `isReady` |
| Archivo de Release | `PanelViewModel.marcasEnCurso` dentro de `#if DEBUG` y usada fuera (lote 4 de eficiencia) | Fuera del bloque, con prueba que lee el fuente |

## Resultado

- Arreglos de pruebas: PR #1214 (mergeado). Build 12 y el arreglo de Release: PR #1215.
- QA completo de `2.3` sobre `e5fff9ec7`: run 46091156235. Las pruebas que estaban en rojo pasan todas (barra
  personalizada 6/6, bienvenida 4/4, edición masiva 3/3, bienvenida tras cuenta lista 4/4, hero de Estadísticas 4/4).
- **Inestable conocido, no arreglado:** al subir el teclado en una hoja, XCTest a veces espera 60 s por gesto y la
  prueba agota su tope; al repetirla pasa (tandas 4, 6, 8 y 10 de esa corrida). Detalle y lo descartado en
  `docs/aprendizajes-tecnicos.md`. Decisión de Jürgen (28-nov): anotarlo como conocido y seguir.
- **Rojo nuevo, fuera de las tandas pedidas:** `BudgetAtLimitUITests` (tanda 13), con su ticket en backlog.
- iCloud: Producción de `yala` y `yala_dev` idéntica al repo (`cktool export-schema`, 27-nov); sin campos pendientes.
- **Yala 2.3 (12) en TestFlight** (28-nov, 05:15 de Lima): archivada en la Max sobre `2.3` con el PR #1215 dentro,
  subida con `xcodebuild -exportArchive` y la llave de `asc`, procesada `VALID` y en `IN_BETA_TESTING` para «Test
  interno». No se envió a revisión. Notas «Qué probar» (es-MX) desde `docs/qa/testflight-2-3-12/notas-que-probar.txt`,
  verificadas literal. Preflight OK; dSYM a Sentry (3 ficheros).
- **Guía de novedades** al día con la build 12 en una URL nueva: https://claude.ai/artifact/9f7BMc2FVzXqysUL4RXkA8
  (pública con enlace): 30 ítems nuevos, 6 cambios, 4 capturas nuevas y las 304 notas de la guía anterior copiadas.

## Paso 0 — decisiones

Las del encargo (`encargos/lanzados/2026-11-27-ci-ui-rojo-y-testflight-2-3-build-12.md`), más:

| # | Decisión | Por qué |
|---|---|---|
| 7 | El arreglo de Release va en el PR de la build aunque `PanelViewModel` no estaba en el `toca:` | Sin él no hay archivo; es una línea movida y no cambia Debug |
| 8 | La guía de novedades estrena URL | La de la build 11 es de otra cuenta y esta sesión solo puede leerla; las 304 notas de Jürgen se copian a la nueva por id |
