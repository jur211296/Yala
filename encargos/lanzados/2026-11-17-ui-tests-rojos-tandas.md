Yala
# Dejar 2.3 perfecta: arreglar las tres pruebas de UI en rojo, mergear todo y subir a TestFlight
---
toca: YalaUITests/Flows/PersonalToGroupConversionUITests.swift, YalaUITests/Flows/SplitCalculatorUITests.swift, YalaUITests/Flows/AccountCardPickersUITests.swift, tickets/done/2026-11-16-ui-tests-rojos-tandas.md, Yala.xcodeproj/project.pbxproj, docs/qa/testflight-2-3-3/
esfuerzo: medium
cierre: cierra-sola
---

## Qué pidió Jürgen (16-nov, 20:16 Lima)
«Si lo consideras encola sesiones para desbloquear», sobre el aviso de que las tandas 1, 8 y 9 de UI tests quedaron en rojo en 2.3 (run https://github.com/jur211296/Yala/actions/runs/43929672868).

## Lo que falla (fallan en los 3 reintentos, así que no son inestables)
- Tanda 1: `PersonalToGroupConversionUITests.test_convertingTheBus_toAGroup` (línea 129).
- Tanda 8: `SplitCalculatorUITests.test_applyingSplitShowsChipInForm` y `test_splitCalculatorComputesPortion` (línea 43).
- Tanda 9: `AccountCardPickersUITests.test_selector_fromTheUSDLine_choosingTheCardGoesBackToThePrincipal` (líneas 88 y 92).
Ninguno de esos tests cambió en los últimos 3 días, mientras entraron unos 56 merges en 2.3 (por ejemplo las tarjetas de cuentas personalizables, la importación de Splitwise y Tricount, y los cambios de grupos). Lo más probable es que la app haya cambiado y los tests no se hayan actualizado.

## Qué hay que lograr
1. Para cada test, encuentra con qué merge empezó a fallar y si es un test desactualizado o un bug real de la app.
2. Si el test está desactualizado: actualízalo para que pruebe lo mismo con la interfaz nueva (no lo borres ni lo marques como fallo esperado).
3. Si es un bug real y chico de la app: arréglalo y anótalo. Si es grande o pide decidir producto, abre un ticket en `tickets/backlog/` y deja el test como está, explicándolo en el cierre.
4. Corre esas tres clases en el simulador hasta que pasen, y deja un ticket de cierre en `tickets/done/2026-11-16-ui-tests-rojos-tandas.md` con la causa de cada uno.
5. Una línea en el cierre sobre cómo evitar que se repita (por ejemplo, qué encargo debió correr esas clases en su gate).

## Suma de Jürgen (16-nov, 21:09 Lima)
«Que la sesión de corrección de los problemas de CI no haga auto merge, mergee todo y se asegure que 2.3 esté perfecta después de esa sesión y luego, con todo mergeado, suba a TestFlight. Incluye actualizar el artifact de lo nuevo.»

6. **Sin auto-merge.** No dejes el PR con auto-merge de GitHub: espera a que su CI termine en verde y mergéalo tú.
7. **Mergear todo.** Revisa todos los PR abiertos contra `2.3`. Mergea, uno por uno y con su CI en verde, los que estén terminados. No mergees los que pertenezcan a una sesión viva, los que esperen una decisión de Jürgen ni los que sean borrador; pon cada uno en el cierre con el motivo.
8. **2.3 perfecta.** Con todo mergeado, `origin/2.3` tiene que quedar con todo el CI en verde, incluidas las nueve tandas de UI sin fallos (no vale que pasen solo al reintentar). Si aparece otro rojo, arréglalo en esta misma sesión. No marques pruebas como fallo esperado para tapar un rojo.
9. **TestFlight 2.3 (3).** Recién entonces: sube CURRENT_PROJECT_VERSION a 3 en todos los targets (MARKETING_VERSION sigue en 2.3) en un PR chico mergeado a 2.3. Compara, en solo lectura, lo que la build usa de CloudKit (`iCloud.com.jurgenschmidt.yala`) y de Supabase Production con lo desplegado en Production; si falta algo, es vital: pregúntalo con la lista exacta y no lo despliegues. Archiva, sube a App Store Connect, espera a que quede procesada y asígnala al grupo interno con notas cortas en español neutro latinoamericano. Instala desde TestFlight en el iPhone 14 por DeviceMCP y haz la prueba de humo: abrir, registrar un gasto, nube, Grupos y el login.
10. **Artifact de lo nuevo.** Actualiza el artifact de lo nuevo de 2.3 (el que lista qué cambió para probar; búscalo en `docs/qa/testflight-2-3-2/` y en la memoria) con todo lo que entró desde la build 2: qué probar y dónde. Fuente en `docs/qa/testflight-2-3-3/`.

## Recursos
- Puedes usar el iPhone 14 conectado por DeviceMCP. Si corres en la Max y otra sesión ocupa un simulador, puedes usar un segundo simulador (tope 2 en la Max; 1 en la Mini).
- Commits y PR sin firma de IA.

## Cierre
- El modo queda fijo al arrancar (nocturno 20:00–05:30, semiautónomo 05:30–20:00, hora Lima). Lo menor y reversible lo decides y lo anotas. En semi, lo vital se pregunta y esperas con la sesión viva; en nocturno, lo vital deja checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni declarar completo lo incompleto.
- Si el trabajo está completo y el modo lo permite, `/cerrar-total`. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el resultado como artifact visual de Claude.

## Paso 0 — decisiones (resueltas en autónomo, nocturno)

- **Base:** `origin/2.3` al día (`dcd5f4cc0`) al arrancar.
- **Los tres rojos son pruebas desactualizadas**, no bugs: se arreglan las pruebas sin cambiar lo que prueban (calculadora: cerrar el teclado antes de «Mi parte»; dólares: reabrir con `openSelectorFirstRow`; conversión: volver arriba y desplazar en las dos direcciones). Sin cambios de app.
- **Auto-merge:** se quita a los cinco PR abiertos contra 2.3 (decisión de Jürgen del 16-nov, 21:09) y se mergean a mano, uno por uno, con su CI verde.
- **PR con conflictos** (guiados de Grupos —que trae dentro el de cuenta/categoría/favorito—, filtros rápidos de Registros, captura de Grupos): esta sesión mergea `2.3` en sus ramas. Textos: unión de los dos lados con chequeo de claves duplicadas. Índice de cobertura: fusión por área. `SummaryHeaderStack`: gana el hero claro de 2.3; el ajuste de aire del rótulo de la rama de filtros queda sin uso y se retira.
- **Gate de esas integraciones:** build de los dos esquemas + las suites tocadas por la resolución + chequeos del CI; el CI del PR corre `YalaTests` entero antes de mergear.
- **Borrador «Conectar Gmail» (PR 613):** no se toca (borrador y «NO MERGEAR»).
- **TestFlight:** servidor medido en solo lectura antes de subir (g31_01 ya en Producción, huella `122f05d7…`).
