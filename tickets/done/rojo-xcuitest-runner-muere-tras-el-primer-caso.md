---
id: rojo-xcuitest-runner-muere-tras-el-primer-caso
status: done
priority: high
area: testing
created: 2026-09-06
updated: 2026-09-07
source: /gate de la sesión fx-presentation-still-shows-1to1 (2026-09-06)
---

# El runner de XCUITest muere tras el primer caso de cada suite

## Qué lo distingue de los rojos ya catalogados

`uitest-compara-fechas-sin-fijar-locale` cataloga **tests que fallan por su aserción** (locale, y
dos vecinos preexistentes). Esto es otra cosa: **el runner se cae**. Cada suite ejecuta su primer
caso, lo pasa, y el proceso muere — «Restarting after unexpected exit, crash, or test timeout»—; la
siguiente ejecución reporta `Executed 0 tests` y la corrida acaba en `TEST FAILED` listando casos
que **nunca imprimieron una línea `Test Case … failed`**.

Corrida de 5 suites (2026-09-06): **5 pasados, exactamente uno por suite**; 0 con línea de fallo; 5
en «Failing tests».

Importa la diferencia porque **el modo de fallo tapa a los otros**: con el runner cayéndose, un rojo
de aserción real en el segundo caso de cualquier suite es indistinguible de este ruido. Por eso es
`high` y no otro «rojo conocido» más.

## Medido, no supuesto

- **No es de la sesión que lo encontró.** Worktree limpio desde `HEAD` (`6d87123e`) con
  `Secrets.xcconfig` copiado: `PanelDashboardUITests` falla **idéntico** — mismos dos casos, mismos
  dos reinicios del runner.
- **Y en la dirección contraria, que es la que cierra la pregunta:**
  `QuickActionsFavoritesUITests.test_opensSaveAsFavoriteSheetFromForm` **PASA en el árbol con
  cambios y FALLA en el árbol limpio.** Un rojo introducido por un cambio no se comporta así.
- **El conjunto de nombres varía entre corridas.** `test_hidingSectionRemovesItFromPanelAndPersists`
  pasó en la corrida de 5 suites y falló en la corrida aislada de su propia suite. Lo que cambia no
  es el test: es cuál de sus casos llegó a ser el primero.

## La sospecha, corregida por lo que ya estaba medido

La primera hipótesis fue el disco (la máquina estuvo entre 8,7 y 15 GB, umbral 25). Se liberaron
6,3 GB —incluidos **5,7 GB en
`CoreSimulator/…/Caches/com.apple.containermanagerd/Dead`**, contenedores de apps desinstaladas que
el informe de disco esconde dentro del total de «Simuladores»— y **el síntoma siguió igual a 14 GB**.

`docs/ESTADO.md` del 6-sep ya apuntaba a la causa mejor: **«el sistema mató `xcodebuild` tres veces
por falta de memoria»**. Esa misma noche, y en esta máquina, el sistema mató además **dos procesos
de espera** de la sesión por presión de memoria (35 % libre). ⇒ **la memoria es la hipótesis
principal, no el disco**; encaja con que el proceso muera sin dejar error de test y con que el caso
afectado dependa del orden.

## Qué hacer

1. Reproducir con memoria holgada (sin builds ni simuladores compitiendo) **y** disco > 25 GB.
   Separar las dos variables, que hasta ahora se movieron juntas.
2. Si persiste, el motivo del `unexpected exit` no está en el stdout: mirar el `.xcresult`
   (`DerivedData/…/Logs/Test/`) y `~/Library/Logs/DiagnosticReports`.
3. Mientras dure, **el paso 3 del `/gate` no da veredicto** para XCUITest. Decirlo en el PR es
   obligatorio: un «XCUITest en rojo» sin esta nota se lee como un fallo del cambio.

## Aviso al siguiente

No archives los nombres que aparezcan en «Failing tests»: **el conjunto depende del orden de
ejecución**, no de qué esté roto. Una lista de nombres aquí envejece en una semana. Los que sí son
rojos de aserción, con su causa medida, están en `uitest-compara-fechas-sin-fijar-locale`.

## No confundir con

- `uitest-compara-fechas-sin-fijar-locale` — rojos de ASERCIÓN preexistentes, causas ya medidas.
- `unit-suite-nondeterministic-reds` — la suite unit, otro target y otro síntoma.


---

## RESUELTO (2026-09-07, noche) — no era el disco ni la memoria: eran dos corridas a la vez

**La causa, reproducida a voluntad 2 de 2 veces.** Dos `xcodebuild test` de XCUITest sobre el
**mismo simulador** se derriban entre sí. Comparten bundle id (`com.jurgenschmidt.yala.dev`), así
que cuando la segunda instala y lanza su runner, **mata el de la primera a media ejecución**. En el
log se ve el relevo: un PID nuevo de `YalaUITests-Runner` diciendo «Running tests…» exactamente
donde el anterior se corta a mitad de un `Synthesize event`.

Lanzadas con 25 s de diferencia, las dos veces dio lo mismo:

| Corrida | Reinicios | Pasados | **Con línea de fallo** | Veredicto |
|---|---|---|---|---|
| A (5 suites) | 4 | 7 | **0** | exit 65 · `Failing tests` con 4 casos |
| B (2 suites) | 3 | 1 | **0** | exit 65 · `Failing tests` con 3 casos |

Es la firma exacta que describe este ticket: el runner cae, `Executed 0 tests`, y «Failing tests»
lista casos que **nunca imprimieron una línea de fallo**.

### Las dos hipótesis del ticket, medidas y descartadas

**La memoria — que este ticket declaraba «la hipótesis principal, no el disco» — no lo explica.**
Durante *todas* las corridas de esta sesión el swap estuvo lleno (6,0-6,1 GB de 6,1) y la máquina
tiene 16 GB de RAM con 14 sesiones de Claude vivas. Aun así el reproductor pasó **12 corridas /
124 casos sin un solo fallo**. Además: **no hay ni un `JetsamEvent` el 6-sep**, el día del ticket, y
en los 8 que existen desde el 1-sep **ni `xcodebuild`, ni el runner, ni la app aparecen nunca con
`reason`** — solo daemons del simulador y `idle-exit` del sistema. Nadie mató al runner por memoria.

**El disco tampoco.** Bajado a **12 GB** a propósito con un fichero de relleno (y devuelto después),
tres corridas seguidas: **11/11 verde cada una, 0 reinicios**. Eso cierra además la pregunta que
`transaction-save-helper-flake-one-per-suite` dejaba abierta —«ninguna de las 21 muestras se tomó
por encima de 25 GB»—: se tomaron a los dos lados del umbral y el umbral no cambia nada aquí.

**Ni el disco ni la memoria distinguían las dos condiciones. La concurrencia sí**, y en las dos
direcciones: la corrida solitaria lanzada *inmediatamente después* de las concurrentes volvió a
**11/11 verde y exit 0** ⇒ el simulador no queda dañado, no es desgaste acumulado.

### Por qué pasaba tanto y por qué hoy no

En esta máquina hay **un solo simulador booteado** y conviven **10 worktrees** (13 `DerivedData` de
Yala). Todos corren el paso 3 del gate con el mismo `-destination name=iPhone 17 Pro`. Dos sesiones
que lleguen al gate a la vez colisionan por construcción. El 6-sep había ~23 sesiones vivas; hoy 14,
y la mayoría dormidas. **Que aquellas corridas del 6-sep tuvieran de hecho una vecina concurrente es
inferencia**, no medición — nadie lo registró entonces; lo medido es que el mecanismo produce esa
firma exacta y que ninguna de las otras dos hipótesis la produce.

Esto explica de paso lo que ningún ticket cuadraba: **por qué falla en TANDA y pasa AISLADO**. Una
tanda son ~3 min de ventana para que otra sesión entre; un test suelto, 30 s.

### El fix

1. **`qa/scripts/sim-libre.sh`** (nuevo) — dice en un segundo si hay otra corrida de test en curso.
   Verificado con control negativo *y positivo*: detecta el `xcodebuild test` y el runner vivo, y
   vuelve a verde al terminar.
2. **`/gate` paso 3** llama a la guardia antes de correr nada.
3. **`.claude/rules/testing.md`** — la regla, con el criterio de clasificación de abajo.

### El criterio que ahorra el diagnóstico entero

**La presencia o ausencia de la línea de fallo clasifica el rojo, y es un `grep -c`:**

- `Failing tests:` **sin** ninguna línea `Test Case … failed` ⇒ **murió el runner**. No hay veredicto
  y el test no es sospechoso.
- **Con** su línea de fallo y su mensaje de aserto ⇒ eso sí es un rojo de test.

Llevaba semanas mezclando dos familias en cuatro tickets distintos.

## Criterio de hecho

- [x] Reproducido con memoria holgada y disco > 25 GB, separando las dos variables (se midió también
      a 12 GB forzados).
- [x] Causa identificada y reproducida 2/2, con control en la dirección contraria.
- [x] Guardia que lo previene, con control positivo.
- [x] El paso 3 del `/gate` **vuelve a dar veredicto** — la advertencia de este ticket queda sin
      efecto mientras se corra con el simulador libre.
