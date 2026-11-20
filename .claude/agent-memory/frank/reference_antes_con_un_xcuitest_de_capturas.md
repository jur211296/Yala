---
name: antes-con-un-xcuitest-de-capturas
description: Para el antes/después de varias pantallas, un XCUITest de capturas escrito ANTES de tocar la app, corrido en la base y luego endurecido como pin
metadata:
  type: reference
---

Cuando un encargo pide capturas de antes y después de muchos puntos de un flujo, conducir el simulador a mano con `axe` o
XcodeBuildMCP sale caro y falla: el tecleo de hardware no entra en los campos de monto (`.amountKeyboard()`), `axe
describe-ui` no expone `isSelected` y el árbol de XcodeBuildMCP pesa miles de tokens por paso. Medido el 2026-11-20
(pulido de Primeros pasos): media hora a mano para 6 capturas, frente a ~2,5 min de corrida para 15.

**Cómo:** escribir la clase de capturas (`XCTAttachment` con nombre por punto) ANTES de editar la app, tolerante a las dos
versiones (ramas `if exists`), correrla sobre la base con `-resultBundlePath`, y sacar los PNG con
`xcrun xcresulttool export attachments`. Después del cambio se le añaden las aserciones de lo nuevo y queda como pin del
encargo. Molde: `YalaUITests/PrimerosPasosPulido/PrimerosPasosPulidoCapturasUITests.swift`.

Si ya conduciste el simulador con `type_text`/`axe type`, bórralo (`simctl erase`) antes de correr XCUITest:
[[ax-loaded-timeout-se-cura-reiniciando]] y la regla de teclado físico de `testing.md`.
