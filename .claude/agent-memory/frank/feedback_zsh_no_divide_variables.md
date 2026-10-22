---
name: zsh-no-divide-variables
description: En zsh una variable escalar NO se divide en palabras, así que `xcodebuild $args` manda todos los filtros como UN argumento — y sale «TEST SUCCEEDED» con cero tests. Misma familia, 2026-09-15: un `;` dentro de una cadena de `&&` publicó un commit a medias con su PR.
metadata:
  type: feedback
---

**El shell de estas sesiones es zsh, y ahí `$args` NO hace word splitting.** Una variable que contiene
varios argumentos separados por espacios llega al comando como **un solo argumento**.

**Why:** el 2026-09-06, montando tandas de XCUITest, construí los filtros en una variable y llamé
`xcodebuild test … $args`. La invocación real fue:

    "-only-testing:YalaUITests/A -only-testing:YalaUITests/B -only-testing:YalaUITests/C "

un filtro único con espacios dentro, que no casa con ninguna suite. Resultado: **`** TEST SUCCEEDED **`
con `Executed 0 tests`**, cuatro veces seguidas, y un resumen que decía `exit=0 fallos=0`. Es
exactamente el «cero casos con exit 0» que `.claude/rules/testing.md` manda cazar, y estuve a un paso
de sellar el gate con él. Lo delató contar los casos, no leer el veredicto.

Y la trampa de dentro de la trampa: **`$(cat fichero)` SÍ se divide** en zsh, así que el mismo patrón
funciona por un camino y falla por el otro. Las tandas grandes de ese día usaban `$(cat tanda.args)` y
corrieron 70 casos; la que usaba `$args` corrió cero. Idénticas a la vista.

**How to apply:**

- Para pasar N argumentos construidos al vuelo: escríbelos a un fichero y usa `$(cat f.args)`, o en
  zsh fuerza el split con `${=args}`, o usa un array (`args=(...)` + `"${args[@]}"`).
- **Y la comprobación que vale por todas: cuenta los casos ejecutados, no leas el veredicto.**
  `grep -c '^Test Case .* \(passed\|failed\)'` para XCUITest (XCTest) y la línea `Test run with N tests
  in M suites` para Swift Testing. Un número que no cuadra con lo que pediste es el fallo, aunque
  ponga SUCCEEDED.

**Segundo disfraz del veredicto, medido el 2026-09-08: el exit code que reporta el wrapper de
background es el del comando COMPUESTO, no el de `xcodebuild`.** Lancé el control positivo por mutación
como `xcodebuild test … > log 2>&1; echo "EXIT=$?"` en segundo plano, y la notificación dijo
**«completed (exit code 0)»**. El `0` era del `echo`, que siempre sale bien. En el log, `xcodebuild`
había escrito `** TEST FAILED **` — que era justo lo que yo quería ver, porque estaba probando que los
tests cazan el bug. Si el mutante hubiera sido el árbol bueno, ese `0` me habría hecho dar por verde una
corrida roja.

⇒ **Nunca cierres un `xcodebuild` en background con otro comando detrás**, y en cualquier caso el
veredicto se lee del log (`** TEST (SUCCEEDED|FAILED) **` + el conteo), nunca de la línea de estado que
devuelve el wrapper.

Relacionado: [[mis-mediciones-fallan-por-el-filtro]] — misma familia: el «cero» no era del código, era
del filtro. Y [[gate-paso3-no-detecta-cero-casos]], que es este mismo hueco en el propio gate.

## El mismo error por el pipe: `| tee | grep` devuelve el exit del GREP (2026-09-10)

Corrí la suite unit completa así:

    xcodebuild test … 2>&1 | tee "$LOG" | grep -E 'TEST SUCCEEDED|✘'

y el harness reportó **exit 0**. La suite había **FALLADO**: `Test run with 6669 tests … failed after
93.7 s with 2 issues`, y en el log había 7 líneas con `✘`. El `0` era del `grep`, que encontró líneas.

Lo cazó el hábito de contar: leí `Test run with` del log en vez de fiarme del exit, y ahí estaba el
`failed`. **Los dos rojos eran míos** —un lector de `UserDefaults` con una key cuyo nº de sitios está
clavado en 26— así que fiarse del exit habría metido el defecto en el PR.

**How to apply:** redirige a fichero y lee el exit de xcodebuild directamente
(`xcodebuild … > "$LOG" 2>&1; echo "EXIT=$?"`), y después grepea el fichero. Con pipe, `$?` es del
último comando de la tubería. Es la misma familia que el word-splitting de arriba: el veredicto se lee
de `Test run with` y del exit **de xcodebuild**, nunca del de un envoltorio.


## Y sigue mordiendo en el gate: 40 filtros en una variable = `Unknown build action` (2026-09-14)

Construí las 40 suites del paso 2 del gate en `SUITES="$SUITES -only-testing:…"` y llamé
`xcodebuild test $SUITES`. zsh la pasó como **un solo argumento** y xcodebuild contestó
`error: Unknown build action ' -only-testing:… -only-testing:…'`. Aquí salió **rojo y ruidoso**
—no el «SUCCEEDED con cero tests» de la primera vez— porque el argumento empieza por espacio y no
casa con ninguna acción; pero es el mismo fallo y la misma cura.

**El molde que uso ya sin pensar:** escribir un script con `ARGS=()` + `ARGS+=("-only-testing:…")` +
`exec … "${ARGS[@]}"`, correrlo con `bash`, y que imprima **cuántas suites pidió** antes de lanzar.
Esa línea es la que se compara con el `Test run with N tests in M suites` del final: 40 pedidas, 40
corridas, 301 casos.

## Un `;` dentro de una cadena de `&&` publica aunque falle el paso anterior (2026-09-15)

Encadené sellar → `git add` → `git status | grep -v …` → commit → push → `gh pr create`. Puse un `;` tras
el `grep`, porque un `grep -v` sin líneas sale 1 y cortaba la cadena. **El `git add` falló**: le pasé la
ruta VIEJA de un ticket movido con `git mv` («pathspec did not match»). El `;` dejó pasar al commit, que se
llevó solo lo que ya estaba en el índice —el renombrado, 1 fichero de 11—, y detrás salieron el push y el
PR con ese contenido. El mensaje del commit describía el arreglo entero.

Se deshizo sin tocar el disco probado: `git reset --soft HEAD~1` devolvió HEAD a la base y el sello del
gate volvió a coincidir (la huella es HEAD + disco); un solo commit completo y `--force-with-lease` sobre
la rama propia, con el PR recién nacido.

**How to apply:**

- En una cadena que termina en commit, push o PR, **ningún `;`**. Lo informativo va dentro de
  `{ …; true; }`, que no puede cortar ni dejar pasar nada.
- **Guarda antes del commit:** `test -z "$(git status --porcelain | grep -v '^[MARD]  ')"`. Si queda algo
  sin stage o sin trackear, la cadena para ahí.
- Tras un `git mv`, el pathspec es la ruta **nueva**; la vieja ya no existe en disco y `git add -A` falla.


## Cuarta vez, en un bucle de mutantes (2026-09-16)

`for batch in "m1 m7" "m3"; do python3 mutate.py $batch; …` — los lotes de DOS mutantes llegaron como un argumento y no se
aplicaron. Lo delató el `|| echo "FALLO al aplicar $batch"` que había puesto detrás; sin él, el test habría corrido sobre
el árbol bueno y el «rojo esperado» habría salido verde, que se lee como mutante superviviente. Con `${=batch}` corrieron.
⇒ **todo paso que prepara una medición lleva su marcador de fallo**, no solo la medición.

## Quinta vez, y esta pintó de VERDE una tanda entera de mutantes (2026-09-17)

`SUITES="-only-testing:A -only-testing:B …"` y `xcodebuild … $SUITES test`. Los cuatro filtros llegaron
como un argumento, xcodebuild no casó ninguna suite y salió **`** TEST SUCCEEDED **` sin una sola línea
`Test run with`**. La tanda de **diez mutantes** se leyó así:

    M1 exit=0 cazadores:   ← «sobrevivió»
    M2 exit=0 cazadores:   ← «sobrevivió»
    …diez veces

**Y esa es la dirección de fallo peligrosa.** Las cuatro veces anteriores el síntoma fue un rojo ruidoso o
un «cero casos» que se caza contando. Aquí el resultado tenía la forma exacta de un hallazgo real —«mis
tests no cazan nada»— y lo que invita a hacer es *escribir más tests* o *aflojar el código*, no sospechar
del shell. Lo delató que **los diez** salieran igual: un mutante que sobrevive es plausible; diez de diez,
no.

**How to apply, y es lo único que hace falta recordar:**

- **Control positivo ANTES de cada tanda, en la misma invocación**: correr el árbol bueno y exigir la línea
  `Test run with N tests in M suites passed` con el N que esperas. Si esa línea no está, la tanda no ha
  medido nada — da igual lo que digan los exit codes.
- Y el corolario de lectura: en un bucle de mutantes, **un veredicto con cero cazadores y cero conteo no es
  «sobrevivió», es «no se midió»**. Sobrevivir exige que la corrida haya ejecutado casos.
