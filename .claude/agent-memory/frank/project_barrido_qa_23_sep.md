---
name: barrido-qa-23-sep
description: El 23-sep la cola de device-QA bajó de 80 a 21 por orden de Jürgen; los 59 cerrados no se le vuelven a pedir, y qué queda esperando de él
metadata:
  type: project
---
El 2026-09-23 Jürgen mandó sanear `tickets/qa/` en vez de seguir con la cola A: de 80 tickets, **59 a `done`
sin device-QA** (`qa-status: not-replicable` o `absorbed`, cada uno con su «Barrido de `qa` · 2026-09-23») y
**21 se quedan** con un guion de un día en `qa/guion-tanda.md`, por bloques A–E y con la lista corta arriba.

**Why:** la cola crecía un ticket por PR (52 el 16-sep, 80 el 23) y casi todo pedía dos teléfonos, SQL o
esperas de horas. Lo que quiere es una lista que pueda recorrer, no un inventario.

**How to apply:**
- **No le pidas probar un ticket que salió en este barrido.** Si hace falta, se reabre con motivo.
- Un ticket nuevo que vaya a `qa` debe tener un camino de UN iPhone con Yala Dev; si no lo tiene, va a
  `done` con los tests, como el #223. Y se añade al guion, que desde hoy vuelve a cuadrar con la carpeta.
- `previous-person-cloud-session-survives-fresh-start-and-reinstall` espera al **próximo TestFlight**: su paso 4
  es instalarlo encima del 13 sin borrar y ver que la sesión de la nube sigue.
- Los guiones de los tickets citan botones que ya se llaman distinto («Restaurar mis datos» es hoy «Traer
  mis datos»). Al pasarle un guion, contrástalo con `Localizable.strings`. Ver [[la-premisa-del-encargo-tambien-se-mide]].
