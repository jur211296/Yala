---
name: simulador-ajeno-parado-se-pregunta
description: Si el simulador de otra sesión sigue encendido porque esa sesión espera a Jürgen, se le pregunta; el 2026-10-09 aprobó usarlo sin apagarlo.
metadata:
  type: feedback
---

**Un encargo que dice «espera a que la Mini quede libre» no contempla la sesión ajena que se queda PARADA esperando a
Jürgen con su simulador encendido.** Ahí la espera no tiene fin: no hay `xcodebuild` corriendo y el simulador no se
apaga hasta que él conteste a la otra sesión. De día, se le pregunta con `AskUserQuestion`.

**Why:** el 2026-10-09 (chat-context-archived-accounts-and-mtd) esperé 20 min con el iPhone 18 Pro de centro-de-mando
encendido; `tmux capture-pane` enseñaba su pregunta pendiente. Jürgen eligió «usar el suyo sin apagarlo»: compilar con
`-jobs 2` y correr los tests en ese mismo simulador, con `sim-lock.sh`, sin arrancar un segundo y dejándolo encendido.

**How to apply:** antes de esperar, mira si la sesión dueña está trabajando (`pgrep -x xcodebuild`, su pane de tmux) o
esperando a Jürgen. Si espera a Jürgen, pregunta con esa opción recomendada; nunca apagues ni borres su simulador, y no
arranques otro. Relacionado: [[carril-espera-a-cola-a]].
