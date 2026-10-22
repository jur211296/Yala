---
id: groups-canal-sin-capability-set
status: backlog
priority: medium
area: "groups, cloudsync, gateway"
created: 2026-09-07
updated: 2026-10-08
source: hallazgo de la review adversarial de groups-budget (2026-09-07)
---

# El canal de Grupos no manda `X-Yala-Capability-Set`, así que cada columna nueva apaga el Merkle del parque viejo

## El hueco

El canal **personal** manda `X-Yala-Capability-Set: v1` en el pull y en el merkle
(`SyncPullClient`, `SyncMerkleClient`), y el gateway **poda** las columnas que ese cliente no conoce
(`gateway/src/sync/manifest.ts`, `projectRowToDelta`). Así, añadir una columna al manifest personal no
cambia lo que ve un cliente viejo.

El canal de **Grupos** no lo manda —`GroupsMerkleClient` lo documenta explícitamente— y su
`merkleColumnsGroup` devuelve `Object.keys(spec.columns)` del manifest, con `canonValueFor` emitiendo
`null` para las columnas ausentes. ⇒ **una columna nueva cambia el root de TODAS las filas**, también las
que no la traen, y un cliente con el contrato anterior calcula un root distinto para el 100 % de sus
grupos.

## Lo que costó la primera vez, y lo que se hizo en su lugar

`groups-budget` (g14_01, 2026-09-07) fue **la primera columna que se añade al manifest de Grupos desde
su commit inicial**, así que nadie había pagado el precio todavía. Sin mitigación, el parque no
actualizado habría entrado en divergencia falsa permanente: canario de divergencia quemado,
`resetGroupCursors` + re-pull completo una vez por sesión y por usuario — el reset de cursor que
`.claude/rules/swiftdata-cloudkit.md` (L151) declara dañino por tres vías.

La mitigación aplicada fue **bumpear `canon_version` a `c2`**, que hace caer a esos clientes en el guard
de canon de `verifyGroupIntegrity` y **saltar** la verificación en vez de remediar algo que no está roto.
Funciona y es barata, pero tiene un coste: mientras convivan las dos versiones, el Merkle de Grupos está
**apagado** para todos —los viejos por el guard, y los nuevos también hasta que el gateway se despliegue—,
y esa red no vuelve sola: hay que acordarse de que se recupera cuando el parque converge.

## Qué habría que hacer

Portar el mecanismo del canal personal:

1. Mandar `X-Yala-Capability-Set` desde `GroupsSyncClient` (pull) y `GroupsMerkleClient` (merkle).
2. Podar por versión en `gateway/src/groups/` — `merkleColumnsGroup` y `projectGroupRowToDelta` ya tienen
   sus gemelos en `src/sync/` como molde.
3. Con eso, la próxima columna de Grupos deja de necesitar un bump de canon y deja de apagarle el Merkle
   a nadie.

## Y la red que falta al lado

No existe para Grupos el equivalente de `CloudCapabilityManifestParityTests`, que en el canal personal
cruza el manifest con `supabase-staging.ddl`. **Nada comprueba que una columna del manifest de Grupos
exista de verdad en el DDL.** En g14_01 se acertó a mano; la próxima no tiene red — y ese test habría
convertido «staging no tiene la columna» en un rojo local en vez de en un dead-letter en un teléfono.

## Medido en 2.1 (triage 2026-10-08)
- El header solo lo mandan `SyncPullClient.swift:169` y `SyncMerkleClient.swift:100`; `GroupsMerkleClient.swift:10,85` documenta que no.
- `merkleColumnsGroup` (`gateway/src/groups/canon.ts:82-86`) sigue devolviendo todas las columnas del manifest.
- El guard de canon sigue en `c2` (`GroupsSyncClient.swift:3786`): la próxima columna exigirá otro bump.
- No hay test que cruce `group_capability_manifest.json` con el DDL: `gateway/test/manifest.sync.test.ts` solo compara la copia con la SSOT.

Triage 2026-10-08: abierto · medium → medium · Nada cambió desde g14_01: el cliente de Grupos no manda X-Yala-Capability-Set, el gateway no poda y no hay test de paridad manifest de Grupos vs DDL.
