---
name: feedback-iphone-bloqueado-se-pide-en-el-chat
description: Con Jürgen en el chat, el iPhone 14 bloqueado se le pide en un mensaje, no con request_human_action de Device MCP (lo rechazó el 17-nov y contestó «desbloqueado»).
metadata:
  type: feedback
---

El 17-nov, con el iPhone 14 bloqueado por Wi-Fi, lancé `request_human_action` («Desbloquea el iPhone 14…») y Jürgen
rechazó la llamada; al preguntarle en el chat cómo seguir, contestó «desbloqueado» y siguió la prueba.

**Why:** el aviso de Device MCP le salta en la Mac y bloquea la sesión hasta que lo cierra; si está en el chat, prefiere
que se lo pidan ahí y desbloquear a su ritmo.

**How to apply:** si Jürgen está en el chat y el teléfono sale `locked` en `list_devices`, pídelo en una línea del
mensaje y sigue con otra cosa; `request_human_action` solo cuando no está en el chat. Relacionado:
[[feedback-si-jurgen-esta-en-el-chat-hablale-directo]], [[feedback-device-mcp-lo-enciende-jurgen]].
