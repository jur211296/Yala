---
name: la-build-cortada-deja-un-app-sin-info-plist
description: Cortar una build-for-testing en cuanto «el app ya compiló» deja un .app sin Info.plist que simctl no instala; el «antes» sale de restaurar los ficheros y recompilar incremental
metadata:
  type: feedback
---

Matar el `xcodebuild build-for-testing` del «antes» cuando ya iba por los tests dejó `Yala.app` sin `Info.plist`
(«Missing bundle ID» al instalar), aunque el log ya había pasado por el target de la app. El empaquetado final de la app
corre más tarde de lo que parece.

**Why:** pasó en S30 (2026-10-30); ya había editado las fuentes, así que no había «antes» que recompilar de cero.

**How to apply:** para el «antes», deja terminar la build o usa `build` (no `build-for-testing`). Si ya editaste:
guarda `git diff --binary` + un tar de los nuevos, `git checkout -- Yala`, compila incremental (solo recompila lo tocado:
minutos) y copia el `.app` con otro nombre; luego `git apply`. Relacionado: [[antes-del-iphone-con-git-archive]].
