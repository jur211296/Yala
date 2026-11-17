---
name: voz-del-chat-en-el-iphone-14
description: Probar la voz de Yala IA en el iPhone 14 desde la Mini — el teléfono no oye el `say` del Mac; Pro sin reset con «Simular Pro».
metadata:
  type: reference
---

Medido el 2026-11-16 (Mini, iPhone 14 por Wi-Fi, encargo guiados-mejoras):

- **El micrófono del iPhone no oye el altavoz de la Mini**: `say` durante la grabación del chat dio «No detecté audio».
  El dictado físico necesita a Jürgen junto al teléfono. Lo que sí se valida solo: escribir en la caja la frase tal
  como la deja el dictado (números en palabras) con `fill` de Device MCP.
- **Pro sin borrar datos**: Ajustes de Yala Dev › sección de privacidad › interruptor «Simular Pro» (solo DEBUG y
  bundle `.dev`). Evita `-uitest -uitest-reset`, que borra la sesión del teléfono.
- El mirror puede estar tomado por Device Hub («Another app is mirroring»): `reconnect_device` lo recupera; antes, mira
  que la sesión de la otra máquina no use el teléfono (ver [[el-iphone-14-lo-ve-tambien-la-otra-maquina]]).
- El teléfono está en español de España: los textos salen en `es-ES` («He gastado», «Lo has dicho tú»).
