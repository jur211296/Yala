---
name: taps-en-la-hoja-de-google
description: En la hoja de Google (ASWebAuthenticationSession) del simulador, los taps de axe se vuelven pulsación larga; Device MCP con `device=` sí toca, aunque espeje otro aparato
metadata:
  type: reference
---

Medido el 12-nov-2026 (iOS 27.2, simulador): `axe tap` sobre el contenido web de la hoja de Google no pulsa «Advanced»
y abre la vista previa del enlace (menú «Open / Copy Link»), como una pulsación larga. `axe` sí vale para la app y para
escribir (`axe type`). Device MCP con `device=<udid>` en cada llamada toca bien la web, aunque `select_device` falle
porque el espejo gratuito está en otro aparato (el iPhone 14).

**How to apply:** en flujos de Google, conduce con Device MCP pasando `device`; no cambies el espejo ajeno. Para
enterarte de que cambió la pantalla web, `axe describe-ui` no ve la hoja: compara capturas.
