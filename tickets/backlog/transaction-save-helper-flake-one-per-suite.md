---
id: transaction-save-helper-flake-one-per-suite
status: backlog
priority: medium
area: qa
created: 2026-09-07
updated: 2026-09-14
---

# Un rojo por corrida completa en el helper que guarda transacciones, y la víctima cambia

## El síntoma

Toda corrida de la suite XCUITest completa termina con **exactamente un fallo**, siempre el mismo
aserto y siempre el mismo mensaje:

```
YalaUITests/Support/XCUIApplication+Yala.swift:208: XCTAssertTrue failed -
No apareció la pantalla de éxito de la transacción (transaction_success_accept) — el guardado no completó.
```

**Lo que cambia es a quién le toca.** Tres corridas completas del mismo árbol, el mismo día:

| Corrida | Víctima | Resultado del otro candidato |
|---|---|---|
| 1ª (134 tests) | `QuickActionsFavoritesUITests.test_saveAsFavoriteFromTransactionAppearsInList` | — |
| 2ª (134 tests) | la misma | — |
| 3ª (134 tests, simulador recién borrado) | **`EdgeCasesUITests.test_extremeMinimumAmountSaves`** | `QuickActionsFavorites` **pasó** (46,5 s) |

Un rojo que se muda de test entre corridas del mismo commit no es un defecto de producto: el defecto
está en el **helper compartido** que todos ellos usan para guardar, o en el entorno que lo sostiene.

## Lo medido (2026-09-07) — 17 muestras

Además de las tres corridas completas, un reproductor de 3 min (las cuatro suites que preceden a
`QuickActionsFavorites` en el orden alfabético, más la suya) da ~50 % de fallo, con el disco entre
7,7 y 9,6 GB libres y con el simulador recién borrado o no.

**Tres cosas que descartan las explicaciones fáciles:**

1. **No es el código.** Se bisecó contra el árbol base durante
   [[welcome-privacy-branch-has-no-secondary-door]], y la muestra que lo zanja es ésta: **falló con
   un único fichero modificado, `OnboardingStepPlan.swift`, cuyo cambio es un parámetro nuevo con
   default `false` que el call-site de esa versión ni siquiera pasa** ⇒ el `Set` de pasos resultante
   es idéntico y ningún camino de ejecución cambia. Un fallo sin causa posible en el código prueba
   ruido en el instrumento, no una regresión. (Y esa muestra es la que salva de perseguir el diff:
   la correlación aparente era 4/6 con cambios contra 0/2 sin ellos.)
2. **No es «el test es lento».** Las corridas que FALLAN tardan **menos** (45-46 s) que las que
   pasan (47-49 s): la espera interna se rinde a los 10 s y el caso termina antes. El reparto es
   binario —la pantalla de éxito aparece o no—, no marginal.
3. **No es el disco libre.** Falla con 9,0 GB y pasa con 9,6; pasa con 7,7 en series recién
   empezadas. Un `simctl erase` (que devolvió el disco de 7,1 a 12 GB) **no lo elimina**: la 3ª
   corrida completa, hecha desde un simulador recién borrado, volvió a dar su único rojo.

## Muestra 18 (2026-09-07, sesión `reentry-killswitch-closes-both-doors`): falla con CUATRO tests

Corriendo **solo los cuatro candidatos** con `-only-testing` (sin las suites que los preceden, en un
árbol distinto y con 13 GB libres): **un único rojo**, `EdgeCasesUITests.test_extremeMinimumAmountSaves`,
con el aserto y el mensaje idénticos. Los otros tres pasaron, incluida `QuickActionsFavorites`.

| Caso | Resultado | Duración |
|---|---|---|
| `EdgeCases.test_extremeMinimumAmountSaves` | **failed** | 60,4 s |
| `QuickActionsFavorites.test_saveAsFavorite…` | passed | 61,7 s |
| `TransactionsCrud.test_createTransaction` | passed | 70,4 s |
| `InboxConvertToGroup.…preservesDraftDate` | passed | 24,1 s |

**Lo que esta muestra añade, y es contra la hipótesis 3:** el ticket propone «acumulación en el
simulador a lo largo de la corrida» como candidato. Aquí la corrida tiene **cuatro casos**, no 134, y
el rojo aparece igual — y le toca al PRIMERO por orden alfabético, sin nada acumulado delante. La
acumulación queda muy debilitada; los candidatos 1 (race en el guardado) y 2 (presupuesto de la
espera) siguen en pie.

Confirma además el punto 2 del apartado anterior: el fallido es el más rápido de los tres que guardan
una transacción, o sea que la espera se rinde antes de que la pantalla aparezca, no después de un
proceso largo.

**Y el uso que se le dio:** clasificar los rojos del CI del PR #88. Bisecados contra el CI del commit
base (`8b2aa939`), los mismos tests fallaban allí ⇒ ninguno era del chip. Esta corrida local fue la
comprobación que lo cerró sin depender de la estadística del CI.

## Por dónde empezar

El aserto vive en `YalaUITests/Support/XCUIApplication+Yala.swift:208`, dentro del helper de guardado
que comparten todos los tests que crean una transacción. Ese es el sitio, y los candidatos son:

1. **Una race en el propio flujo de guardado** que el helper destapa 1 vez de cada ~130. Es la
   hipótesis que más explicaría, y la única que sería un defecto de PRODUCTO y no de QA. Merece
   mirarse antes que las otras dos: si el guardado de una transacción falla 1 de cada 130 veces en
   un simulador, en un teléfono real también pasará alguna vez, y ahí no hay aserto que lo cace.
2. **El presupuesto de la espera** (10 s) es corto para un simulador cargado. Subirlo taparía el
   síntoma — y si el candidato 1 es cierto, taparía la única señal que tenemos de él.
3. **Acumulación en el simulador** a lo largo de la corrida. Encaja con que la víctima varíe, pero
   no con que la 3ª corrida golpeara a un test TEMPRANO (la E) y perdonara al tardío (la Q).

## Por qué esto merece un ticket y no una línea en la Lista Negra

Porque su síntoma ya engañó una vez, en sentido contrario: el caso del `.alert` con label dinámico
(`.claude/rules/swiftui-ds.md`) fue **una rotura real** que se manifestó exactamente así, en
`QuickActionsFavoritesUITests`, tras un cambio en invitaciones de grupo que no tenía ninguna relación
aparente. ⇒ **Un rojo de este aserto no se puede dar por ruido sin medirlo**, y medirlo cuesta dos
horas de bisección si no se sabe por dónde. Este ticket existe para que la próxima sesión tenga el
reproductor de 3 minutos y la tabla, y para que tampoco lo descarte a la ligera.

## Criterio de hecho

- [ ] Diagnóstico de por qué `transaction_success_accept` no aparece — empezando por si es una race
      del producto y no del test.
- [ ] 3 corridas completas de `YalaUITests` en verde, sin haber subido ningún timeout.

## Relacionados

- [[welcome-privacy-branch-has-no-secondary-door]] — la sesión que lo midió (no lo causó)
- `.claude/rules/swiftui-ds.md` — el precedente donde este MISMO aserto cazó una rotura real
- `.claude/rules/testing.md` — «NO apagar el simulador entre corridas» y «la primera corrida tras
  bootear no cuenta», las dos reglas de entorno que rodean esto

## Cuarta medición (2026-09-07, tarde) — la que descarta el código sin bisecar

Salió otra vez en el gate de `panel-colapsa-la-seleccion-de-cuentas-a-la-primera`, víctima
`EdgeCasesUITests.test_extremeMinimumAmountSaves`. Dos datos que este ticket no tenía:

**1. No hace falta la suite completa: con CINCO suites ya sale.** Las del gate de aquel cambio —
`EdgeCases`, `PanelDashboard`, `ProConversionUpsells`, `StatisticsNavigation`,
`WelcomeFreshStartAlert`— 11 casos en total. Es un reproductor aún más corto que el de 3 min de
arriba.

**2. El árbol base falla IGUAL con el mismo comando.** Cuatro corridas, dos árboles:

| Árbol | Comando | Resultado |
|---|---|---|
| `encargo/…panel-colapsa…` | las 5 suites | **FALLA** — 11 tests, 1 fallo |
| **`HEAD` limpio (`ad39a13d`)** | **las 5 suites** | **FALLA — el mismo test, 11 tests, 1 fallo** |
| `encargo/…panel-colapsa…` | `EdgeCases` aislado, ×2 | PASA — 2 tests, 0 fallos |
| `HEAD` limpio | `EdgeCases` aislado | PASA — 2 tests, 0 fallos |

**Esas cuatro celdas cierran «¿es del cambio?» en cuatro corridas, sin bisecar.** La comparación que
sirve es el **mismo comando en los dos árboles**: correr aislado en el base y en tanda en la rama
diría «es tuyo» y sería falso. Vale la pena repetirlas antes de gastar muestras en cualquier rojo
futuro de este aserto.

**3. La condición se estrecha: es la TANDA, no la corrida completa ni el disco.** En aislado pasa
siempre, en tanda falla; disco entre 11 y 14 GB en estas cuatro, dentro del rango ya observado. Lo
que sigue sin descartarse es que el umbral de 25 GB importe: **ninguna de las 21 muestras se ha
tomado con el disco por encima de él**. Es la comprobación más barata que queda y no se ha hecho.


## Quinta medición (2026-09-07, noche) — la pregunta del disco ya tiene respuesta, y es «no»

Este ticket cerraba diciendo que **ninguna de las 21 muestras se había tomado con el disco por
encima de 25 GB** y que era «la comprobación más barata que queda». Hecha, y además a los dos lados
del umbral, con el reproductor de 5 suites de la cuarta medición:

| Condición | Corridas | Casos | Fallos | Reinicios |
|---|---|---|---|---|
| Disco **24-25 GB** | 9 | 99 | **0** | 0 |
| Disco **12 GB** (forzado con un fichero de relleno) | 3 | 33 | **0** | 0 |

**El umbral no cambia nada**, ni hacia arriba ni hacia abajo. Y la memoria tampoco: el swap estuvo
lleno (6,0-6,1 GB de 6,1 GB) en las doce. Nota para quien lea la afirmación original: era falsa
además por otro lado — `edgecases-extreme-minimum-flaky-under-load` ya documentaba un fallo **con
26 GB libres** el 5-sep, por encima del umbral. Dos tickets se contradecían sobre el mismo hecho.

**Lo que sí apareció es un segundo fenómeno, y hay que separarlo de éste antes de gastar muestras**
(medido en [[rojo-xcuitest-runner-muere-tras-el-primer-caso]]): dos corridas de XCUITest sobre el
mismo simulador se derriban entre sí y producen rojos **sin ninguna línea `Test Case … failed`**.
Con 10 worktrees vivos y un solo simulador, eso pasa cuando dos sesiones llegan al gate a la vez.

⇒ **Antes de anotar una muestra en este ticket, clasificá el rojo:** si el caso trae su línea de
fallo con el mensaje de `XCUIApplication+Yala.swift:208`, es de aquí. Si sólo aparece en el bloque
`Failing tests` y nunca imprimió una línea de fallo, **no es de aquí** y no cuenta como muestra.
Parte de las 21 pueden ser de la otra familia; no hay forma de saberlo a posteriori porque no se
registró el log completo.

Lo que este ticket sigue teniendo abierto es intacto: **por qué `transaction_success_accept` no
aparece en 10 s** cuando el rojo SÍ trae su línea de fallo. Los candidatos 1 (race del producto) y 2
(presupuesto de la espera) no se tocan. Corré el reproductor con `bash qa/scripts/sim-libre.sh` en
verde, o la muestra no vale.

## Muestra 19 (2026-09-11, sesión `session-exits-one-verb-per-session`): DETERMINISTA en una clase, y bisecado

La corrida completa por lotes (62 clases, 11 lotes) dio su rojo de siempre —mismo aserto, mismo
mensaje— y esta vez la víctima fue **`TransactionsCrudUITests.test_createTransaction`**. Lo nuevo:

| Corrida | Árbol | Resultado |
|---|---|---|
| En su lote (6 clases) | paso 9 | **failed** (39,7 s) |
| La clase SOLA | paso 9 | **failed** (39,6 s) |
| La clase SOLA | **`ba618216` (base, worktree limpio)** | **failed** (40,1 s) |

**Dos cosas que esta muestra añade:**

1. **Ya no siempre se muda.** Aquí repitió víctima en dos corridas seguidas y a solas: el fallo fue
   **determinista para esa clase ese día**. La hipótesis «un rojo por corrida, aleatorio entre los
   cuatro candidatos» no cubre esto; lo que sí sigue en pie es que el reparto es binario y rápido
   (39-40 s frente a los ~70 s de un paso).
2. **Bisecado contra el árbol base, y allí falla igual.** Es la prueba que cierra la clasificación
   sin depender de la estadística: el worktree de `ba618216` no tiene ni una línea del paso 9 y el
   caso cae con el mismo aserto y una duración indistinguible (±0,5 s). ⇒ el rojo no pertenece a
   ningún cambio de esa rama.

**Y cómo usarla:** si este rojo aparece en un gate, la comprobación barata ya no es «re-córrelo a
ver si se muda» —puede no mudarse—. Es **correr esa clase sola en un worktree desde el commit
base**: dos corridas y 90 s zanjan de quién es.

## Muestra del 2026-09-14 — el MISMO lote, dos corridas, resultados opuestos

Apareció en el gate de `wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`, con el aserto
de siempre (`transaction_success_accept` — «el guardado no completó», `XCUIApplication+Yala.swift:220`).

Lo que aporta esta muestra, y por qué contradice el punto 1 de arriba:

| Corrida | Lote (idéntico, mismo orden) | Centinela | Resultado |
|---|---|---|---|
| 1.ª | GroupsSmoke · GroupsEmptyState · GroupPendingMemberDoor · GroupExpenseSuccess · TransactionsCrud | `0` (solo, 63 muestreos) | 18 tests, **1 fallo** (`test_createTransaction`, 36,1 s) |
| aislada | solo `TransactionsCrudUITests` | `0` (solo, 17 muestreos) | 2 tests, **0 fallos** (52,7 s) |
| 2.ª | el MISMO lote, mismo orden, mismo árbol | `0` (solo, 58 muestreos) | 18 tests, **0 fallos** |

O sea: **no fue determinista para la clase ese día**. Con el lote entero repetido sin cambiar una
línea, el rojo no volvió — así que la receta del final («correr la clase sola en un worktree base»)
no era necesaria aquí: bastó repetir el LOTE. Las dos observaciones conviven si lo que decide es el
estado del simulador acumulado dentro de la tanda, no la clase ni la rama.

Dato de duración coherente con el patrón binario ya descrito: el fallo tardó **36,1 s** y el paso
aislado **52,7 s**.

**Recomendación práctica para un gate:** ante este aserto, repetir el lote completo antes de montar
el worktree base. Si el rojo se va, es esto; si se queda, ya toca bisecar.
