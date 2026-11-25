---
id: 2026-11-25-gateway-d1-overloaded-vincular-suscripcion
status: done
priority: high
area: "gateway, entitlement, d1"
created: 2026-11-25
updated: 2026-11-25
source: "Sentry YALA-GATEWAY-2, -3 y -4 (24-nov 21:15 Lima) · card del tablero «Gateway en producción: D1 DB is overloaded al vincular la suscripción»"
---

# Gateway: «D1 DB is overloaded» al vincular la suscripción

El 24-nov a las 21:15 Lima (25-nov 02:15:26–27 UTC) el gateway de producción devolvió 500 a tres peticiones con
`D1_ERROR: D1 DB is overloaded. Requests queued for too long.`:

| Issue | Ruta | Dónde cayó |
|---|---|---|
| YALA-GATEWAY-3 | `POST /account/entitlement` | la lectura del estado en la rama «sandbox en producción» (compra de TestFlight) |
| YALA-GATEWAY-4 | `GET /account/entitlement` | la lectura del estado |
| YALA-GATEWAY-2 | `GET /mail/drafts` | `listDrafts` |

## Causa (medida)

- Las tres comparten **una traza**: es una sola apertura de la app que lanzó las tres peticiones en 0,8 s. No hubo
  ráfaga de vinculaciones ni reintentos de la app.
- El Worker recibía **~10 peticiones por minuto** (GraphQL `workersInvocationsAdaptive`: 4 en el minuto 02:15).
- Las métricas de la base (`d1AnalyticsAdaptiveGroups`) **no registran ninguna consulta en 02:14–02:15**: las sentencias
  se quedaron en la cola de Cloudflare y no llegaron a ejecutarse.
- Todas las consultas de la ruta van por clave primaria (`user_id`) o índice único (`original_transaction_id`), y la
  escritura ya era un solo batch idempotente.
- La página de estado de Cloudflare no publicó incidente de D1 esa hora.

⇒ saturación pasajera de D1 en la plataforma, no carga nuestra ni consulta lenta. Nadie perdió Pro: la app trata el
5xx como pasajero y conserva el derecho guardado.

## Hecho cuando

- Una saturación breve de D1 no llega al usuario en `/account/entitlement`: se reintenta con tope.
- Si persiste, la respuesta es 503 con `Retry-After`, no un 500 genérico, en cualquier ruta.
- La vinculación queda una sola vez aunque se reintente, y un reintento no resucita una suscripción revocada.
- Tests en `gateway/test/d1-overloaded/`.

## Resolución

- `gateway/src/d1-reintento.ts`: `conReintentoD1` reintenta solo la familia «cola saturada» (3 intentos, backoff
  exponencial con jitter completo, peor caso ~300 ms) y `esD1Saturada` la reconoce también en `cause`.
- `gateway/src/sync/entitlement.ts`: el GET y las lecturas del POST van con reintento; el bind reintenta su secuencia
  D1 ENTERA (leer → decidir → escribir → leer), así cada intento vuelve a ver revocaciones del webhook.
- `gateway/src/index.ts`: `app.onError` convierte la saturación en 503 `yala_unavailable` con `Retry-After: 2` en
  todas las rutas (cubre `/mail/drafts`), y la manda a Sentry como aviso con una sola huella (`d1-saturada`).
- Tests: `gateway/test/d1-overloaded/` (20 casos, D1 de SQLite con el error inyectado). Dos mutantes comprobados:
  reintentar solo el batch y quitar el 503 ponen rojos 2 casos cada uno.

## Despliegue

- **Staging (2026-11-25, 06:31 Lima):** versión `74034dfa`, sobre lo que ya corría (`bd180561`, manifest v9, que va por
  detrás de 2.3) + solo el parche de bundle de este cambio. Verificado: el script vivo es byte a byte el parcheado;
  `/healthz` y `/config` 200; `GET` y `POST /account/entitlement` con el usuario de prueba A → 200. La saturación no se
  puede provocar en staging: la cubren los tests. Vuelta atrás: `wrangler rollback bd180561`.
- **Producción:** la despliega Dan (pasos en el PR). Después, resolver YALA-GATEWAY-2, -3 y -4 en Sentry.
