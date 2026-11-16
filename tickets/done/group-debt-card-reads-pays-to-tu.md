---
id: group-debt-card-reads-pays-to-tu
status: done
priority: medium
area: groups, copy, accessibility
created: 2026-11-07
updated: 2026-11-10
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
---

# Las deudas que te pagan dicen «Beto paga a Tú»

En Saldos, cada deuda en la que te pagan a ti se lee **«Beto · paga a · Tú»** (y VoiceOver dice lo mismo). Cuando pagas
tú ya se arregló («Tú pagas a Ana»), pero el otro sentido quedó con el nombre propio «Tú» en tercera persona.

Evidencia: capturas `13-saldos` a `15-saldos-3` de la revisión. Código: `GroupBalancesView.swift:274-291` (la frase) y
`:472-475` (`name()` devuelve «Tú» para ti).

Criterio: «Beto te paga» (o equivalente aprobado), en pantalla y en VoiceOver, en los 16 idiomas. Relacionado con la
alternativa A4 del problema 1 de la revisión, que propone el mismo texto.

## Resuelto (2026-11-10, mejoras necesarias 2.3 · lote 06)

La tarjeta dice «Beto · te paga», sin el avatar de «Tú» detrás, y VoiceOver lee «Beto te paga: S/ 30.00», en los 16
idiomas. Lo decide `GroupBalancesPresentationLogic.pairRole`, que usan también las filas de «Pagos». Lo fijan
`GroupsNecesarias23Lote06UITests#test_debtToYou_readsPaysYou` (rojo con el código de antes: «Beto paga a Tú: S/ 30.00»)
y `GroupsNecesarias23Lote06Tests`. Capturas antes y después en el PR.
