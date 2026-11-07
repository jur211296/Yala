---
id: inbox-bulk-save-and-swipe-skip-the-duplicate-check
status: backlog
priority: high
area: inbox
created: 2026-11-07
updated: 2026-11-07
source: revisión por vistas 2.3, zona 38, problema 3 (docs/ux/revision-vistas-2.3/38-bandeja-ia/13-el-dudoso.html)
---

# «Guardar los N listos» y deslizar para guardar no buscan duplicados

La Bandeja busca un registro igual (mismo día, importe y cuenta) solo cuando se guarda desde el borrador abierto
(`InboxDraftEditSheet.swift:912-921`, `findDuplicateTransaction` en `:1042-1065`), y entonces avisa «Posible duplicado».
Los otros dos caminos para guardar no la llaman: el lote («Guardar los N listos», `InboxView.swift:965-995` →
`DraftService.bulkApprove`, `DraftService.swift:532-560`) y el deslizamiento a la derecha (`InboxView.swift:867-876`,
`approveDraft` en `:1081`). Leído en el código; no reproducido en pantalla.

Caso: el correo del banco y Apple Pay traen el mismo pago, completo los dos. El lote guarda ambos y el gasto cuenta doble,
sin ningún aviso. En finanzas, contar dos veces el mismo dinero es el error a evitar.

## Qué hay que decidir

Es la alternativa C3 de la revisión (y C1 la complementa: buscar el duplicado al llegar el borrador). Jürgen decide;
la revisión recomienda C1 + C3.
