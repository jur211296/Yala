---
name: avisar-a-frank-webhook
description: Cómo se avisa al Grok dueño — normalmente NO hay que hacer nada: el hook avisa solo. A mano, `<motivo>` a secas no envía (sale 0 en silencio) y el POST propio da 401
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
- `--dry-run <motivo>` → compone y dice si pasaría la puerta, sin enviar.
- **`<motivo>` a secas NO envía** — corregido el 2026-09-05, midiendo el log antes y después:
  `main()` solo desvía a `modo_manual` con `--dry-run` o `--probar`; sin flag cae al **modo hook**,
  que espera el JSON del evento por stdin, revienta al no encontrarlo y **sale 0 sin decir nada**.
  Esta línea decía «→ envía», que es el peor error posible aquí: crees que avisaste y no avisaste.
  Es la familia del «cero casos con exit 0» de `.claude/rules/testing.md`.
- Motivos: `espera-input`, `espera-permiso`, `espera-pregunta`, `fallo-build`, `fallo-tests`,
  `artefacto-captura`, `artefacto-pr`, `artefacto-preview`, `artefacto-publicado`.
- Comprueba `~/.claude/cache/avisos-grok/envios.log`: la línea dice `HTTP 200` o no lo dice.

**El hook avisa solo, y de más cosas de las que parecía: normalmente no hay nada que hacer.** Además
del `fallo-tests` de aquella noche, el 2026-09-05 mandó el **`artefacto-pr` él solo, 48 segundos
después de `gh pr create`**, sin que yo tocara nada. ⇒ cuando un encargo pida «avisa al webhook al
dejar el PR listo», la tarea real es **comprobar el log**, no enviar:

    tail -5 ~/.claude/cache/avisos-grok/envios.log

**Y el 401 tiene un segundo modo de fallo, distinto del de la cabecera.** Los destinos cuelgan de
`destinos.<agente>`, no del top level, así que una heurística que busque «la primera url del fichero»
apunta a **otro agente** (me fue a la de Dan); y la clave se llama `sender_key`, que no casa con
`key`/`token`, así que el POST sale sin `Authorization` encima. El fichero trae sus propias
instrucciones en las claves `_1_`…`_6_`: leerlas cuesta menos que adivinar el esquema.

**El canal tiene vuelta:** la sesión corre en tmux con nombre `repo--slug`, así que Frank puede
contestar con `tmux send-keys`. Eso hace que valga la pena que el mensaje diga qué se necesita, no
solo qué pasó. Relacionado: [[push-solo-lo-de-la-sesion]].
