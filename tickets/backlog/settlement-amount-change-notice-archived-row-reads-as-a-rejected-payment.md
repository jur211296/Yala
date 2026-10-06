---
id: settlement-amount-change-notice-archived-row-reads-as-a-rejected-payment
status: backlog
priority: low
area: "inbox, copy"
created: 2026-10-05
source: "review adversarial de `settlement-amount-edited-after-approval-leaves-the-bank-stale` (2026-10-05, lente de copy); NO reproducido"
---

# En Archivados, el aviso que dejé como estaba parece un pago rechazado

## El síntoma, en lenguaje de usuario

Ana corrigió de 25 a 30 una liquidación que ya había aprobado, y elegí «Dejar en S/ 25». En Archivados aparece una fila
con el importe nuevo en grande (S/ 30) y la línea de siempre («Liquidación recibida • Banco»). Se lee como «rechacé
registrar un pago de 30», cuando lo que hice fue quedarme con los 25 que ya tenía.

## Lo medido

- La fila archivada no lee relaciones (`InboxDraftRowView`), así que el aviso rechazado cae a la línea genérica.
- Tocarla abre la hoja del aviso, que sí explica el cambio y deja ajustar.

## Qué hay que decidir

Un texto propio para el aviso archivado («Lo dejaste en S/ 25»), guardado al rechazar, o dejarlo así porque la hoja lo
explica.

## Relacionados

- [[settlement-amount-edited-after-approval-leaves-the-bank-stale]]
