---
name: feedback-gate-en-disco-local-no-extdev
description: xcodebuild con -derivedDataPath en /Volumes/ExtDev se cuelga a 0 % CPU en «Resolve Package Graph»; para el gate, DerivedData en disco local
metadata:
  type: feedback
---

Para correr tests o compilar con `-derivedDataPath`, usa disco local (`~/Library/Developer/Xcode/DerivedData/<slug>-local`), no `/Volumes/ExtDev/DerivedData/...`.

**Why:** el 2026-11-05 (lote T3) tres `xcodebuild` sobre ExtDev se quedaron a 0 % CPU en «Resolve Package Graph» (uno 49 min, otros muertos con 143/144) con el turno del simulador tomado. Jürgen lo cortó: «No uses más ExtDev para esta corrida». En disco local resolvió y compiló en minutos. Antes, ese mismo día, `build-for-testing` sobre ExtDev sí había funcionado: falla a ratos, no siempre.

**How to apply:** DerivedData en local desde el principio. Si un `xcodebuild` lleva 3 min en «Resolve Package Graph» sin avanzar, mátalo (suelta el `sim-lock`) y cambia de ruta; no reintentes igual. Vigila las corridas largas con Monitor (casos terminados + «sin avance N min»): la corrida colgada se descubrió por una pregunta de Jürgen, no por un aviso. Relacionado: [[reference-adjuntos-de-xctest-en-el-simulador]].
