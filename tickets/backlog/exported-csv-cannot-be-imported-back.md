---
id: exported-csv-cannot-be-imported-back
status: backlog
priority: medium
area: "export, import"
created: 2026-10-18
updated: 2026-10-18
source: "medido en la entrega 4 de la tarjeta con varias divisas (`multi-currency-accounts-4-reports-and-export`), al comprobar su criterio «reimportar ese CSV sigue funcionando»"
---

# El CSV que exporta Yala no se puede volver a importar en Yala

## Qué ve el usuario

Exporta sus movimientos desde Ajustes con las columnas que vienen marcadas y, al importar ese mismo fichero, Yala
dice que la cabecera no es válida. Para que entre tiene que volver a exportar desmarcando «Cuenta», «Total original»
y «Porción», que nadie le dice que estorban.

## Lo medido (2026-10-18, origin/2.2 `0a752eb06`)

- El export escribe por defecto `date,amount,currency,account,category,subcategory,tags,note,split_total,split_portion`
  (`ExportColumns.default`, todas las columnas; `TransactionsExportModels.swift`).
- El import exige la cabecera **exacta** `date,amount,currency,category,subcategory`, con `tags` y `note` opcionales al
  final (`TransactionCSVImportService.swift:316-331` y su gemelo multidivisa `:1295-1307`). Cualquier otra columna, o
  el mismo conjunto en otro orden, cae en `ImportError.invalidHeader`.
- La columna `card` que añade la entrega 4 solo sale si el usuario tiene una tarjeta con líneas, y cae en el mismo
  rechazo que `account`: no lo empeora, pero tampoco lo arregla.

## Qué haría falta decidir

Si el import debe leer por NOMBRE de columna e ignorar las que no conoce (lo robusto, y lo que haría que una columna
nueva del export no vuelva a romperlo), o si el export debe ofrecer un preajuste «para volver a importar». La primera
toca los dos caminos del import (CSV y XLSX, simple y multidivisa) y sus tests.

## Criterio de hecho

- [ ] Exportar con las columnas por defecto e importar ese fichero funciona; test de ida y vuelta.
- [ ] Un CSV con una columna desconocida se importa ignorándola.
