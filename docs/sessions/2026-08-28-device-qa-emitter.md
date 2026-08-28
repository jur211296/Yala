# Sesión 2026-08-28 — QA device del emisor en segundo plano (Grupos)

Sesión de **cierre por QA**, no de implementación. Solo el PASS del owner. Sin build nuevo, sin subida,
sin tocar `A7`/`M5`.

Ticket: `tickets/done/groups-background-emitter-no-upload.md`.

## Lo que corrió el owner (Jurgen, Lima)

Dos teléfonos en el mismo grupo, con el binario de campo **TF 2.1 build 12**:

- **Teléfono A** (emisor): crea un gasto de grupo y se va al **Home de iOS**. **Sin force-quit**.
- **Teléfono B** (receptor): en el feed del grupo. A **no se vuelve a abrir** en ningún momento.
- **Resultado**: el gasto apareció en B en **~30 s**. Veredicto del owner: **PASS**.

Ese es el caso que abrió el ticket: apuntar el gasto y guardar el teléfono. Antes el gasto no salía del
emisor hasta que el emisor reabría Yala.

## Qué significa y qué no

**Es QA, no un fix nuevo.** El código ya estaba en el árbol de `2.1` vía
[PR 19](https://github.com/jur211296/Yala/pull/19) (merge `b9526c8e`, head `c1577137`); esta sesión no
toca Swift. Lo único que faltaba era este PASS en device, pendiente desde el 2026-08-18.

**No hubo subida a TestFlight hoy**, así que no hay PASS sobre ningún build posterior al 12. Los ~30 s
son una medición del caso dominante, no una distribución.

## Qué cambió en disco

- Ticket a `tickets/done/` con `status: done`, `updated: 2026-08-28` y su sección de owner check.
- `docs/TICKETS.md`: fila y mapa de origen apuntando a `done/`, counts in-progress 10 → 9 y done 3 → 4
  (total 63, es un movimiento) y la nota de cierre. Los counts están **recontados sobre disco** tras
  rebasar sobre `2.1`, que ya trae el alta de `fx-partial-rate-rows-silent-1to1` (backlog 28, total 63).
- Esta nota.
- **Sin cambios bajo `Yala/`** ⇒ no aplica tocar `qa/coverage-index.json`.
- Sin cambios en `docs/ESTADO.md` ni en `docs/modo-nube/`: su lectura de `D-R1` sigue como estaba y este
  cierre no la reescribe.
