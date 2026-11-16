---
name: feedback-iphone-14-libre-para-pruebas
description: Cualquier sesión puede usar el iPhone 14 de pruebas (siempre conectado y activo en Device MCP) cuando la prueba sale mejor en el teléfono que en el simulador
metadata:
  type: feedback
---

El iPhone 14 de pruebas está siempre conectado y activo en Device MCP, y las sesiones pueden usarlo sin pedir permiso
cuando la prueba sale mejor en el teléfono: más rápido, menos carga para la Mac, o medición real (memoria, cuelgues,
jetsam) que el simulador no da.

**Why:** Jürgen, 2026-11-06, en el lote de crashes de Sentry, al verme montar en el simulador una medición de memoria
con foto de perfil de 48 MP y conductor XCUITest.
**How to apply:** antes de montar un conductor pesado en el simulador, pregúntate si en el iPhone 14 sale antes o más
fiel. Ojo: sus relanzamientos con `devicectl --terminate-existing` generan falsos WatchdogTermination en Sentry de la
build de desarrollo (por eso desde el 2026-11-06 desarrollo ya no los manda). Ver [[feedback-qa-fisico-datos-dev-no-preguntes]].
