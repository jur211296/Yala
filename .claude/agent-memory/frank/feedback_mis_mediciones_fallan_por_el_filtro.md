---
name: mis-mediciones-fallan-por-el-filtro
description: Mis errores de medición se repiten con la misma forma — el filtro descarta justo lo que busco y la ausencia se lee como resultado. Ocho casos en dos sesiones (2026-09-02).
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
