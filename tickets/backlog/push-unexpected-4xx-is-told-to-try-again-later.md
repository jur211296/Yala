---
id: push-unexpected-4xx-is-told-to-try-again-later
status: backlog
priority: low
area: "modo-nube, sync, sesión"
created: 2026-09-25
updated: 2026-10-08
source: "review adversarial de `cloud-signout-collapses-the-personal-push-all-reason-into-permanent` (2026-09-25)"
---

# Un 4xx que el gateway no cablea se anuncia como «inténtalo en un rato»

## El problema, en lenguaje de usuario

Si la subida de mis cambios choca con un error del servidor que no se arregla esperando (un 400 por un cuerpo que el
Worker no acepta, un 413 por un lote demasiado grande), al cerrar sesión Yala me dice «Tus últimos cambios no llegaron a la
nube… inténtalo de nuevo en un rato». Lo intento en un rato y sigue igual.

## Lo medido (leído, sin ejecutar)

- `SyncPushClient.pushBatch`, rama `default:` — el 5xx, el 429 y «4xx inesperados» salen `.transient` desde siempre, y el
  comentario lo reconoce. Desde el 2026-09-25 encienden además el testigo de la subida, así que el cierre en la nube les pone
  el texto de «en un rato».
- Grupos hace lo mismo (`GroupsSyncClient`, su `default:`), con el texto de grupos.
- Hoy el gateway no emite ningún 4xx de ese tipo en `/sync/push` que se sepa; es un camino defensivo.

## Lo que hay que decidir

¿Un 4xx no cableado merece su propio motivo (o el genérico), en los dos canales? Pide medir antes qué 4xx puede devolver de
verdad el Worker.

## Medido en 2.1 (triage 2026-10-08)

- `SyncPushClient.pushBatch`, `default:` con el comentario «5xx (retry), 429 (rate-limit → retry), y 4xx inesperados» → `.transient`; `GroupsSyncClient` igual (`default: return .transient`).
- Medido en el gateway: `/sync/push` sí emite un 4xx no cableado, el 400 `yala_bad_request` de un cuerpo que no es JSON o no trae `deltas` (`gateway/src/sync/routes.ts`); solo lo provoca un cliente roto.

Triage 2026-10-08: abierto · low → low · camino defensivo: el único 4xx no cableado que el gateway emite en /sync/push es de un cliente roto.
