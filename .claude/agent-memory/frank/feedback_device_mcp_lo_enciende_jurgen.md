---
name: device-mcp-lo-enciende-jurgen
description: En el QA de iPhone físico con Device MCP, los permisos y el interruptor del servidor MCP los da Jürgen en pantalla; no se scriptea su UI ni se da el aparato por listo por un `devicectl`.
metadata:
  type: feedback
---

Lo que Device MCP pide en la pantalla de la Max (permisos, encender su servidor MCP en Settings › MCP) lo da
Jürgen. No se abre su ventana por AppleScript/System Events: se anota el paso, se le pasa al bot y se espera.

**Why:** 2026-11-05, QA físico: intenté abrir los ajustes de Device MCP con `osascript` para encender el
servidor y Jürgen lo rechazó. El bot añadió: «no asumas que el aparato ya está listo» — `devicectl` decía
`available (paired)` mientras `xctrace` lo daba offline y sin USB (emparejado por red ≠ conectado).

**How to apply:** el aparato está listo cuando el bot lo confirma con `decirle` (cable, Confiar, Modo de
desarrollador, permisos, servidor MCP encendido). Mientras, se adelanta lo que no lo necesita (build, guion).
Device MCP registrado a mitad de sesión no expone sus tools en esa sesión: se le habla por stdio
(`device-mcp` con JSON-RPC) o se relanza. Relacionado: [[credencial-pendiente-se-aparca]].
