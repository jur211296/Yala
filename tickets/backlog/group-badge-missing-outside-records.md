---
id: group-badge-missing-outside-records
status: backlog
priority: very-low
area: "grupos, registros"
created: 2026-11-02
updated: 2026-11-02
source: "review adversarial del encargo 2026-11-02-grupos-b-cabos-sueltos (card oibr), previo al cambio"
---

# Las filas de un gasto de grupo no dicen su grupo fuera de Registros

La cápsula con el nombre del grupo (y desde la card oibr, la de la entrada de una recarga) la pinta `RecordRowView` con el
catálogo que publica `.providesGroupNames()`. Solo lo lleva `RecordsTabView`. `GlobalSearchView` y
`CashFlowCellDetailSheet` usan la misma fila sin él: ahí una pata de grupo enseña la cuenta de sistema «Grupos PEN» y la
entrada de una recarga, su cuenta sin el grupo. Medido leyendo; sin captura.
