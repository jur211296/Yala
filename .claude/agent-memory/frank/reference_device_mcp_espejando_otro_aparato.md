---
name: device-mcp-espejando-otro-aparato
description: Device MCP Free solo espeja un aparato; si está con el iPhone de Jürgen, el simulador no se puede conducir por MCP (medido 2026-11-21 en la Max)
metadata:
  type: reference
---

El 21-nov, en la Max, `select_device` del simulador contestó: «Device MCP Free mirrors one device at a time, and it's
mirroring iPhone de JURGEN». Ese iPhone es el personal de Jürgen, no el de pruebas: no se toca y no se le pide que cambie
el espejo para unas capturas.

**Qué hice:** las capturas antes/después con un XCUITest conductor temporal (una prueba con `XCTAttachment` por pantalla,
`TEST_RUNNER_YALA_PREFIJO=antes|despues`) y `xcresulttool export attachments`. Sirve también para las hojas, que `axe` no ve.
El fichero no se commitea: se borra antes del gate.

**How to apply:** si Device MCP dice que espeja otro aparato, ve directo al conductor; no esperes ni reintentes MCP.
Relacionado: [[device-mcp-lo-enciende-jurgen]], [[el-iphone-de-pruebas-es-el-14-por-cable]].
