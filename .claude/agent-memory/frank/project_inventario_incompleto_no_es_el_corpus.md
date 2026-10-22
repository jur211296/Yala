---
name: inventario-incompleto-no-es-el-corpus
description: PR del 23-sep (cola A nocturna): los inventarios de la migración y el backfill ya no leen una tabla ilegible como vacía; qué quedó fuera y por qué.
metadata:
  type: project
---

Ticket `an-incomplete-inventory-reads-as-the-whole-corpus`, a `done` sin device-QA (una base ilegible no se provoca en
un iPhone). Cierra la serie «lectura local fallida ≠ vacío» por el lado de la migración, tras outbox (#211) y Merkle
(#219).

**Why:** en la ida, el adopt y la vuelta a iCloud, una tabla que no se dejaba leer se daba por subida, apagaba el guard
anti-fusión del adopt o cerraba la vuelta con `.drained`.

**How to apply:** lo que queda abierto de la familia vive en tres tickets nuevos, y dos de ellos esperan una decisión
de producto de Jürgen:
- `adopt-effect-retries-forever-with-no-ceiling`: el adopt en `.transient` no tiene techo ni tarjeta. Pide decidir el
  techo, el texto y la salida.
- `reverse-upload-unreadable-sample-waits-the-long-ceiling`: plazo y texto de la vuelta con la base ilegible. También
  es producto.
- `two-silent-local-reads-leave-a-false-or-no-trace`: cinco lecturas que solo fallan en el rastro. Es técnico y low.
- El gemelo `groups-cursor-map-reads-an-undecodable-json-as-no-cursors` seguía en backlog, fuera de alcance.
