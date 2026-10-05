---
name: medir-en-simulador-salida-y-pid
description: Dos trampas medidas el 2026-10-05 al instrumentar y vigilar corridas en el simulador — dónde sale el print de la app y qué PID recibe el centinela
metadata:
  type: feedback
---

**Para leer un `print` temporal de la app, lanza con `simctl launch --console-pty` en background.**
`simctl launch --stdout=<fichero>` no dejó nada (el fichero ni se creó) y el `print` tampoco llega al log unificado
(`log show` vacío). Con `--console-pty --terminate-running-process … > fichero` las líneas salen.

**El centinela (`sim-libre.sh --vigilar`) necesita el PID del `xcodebuild`, y `eval … & P=$!` da el del subshell.**
Usé `eval` para que zsh partiera la lista de `-only-testing` y el centinela salió `2` («no se vigiló nada»). Lo
arreglé lanzando un segundo centinela sobre el PID real (`pgrep -lf 'xcodebuild -scheme'`), que dio `0`.

**Why:** las dos fallan en silencio: la primera parece «la app no imprime», la segunda deja una corrida verde sin
veredicto válido.

**How to apply:** al medir coste con instrumentación temporal, y en el paso 3 del gate cuando la lista de suites va en
una variable. Relacionado: [[zsh-no-divide-variables]] · [[dos-corridas-un-simulador]] · [[instrumentar-gana-a-razonar]].
