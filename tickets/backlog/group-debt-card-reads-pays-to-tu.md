---
id: group-debt-card-reads-pays-to-tu
status: backlog
priority: medium
area: groups, copy, accessibility
created: 2026-11-07
updated: 2026-11-07
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
---

# Las deudas que te pagan dicen «Beto paga a Tú»

En Saldos, cada deuda en la que te pagan a ti se lee **«Beto · paga a · Tú»** (y VoiceOver dice lo mismo). Cuando pagas
tú ya se arregló («Tú pagas a Ana»), pero el otro sentido quedó con el nombre propio «Tú» en tercera persona.

Evidencia: capturas `13-saldos` a `15-saldos-3` de la revisión. Código: `GroupBalancesView.swift:274-291` (la frase) y
`:472-475` (`name()` devuelve «Tú» para ti).

Criterio: «Beto te paga» (o equivalente aprobado), en pantalla y en VoiceOver, en los 16 idiomas. Relacionado con la
alternativa A4 del problema 1 de la revisión, que propone el mismo texto.
