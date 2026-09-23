---
name: merkle-grupos-tabla-ilegible
description: PR del 23-sep — el Merkle de grupos ya no lee una tabla ilegible como vacía; ticket nuevo del mapa de cursores.
metadata:
  type: project
---

Cerrado el 2026-09-23 (cola A, noche): `groups-merkle-reads-an-unreadable-table-as-an-empty-one` a `done` sin device-QA.
La review de tres lentes no encontró defectos de comportamiento; solo endurecimiento de tests.

**Why:** gemelo en Grupos de `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (personal). Con él, la familia
«no pude leer ≠ no hay» queda cerrada en apply, danglers, drain y Merkle de los dos canales.

**How to apply:** el siguiente gemelo vivo de la familia en Grupos es `groups-cursor-map-reads-an-undecodable-json-as-no-cursors`
(medium). Lo que se DESCARTÓ sin ticket: un remoto con `entities: {}` —inferido, el servidor emite las cinco tablas—.
