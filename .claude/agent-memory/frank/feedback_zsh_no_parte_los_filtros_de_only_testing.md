---
name: feedback-zsh-no-parte-los-filtros-de-only-testing
description: En el Bash de la sesión (zsh) `$F` con varios -only-testing no se parte en palabras: xcodebuild corre 0 casos y sale TEST SUCCEEDED
metadata:
  type: feedback
---

Con la salida de `suites-de-fichero.py` en una variable, `xcodebuild … test $F` en zsh pasa UN argumento con saltos de
línea: con varias suites no casa nada, Swift Testing corre 0 casos y la corrida sale `** TEST SUCCEEDED **` sin la línea
`Test run with`. Con una sola suite sí funciona, y eso despista. Hay que escribir `${=F}`.

**Why:** el 13-nov (adopt sobre la nube) perdí tres corridas y un reinicio de simulador creyendo que era el entorno.

**How to apply:** siempre `${=F}` en zsh, y sin la línea `Test run with N tests in M suites` la corrida no cuenta. Ver
[[feedback-runner-ax-timeout-tras-suite-larga]] antes de culpar al simulador.
