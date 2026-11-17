---
name: taps-en-la-hoja-de-google
description: En la web de Google del simulador axe no toca (pulsación larga o nada); Device MCP sí, pero desde el 16-nov solo si el espejo está en ese simulador
metadata:
  type: reference
---

Medido el 12-nov-2026 (iOS 27.2, simulador): `axe tap` sobre el contenido web de la hoja de Google no pulsa «Advanced»
y abre la vista previa del enlace (menú «Open / Copy Link»), como una pulsación larga. `axe` sí vale para la app y para
escribir (`axe type`). Device MCP con `device=<udid>` en cada llamada toca bien la web, aunque `select_device` falle
porque el espejo gratuito está en otro aparato (el iPhone 14).

**16-nov:** Device MCP Free ya no deja tocar un aparato que no espeja (`device=` da error y nombra el espejado). Hubo que
pedir a Jürgen «Mirror This Simulator Instead»; `axe tap` en el campo de correo de Google tampoco escribió.

**How to apply:** en flujos de Google, conduce con Device MCP pasando `device`; si el espejo está en otro aparato, pide el cambio dentro del mismo BLOQUEANTE del login. Para
enterarte de que cambió la pantalla web, `axe describe-ui` no ve la hoja: compara capturas.
