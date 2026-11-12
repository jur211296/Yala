---
name: lote6-espera-eleccion-de-variantes
description: Auditoría UX 2.2 lote 6 (2026-10-14) — PR #495 abierto con 5 bugs; la sesión queda viva esperando que Jürgen elija variantes de L6-4, L6-5 y L6-6
metadata:
  type: project
---

Lote 6 de la auditoría UX 2.2 (primera vez con datos previos o en la nube) terminado el 2026-10-14: PR #495 contra
`2.2` con cinco bugs (B1–B5, cards en curso hasta el merge), trece mejoras con card en espera decisión y tres
elecciones visuales en https://claude.ai/artifact/M1PVzjojCBxyEPRJjLaYJ6 (local:
`~/Claude/propuestas/auditoria-ux-2.2/variantes-L6.html`).

**Why:** el encargo pide, con elecciones de UI pendientes, NO correr `/cerrar-total` y quedarse viva hasta que Jürgen
elija (llega por `decirle`). El PR no va a cola de auto-merge por eso; lo mergea Jürgen.

**How to apply:** al llegar la elección, implementarla contra 2.2 partiendo de la maqueta
(`~/Claude/entregas/Yala--auditoria-ux-2-2-lote-6-datos-previos-nube/maquetas-lote-6.patch`, vistas `Mock6*Variant`),
con copy en 16 idiomas y capturas antes/después. Ver [[maqueta-de-estados-del-welcome]].
