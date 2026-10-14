---
name: lote5-espera-eleccion-de-variantes
description: Auditoría UX 2.2 lote 5 (2026-10-14) — PR #494 abierto con 7 bugs; la sesión queda viva esperando que Jürgen elija variantes de L5-4, L5-8, L5-10 y L5-13
metadata:
  type: project
---

Lote 5 de la auditoría UX 2.2 (primeros días, guías y tips) terminado el 2026-10-14: PR #494 contra `2.2` con siete
bugs (B1–B7, cards en qa), quince mejoras con card en espera decisión y cuatro elecciones visuales en
https://claude.ai/artifact/KJDSBjF6v6Z2nFojh5MFNV (local: `~/Claude/propuestas/auditoria-ux-2.2/variantes-L5.html`).

**Why:** el encargo pide, si hay elecciones de UI, NO correr `/cerrar-total` y quedarse viva hasta que Jürgen elija
(llega por `decirle`). El PR no se dejó en cola de auto-merge por eso.

**How to apply:** al llegar la elección, implementarla sobre la misma rama o una nueva contra 2.2 (la maqueta está en
`~/Claude/entregas/Yala--auditoria-ux-2-2-lote-5-primeros-dias/maquetas-lote-5.patch`, `-mockv N`), gate, y entonces
`/cerrar-total`. Si llega otra cosa, preguntar qué hacer con el PR #494.
