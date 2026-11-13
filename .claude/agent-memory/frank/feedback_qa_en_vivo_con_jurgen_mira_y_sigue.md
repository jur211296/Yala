---
name: qa-en-vivo-con-jurgen-mira-y-sigue
description: Cuando Jürgen prueba él mismo en el iPhone 14, no lanzar request_human_action ni tocar: mirar la pantalla con capturas y seguirle; y lo que la prueba destapa va a su card, no al PR.
metadata:
  type: feedback
---

Cuando Jürgen está probando en el iPhone 14, **no le lances `request_human_action`** (lo rechazó el 2026-11-13: «estoy
probando, mira la pantalla y haz seguimiento») **ni toques el teléfono**: captura cada pocos segundos, cronometra y mide
el store con devicectl. Se le habla por `preguntar-bot` con una instrucción concreta («AHORA: toca X»), y luego se mira.

Y un bug grave que la prueba destapa **no se arregla en el PR en curso** salvo que lo diga: el mismo día pidió arreglar en
el PR la vuelta a la bienvenida tras «Ya está tu cuenta» y un minuto después lo corrigió — card crítica aparte, sesión
interactiva, y en la card todo lo medido con `tablero comentar` (tope 2.000 caracteres por comentario: partir en varios).

**Why:** el popup de Device MCP le interrumpe en la Mac mientras tiene el teléfono en la mano; y mezclar un arreglo nuevo en
el PR del encargo le quita la revisión con él delante.
**How to apply:** en device-QA con Jürgen presente, mirar y reportar; ante un hallazgo, medir (hora, estado del store y de
UserDefaults), dejarlo en su card y seguir con el encargo. Relacionado: [[si-jurgen-esta-en-el-chat-hablale-directo]].
