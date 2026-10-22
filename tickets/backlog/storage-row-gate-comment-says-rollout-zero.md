---
id: storage-row-gate-comment-says-rollout-zero
status: backlog
priority: low
area: "cloud, docs"
created: 2026-09-08
source: hallazgo de camino en chat-rows-with-unsigned-amount-have-no-repair-path (2026-09-08)
updated: 2026-10-08
---

# El comentario de la fila «Almacenamiento» dice que la nube está apagada, y lleva mes y medio abierta

## Qué pasa

`Yala/App/Logic/StorageRowGateLogic.swift:11-12` afirma, sobre el estado de producción:

> Sigue siendo el estado de producción HOY, pero por otra razón que antes: el backend ya está
> configurado (D-R1 paso 1) y lo que apaga la fila es el flag remoto, porque el gateway sirve
> `CLOUD_MODE_ROLLOUT_PERCENT = "0"`.

**Medido el 2026-09-08 en este árbol:** `gateway/wrangler.toml:130`, dentro de `[env.production.vars]`,
sirve `CLOUD_MODE_ROLLOUT_PERCENT = "100"`. Y el comentario que lo acompaña (`:125-129`) dice que está
así **desde el 2026-07-30** y que «NO es un valor de tránsito». Staging sirve `"100"` también
(`wrangler.toml:51`).

⇒ El comentario describe el estado de producción **al revés**, y lleva así mes y medio.

## Por qué importa, y no es cosmético

Ese comentario es lo que alguien lee para responder «¿puede un usuario real entrar a Modo Nube hoy?».
Dice que no. La respuesta medida es que **sí**: la fila de «Almacenamiento» es visible y cualquiera
puede lanzar la migración, que ejecuta el backfill de identidad con rebind por ancla
(`SyncIdentityService.swift:237-244`).

Salió al evaluar si un barrido que cambia el signo de transacciones viejas podía romper el rebind por
ancla. La pregunta «¿está esa puerta abierta?» se contestó con el comentario primero y con el
`wrangler.toml` después, y las dos respuestas no coincidían.

## Qué hay que hacer

1. Corregir el comentario para que diga lo que sirve el gateway, con su fecha.
2. Barrer si hay más comentarios que afirmen el percent viejo — un valor de configuración copiado a
   prosa envejece en cuanto alguien lo cambia, y este se cambió sin tocar el código que lo describe.
3. Considerar si el estado de las dos puertas debe leerse de un solo sitio en vez de narrarse.

## Criterio de hecho (AC)

- [ ] `StorageRowGateLogic` describe el percent que sirve producción de verdad, con fecha.
- [ ] Barrido de otras menciones al percent en comentarios, corregidas o retiradas.

## Medido en 2.1 (triage 2026-10-08)

- `StorageRowGateLogic.swift:10-12` sigue afirmando que el gateway sirve `CLOUD_MODE_ROLLOUT_PERCENT = "0"`; `gateway/wrangler.toml` sirve `"100"` en `:51` (staging) y `:127` (producción).
- Barrido hecho: es la única mención del percent viejo en `Yala/` y `gateway/src`, así que el segundo criterio se reduce a ese comentario.

Triage 2026-10-08: abierto · low → low · el comentario sigue diciendo 0 % con producción en 100 %; no lo ve ningún usuario, pero confunde a quien decide si algo es alcanzable.
