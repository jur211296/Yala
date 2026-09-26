---
name: mis-mediciones-fallan-por-el-filtro
description: Mis errores de medición se repiten con la misma forma — el filtro descarta justo lo que busco y la ausencia se lee como resultado. Veinte casos entre el 2026-09-02 y el 2026-09-09 — el del 9 es una REINCIDENCIA con el mismo fichero y la misma regex de una que ya estaba escrita aquí, incluidas las variantes inversas: el filtro INVENTA un defecto, el filtro FABRICA el no-determinismo que se investigaba, y el INSTRUMENTO entero que acabo de escribir da un cero idéntico al cero bueno si nadie lo calibra.
metadata:
  type: feedback
---

**Antes de creerme una medición mía, compruebo que el instrumento sabe producir el resultado
contrario.** Es la regla; lo que sigue es por qué me hace falta tenerla escrita.

**El caso más barato de todos, y por eso el que más se repite: el conjunto de caracteres de mi
regex** (2026-09-08, dos veces en la MISMA sesión). Comparando el índice de tickets contra el disco,
`[a-z0-9\-]+` no aceptaba mayúsculas y se comió la fila `rojo-heroBuckets-thisWeek-trailing-window`:
declaré el índice desincronizado y estuve a punto de «arreglar» un índice correcto. Media hora
después, comprobando el orden alfabético, otra regex laxa coló la fila de cabecera y me dijo que yo
había roto el orden. **Las dos veces el fallo estaba en mi instrumento y las dos veces la conclusión
era la contraria a la realidad.** ⇒ cuando una medición mía diga que un documento del repo está mal,
el primer sospechoso es el filtro, no el documento: cuesta un `git show HEAD:<fichero>` comparar
contra el estado anterior y ver si el «defecto» ya estaba.

**Y el 2026-09-09 lo repetí con el MISMO fichero y la MISMA regex, teniendo esta nota escrita.**
Volví a contrastar el índice de tickets contra el disco con `[a-z0-9][a-z0-9-]*`, volvió a no ver
`rojo-heroBuckets-thisWeek-trailing-window` (lleva mayúsculas: `heroBuckets`, `thisWeek`), y esta
vez no me quedé en la conclusión falsa: **añadí la fila que ya existía y la dupliqué**. Dos lecciones
nuevas, porque el fallo llegó más lejos que la vez anterior:

1. **Tener la nota no basta si no la leo ANTES de escribir el filtro.** La leí después, al ir a
   actualizar la memoria, y por eso lo cacé. El id de ese ticket es el canario de este error: si
   aparece en un resultado mío, el filtro está mal.
2. **Mi verificación tenía el mismo punto ciego que la medición.** Re-verifiqué con
   `[a-zA-Z0-9]` —ya corregida— y dio «faltan: [], sobran: []», verde. No vio el duplicado porque
   metía las filas en un `dict`, y **un dict colapsa duplicados**: el error que acababa de cometer
   era invisible para el instrumento con el que lo comprobaba. ⇒ cuando lo que puede fallar es
   «hay de más», hay que **contar filas**, no claves; `set` y `dict` son el filtro que borra la
   evidencia.

**La variante del mismo día en `-only-testing`, que cierra el cerco de la nota de arriba:** el
filtro casa contra el nombre del **TIPO**, no del fichero. `-only-testing:YalaTests/DeadPointerSeedTests`
no corrió nada porque ese fichero declara `DeadPointerSeedBehaviorTests` y `DeadPointerSeedWiringTests`
— ningún tipo se llama como el fichero. Lo cacé porque el gate obliga a comparar «Test run with N
tests in **M suites**» contra las suites pedidas: dije 6 y salieron 5. Sin ese conteo habría
declarado verde una suite que nunca se ejecutó. Y ojo al leerlo: dos de las que «faltaban» sí
corrieron, con su `@Suite("nombre display")`, así que **el nombre que imprime el log no es el que
acepta el filtro**.

**Y una tercera del mismo día, en la matriz de mutación:** filtré los tests muertos con
`✘ Test [a-z_]+\(\) failed` y tres mutantes salieron «verdes». No lo estaban — los nombres son
camelCase (`seededAmounts_hitTheirTarget…`) y `[a-z_]+` no acepta mayúsculas. **Es el mismo error
del índice, en el mismo día, en otro instrumento.** Lo cazó el control positivo: tres mutantes
seguidos sin matar a nadie es un resultado sospechoso, y bastó preguntarle al log si los tests
habían corrido (`TEST FAILED` estaba ahí). ⇒ **un resultado que me conviene es el que más control
positivo necesita.**

**Why:** el 2026-09-02, en una sola sesión, tropecé **cuatro veces con la misma forma de error** —
un filtro que descarta lo que busco, y una ausencia que leo como dato:

1. `-only-testing` con el nombre de un **método** de Swift Testing no filtra: corre cero tests y
   devuelve `TEST SUCCEEDED`. Concluí que mi test no protegía y estuve a punto de reescribir uno
   que estaba bien. (A nivel de FICHERO sí funciona.)
2. `grep 'Co-Authored-By'` sin anclar dio positivo porque el mensaje **mencionaba** esa cadena en
   la prosa. Concluí que había puesto un trailer que no había puesto.
3. `grep -E "error:"` sobre la salida de `xcodebuild` casó con la etiqueta de parámetro Swift
   `classify(error:` y me sepultó la señal en ruido. Dos veces el mismo día.
4. Medí «45 pasos del CI en verde» filtrando por `conclusion=="success"` **a nivel de job** —o sea
   contando sólo los buenos— y además sobre un campo que `continue-on-error` pinta de verde aunque
   el comando salga con `exit 65`. La conclusión era exactamente la contraria a la realidad: el CI
   llevaba semanas verde con ocho tests en rojo.

Los cuatro comparten el patrón, y el número 4 es la lección: **un numerador sin denominador no es
una proporción**. La sesión de la mañana había cometido ese mismo error con `git log --grep` y yo
lo critiqué por escrito… antes de repetirlo dos veces.

**How to apply:**
- **Control positivo, siempre.** Antes de leer una ausencia (o un verde) como señal, corre el mismo
  instrumento sobre un caso donde la señal SÍ está y comprueba que aparece.
- **Exige el conteo.** `Test run with N tests in M suites` (Swift Testing) o `Executed N tests`
  (XCTest). Sin conteo, no has medido nada, diga lo que diga el veredicto.
- **Ancla los patrones** a la línea que buscas y nada más. Nada de `grep` de subcadenas sueltas
  sobre logs de código: el código contiene tus propias palabras clave.
- **Cuenta el total y los que cumplen por separado**, y desconfía de toda proporción que dé 100 %.
- **Un campo de estado no es el resultado.** `continue-on-error`, `advisory`, `|| true` y los
  reintentos desacoplan «lo que dice el campo» de «lo que pasó». Ve al log.

## Cuatro casos MÁS, la noche del mismo día — y ya no es mala suerte

Volvió a pasar cuatro veces en la sesión nocturna, con el mismo patrón y a pesar de tener esta
ficha escrita. Eso es el dato: **conocer la lista de trampas no me protege; sólo me protege exigir
el denominador.**

5. `grep -E "failed"` sobre un log de `xcodebuild` casó con `.failed(.expired)` del código de los
   tests y me sepultó el resultado. (La ficha ya lo decía: no hagas grep de subcadenas sueltas
   sobre logs que contienen código.)
6. **`-only-testing` con el nombre del FICHERO tampoco filtra** si las suites del fichero se llaman
   distinto: pedí 3 suites, arrancaron 2, salió `TEST SUCCEEDED`. La que no corrió era la única red
   del mutante que estaba verificando. Peor que el caso del método —el nº 1 de arriba— porque ahí
   el conteo era 0 y saltaba a la vista; aquí sí hay tests y sí hay conteo, y sólo delata el número
   de SUITES.
7. Conté «tickets» con `ls tickets/done` y me llevé tres PNG de capturas por delante ⇒ reporté un
   descuadre del índice que no existía.
8. `grep -oE '^\| [a-z0-9-]+ \|'` no casó con un id que llevaba mayúsculas
   (`rojo-heroBuckets-…`) ⇒ concluí que faltaba del índice cuando estaba.

**El añadido a la regla:** el control positivo no basta si el instrumento es un `grep` que yo mismo
escribo al vuelo. Antes de reportar una ausencia (falta X, sobra Y, no hay Z), **compara dos
totales que tengan que cuadrar** — filas del índice contra ficheros en disco, suites pedidas contra
suites arrancadas — y sólo entonces mira el detalle. Un total que cuadra refuta de golpe cualquier
lista de faltantes que haya fabricado un filtro roto.

**La novena, y es de otra familia: el filtro estaba bien y el UNIVERSO era el equivocado.** El
2026-09-03 escribí en el ESTADO y en un ticket que `g8_03` no estaba aplicado a producción, y de ahí
salió un aviso a Jürgen de que el device-QA de los dos teléfonos estaba bloqueado. Lo que había medido
de verdad es que **no consta en el repo**, que es otra afirmación: el estado de una base de datos no
vive en git. Jürgen preguntó «¿no está hecho?», bastó una consulta a `pg_proc` y las dos RPC estaban
ahí, con su grant a `yala_push` y con el `revoke` aplicado.

**Why:** buscar en el sitio equivocado y leer el vacío como respuesta es el mismo error que los ocho
de arriba, sin ningún grep roto de por medio — por eso conviene tenerlo aquí y no en otra ficha.
Y el coste iba en la dirección cara: le habría hecho posponer una sesión de dos teléfonos por nada.

**How to apply:** antes de reportar que algo del SERVIDOR no está hecho —una migración, un secret, un
deploy, un flag de rollout—, compruébalo **contra el servidor**. Hay MCP de Supabase conectado y una
consulta de solo lectura cuesta segundos; para Cloudflare, `wrangler`. Si de verdad no puedes medirlo,
la frase que se escribe es «no consta en el repo», nunca «no está hecho» — y se dice qué comando lo
resolvería.

Relacionado: [[trailer-de-commit-nunca-en-yala]] (el mismo error, cometido por otra sesión, es lo
que casi tumba una regla del owner).

**La décima, y es la inversa de todas las anteriores: culpar al ENTORNO sin leer el error.** El
2026-09-04, un `xcodebuild test-without-building` falló con `TEST EXECUTE FAILED` y sin una sola
línea de `Executed`. Encajaba a la perfección con el síntoma que el `CLAUDE.md` documenta —XCUITest
que no llegan a lanzar, disco lleno, once días de diagnóstico— y el disco venía bajando de verdad:
23,9 → 12 GiB en la sesión. Ya se lo había medio anunciado a Jürgen como causa cuando leí el error
COMPLETO en vez del que había pasado por mi propio `grep`:

```
Cannot launch simulated executable: no file found at .ddp/…/YalaUITests-Runner.app
```

Yo había borrado `.ddp` para liberar espacio, y el paso 1 del gate usa `xcodebuild build`, que
compila la app pero **no** los targets de test. Causa mía, de procedimiento, a un `build-for-testing`
de distancia. Mi `grep` filtraba por `Executed|RequestDenied|failed to launch` y el error no decía
ninguna de las tres.

**Y la coda, que es lo que casi me hace parar el trabajo:** informé a Jürgen de que el disco estaba
en 12 GiB y de que la autonomía se acababa ahí. Al ir a medir qué borrar, `df` daba **34 GiB**. APFS
había tardado en reclamar el espacio del `simctl erase` y del `.ddp` que yo mismo había borrado
minutos antes. Las lecturas eran ciertas y transitorias a la vez.

**Why:** «antes de culpar al código, mira el entorno» es la regla del repo, y de tanto tenerla a mano
la apliqué como conclusión en vez de como hipótesis. Una hipótesis del entorno es igual de
verificable que una del código, y cuesta lo mismo: leer el error entero.

**How to apply:**
- **Antes de culpar al entorno, lee el error sin filtrar.** `tail -30` del log crudo antes que
  cualquier `grep` propio. El fallo que buscas casi nunca usa las palabras que tú elegiste.
- **Un `TEST EXECUTE FAILED` sin conteo no es un test en rojo: es que no arrancó.** Son dos
  diagnósticos distintos y se parecen en el veredicto.
- **Una medida de disco recién liberado no es fiable de inmediato.** Tras `simctl erase` o borrar
  DerivedData, APFS tarda en reflejarlo: vuelve a medir antes de decidir nada, y desde luego antes
  de decirle a Jürgen que hay que parar.

## Noveno caso (2026-09-04): revisar un diff que sigue moviéndose

Lancé una review adversarial de 98 agentes sobre un cambio **sin commitear y que seguí editando
mientras corría**. Resultado: los hallazgos de la primera fase describían código que ya no existía, y
los refutadores de la segunda —que arrancaron una hora después— citaban **mi propio arreglo** para
refutarlos. Cinco «altas» sonaban a bugs vivos y estaban cerradas antes de que se escribieran.

No invalidó la review: el hallazgo de fondo era real y lo arreglé yo mismo por auto-revisión antes de
que llegara. Pero costó una lectura larga separar «esto sigue vivo» de «esto ya lo cerré», y el
riesgo de la confusión inversa —dar por cerrado algo que no lo estaba— era el mismo.

**How to apply:** una review sobre un diff se lanza contra un árbol **congelado**. O commiteas primero
(en rama, si hace falta), o paras de editar hasta que vuelva, o le pasas el `git stash`/hash exacto que
debe mirar. Y al leer sus resultados, lo primero es fechar cada hallazgo contra el árbol de AHORA, no
contra el de cuando se escribió — la misma regla de la casa de «cita la línea del árbol en el que
estás», aplicada al revés.

**Corolario que sí es nuevo:** los tres refutadores por hallazgo hicieron su trabajo *demasiado* bien
— 85 de 93 refutados. Cuando la tasa de refutación es tan alta, la señal no es «el código está
limpio»: es que el revisor de la primera fase estaba mirando otra cosa. La tasa de refutación es un
diagnóstico del montaje, no del código.

## Undécimo (2026-09-04): la key de l10n vive en DOS formas y mi grep sólo conocía una

Verificando un borrado, comprobé si el copy `welcome.invite.back` había sobrevivido con
`grep "welcome.invite.back" WelcomeBackButton.swift`. Cero resultados. **Llegué a escribir
«DESAPARECIÓ» y a dar la alarma.** El fichero ni siquiera estaba en el diff: la línea 29 sigue
diciendo `.accessibilityLabel(L10n.Welcome.Invite.back)` — el **accessor generado**, no el literal.

Es el mismo caso que este repo ya documenta al revés en `guest-journey-dead-screens`: allí un grep
de la key la dio por muerta sin ver que un `accessibilityLabel` la usaba. La forma exacta del error
tiene dos caras y las dos muerden:

- buscar el **literal** `"grupo.la.key"` no ve `L10n.Grupo.La.key`;
- buscar el **accessor** `L10n.Grupo.La.key` no ve `String(localized: "grupo.la.key")`, que es como
  la usa `GroupBackendInviteEntryHandler` para reutilizar copy de otra pantalla.

**How to apply:** para decidir si una key de l10n está viva o muerta hay que buscar **las dos
formas**, y además `accessibilityLabel`/`accessibilityIdentifier`. Y antes de reportar que algo
«desapareció» en un borrado, mira si el fichero está siquiera en `git diff --stat`: si no lo está,
el que falla es tu grep, no el borrado.

**El dato de la sesión, que es lo que hay que retener:** tres mediciones mías fallaron el mismo día
por la misma familia (el conteo de filas con mayúsculas, un `cut` que no resolvía dentro de un
subshell y ésta). Ninguna llegó a Jürgen como error porque las tres las cacé con control positivo.
**El control positivo no es ceremonia: es lo único que me separa de reportar tres falsedades.**

## Duodécimo (2026-09-05): «todos los checks en verde» cuando el check que importa NO EXISTE

Abrí el PR #64 y armé un monitor con el patrón canónico: *emite cuando ningún check siga en
`pending`, entonces para*. A los pocos minutos dijo **`CI TERMINADO: Vercel=pass, Vercel Preview
Comments=pass`**. Los dos verdes, cero pendientes, condición de parada cumplida. Y la suite de QA
—la que compila la app y corre 6000 tests— **no había arrancado siquiera**.

La causa estaba a una consulta: el PR nacía `mergeable=CONFLICTING / mergeStateStatus=DIRTY` porque
`2.1` había avanzado mientras yo trabajaba. **GitHub no dispara `pull_request` cuando no puede
construir el merge de prueba**, así que el workflow no existía como check — y «no existe» y «pasó»
se ven idénticos si sólo cuentas los que hay.

Es el error nº 4 otra vez (numerador sin denominador) con ropa nueva: conté los checks presentes en
vez de comprobar que estuviera el que importa.

**How to apply:**
- **Antes de esperar un CI, comprueba que existe.** `gh run list --branch <rama>` — si no hay un run
  para tu rama, no hay nada que esperar y el monitor te va a mentir.
- **Un monitor de checks necesita una lista ESPERADA, no sólo la observada.** La condición correcta
  es «los checks que espero están todos presentes y ninguno pendiente», no «los presentes no están
  pendientes».
- **`gh pr view --json mergeable,mergeStateStatus` es lo primero que se mira cuando el CI no
  arranca.** `DIRTY` explica el silencio entero y se arregla mergeando `2.1` en la rama.
- **En Yala, el conflicto al mergear `2.1` es lo esperable, no la excepción** (ADR-008): choca en
  `docs/ESTADO.md`, `docs/TICKETS.md` y `qa/coverage-index.json`, nunca en código. `TICKETS.md` se
  resuelve **regenerando la tabla desde el disco**, que es determinista; los otros dos, a mano
  conservando las dos aportaciones.

---

**El grep de una AUDITORÍA es un instrumento y también necesita control positivo — 2026-09-05, tres
veces en una sola sesión.** Los conteos de tests ya los verifico; los greps con los que *audito* el
código, no, y ahí el fallo es más silencioso porque «cero coincidencias» se lee como «está limpio»:

1. **`grep -E "try\?"` sobre el diff dio 5 falsos positivos**: «en**try?**» contiene `try?` como
   substring. Es la misma trampa del hook de secretos ([[hook-secretos-disparador-substring]]).
   Frontera de palabra: `[^A-Za-z]try[?]`.
2. **`grep -E "error:"` sobre un log de xcodebuild «encontró errores»** que eran el texto
   `classify(error: ...)` de un `#expect`. Me hizo dar por muerta una corrida de XCUITest que seguía
   viva, y por poco la doy por rota.
3. **`[a-z0-9-]+` no casó un id de ticket con mayúsculas** (`rojo-heroBuckets-…`), así que el
   validador del índice inventó un huérfano que no existía.

**How to apply:** cuando un barrido de auditoría dé **cero**, pásale una sonda con el defecto dentro
antes de escribir «limpio» — dos líneas y un `grep -c`. Si la sonda no da 1, lo que está roto es el
filtro, no el código. Y para los que sí dan resultados, mira **una** coincidencia entera antes de
creértela: los tres de arriba se veían venir leyendo la línea completa.

---

**Decimotercero (2026-09-05): el build INCREMENTAL da cero warnings porque no compiló nada.** Tras
tocar cuatro ficheros corrí `xcodebuild build | grep -c "warning:"` sobre la scheme Dev y salió **0**.
Iba a escribir «cero warnings nuevos» en el informe del gate. El build anterior ya había dejado todo
compilado, así que ese cero no decía nada del código: decía que no hubo compilación. El control
positivo lo delató al instante — *warnings totales de la corrida* también era 0, y un build real de
este repo siempre trae nueve.

**Why:** es la familia del universo vacío (el caso nº 9), no la del filtro roto. El grep estaba
perfecto; lo que no había era nada que filtrar. Y aquí duele especialmente porque el paso 1 del gate
existe justo para eso, así que un cero falso convierte el gate en un sello de goma.

**How to apply:** para medir warnings de tus ficheros, **fuerza la recompilación** (`touch` de los
ficheros tocados, o `-derivedDataPath` limpio) y **verifica que recompiló** antes de leer el número:
`grep -c "<TuFichero>.swift"` sobre la salida tiene que dar >0, y el total de warnings de la corrida
tiene que parecerse al baseline conocido. Un `BUILD SUCCEEDED` instantáneo es la señal de que estás a
punto de medir el vacío.

**Y la nota buena del mismo día: el conteo de suites me salvó otra vez.** Pedí 18 filtros
`-only-testing` y la línea dijo `139 tests in 16 suites`. Dos de mis filtros eran nombres de FICHERO
(`RelaunchNetLogicTests`, `SessionPreferenceKeysTests`) y ningún struct se llama así — el caso nº 6 de
esta ficha, repetido. La diferencia es que esta vez lo cacé en el sitio, porque comparar *pedidas
contra arrancadas* ya es reflejo. Los 8 structs reales (`RelaunchNetVerdictTests`,
`SessionPreferenceKeysNetTests`, …) dieron 32 tests más. **`.claude/rules/testing.md` L103 ya lo
documenta**: resuelve los nombres con `grep -n "@Suite" <fichero>`, nunca por el nombre del fichero.

---

## Decimocuarto (2026-09-05): incumplí L103 el mismo día que la cité, y lo cazó el CI

En el gate corrí `-only-testing:YalaTests/SignOutWipeHookTests`. Ese fichero declara **TRES**
suites (`SignOutWipeHookTests`, `GroupsOnlySignOutWipeHookTests`, `SignOutNotificationWiringTests`)
y solo corrió la primera. La tercera —la de source-scan del cableado— tenía un conteo que mi cambio
rompía, **determinista, 3 de 3 iteraciones en CI**. Declaré el gate en verde con un rojo dentro.

Lo doloroso: horas antes, en esta misma sesión, había **leído y citado** `.claude/rules/testing.md`
L103, que lo dice literalmente —«la segunda suite de un fichero suele ser justamente la de
source-scan del cableado, la que más te interesa cuando tocas producción»— y aun así resolví los
filtros por nombre de fichero. Y el conteo de suites tampoco me salvó: cuadró (12 pedidas, 12
arrancadas), porque **el error no fue pedir de más sino no saber qué había que pedir**.

**Why:** el conteo pedidas-vs-arrancadas detecta filtros que no expanden; **no** detecta suites que
nunca pediste. Son dos huecos distintos y yo solo tenía red para uno.

**How to apply:** al acotar el gate por suites, el universo no se arma a mano. Se deriva:

    # 1. qué ficheros de test mencionan cada fuente tocada
    grep -rl "<Fuente>.swift" YalaTests/
    # 2. TODAS las suites de esos ficheros, por tipo y no por fichero
    grep -h "^struct " <esos ficheros> | sed 's/struct \([A-Za-z0-9_]*\).*/\1/' | sort -u
    # 3. filtros en ARRAY, y al final: filtros pedidos == suites arrancadas

Aplicado después del rojo: 7 ficheros → **21 suites** (yo había corrido 12) → 168 tests, 21 de 21.

**Y el corolario sobre el CI, que es la otra mitad:** el paso que lo cazó estaba marcado
`continue-on-error: true` y su estado decía **`success`**. El rojo solo aparece bajando el log del
job (`gh api repos/<o>/<r>/actions/jobs/<id>/logs`) y leyendo `Test run with N tests in M suites
failed`. Es el caso nº 4 de esta ficha, vivo y coleando: **en este repo el estado de un paso del CI
no es su resultado, nunca**. Y para clasificar lo que salga, `-retry-tests-on-failure` reintenta la
corrida entera: contar **en cuántas de las N iteraciones falló cada test** separa lo determinista
(mío, 3/3) de lo flaky (los spikes R3, 2/3 y 1/3) sin tener que suponerlo.

## La otra mitad: cómo se contesta «¿este warning es MÍO?» sin inferirlo (2026-09-05)

El gate exige «cero warnings nuevos en los archivos tocados», y un build incremental **solo reporta
lo que recompiló** ⇒ un warning viejo aparece por primera vez el día que tu cambio obliga a
recompilar ese fichero. Ese día parece tuyo. Y si tu diff añade o quita líneas, ni siquiera el
número de línea casa con el del original.

**La forma barata de medirlo, en vez de razonarlo:** copiar a un scratchpad los `.swift` de
producción que tocaste, `git checkout HEAD --` sobre ellos, **mover fuera los ficheros nuevos**
(no existen en HEAD y romperían el build), compilar, y restaurar las copias. Tres minutos.

El 2026-09-05 así se demostró que el warning de `ContentView` era preexistente: HEAD lo tenía en la
línea 1551 y mi árbol lo enseñaba en la 1549 — desplazado exactamente por las dos líneas que quitaba
mi diff. Sin esa corrida habría escrito «es preexistente» como inferencia, que es justo lo que el
`CLAUDE.md` pide distinguir.

**Y el que sí era mío, en la misma corrida:** un `enum` nuevo sin `nonisolated` bajo
`SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` da *«main actor-isolated conformance … cannot be used in
nonisolated context; this is an error in the Swift 6 language mode»* en cuanto un `enum nonisolated`
lo compara. Todo tipo nuevo de la capa `Logic` nace `nonisolated`, como sus 130 hermanos.

**Es la cara complementaria del caso decimotercero de arriba:** allí el build incremental no compiló nada y el cero era falso; aquí sí compiló, y lo que engaña es lo contrario — un warning que llevaba meses ahí aparece por primera vez.


## Decimoquinto (2026-09-05): `gh pr merge --auto` no difiere nada en este repo

Acababa de escribir en el PR «espero a que termine el CI antes de mergear» y llamé a
`gh pr merge 68 --merge --auto` creyendo que dejaba el merge ARMADO. El PR salió `MERGED` en el acto.

**Why:** `--auto` solo espera si hay **checks requeridos** por branch protection. `jur211296/Yala` no
tiene ninguno ⇒ no hay nada que esperar y GitHub mergea. La salida del comando fue **vacía**, así que
tampoco avisó: lo delató `gh pr view --json state`.

**How to apply:** en este repo `--auto` == merge inmediato. Para esperar de verdad a un run hay que
sondear (`gh run watch <id>`) y mergear después. Y como siempre: **el estado se comprueba, no se
supone** — un comando que no imprime nada no ha confirmado nada.

## Decimosexto (2026-09-05): el MUTANTE del control positivo también hay que medirlo

Verificando un fix con control positivo, reintroduje el bug sustituyendo un `guard force else
{ return }` por un `return` a secas. El log salió `TEST FAILED`, exit 65 — el mutante «cazado». Falso:
Swift parseó `return` + la línea siguiente como `return (if ...)` y lo que falló fue **la
compilación**, no ningún aserto. Un mutante que no compila da exactamente el mismo veredicto que uno
detectado, y mi grep (`✘|TEST FAILED`) no distingue las dos cosas.

**Why:** es la familia del universo vacío otra vez, en el sitio donde más duele: el control positivo
es justo el instrumento que existe para no fiarme del verde, así que un control positivo mal medido
me deja creyendo que tengo red donde no la hay.

**How to apply:** un mutante solo vale si **compila** y falla **en el aserto**. Exige ver el nombre
del test en rojo (`✘ Test <nombre> ... recorded an issue`) y el mensaje del `#expect`, no el veredicto
del run. Si el log trae `error:` de compilación, el mutante está mal escrito: reescríbelo. El mutante
bueno del 2026-09-05 fue sustituir el bloque ENTERO por la forma vieja (`guard inFlight == nil else
{ return }`), no editar una línea por dentro.


## La variante cara: la afirmación la escribo yo (2026-09-05)

Los doce casos de arriba son filtros que fallan. Éste es el que va en dirección contraria: **el
dato falso lo produje yo escribiendo prosa**, y sólo lo cacé porque lo medí antes de commitear.

Metiendo `Secrets.xcconfig` en `.claude/worktree-enlaces` escribí, como justificación, «sin él el
primer build del worktree falla». Sonaba obvio: es `baseConfigurationReference` de las 4 build
configurations. Medido: el fichero tiene **cero claves activas** (viven en el Worker desde el
2026-06-15) y `xcodebuild -showBuildSettings` devuelve **636 líneas idénticas con y sin él**. Habría
commiteado una falsedad dentro del fichero de instrucciones que otros van a leer — la clase de
documento que en este repo envejece mal y luego dirige el trabajo de alguien.

**How to apply:** una frase con «falla», «rompe», «hace falta para» o una cifra es una afirmación
verificable **aunque la esté escribiendo yo, y aunque sea el motivo del cambio que me pidieron**.
Antes de commitear un comentario o una descripción de PR, mido las afirmaciones fuertes que
contiene; y si la medición las tumba, el cambio suele seguir valiendo la pena por otra razón —
aquí, evitar la copia manual y cubrir el día que vuelva a haber una clave, cuando un worktree sin
enlace compilaría en silencio sin ella. Escribir la razón verdadera es más útil que la razón
impactante. Relacionado: [[revertir-sin-commit-destruye]].

## Decimoséptimo (2026-09-06): el subagente midió la VARIABLE y yo la FUNCIÓN que la escribe

Delegué a un `Explore` la auditoría de `GroupDetailView`. Volvió con un informe excelente y una
conclusión falsa: *«Hoy no existe ninguna otra vía — el grep de `selectedGroup` sobre `Yala/` solo
devuelve `GroupsViewModel:87/544` y `GroupsContainerView:190/193`»*. Yo, en paralelo, había medido
`grep -rn "openDetail(for:"` y salían **tres** call-sites: la tarjeta, el deep link de una
notificación y un nudge. Los dos últimos sin ningún gate de estado.

La diferencia entera es qué se buscó: él, la **variable** de estado (`selectedGroup`); yo, la
**función pública que la escribe** (`openDetail`). Como la única asignación vive dentro de esa
función, buscar la variable devuelve un resultado correcto y una conclusión al revés.

De haberme quedado con su informe, habría cerrado la tarjeta y firmado el AC con dos puertas
abiertas — justo las que ningún device-QA prueba, porque hay que llegar por una notificación o por
un nudge.

**Why:** un encapsulamiento bien hecho **reduce** las coincidencias del grep de la variable a uno.
Cuanto mejor está escrito el código, más engaña esa búsqueda.

**How to apply:**
- Para «¿cuántas formas hay de llegar a X?», el universo es el **setter público** (`openDetail`,
  `present`, `route`), no el `@State`. Y si hay las dos, se buscan las dos.
- **Un hallazgo de subagente que afirma una AUSENCIA** («solo existe una vía», «no hay más usos»)
  se re-mide antes de construir encima; es el mismo caso nº 9 de esta ficha —universo equivocado—
  cometido por otro. Y las lentes que se contradicen no se eligen, se miden
  ([[lentes-adversariales-se-contradicen]]).
- Lo que sí me salvó: **control positivo explícito**. Volví a correr el grep pidiéndole que
  imprimiera además la línea de la tarjeta que ambos dábamos por buena. Si esa no salía, el roto
  era mi filtro.

---

**Caso 13 (2026-09-07), y es el que va al revés: el filtro me inventó un problema que no existía.**
Auditando `docs/TICKETS.md` contra el disco, mi regex de filas era
`^\| ([a-z0-9-]+) \| (backlog|qa|…)`. Reportó «128 filas, 129 ficheros, huérfano:
`rojo-heroBuckets-thisWeek-trailing-window`». Empecé a escribir el parche que le añadía la fila…
y el `assert fila not in t` saltó: **la fila ya estaba ahí**, en la línea 133. El id lleva
MAYÚSCULAS (`heroBuckets`) y `[a-z0-9-]+` no las acepta. El índice estaba sano; el roto era yo.

**Por qué importa más que los otros doce:** los anteriores me hacían ver una AUSENCIA falsa y
concluir «no hay nada». Este me hizo ver un DEFECTO falso y casi me lleva a "reparar" un documento
correcto — un cambio que habría duplicado una fila y que nadie habría cuestionado, porque venía con
una medición detrás.

**How to apply:** cuando una auditoría mía diga que un documento está roto, **antes de arreglarlo,
grep del identificador suelto** (`grep -n "<id>" fichero`). Si aparece y mi regex no lo veía, el
defecto es del filtro. Y en este repo, las clases de caracteres para ids llevan `[A-Za-z0-9._-]`:
hay ids en camelCase y con puntos. Lo que me salvó fue un `assert` de sanidad antes de escribir —
si hubiera hecho el `replace` a ciegas, el parche habría "funcionado" y roto el índice.

---

**Caso 14 (2026-09-07): diez XCUITest en rojo que eran de mi COMANDO, no del árbol.** Corrí la suite
entera con `-scheme Yala` y salieron 10 rojos —Grupos, Cuentas, Onboarding, SecondarySession—,
ninguno del área que había tocado. Iba a bisecarlos contra un worktree desde HEAD (que ya tenía
montado y compilando). Antes, medí los dos schemes:

    Yala        SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
    Yala Dev    SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG DEV_BUILD

`.claude/rules/testing.md` lo dice en su primera línea de XCUITest —«Scheme **Yala Dev**»— y explica
por qué: los flags de Grupos nacen ON en XCUITest **porque** `DEV_BUILD` hace que el default-ausente
de remote-config sea `true`. Sin ese flag, esas pantallas pintan otra cosa y los tests fallan **por
diseño**. El árbol estaba sano; el roto era el scheme que elegí.

**Why:** es la familia del universo equivocado (casos 9 y 17), pero con una diferencia que la hace
peor: aquí el instrumento **sí ejecutó** los tests y **sí dio conteo** —10 failed, 112 passed—, así
que todas mis redes habituales (conteo, denominador, control positivo del grep) daban verde. Lo único
que lo delataba era la CONFIGURACIÓN del arnés.

**How to apply:**
- **El scheme es parte del universo, no un detalle de invocación.** En Yala: unit → `Yala`,
  XCUITest → `Yala Dev`, y el gate corre el build en los DOS. Antes de bisecar un rojo de XCUITest,
  comprueba con qué scheme lo produjiste.
- **Un rojo en un área que no tocaste es primero una hipótesis sobre el arnés, y solo después sobre
  el código.** Cuesta un `-showBuildSettings | grep COMPILATION_CONDITIONS` comprobarlo, y monté un
  worktree entero (1,6 GB de DerivedData) antes de gastar esos diez segundos.
- El worktree base **no se tira**: sigue siendo la respuesta correcta a «¿es mío?» cuando el arnés ya
  está descartado. Lo que cambia es el ORDEN — arnés primero, porque es más barato.

## 2026-09-07 — dos más, y la segunda casi me hace abrir un ticket fantasma

**(a) `-only-testing` por TIPO, no por fichero: me pasó DOS veces en la misma sesión.** Pedí seis
suites y corrieron cinco; pedí ocho y corrieron siete. **xcodebuild no avisa** — sale exit 0 y
`TEST SUCCEEDED`, y la suite que falta desaparece sin ruido. Las dos veces el motivo fue el mismo:
el TIPO no se llama como el fichero (`SessionPreferenceKeysTests.swift` declara
`SessionPreferenceKeysNetTests`; `GroupRemoteDeletionUnbridgeTests.swift` declara cinco tipos y
ninguno con ese nombre). Y la segunda vez la suite que faltaba era **justo la que verificaba mi
cambio**. Está en `.claude/rules/testing.md` y aun así lo repetí: ⇒ **resolver los nombres con
`grep -n "@Suite\|^struct" <fichero>` ANTES de construir el comando**, y contar las suites
ejecutadas contra las pedidas siempre, no solo cuando algo huele mal.

**(b) El filtro que INVENTA un defecto, otra vez.** Conté las filas del índice de tickets con
`grep -cE '^\| [a-z0-9-]+ \| ...'` y los ficheros con `ls | wc -l`: me salió **138 filas vs 144
ficheros vs «139» declarado**, y estuve a punto de anotarlo como descuadre del board. Las dos
mediciones estaban mal: la regex se comía los ids con mayúsculas y el `ls` contaba `.gitkeep` y PNG
de evidencia. Medido con **conjuntos** —`set(indice) - set(disco)` en las dos direcciones— salió
**139 = 139, cero huérfanos**. El propio `ESTADO.md` del repo ya avisaba de las dos trampas.

⇒ el patrón se repite: **mi filtro falla en la dirección que más ruido genera**. Un conteo que no
cuadra es sospechoso del INSTRUMENTO antes que del dato, y la forma barata de zanjarlo no es afinar
la regex: es comparar conjuntos y que te diga *qué* elemento sobra o falta. Si no puede nombrarlo,
no hay defecto.

### 2026-09-07, más tarde — lo repetí con esta ficha ya escrita, así que la prescripción cambia

El mismo día, en la sesión del timeout del CI, volví a contar las filas del índice con
`grep -cE '^\| [a-z0-9-]+ \| \w+ \| tickets/'`: **149 filas vs 151 ficheros**, y otra vez pensé
«el índice viene descuadrado». No lo estaba. Mi regex se comía dos filas legítimas: `in-progress`
lleva guion y `\w+` no lo casa, y un id con mayúsculas (`rojo-heroBuckets-thisWeek-…`) no casa
`[a-z0-9-]+`. El cruce de conjuntos dio **151 = 151, cero huérfanos por ambos lados**.

Lo que esto añade no es un tercer ejemplo: es que **la advertencia no funcionó**. Estaba escrita,
la había leído, y aun así el primer gesto volvió a ser un `grep -c`. Un `grep -c` es más rápido de
teclear que un cruce de conjuntos, y esa diferencia de dos segundos gana siempre.

⇒ **la regla deja de ser «sospecha del instrumento» y pasa a ser una prohibición**: para comparar
un índice con un disco, **`grep -c` no es una medición válida ni como primer tanteo**. El primer
gesto es el script de conjuntos, que además nombra qué sobra y qué falta. Si me sorprendo tecleando
`| wc -l` para comparar dos poblaciones, es la señal.

Y un corolario que sí es nuevo: **cuando el conteo cuadra, dilo con el cruce, no con el número.**
«151 = 151» no prueba nada por sí solo —dos errores pueden compensarse—; «cero huérfanos en ambas
direcciones y todos los `status` casan con su carpeta» sí.

---

**2026-09-07, `fx-manual-writes`: los dos clásicos de este fichero, otra vez, en los primeros cinco
minutos — y esta vez la lección es que hace falta el PATRÓN, no la advertencia.**

`grep -E "error:"` sobre un log de `xcodebuild` volvió a decir **720 errores** donde había cero:
eran el eco de cada `#expect(... classify(error: ...))`. Es la tercera vez que lo anoto. Y el
primer `grep -rn ... --include=*.swift` volvió a morir por el glob de zsh sin comillas, devolviendo
un **`wc -l` de 0** que, de haberlo creído, cerraba la sesión en falso a los dos minutos.

Lo que faltaba aquí no era otro ejemplo. Era esto, para copiar y pegar:

- **Errores de compilación reales:** `grep -cE "^/.*\.swift:[0-9]+:[0-9]+: error:"`. El ancla `^/`
  y el `línea:columna:` son lo que separa un diagnóstico del compilador del texto de un test.
- **Veredicto de build:** `grep -E "^\*\* BUILD (SUCCEEDED|FAILED)"`, con el `^\*\*`.
- **Casos de Swift Testing:** la línea `Test run with N tests in M suites`, y **M se compara con el
  número de `-only-testing` que pedí**. Los `Executed N tests` son de XCTest (XCUITest) y en una
  corrida de Swift Testing salen como `Executed 0 tests`, que no significa nada malo.
- En zsh, **todo patrón de `grep`/`find` va entre comillas**, siempre.

⇒ **Un cero es un resultado sospechoso por defecto.** Cero coincidencias, cero errores, cero tests:
antes de creerlo, correr el mismo comando con un patrón que SÍ deba casar. Cuesta un segundo y es la
diferencia entre medir y no medir. Aquí el falso cero llegó antes que cualquier hallazgo real.

---

**Caso 14 (2026-09-07), y es el que más caro salió: el instrumento FABRICÓ el fenómeno que se
investigaba.** Un ticket `high` decía que `YalaTests` daba «rojos DISTINTOS en cada corrida». La
suite es determinista: tres corridas del mismo árbol dan 6414/653 y `failedTests: 0`. Lo que variaba
era el **conteo**, porque los `print` de la app y el reporter de Swift Testing comparten stdout sin
lock: un log a media línea la parte en dos y **ninguna mitad casa con `^✔ Test .* passed`**. El grep
anclado perdía 43-50 líneas de 6403 **y otras distintas en cada corrida**.

Tres cosas que retener, más allá del ancla:

1. **Lo prescribía yo.** El método roto estaba en el ticket *y* en mi propia memoria
   (`el_arbol_base_contesta_si_es_mio`), presentado como «cuenta a mano porque el resumen miente».
   Era al revés: `Test run with` daba 6414 las tres veces. **Acusé al instrumento fiable para
   defender el mío.**
2. **La línea de arriba ya avisaba** — «los casos de Swift Testing se leen de `Test run with`» — y
   aun así usé el grep. Tener la regla escrita no basta si la aplico solo cuando me acuerdo.
3. **Cuando el fenómeno es «no determinista», sospecha del medidor ANTES que del sistema.** Un
   sistema no determinista y un medidor no determinista producen la misma tabla. Lo que los separa
   es una fuente estructurada: `-resultBundlePath` + `xcrun xcresulttool get test-results summary`,
   inmune al entrelazado. Debió ser mi primera medición, no la tercera.

⇒ **Si mido texto que dos procesos escriben a la vez, no tengo una medición: tengo una carrera.**
Antes de anclar en `^`, preguntarme quién más escribe en ese descriptor.

---

**Caso 15 (2026-09-08): el instrumento que monto para medir puede estar roto, y su cero es
idéntico al cero bueno.** Para saber si el `cron` de GitHub Actions dispara en Yala monté un
workflow canario con `*/5` — la pregunta costaba dos días sobre la nocturna real y treinta minutos
sobre el canario. Siete ventanas, cero runs. Iba a concluir «el `schedule` no sirve aquí».

**Lo que faltaba era una línea:** lanzar el canario a mano. Corrió y acabó en verde en segundos, y
solo entonces el cero significaba algo — el workflow es válido, ejecutable y GitHub lo reconoce,
así que lo que falla es el reloj. **Sin ese control positivo habría documentado un error mío como
un fallo de la plataforma**, y con la firmeza que da un número.

Es una vuelta de tuerca sobre los catorce de arriba, y por eso la anoto aparte: allí el defectuoso
era el **filtro** sobre datos buenos; aquí lo sería el **instrumento entero**, que yo mismo acababa
de escribir. Un aparato recién construido es la fuente menos fiable de la sala, y es justo el que
llega sin historial de fallos que me haga desconfiar.

⇒ **Un instrumento nuevo se calibra antes de creerle un cero: hazle producir un uno.** Si no sabes
cómo forzarlo a dar el resultado contrario, no tienes una medición — tienes una esperanza.

⇒ Corolario del mismo día, y aplica a cualquier mecanismo de emergencia: **el camino que solo se
recorre cuando algo va mal no está probado.** El vigilante que escribí lleva la ventana como
parámetro únicamente para poder forzarlo (`horas: 1`) y comprobar los cuatro eslabones. Un
salvavidas que se estrena durante el naufragio es decoración.


## Caso 15 (2026-09-08): el filtro laxo contó una SEGUNDA tabla del mismo documento

Al re-contar el índice de `docs/TICKETS.md` tras añadir dos tickets, usé
`l.startswith("| ") and "tickets/" in l` y el encabezado salió **`## Index (234)`** cuando el disco
tenía 174. El documento tiene **dos tablas**: el índice (3 columnas) y, 400 líneas más abajo, el
mapa de origen de YalaWiki (2 columnas, y su segunda columna también contiene `tickets/`). Sesenta
filas contadas de más.

**Lo que lo salvó fue tener la medición estricta de antes**: `NF>=5 && $4 ~ /tickets\//` había dado
174/174 diez minutos antes, así que el salto a 234 cantó solo.

**Why:** es el fallo de siempre por el lado contrario. Las otras 14 veces el filtro se comió casos y
salió un verde falso; aquí el filtro **cogió de más** y salió un número falso. Los dos vienen de lo
mismo: **elegir el filtro por lo que quiero contar y no por lo que hay en el fichero.** Un documento
con dos tablas es exactamente el caso que un `startswith("| ")` no distingue.

**How to apply:** cuando cuentes filas de una tabla en un `.md`, **cuenta las columnas** (`NF`) y
ancla la que identifica la tabla, no solo su contenido. Y cuando un conteo cambie de golpe respecto
a otro que hiciste hace un rato, **el sospechoso es el filtro nuevo**, no el fichero.


## Caso 16 (2026-09-08): un cambio de comportamiento que no mueve NI UN test

Cambié el criterio del «≈» de un OR a un umbral del 5 % y corrí las 4 suites del área: **59 verdes,
cero rojos, cero cambios de color**. Eso no era una buena noticia: significaba que **la batería no
distinguía el criterio viejo del nuevo**. Los 14 tests usaban importes iguales, donde una de seis
pesa un 16,7 % y sigue marcando con los dos criterios.

**Why:** un verde que no se movió al cambiar el comportamiento **no es una verificación, es un
silencio**. Si hubiera commiteado ahí, el gate habría sellado un cambio del que nadie podía decir si
hacía algo.

**How to apply:** después de cambiar un comportamiento, **antes de mirar si los tests pasan, mira si
alguno CAMBIÓ**. Si ninguno se movió, escribe el que distingue los dos criterios y **verifícalo con
el mutante** (recompila el código anterior y comprueba que se pone rojo). Es el control positivo de
[[mutante-compilado-zanja-hipotesis]] aplicado a mi propio cambio, no a una hipótesis ajena.

Corolario del mismo día: un test que mide **un número** en vez de **el invariante** se pone rojo ante
un cambio legítimo. `UITestSeamPersistenceIsolationTests` exigía `pushes == 1` en el primer de
notificaciones; añadir una segunda preferencia —justo lo que el ticket pedía— lo puso rojo sin que
nada estuviera mal. Ahora compara contra la lista de símbolos esperados.


**Y la vuelta de tuerca del 2026-09-08 (tarde): el filtro que falla puede ser EL DEL PROPIO GATE, y
con un BORRADO falla siempre.** El paso 2 de `/gate` mapea las suites a correr desde los `.swift`
modificados, «por convención `<Clase>Tests.swift` y por `grep -rl "<Clase>"`». Borré un método de
`TransactionService`, corrí las 7 suites que ese mapeo produce, todo verde, sellé y commiteé. El CI lo
puso rojo: `WidgetSessionSealWiringTests.laPuerta_gateaLos49Escritores` cuenta los call-sites de
`WidgetDataCache.updateCache(` bajo `Yala/` y el método borrado tenía uno en su última línea.

**El mapeo del gate no podía encontrarlo por construcción**: ese source-scan no menciona
`TransactionService` ni por nombre de clase ni por fichero — vigila un choke-point del **widget**, un
área sin ninguna relación temática con lo que toqué. Ningún grep razonable sobre el nombre de la clase
modificada lo alcanza.

⇒ **Cuando el cambio QUITE código con cuerpo, corre `-only-testing:YalaTests` entero antes de sellar**
(6513 tests, ~2 min de reloj en esta máquina: más barato que un ciclo de CI de 32 min y un
re-commit). El corolario de arriba decía que un test que mide un NÚMERO se pone rojo ante un cambio
legítimo; éste añade **quién** lo mueve: no solo añadir, también **borrar** — y un conteo global de
call-sites baja cuando se va código muerto, aunque el escritor que desaparece nunca se ejecutara.

Dos cosas que este caso deja claras y conviene no confundir: el test **no estaba mal** (es un
anti-drift que hace su trabajo, y su docblock ya decía «si el número cambia por una razón legítima,
ajústalo a conciencia»), y **la review adversarial tampoco lo cazó** — una de las tres lentes buscó
explícitamente dependencias de test del borrado, revisó suelos de otros source-scans y dio el visto
bueno. Un conteo exacto en un área remota es un punto ciego de las tres redes a la vez: gate acotado,
lentes y mi propia lectura. La suite completa es la única que lo ve.

## Dos más el 2026-09-09, y el segundo casi cuela un test que nunca corrió

- **`-only-testing:<Suite>` corrió OTRA suite del mismo archivo.** Añadí dos tests al final de
  `ApproximateMarkWiringTests.swift` creyendo que caían en la suite del nombre del archivo, y caían
  en la **segunda** suite (`…SecondarySurfacesWiringTests`). El filtro corría 6 tests de la primera y
  mis dos nuevos **no se ejecutaron en ninguna de las corridas anteriores**: verde y vacío. Lo destapó
  un mutante que debía ponerlos rojos y no los puso. ⇒ **un archivo puede tener varias suites, y el
  filtro va por SUITE, no por archivo.** Cuenta los tests que dice haber corrido y cuádralos.
- **Una regex mía descartó una fila del índice por las mayúsculas.** `[a-z0-9\-]+` sobre
  `docs/TICKETS.md` no casó `rojo-heroBuckets-thisWeek-…` y me hizo creer que faltaba en el índice.
  Estaba. El control que lo cazó fue el más barato: grepear el nombre a mano antes de reportar.

**How to apply:** cuando una medición diga «falta X» o «esto no está», **búscalo una vez a mano**
antes de escribirlo. Y cuando diga «pasó», exige el número de casos: un filtro que no casa nada sale
verde por el mismo camino que uno que casa todo.

## 2026-09-10 — el guard que mi propia prueba dejaba abierto, y por qué el control negativo PURO es otra cosa

Escribí un trigger que debía impedir que el dueño de una cuenta se auto-promoviera escribiendo una
columna. Lo probé con tres casos —negativo, positivo, regresión— y los tres salieron como esperaba.
**Y la prueba era inválida**, dos veces seguidas y por motivos distintos:

1. **El positivo contaminó al negativo.** El guard vive en una variable de transacción, y yo corrí los
   tres casos EN LA MISMA. El negativo, ejecutado después del positivo, veía el guard ya cerrado por
   el positivo — o sea, medía «el guard se cierra bien», no «el guard estaba cerrado desde el
   principio». El estado real de producción es que **nunca se ha puesto**, y ese caso no lo probé.
2. **Luego añadí una exención por rol** (`if session_user = 'postgres' then return new`) que una lente
   me había sugerido, con buen motivo: que una reparación futura no se bloqueara. Volví a correr las
   pruebas y **los cuatro casos pasaron, incluido el que debía fallar**. La exención abría el guard
   ENTERO en el único banco de pruebas que existe: `set local role authenticated` cambia
   `current_user` pero **NO `session_user`**, y yo me conecto como administrador.

Lo que lo cazó fue rehacer el negativo **en transacción fresca y con el GUC sin tocar**, más dos
negativos que antes no existían: el guard abierto por OTRA transacción (la fuga del pool) y el literal
del diseño viejo. Cinco negativos, uno positivo, dos regresiones.

**Why:** un control negativo que corre después del positivo no es un control negativo — es la segunda
mitad del positivo. Y una salvaguarda con una exención para «el entorno desde el que se administra»
es exactamente una salvaguarda que no se puede probar desde donde se prueba.

**How to apply:**

- **El negativo va PRIMERO y en su propia transacción**, o con el estado explícitamente al valor que
  tendrá en producción. Si el mecanismo usa estado de sesión (un GUC, un flag, una caché), el orden de
  los casos ES parte del experimento.
- **Antes de aceptar una exención sugerida —por una lente o por mí—, pregunta desde dónde se prueba lo
  que exime.** Si la exención cubre justo ese camino, el banco se queda ciego. Aquí la retirada costó
  una línea; descubrirla en producción habría costado la columna entera.
- **«Un guard que no se puede probar no es un guard»** es la regla, y vale para elegir entre dos
  diseños igual de correctos sobre el papel: gana el que el banco disponible sabe tumbar.

Relacionado: [[la-asercion-que-no-puede-fallar]] · [[el-prefiltro-tapa-al-criterio]] (la misma familia:
algo aguas arriba deja la comprobación sin nada que comprobar).

**Y el filtro puede ser el NOMBRE, medido el 2026-09-11.** Una tanda de 14 mutantes salió «5 muertos»: la
buscaba como `✘ Test <función>(` y Swift Testing escribe el **nombre visible** cuando el test lo tiene
(`@Test("la tabla entera")` sale como `✘ Test "la tabla entera"`). Releída con los dos formatos, 14/14. ⇒ al
leer el log de un mutante, resuelve el nombre visible desde el fuente, o lee el result bundle; y un
«sobrevive» en un test con nombre visible es sospechoso hasta mirarlo.

## 2026-09-12 · el exit que no informa

`bash qa/scripts/disk-report.sh --guard` **SIEMPRE sale 0**, también por debajo del umbral: es un
hook de aviso, no un bloqueo. Leí ese 0 como «hay disco de sobra» y seguí con 21 GB (umbral 25). El
dato está en el texto, no en el código de salida. **Antes de derivar una decisión del exit de un
script, mira si ese exit tiene más de un valor posible** — un `grep -n "exit" <script>` lo dice.

Y el hermano del mismo día: un `ok`/`mal` de banco cuyo comparador devuelve TRES códigos (0 / 1 / «no
pude medir») y solo se comprueban dos: el tercero cae en la rama del ✓.


## 2026-09-24 — el control negativo de una COMPROBACIÓN de migración cazó que abortaría la buena

Escribí en el §2 de `g16_01` «toda tabla con `user_id` + `server_seq` lleva `stamp_server_seq`». Antes de aplicarla la
probé con una tabla falsa sin el trigger: salieron DOS culpables, la falsa y `group_members`, que lleva las dos columnas
y el contador de Grupos. Aplicada sin ese control, la migración se habría abortado a sí misma en producción. ⇒ una
comprobación estructural nueva se ejecuta primero con un caso que DEBE fallar y se lee la lista entera de lo que falla,
no solo si falla.

## 2026-09-26 — un test añadido tras la review lo corrí PRIMERO bajo el mutante, y «lo mató» porque fallaba siempre

La lente de tests pidió fijar que el drain personal estampa con la fecha de la transacción. Escribí el test y lo estrené
directamente con el mutante (`tx.timestamp - 3600`): rojo, «muerto». Rojo también sin mutante — el oráculo cogía la
ÚLTIMA transacción del movimiento, y el barrido del drain le asigna el `syncID` en otra posterior que no se emite. Lo
cazó la suite completa del gate. ⇒ **un test nuevo se corre verde contra el código real antes de apuntarle un mutante**;
un mutante «muerto» por un test que nunca pasó no mide nada.
