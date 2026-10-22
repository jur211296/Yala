---
name: barrido-qa-23-sep
description: Barridos de tickets/qa (23-sep 80→21, 28-sep 51→23); lo que salió no se le vuelve a pedir a Jürgen, y el ritmo al que la cola vuelve a crecer
metadata:
  type: project
---
El 2026-09-23 Jürgen mandó sanear `tickets/qa/` en vez de seguir con la cola A: de 80 tickets, **59 a `done`
sin device-QA** (`qa-status: not-replicable` o `absorbed`, cada uno con su «Barrido de `qa` · 2026-09-23») y
**21 se quedan** con un guion de un día en `qa/guion-tanda.md`, por bloques y con la lista corta arriba.

El 2026-09-28 (PR #291) se repitió como **rutina semanal**: la cola había vuelto a **51** en cinco días (28
nuevos, casi todos residuales de reviews adversariales de sync/wipe/migración). Bajaron 28, quedaron **23**, y
entró un bloque F («Vaciar datos» con grupos) que va el último porque vacía el iCloud de Yala Dev.

**Why:** la cola crece ~5 tickets por día de Cola A, y casi todo pide dos dispositivos, SQL o esperas de una
hora. Lo que quiere es una lista que pueda recorrer, no un inventario. A 2026-09-28 **aún no ha corrido
ningún bloque del guion**.

**How to apply:**
- **No le pidas probar un ticket que salió en un barrido.** Si hace falta, se reabre con motivo.
- Un ticket nuevo que vaya a `qa` debe tener un camino de UN iPhone con Yala Dev; si no lo tiene, va a
  `done` con los tests. Y se añade al guion, que desde cada barrido vuelve a cuadrar con la carpeta.
- **Los guiones «inferidos del código» de los tickets mienten a veces.** El 28-sep, dos `fresh-start-*`
  decían que «Vaciar datos» vuelve a la bienvenida; con sesión privada va al onboarding personal
  (`DestructiveScopeLogic.wipeLanding`). Antes de meter un paso al guion, mide a qué pantalla lleva.
- Contrasta los botones del guion con `Localizable.strings` (y `.stringsdict`) en cada barrido.
- `previous-person-cloud-session-survives-fresh-start-and-reinstall` espera la subida 13 → 14 de TestFlight
  sin borrar. Ver [[la-premisa-del-encargo-tambien-se-mide]].
