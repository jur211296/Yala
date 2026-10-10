---
id: sync-rpcs-accept-a-malformed-hlc
status: done
priority: low
area: "modo-nube, sync, backend"
created: 2026-10-07
updated: 2026-10-08
source: "medido al cerrar `personal-clock-ahead-wins-every-conflict-until-real-time-catches-up` (2026-10-07), sonda REST contra staging"
---

# Los RPC de sync aceptan cualquier texto como HLC

## El problema

`apply_pref` guardó `hlc = 'zz'` sin quejarse (staging, usuario de test A, key `zz_hlc_probe_20261007`, 2026-10-07
06:18 UTC). Como el LWW compara texto, `'zz'` ordena por encima de cualquier HLC c1 y esa preferencia ya no la cambia
nadie. Inferido sin medir: `apply_delta` y `apply_group_delta` tampoco validan el formato (comparan con `>` y
guardan el valor tal cual; el de Grupos se lee en `supabase-groups-staging.ddl:970`).

Ningún cliente nuestro manda un HLC mal formado: `HLC.description` siempre da los 46 caracteres c1. El riesgo es un
cliente futuro con un bug, o alguien que llama al RPC directo por PostgREST con su JWT (solo daña sus propios datos,
o los de su grupo).

## Lo que ya lo acota

Desde `qa/cloud/hlc01_cap_future_hlc.sql` (aplicada en staging y producción el 2026-10-07) el trigger `cap_future_hlc` reescribe un valor mal
formado que ordene por encima de `now() + 60 s` como `<tope>-0000-0000000000000000`, y la normalización de esa misma
migración arregla la key de la sonda. Lo que queda: un valor mal formado que ordene por DEBAJO (`'0'`, `''`) se guarda
y pierde contra todo, en silencio.

## Qué habría que decidir

- ¿Validar el formato c1 en el trigger y rechazar (`raise`) lo que no lo cumpla? El cliente lee un rechazo como
  dead-letter: hay que mirar qué hace cada canal con él antes.
- ¿O validarlo en el gateway, que ya valida la forma del delta?

## Criterios de aceptación

- [ ] Decisión escrita.
- [ ] Un HLC que no cumple el formato c1 no se guarda, en los tres RPC.

## Medido en 2.1 (triage 2026-10-08)

- El ticket nació en el mismo commit que `hlc01` (`a1b7297c5`) y describe una versión anterior del trigger. La que se aplicó (verbatim en `supabase-staging.ddl:482` y en el de Grupos, `e616ec41a`) sustituye **cualquier** valor que no sea c1 por `<tope>-0000-0000000000000000` **sin mirar su orden**, en `hlc`, `deleted_hlc` y cada `field_hlcs`, con 22 triggers `cap_future_hlc` en los tres canales.
- `qa/cloud/hlc01-cap-test.sql` fija justo el resto que el ticket daba por vivo: «prefs: un mal formado que ordena por DEBAJO también se sustituye (sin mirar su orden)», con `hlc = '0'`.
- La decisión que pedía el primer criterio está escrita en la cabecera de `hlc01_cap_future_hlc.sql`: se reescribe, no se rechaza («nada se rechaza ni va a dead-letter»). Solo `''` y `null` pasan tal cual, a propósito: `''` es el valor que la rama de tombstone de `apply_group_delta` escribe.

Triage 2026-10-08: resuelto · low → — · hlc01, aplicada en staging y producción, ya sustituye cualquier HLC que no sea c1 sin mirar su orden, y un test lo fija.
