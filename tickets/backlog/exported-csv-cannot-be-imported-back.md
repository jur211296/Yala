---
id: exported-csv-cannot-be-imported-back
status: backlog
priority: medium
area: "export, import"
created: 2026-10-18
updated: 2026-10-29
source: "medido en la entrega 4 de la tarjeta con varias divisas (`multi-currency-accounts-4-reports-and-export`), al comprobar su criterio «reimportar ese CSV sigue funcionando»"
---

# El CSV que exporta Yala no se puede volver a importar en Yala

**Versión propuesta: 2.2** (antes, 2.4 por el roadmap). Es H4 de la auditoría del import (`docs/import/AUDITORIA-IMPORT-2-2.md`,
2026-10-29): barata, y la base de todo el paquete de ida y vuelta. **Va con `reimported-group-legs-become-transfers`**: en
cuanto el export vuelva a entrar, sin ese ticket las patas del puente de Grupos se reimportarían como transferencias.
La decide Jürgen.

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

## Ampliación (auditoría del import, 2026-10-29)

**Decisión que este ticket toma** (la que quedaba abierta arriba): leer la cabecera **por nombre**, en cualquier orden,
ignorando las columnas desconocidas. No un preajuste del export: el usuario puede reordenar y quitar columnas, y cada
columna nueva del export volvería a romperlo.

Lo que añade la auditoría:

- **Excel igual que CSV**: `XLSXReader.swift:84-97` tiene la misma cabecera fija. Y la fecha de Excel solo se convierte
  en la columna 0 (`:210-216`): con columnas por nombre, en la columna `date`.
- **La validación existe cuatro veces** (CSV simple `TransactionCSVImportService.swift:358-538`, CSV multidivisa
  `:1265-1413`, Excel vía `validateAndCreateDraft` `:649-735`). Este ticket la deja en un solo sitio: las cuatro rutas
  leen a un `RawImportRow` común y validan igual. Los demás arreglos del import (montos, fechas, transferencias) se
  hacen después una sola vez.
- **Error de cabecera útil**: si falta una columna obligatoria, decir cuál; las que sobran se nombran en la vista previa
  («la columna `card` no se usa»).
- **Las columnas que el export escribe y el import aún no usa** (`account`, `card`, `split_total`, `split_portion`) se
  aceptan y se ignoran. Usarlas es de otros tickets: `import-account-column-by-name`,
  `export-import-carry-record-kind-and-transfer-pair`.
- **El caso real** (`Yala_Registros_27-oct-2026_con-transferencias.xlsx`) además necesita
  `xlsx-with-inline-text-cannot-be-opened`.

Criterio de hecho añadido:

- [ ] Un archivo con las columnas obligatorias en otro orden se importa igual.
- [ ] El mismo test de ida y vuelta, en CSV y en Excel.
