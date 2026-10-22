---
id: tag-chips-change-order-on-every-launch
status: backlog
priority: low
area: "records, tags"
created: 2026-09-30
source: "diff al píxel del iPhone en `ipad-and-duo-panel-and-statistics-use-the-width` (capturas antes/después)"
updated: 2026-10-08
---

# Las etiquetas de un registro cambian de orden en cada arranque

## Qué ve el usuario

Un registro con dos etiquetas las enseña como «Trabajo · Urgente» en un arranque y como «Urgente · Trabajo» en el
siguiente. Con más de tres, cuáles se ven y cuáles van al «+N» también cambia.

## Lo medido (2026-09-30)

- Dos arranques del mismo árbol con `-uitest-seed realista` en `YalaLane-Adapt-iPhone-SE`: la fila «Supermercados y
  bodegas» de Estadísticas › Registros sale con las etiquetas en orden distinto (capturas `se__antes__v-07` y
  `se__despues__v-07`, 7.252 px de diferencia justo en los chips; el resto de la pantalla, igual al píxel).
- Causa, leída en el código: `TagDisplayResolver.resolve(ids:catalog:limit:)`
  (`Yala/App/Logic/Helpers/TagDisplayResolver.swift:73`) recorre un `Set<UUID>` (`resolvedTagIDs`) con `compactMap`
  y, con `limit`, se queda con el `prefix`. El orden de un `Set` cambia entre procesos (semilla de hash por arranque).

## Hecho cuando

- El orden de las etiquetas de un registro es estable entre arranques (p. ej. por nombre, o por el orden del
  catálogo), en todos los sitios que usan `TagDisplayResolver` (filas de Registros, detalle, bandeja, favoritos,
  planificados).
- Con más de `limit` etiquetas, las que se enseñan son siempre las mismas.
- Test de `TagDisplayResolver` que fija el orden.

## Medido en 2.1 (triage 2026-10-08)

- `TagDisplayResolver.resolve(ids:catalog:limit:)` sigue haciendo `ids.compactMap { catalog[$0] }` sobre un `Set<UUID>` y luego `prefix(limit)`, sin ordenar. Su docblock incluso dice «display order is not guaranteed». El fichero no tiene commits desde el 2026-09-30.

Triage 2026-10-08: abierto · low → low · sigue pasando (Set sin ordenar en TagDisplayResolver); es incómodo y cambia qué etiquetas se ven, pero no toca ningún dato.
