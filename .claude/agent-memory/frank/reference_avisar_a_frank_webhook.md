---
name: avisar-a-frank-webhook
description: Cómo se avisa al Grok dueño — con el script `avisar_grok.py` y sus motivos tipificados, nunca componiendo el POST a mano (la cabecera es Authorization Bearer y a mano da 401)
metadata:
  type: reference
---

**El aviso a Frank se manda con `python3 ~/.claude/hooks/avisar_grok.py <motivo>`, no con un POST
propio.**

**Why:** el 2026-09-05 compuse el POST a mano leyendo `~/.claude/grok-webhooks.json` y me dio **401**.
El fichero tiene dos campos que parecen una cosa y son otra: `cabecera` vale `Authorization` (no
`X-Sender-Key`) y `prefijo` vale `Bearer` — es el prefijo del **token**, no del mensaje. El script ya
sabe todo eso, elige el destino por el cwd y escribe el registro.

**How to apply:**

- `--estado` → qué destinos hay, la sesión tmux de esta sesión y los últimos envíos.
- `--dry-run <motivo>` → compone y dice si pasaría la puerta, sin enviar. Úsalo antes del real.
- `<motivo>` a secas → envía. Motivos: `espera-input`, `espera-permiso`, `espera-pregunta`,
  `fallo-build`, `fallo-tests`, `artefacto-captura`, `artefacto-pr`, `artefacto-preview`,
  `artefacto-publicado`.
- Comprueba `~/.claude/cache/avisos-grok/envios.log`: la línea dice `HTTP 200` o no lo dice.

**El hook ya avisa solo de algunas cosas.** Esa misma noche mandó un `fallo-tests` por su cuenta
cuando un XCUITest salió rojo, antes de que yo mandara el `artefacto-pr`. Antes de avisar a mano de
un build o unos tests rotos, mira el log: puede que ya esté enviado y solo gastes uno de los 12 de la
sesión.

**El canal tiene vuelta:** la sesión corre en tmux con nombre `repo--slug`, así que Frank puede
contestar con `tmux send-keys`. Eso hace que valga la pena que el mensaje diga qué se necesita, no
solo qué pasó. Relacionado: [[push-solo-lo-de-la-sesion]].
