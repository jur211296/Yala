---
id: qa-folder-keeps-evidence-of-tickets-that-already-left
status: backlog
priority: very-low
area: "proceso, board"
created: 2026-09-23
updated: 2026-09-23
source: "barrido de `qa` del 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`)"
---

# La carpeta `tickets/qa/` guarda capturas de tickets que ya no están en `qa`

## Qué pasa

Medido el 2026-09-23: en `tickets/qa/` hay tres cosas que no son tickets, y dos de ellas son de tickets que
ya salieron de ahí.

| Fichero | De qué ticket | Dónde está ese ticket hoy |
|---|---|---|
| `evidencia-welcome-privacy-secondary/` (3 PNG) | `welcome-privacy-branch-has-no-secondary-door` | `discarded` |
| `qa-hero-caption-distribucion-gastos-20260907.jpg` | `hero-estadisticas-stock-vs-flujo-entre-pestanas` | `done` |
| `evidencia-groups-only-mount/` (1 PNG) | `groups-entry-on-a-mirrored-store-still-blocks-the-owner` y `groups-only-second-launch-mounts-icloud-mirror` | `qa` (bien) |

Cuando un ticket se mueve de carpeta, su evidencia se queda atrás y el enlace del ticket pasa a apuntar a
otra carpeta. Nadie lo nota porque el índice (`docs/TICKETS.md`) solo cuenta `.md`.

## Qué haría falta

Decidir una de dos: que la evidencia viaje con el ticket al moverlo, o que viva en un sitio fijo
(`tickets/_evidencia/`) que no dependa del estado. Y mover las dos que ya están descolocadas.

No es urgente: no rompe nada, solo ensucia la carpeta que Jürgen mira para saber qué le toca probar.
