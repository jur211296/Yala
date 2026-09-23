---
id: groups-cursor-map-reads-an-undecodable-json-as-no-cursors
status: backlog
priority: medium
area: "grupos, modo-nube"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `groups-merkle-reads-an-unreadable-table-as-an-empty-one` (2026-09-23)"
---

# Si la app no entiende dónde se quedó con cada grupo, se los vuelve a bajar todos desde cero

## El problema, en lenguaje de usuario

La app apunta, por cada grupo, hasta dónde ha bajado ya los cambios del servidor. Si esa nota no se deja leer,
la app no dice «no sé dónde estaba»: da por hecho que **no ha bajado nada de ningún grupo** y, en el siguiente
pull o en la siguiente remediación, pisa la nota con una nueva que solo lleva los grupos de esa página. Los
demás grupos vuelven a bajar enteros. No se pierden datos, pero es tráfico y trabajo inventados sobre una avería.

## Por qué pasa (leído el 2026-09-23 en este árbol; no ejecutado)

Misma familia «no pude leer ≠ no hay nada», en el mapa de cursores del canal de Grupos:

1. `GroupsSyncClient.decodeCursors` (`:3176-3180`) decodifica con `try?` y devuelve `[:]` si falla — además
   incumple la regla de `CLAUDE.md` de no silenciar con `try?`.
2. El pull (`:2112`) arranca `maxSeqByGroup` de ese `[:]` y persiste el mapa sin los grupos que la página no trae.
3. `resetGroupCursors` (`:3412`) escribe `{gid: 0}` solo para los grupos que resetea: el resto pierde su cursor.
   Lo llaman la remediación Merkle y `reconcileLostMemberships`.
4. Y la mitad de escritura: `encodeCursors` (`:3182-3187`) devuelve `"{}"` si el encode falla (`try?`), que
   persiste un mapa vacío.

Los lectores que ya fallan cerrado con `[:]`: `pulledGroupIDs` (`:1163`, niega la evidencia de frescura),
`reconcileLostMemberships` (`:2293`, sin enumeración no borra ninguna zona) y `runGroupMerkleVerification`
(`:3257`, no hay grupos que verificar).

La corrupción es improbable (el JSON solo lo escribe `encodeCursors`), por eso `medium` y no `high`.

## Criterios de aceptación

- [ ] Un mapa de cursores que no decodifica NO se lee como «sin cursores» en el pull ni en `resetGroupCursors`:
      el pull no persiste encima y el reset no pisa los demás grupos.
- [ ] `encodeCursors` no persiste `"{}"` por un encode fallido.
- [ ] Rastro en producción de la avería.
- [ ] Tests con el JSON corrupto + control positivo; los tres lectores fail-closed siguen igual.

## Relacionado

- `groups-merkle-reads-an-unreadable-table-as-an-empty-one` — el Merkle de grupos, cerrado el 2026-09-23.
