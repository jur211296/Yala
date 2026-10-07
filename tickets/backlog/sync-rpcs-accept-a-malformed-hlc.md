---
id: sync-rpcs-accept-a-malformed-hlc
status: backlog
priority: low
area: "modo-nube, sync, backend"
created: 2026-10-07
updated: 2026-10-07
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

Desde `qa/cloud/hlc01_cap_future_hlc.sql` (pendiente de aplicar) el trigger `cap_future_hlc` reescribe un valor mal
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
