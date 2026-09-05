---
name: mis-mediciones-fallan-por-el-filtro
description: Mis errores de medición se repiten con la misma forma — el filtro descarta justo lo que busco y la ausencia se lee como resultado. Doce casos entre el 2026-09-02 y el 2026-09-05, incluido un CI "en verde" cuyo check clave no existía.
metadata:
  type: feedback
---

**Antes de creerme una medición mía, compruebo que el instrumento sabe producir el resultado
contrario.** Es la regla; lo que sigue es por qué me hace falta tenerla escrita.

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

