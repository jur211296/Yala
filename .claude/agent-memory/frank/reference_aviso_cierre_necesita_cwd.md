---
name: aviso-cierre-necesita-cwd
description: El aviso de cierre se descarta si lo lanzas tras retirar el worktree — el script deduce repo e identidad del cwd, y desde ~/Users/jur va a Dan y muere como «carpeta sin trabajo»
metadata:
  type: reference
---

`avisar_grok.py` deduce **el destinatario y el repo del cwd**, no de argumentos. En `/cerrar-total`
el paso del worktree (8) va ANTES del aviso (9), así que al llegar al aviso el cwd ya no existe y la
shell te ha dejado en `/Users/jur`.

Resultado medido el 2026-09-06: `DESCARTADO destino=dan motivo=cierre-resumen repo=jur — carpeta sin
trabajo (jur)`. Va a **Dan**, no a Frank, y ni siquiera se envía. **No da error**: imprime
«DESCARTADO por la puerta» y sale con éxito, así que si no lees la salida das el aviso por enviado.

**Cómo se lanza bien:** `cd /Users/jur/Yala && python3 /Users/jur/.claude/hooks/avisar_grok.py
--avisar cierre-resumen --texto "..."` → `ENVIADO destino=frank ... HTTP 200`.

**Y siempre lee la línea de salida.** `ENVIADO ... HTTP 200` es la única prueba; cualquier otra cosa
significa que el aviso no salió. El log de descartes está en
`~/.claude/cache/avisos-grok/descartados.log` y dice el motivo.

Relacionado: [[reference_avisar_a_frank_webhook]] — el hook ya manda PR y rojos solo, no los
dupliques; esto es solo para el aviso de cierre, que sí lo manda el comando.
