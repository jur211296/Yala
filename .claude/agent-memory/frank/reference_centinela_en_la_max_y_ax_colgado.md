---
name: centinela-en-la-max-y-ax-colgado
description: En la Max el centinela de sim-libre cuenta los xcodebuild test de Mando (otro proyecto, otro simulador) como intrusos; y tras conducir el simulador con axe, el runner de XCUITest puede no arrancar («Timed out waiting for AX loaded notification»).
metadata:
  type: reference
---

Medido el 2026-11-10 en la Max, gate del lote 02 de mejoras necesarias de 2.3.

- **El centinela canta por Mando.** `sim-libre.sh --vigilar` sale 1 si hay CUALQUIER `xcodebuild … test` en la
  máquina, también el de la sesión de Jhon sobre `Mando.xcodeproj` en su propio simulador («Mando-Carriles»). No
  comparte simulador ni bundle con Yala, pero el veredicto queda invalidado igual. Mira el comando de los PID que
  lista antes de repetir; si es Mando, espera a que termine su tanda (duran minutos) y repite.
- **«Timed out waiting for AX loaded notification» = cero casos, fallo de infraestructura.** Me salió dos veces seguidas
  después de lanzar la app a mano y tocarla con `axe` en el mismo simulador. Lo curó `simctl shutdown` + `boot` +
  ~45 s de espera; la corrida siguiente ya ejecutó los 27 casos.
- **El formulario de gasto de grupo no se deja rellenar por XCUITest ni por `axe`:** `typeText` en el campo de una
  persona del reparto «Monto» no cambia el valor, y `axe tap` en «Nuevo gasto» de Grupos no abre nada (familia de
  [[tarjeta-de-grupo-no-se-abre-con-toques-sinteticos]]). La etiqueta del segmento es «Monto exacto», no «Monto».
  Para capturas de ese formulario, Device MCP en el iPhone 14 o la mano de Jürgen.
