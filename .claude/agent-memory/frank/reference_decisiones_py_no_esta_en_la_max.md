---
name: decisiones-py-no-esta-en-la-max
description: El pie de lanzar-sesion pide `decisiones.py incorporar-lote` al commitear decisiones de Jürgen; en la Max ese script no existe (medido 2026-11-10).
metadata:
  type: reference
---

`python3 ~/.claude/scripts/decisiones.py incorporar-lote …` (lo pide el bloque «Decisiones de Jürgen pendientes» que
añade `lanzar-sesion`) **no existe en la Max**: `~/.claude/scripts/` trae `checkpoint_nocturno.py` y otros 50, pero no
`decisiones.py`. Medido el 2026-11-10 en el lote 09 de mejoras 2.3.

**Qué hice:** incorporar la decisión a `docs/DECISIONS.md` (entrada + su línea en el índice) y decir en el
cierre que el registro del lote quedó sin hacer, para que lo corra la Mini o el bot.

**How to apply:** en la Max, antes de prometer el registro, `ls ~/.claude/scripts | grep decis`. Si sigue sin estar,
no inventes otra vía: incorpora en el repo y anótalo en «Necesita de ti».

**Para leer el registro desde la Max (21-nov):** `ssh mini` funciona sin contraseña. `scp mini:Claude/flota/decisiones/decisiones.jsonl`
y filtrar en Python (tipo `capturada`, proyecto Yala o «yala», quitar los `sustituye` de las filas `sustitucion`). Lo mismo para
`ssh mini 'python3 ~/.claude/scripts/coordinador.py estado'` y los briefs de `~/Claude/flota/borradores/`. El registro de Yala
empieza el 7-nov.

**21-nov: no corras `indexar_doc.py --apply` sobre `docs/DECISIONS.md` en una rama.** Reordenó ~20 líneas del índice que
no eran mías (entradas del mismo día cambian de sitio) y el diff pasó de 9 a 48 líneas: choque seguro con otra sesión.
Inserta la entrada y su línea del índice a mano (y sube «Índice (N entradas)»).

