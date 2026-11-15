---
name: centinela-canta-por-otro-proyecto
description: En la Max, sim-libre.sh --vigilar sale 1 por xcodebuild de OTRO proyecto (centro de mando con sus simuladores Mando-Visor); no es pisada de Yala si soy la única sesión de Yala en la máquina.
metadata:
  type: feedback
---

El centinela del gate (`sim-libre.sh --vigilar`) cuenta cualquier `xcodebuild … test` y cualquier `*UITests-Runner` de la
máquina, sin mirar el proyecto ni el simulador. El 2026-11-12, en la Max, salió 1 («NO estuviste solo») con seis
`xcodebuild` y un segundo runner que eran de la sesión de centro de mando, en sus simuladores Mando-Visor-iPhone/iPad.

**Why:** la pisada que invalida un veredicto es otra corrida de Yala que instala sobre el mismo bundle
(`com.jurgenschmidt.yala.dev`) en el mismo simulador. Un proyecto distinto en otro simulador no la produce, y Yala tiene
como mucho una sesión por máquina (ADR-074 de casa). Repetir 9 min de XCUITest no habría aislado nada: la otra sesión
seguía corriendo.

**How to apply:** con centinela 1, mira de quién son los PID (`ps -o command= -p <pid>`) antes de repetir. Si son de
otro proyecto y yo soy la única sesión de Yala en la máquina, el verde vale y se anota en el informe del gate y en el
PR. Si alguno es Yala (otra sesión, o un `xcodebuild` mío olvidado), se repite aislada como dice la regla.
