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

## Confirmado el 2026-09-05 por segunda vez, y con el coste: dupliqué el aviso

En el PR #66 mandé `--avisar artefacto-pr --texto "..."` a mano porque el encargo lo pedía. El log
lo dice todo: **06:57:59 el hook, 06:59:06 el mío**. Dos avisos del mismo PR a Frank con 67 s de
diferencia. El antirrebote de 10 min no los para porque el motivo se compone distinto según el
camino. ⇒ ante un encargo que pida avisar de un PR, `tail -5 envios.log` PRIMERO; si ya está, no
mandes nada y di que el hook lo cubrió.

## `--avisar` sí envía, y su trampa NO es la del `<motivo>` a secas

`--avisar <motivo> --texto "..."` entra por `modo_avisar` y **sí manda** (`ENVIADO … HTTP 200`);
lo que no envía es `<motivo>` a secas, que es lo que dice arriba. Los dos caminos existen y se
parecen; el que compone un texto propio es el de `--avisar`.

## Y la trampa que costó un descarte: la palabra «prueba» dentro del texto

`RX_PRUEBA = re.compile(r"\bPRUEBA\b", re.IGNORECASE)` corre sobre el **cuerpo entero**, no sobre
una marca. Mi aviso decía «conservamos la prueba de su consentimiento» y la puerta lo descartó
como si fuera un aviso de test: `DESCARTADO … — prueba`, sin enviar nada.

**Why:** es la familia exacta de [[hook-secretos-disparador-substring]] — un disparador que casa
por contenido y no por intención. Y aquí el fallo es silencioso en la dirección cara: el script
imprime el descarte, pero si no lees esa línea crees que avisaste.

**How to apply:** evita la palabra «prueba» (y «PRUEBA», «pruebas») en el cuerpo de un aviso —
usa «registro», «evidencia», «comprobación», «tests». Y **lee siempre la última línea del script**:
`ENVIADO … HTTP 200` o `DESCARTADO … — <razón>` son lo único que distingue haber avisado de creerlo.
