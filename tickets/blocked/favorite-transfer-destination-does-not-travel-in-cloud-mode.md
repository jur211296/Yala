---
id: favorite-transfer-destination-does-not-travel-in-cloud-mode
status: blocked
priority: low
area: "favorites, cloud-sync"
created: 2026-10-22
updated: 2026-10-25
source: lote decidido 2.2 · 02, sesión A (L2-14)
---

# El destino de un favorito de transferencia no viaja por el Modo Nube

## Qué pasa

Desde 2.2 un favorito de transferencia guarda origen y destino (`FavoritePayment.destinationAccount`, L2-14). El destino
viaja por iCloud (campo `CD_destinationAccount`, ver `docs/despliegue-cloudkit-2-2.md`), pero **no por el Modo Nube**:
`EntityEmissionMap.favoritePayment` no lo emite y la tabla `favorite_payments` de Supabase no tiene columna para él.

Para quien usa la nube: un favorito de transferencia creado en un teléfono llega al otro **sin destino**. Al usarlo, el
formulario pone el origen y deja el destino vacío, y la línea de encima de «Guardar» dice que falta. Es el mismo trato que
un favorito de transferencia guardado antes de 2.2. No se pierde dinero ni se crea nada de más.

## Por qué no se hizo en la sesión A

Llevarlo a la nube pide DDL en Supabase (columna `destination_account_ref`), el manifest con `since` y `manifest_version`
nuevo (`.claude/rules/swiftdata-cloudkit.md`, regla de la columna nueva del Modo Nube), Worker y despliegue en staging y
producción. Esa sesión no desplegaba backend.

## Qué hay que hacer

- DDL `favorite_payments.destination_account_ref uuid` en staging y producción.
- `capability_manifest.json`: la columna con `since: <versión>` y `manifest_version` +1; `supabase-staging.ddl` al día.
- `EntityEmissionMap.favoritePayment` y `EntityApplyMap`: emitir y aplicar la ref (con dangler, como `account_ref`).
- Orden de despliegue: DDL → Worker → app.

## Acceptance Criteria

- [ ] Un favorito de transferencia creado en un teléfono en la nube llega al otro con su destino.
- [ ] Un teléfono con la app anterior no recibe la columna (proyección por versión del manifest).

## Lote 12.2 (2026-10-25): el código está; falta desplegar

Hecho en el repo: `capability_manifest.json` v4 con `destination_account_ref` (`since: 4`), `supabase-staging.ddl`, DDL
`qa/cloud/g24_01_favorite_destination.sql` + `g24_01_rollback.sql`, emisión y aplicación con dangler, reemisión al subir de
versión (`SyncCapability.noteSuppressedFavoriteDestination`) y el remap de identidad de la cuenta destino. Tests:
`FavoriteDestinationSyncTests` y los del gateway (`manifest.capability`, `config`; 552/552 en local).

**Bloqueado en el despliegue**, que esta sesión no hace (nada en Supabase de producción): g24_01 en staging y producción →
Worker v4, pasos en `docs/RUNBOOK-staging-ddl.md`. Hasta entonces la app declara v3 y el destino no viaja (como hoy).

Residual aceptado: lo apuntado para la reemisión va por `syncID`, que en favoritos es identidad acuñada; si una
re-identificación (linaje, restauración del relevo) cae entre el apunte y la subida de versión, ese destino no se reemite.
