---
name: lote-de-decisiones-puede-estar-ya-incorporado
description: el lote «Decisiones de Jürgen pendientes» que trae el encargo puede estar ya en la rama de otra sesión sin mergear; incorporarlo otra vez lo duplica
metadata:
  type: feedback
---

Antes de incorporar el lote de decisiones que pega `lanzar-sesion` al final del encargo, busca si otra sesión ya lo
metió en su rama: `git log --all --oneline -- docs/DECISIONS.md | head` y `git branch -r --contains <sha>`.

**Why:** el 22-nov (encargo «Esto leí» opción A) el lote de las 15:05 ya estaba en `docs/DECISIONS.md` de la rama
`encargo/2026-11-22-grupos-guardado-fallido-sin-duplicar`, aún sin mergear. Dos PR con la misma entrada chocan en el
índice y dejan el lote dos veces.

**How to apply:** si ya está en otra rama, no lo incorpores ni corras `decisiones.py incorporar-lote`; dilo en el cierre
(«lo incorpora la sesión X»). Si no está en ninguna, sigue el procedimiento de siempre. Relacionado:
[[decision-de-ticket-viejo-puede-estar-tomada]].
