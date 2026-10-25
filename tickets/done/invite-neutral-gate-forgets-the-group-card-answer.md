---
id: invite-neutral-gate-forgets-the-group-card-answer
status: done
area: groups
priority: low
created: 2026-10-21
updated: 2026-10-24
source: review adversarial del lote decidido 2.2 · 14 (L12-17)
---

# Tras la puerta del teléfono con datos, la tarjeta del grupo vuelve a salir y hay que reescribir el nombre

## Qué pasa

Desde L12-17 la tarjeta del grupo sale antes que la puerta del teléfono con datos de otra persona. Si la persona
escribe su nombre y toca «Unirme», la marca de la tarjeta (`PendingJoinEntry.groupCardAcceptedAt`) y el nombre
se guardan en la invitación; la puerta borra el teléfono (`PendingJoinStore.clearAll()`) y el sobre de
reanudación (`GroupInviteResumeStore`) solo repone grupo y token. Al volver, la tarjeta sale otra vez vacía.

No une de más ni con otro nombre: cuesta repetir un paso.

## Arreglo probable

Que el sobre de reanudación lleve también la marca y el nombre tecleado.

## Relacionado

Con dos invitaciones vivas a la vez, el nombre escrito en una tarjeta viaja también a la otra
(`PendingJoinStore.updateDisplayName` es global, residual ya declarado en `performJoinOnlySetup`), y ahora se
aplica sin que la persona lo vea si la segunda une sola en su ventana de 30 minutos.

## Cerrado (2026-10-24, lote 12.1 Grupos)

El sobre de reanudación lleva también cuándo dijo «Unirme» y el nombre tecleado, y `restoreIntoPendingJoins` los repone en esa invitación solo dentro de la ventana de la unión sola (30 min desde «Unirme»). Fuera de ella, o sin «Unirme», el sobre es el de siempre: un sobre huérfano que repone otro cierre de sesión días después no trae el nombre de nadie. Tests: `GroupInviteResumeStoreTests#groupCardAnswer_*` y `#withoutGroupCardAnswer_theNameDoesNotTravel`. El residual del nombre global con dos invitaciones vivas sigue como estaba.
