---
name: simulador-iphone-14-para-medir-tamano
description: Con el iPhone 14 ocupado por otra sesión, un simulador «iPhone 14» (390×844) con simctl io + axe mide si algo cabe; Device MCP Free no lo espeja
metadata:
  type: reference
---

Para un bug de «no cabe en el iPhone 14» con el teléfono en manos de otra sesión (13-nov, la de la Mini lo tenía
esperando desbloqueo), sirvió un segundo simulador del MISMO tamaño: `xcrun simctl create "… iPhone14 QA"
com.apple.CoreSimulator.SimDeviceType.iPhone-14 com.apple.CoreSimulator.SimRuntime.iOS-27-2`, build de la rama a medir
en un worktree temporal (`git worktree add --detach` + `Secrets.xcconfig`), `simctl install/launch` y medir con
`axe describe-ui --udid` (marcos en puntos) + `simctl io screenshot`. Device MCP Free solo espeja un dispositivo
(ver [[device-mcp-free-un-espejo]]), así que no sirve para ese simulador. Al acabar: `simctl delete` y
`git worktree remove`. Ver [[segundo-simulador-en-la-max]].
