---
name: hook-avisos-grok-automaticos
description: Los avisos a Grok (PR abierto, build/tests rojos, espera de input) los manda solo el hook avisar_grok.py; POSTear a mano al webhook es innecesario y sale mal
metadata:
  type: reference
---

Cuando un encargo pide «avisa al webhook al dejar el PR listo / si falla el build», **no hay
nada que hacer**: `~/.claude/hooks/avisar_grok.py` ya lo manda solo, por evento (ADR-010 de casa).
Medido el 2026-09-05: el aviso `artefacto-pr` salió con HTTP 200 **48 segundos después** de
`gh pr create`, sin que yo hiciera nada.

**Cómo comprobar que salió**, que es lo único que sí toca hacer:

    tail -5 ~/.claude/cache/avisos-grok/envios.log
    python3 ~/.claude/hooks/avisar_grok.py --estado   # mapa, motivos y últimos envíos

Motivos que disparan: `espera-input` · `espera-permiso` · `espera-pregunta` · `fallo-build` ·
`fallo-tests` · `artefacto-pr` · `artefacto-captura` · `artefacto-preview` · `artefacto-publicado`.

**Por qué NO POSTear a mano.** Lo intenté antes de mirar y me llevé un 401: el fichero
`~/.claude/grok-webhooks.json` tiene los destinos bajo `destinos.<agente>`, no en el top level, así
que una heurística que busque «la primera url» coge **la de otro agente** — mandé a la de Dan. Y la
clave se llama `sender_key`, que no casa con los nombres habituales (`key`/`token`), así que fue sin
`Authorization` encima. Auth = `cabecera` + `prefijo` + `sender_key`, todo declarado en el propio
fichero, que además trae sus instrucciones en las claves `_1_`…`_6_`.

El modo manual del script (`python3 avisar_grok.py <motivo>`) es **dry-run**: imprime el cuerpo y la
decisión de la puerta, no envía. `--probar --forzar` envía marcándolo como PRUEBA, y existe para
comprobar una clave recién rotada — no para avisar de trabajo real.

Ver también [[feedback_mis_mediciones_fallan_por_el_filtro]]: el 401 fue otra medición rota por el
filtro, esta vez uno que adivinaba nombres de campo en vez de leer el esquema.
