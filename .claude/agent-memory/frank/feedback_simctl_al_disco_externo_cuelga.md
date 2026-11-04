---
name: simctl-al-disco-externo-cuelga
description: Una captura de simctl con destino en /Volumes/ExtDev se cuelga sin error: macOS pide permiso de volumen extraíble en un diálogo que nadie ve
metadata:
  type: feedback
---

`simctl io … screenshot` hacia `/Volumes/ExtDev/…` se quedó colgado 5 min sin salida (4-nov-2026, capturas App Store
2.2). La causa estaba en la pantalla del Mac: tres diálogos «CoreSimulatorService solicita acceso a los archivos de un
volumen extraíble», apilados encima de Device Hub. Los clics sintéticos de `clic` no los cierran.

**Why:** la sesión lanzada no ve el escritorio; el fallo parece un simulador colgado, no un permiso.

**How to apply:** la salida de capturas (`YALA_FICHA_SALIDA`) va al disco interno (`~/Claude/propuestas/…`); el
DerivedData sí puede ir a ExtDev. Si algo de simctl se cuelga, mira el escritorio con
`osascript -e 'do shell script "screencapture -x …"'` antes de culpar al simulador. Relacionado:
[[conducir-el-duo-sin-pantalla-propia]], [[deriveddata-en-extdev]].
