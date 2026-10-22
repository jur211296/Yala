---
name: head-retiene-el-veredicto-de-xcodebuild
description: Un `| head -N` al final de un xcodebuild retiene la salida entera hasta que el proceso muere. Parece un teardown colgado de 20 minutos y es el pipe. Redirige a fichero y grepea después.
metadata:
  type: feedback
---

**Nunca cierres un `xcodebuild … test` con `| grep … | head -N`.** `head` no puede hacer flush: mientras
no reciba sus N líneas, no imprime **nada**, y el pipe no se cierra hasta que `xcodebuild` termina. Como
el teardown de `xcodebuild` en esta máquina dura muchos minutos después de que los tests acaben, el
síntoma es un comando que «lleva 20 minutos corriendo» cuando en realidad el veredicto existe desde el
minuto dos.

**Why:** el 2026-09-14. La suite unit completa dio su `Test run with 6829 tests … passed` a los 86 s
cuando la salida iba a un fichero (`> unit-full.log`). La misma corrida con
`| grep -E "…" | head -20` se quedó 19 minutos sin imprimir una línea — con el simulador booteado, sin
ningún proceso `xctest` vivo y con el `.xcresult` todavía abierto, o sea con toda la pinta de un teardown
colgado. Perdí dos corridas enteras diagnosticando el pipe.

**How to apply:**

- **Redirige a fichero y grepea después**: `xcodebuild … > /tmp/x.log 2>&1` y luego
  `grep -E "✘ Test .* failed|Test run with|\*\* TEST" /tmp/x.log`. Así la salida se ve en cuanto se
  escribe, y el fichero queda para el informe.
- Si necesitas seguirlo en vivo, un `Monitor` con `until grep -q … ; do sleep 10; done` sobre ese fichero
  da la respuesta en cuanto aparece, sin esperar al teardown.
- **La señal de que es el pipe y no un cuelgue:** `xcrun simctl list devices booted` enseña el simulador
  arriba, `pgrep -fl xctest` no devuelve nada (los tests ya acabaron) y el `.xcresult` más reciente aún
  no se puede leer (`xcresulttool` dice que falta su `Info.plist`). Las tres cosas a la vez significan
  «terminó de testear, está cerrando» — no «se colgó».
- Lo mismo vale para cualquier filtro que acumule: `head`, `tail` sin `-f`, `sort`. `grep
  --line-buffered` sí fluye.

Relacionado: [[feedback_zsh_no_divide_variables]] · [[reference_xcuitest_completo_por_lotes]] ·
[[feedback_dos_corridas_un_simulador]]
