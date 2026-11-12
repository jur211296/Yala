---
id: group-split-line-entry-reads-as-a-loose-transfer-in-records
status: done
priority: low
area: "grupos, registros"
created: 2026-11-01
updated: 2026-11-02
source: "review del encargo 2026-11-01-grupos-b-puente-y-estadisticas (Grupos B · card 2)"
---

# La entrada de una recarga de tu parte se ve en Registros como una transferencia suelta

Cuando partes tu parte con una recarga (Pía te recarga 500 a Sip), el puente apunta la salida en «Grupos» y la entrada
en Sip. La entrada no lleva puntero de grupo a propósito (D4 del ticket `grupos-tu-parte-en-lineas`), así que en
Registros:

- no lleva la insignia del grupo (`RecordRowView` la pinta por `splitGroupZoneID`), y el botón «abrir el grupo» del
  editor cae a la lista de Grupos;
- con «Incluir movimientos de grupos» apagado, la salida se oculta y la entrada se ve sola (`BridgedTransactionFilter`).

No cambia ninguna cifra: las transferencias no cuentan en Estadísticas, presupuestos ni Yala IA. Es lectura. La entrada sí
está bloqueada como del puente (no se edita ni se borra suelta) y su detalle dice que se borra desde el grupo.

## Hecho (2026-11-02, encargo `2026-11-02-grupos-b-cabos-sueltos`, card oibr)

La entrada dice su grupo por su salida (mismo `transferPairID`): `GroupSplitLineEntryGroupLogic`. Registros le pinta la
cápsula del grupo (`GroupNameCatalogProvider` publica también la zona por par) y la lee VoiceOver; con «Incluir movimientos
de grupos» apagado se oculta con su salida (`RecordsViewModel.applyFilters`). Sin cambio de modelo ni de cifras. El «abrir el
grupo» del editor sigue cayendo a la lista de Grupos (no lo pedía la card).
