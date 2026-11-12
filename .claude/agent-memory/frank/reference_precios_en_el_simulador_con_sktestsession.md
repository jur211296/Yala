---
name: precios-en-el-simulador-con-sktestsession
description: Para ver planes, comprar y restaurar en el simulador hace falta un conductor XCUITest con SKTestSession; xcodebuild+simctl no cargan precios
metadata:
  type: reference
---

El paywall sale sin planes en el simulador si la app se lanza con `simctl`/`build_run_sim`: la configuración
StoreKit del scheme `Yala Dev` solo la aplica Xcode al darle a Run. Lo que funcionó (lote 17, 2026-10-16): un
XCUITest TEMPORAL que crea `SKTestSession(configurationFileNamed:)` con una copia de `Configuration.storekit`
dentro de `YalaUITests/` (carpeta sincronizada: entra sola al bundle), lanza la app con los args de siempre y se
queda escuchando órdenes en un fichero (`launch …`, `expire`, `clear`, `stop`). Copia guardada en
`~/Claude/entregas/Yala--auditoria-ux-2-2-lote-17-yala-pro/maquetas/ZZLote17DriveUITests.swift`.

Tres cosas medidas: (1) la PRIMERA sesión tras arrancar el simulador falló con `SKInternalErrorDomain Code=4`; la
segunda corrida, igual, funcionó; (2) **la configuración se queda en el simulador** después: la app lanzada a mano
seguía cargando precios, y el XCUITest de «sin precios» habría salido rojo — `simctl erase` antes del gate; (3) en
Yala Dev una compra real nunca activa Pro (rama `.dev` de `updateSubscriptionStatus`), así que la bienvenida y la
prueba en curso se ven con maqueta, no comprando. Relacionado: [[el-final-del-ciclo-borra-la-prueba]].
