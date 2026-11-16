---
name: plantar-estado-del-host-de-unit-tests
description: Para probar un rojo «según el orden de la corrida» se planta el estado en el plist del host con el simulador apagado; Swift Testing no se deja barajar
metadata:
  type: reference
---

`xcodebuild` no tiene forma de barajar el orden de Swift Testing (solo `-test-iterations`/reintentos). Cuando un encargo
pide «dos órdenes distintos» para un rojo que depende de lo que dejó la corrida anterior, lo que discrimina es PLANTAR ese
estado en el host: `simctl get_app_container <udid> com.jurgenschmidt.yala.dev data` → `Library/Preferences/<bundle>.plist`,
editado con `plistlib` con el simulador APAGADO, y `boot` después (2026-11-07, card r9e8: marca `cloudSync.hasPrivateSession`
en `false` reprodujo el rojo con el mutante y dio verde con el arreglo).

Dos trampas medidas: la ruta del contenedor CAMBIA en cada reinstalación (vuelve a pedirla), aunque el valor plantado
sobrevive; y los ciclos `shutdown`/`boot` de esto dejaron el XCUITest siguiente en «AX loaded notification» → la cura de
[[ax-loaded-timeout-se-cura-reiniciando]]. El grep `simctl spawn defaults read <bundle>` no ve ese dominio.
