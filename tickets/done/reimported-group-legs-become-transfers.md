---
id: reimported-group-legs-become-transfers
status: done
priority: high
area: "import, groups"
created: 2026-10-29
updated: 2026-11-12
card: tablero-fallos-altos-hoja-de-exito-en-blanco-al-hq7p
source: "auditoría del import 2.2 (sesión S27j), H5 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# Al reimportar, las patas del puente de Grupos entran como transferencias

**Versión propuesta: 2.2.** Abre una cifra equivocada en cuanto entre la lectura por nombre: tiene que ir con ella, en 2.2. La decide Jürgen. Card: `l2g9`.

## Qué ve el usuario

Hoy no se alcanza, porque el archivo exportado no entra. En cuanto entre (`exported-csv-cannot-be-imported-back`), un «Préstamo a grupos» o una «Liquidación enviada» reimportados caen en una cuenta real, con tipo transferencia: salen de gastos e ingresos y la heurística puede emparejarlos. El reparto (`split_total`, `split_portion`) se pierde.

## Evidencia

El import trata como transferencia toda subcategoría `isAnySystem` que no sea el ajuste (`TransactionCSVImportService.swift:220-228`); las del puente son `isSystem` (`CategorySeed.swift:707-734`, `GroupBridgeSystemEntities.swift:23-49`) y el resolutor las encuentra por nombre (`CategoryImportHelper.swift:115-122`). El reparto se exporta como texto para leer (`TransactionsExportService.swift:697-716`). Inferido del código; el caso real trae una fila así.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H5.

## Propuesta

El import no crea patas del puente: una fila con subcategoría del puente se deja fuera y la vista previa lo dice («N movimientos de grupos no se importan: se recrean desde el grupo»). `split_total` y `split_portion` se aceptan y se ignoran.

## Criterio de hecho

- [ ] Test: exportar con un gasto de grupo, importar ese archivo, y la pata del puente no se crea; la vista previa la cuenta.
- [ ] Las columnas de reparto no rompen la lectura.

## Ya estaba arreglado (verificado el 2026-11-12)

Lo cerró el commit «feat(import): columnas por nombre, cuenta por fila, Excel en línea y montos por archivo; Grupos
fuera» (29-oct, decisión de Jürgen de ese día), y está en `1.0` (lo publicado) y en `2.3`. La ficha se quedó en backlog
por descuido. Lo que hace hoy el import:

- `ImportGroupRowFilter` reconoce por NOMBRE, en los 16 idiomas y con los nombres viejos, las categorías «Grupos» y
  «Cobros de grupos», las siete subcategorías del puente y la cuenta interna de Grupos, ANTES de resolver nada: esas
  filas no entran ni crean su categoría.
- Lo resuelto también: una entidad de sistema del puente con un nombre que la lista no conoce sale igual
  (`TransactionCSVImportService`, `category.isSystem || subcategory.isSystem`).
- La vista previa las cuenta («Movimientos de Grupos que no se importan: N»), y `split_total` y `split_portion` se
  aceptan como columnas ignoradas.

**Criterio de hecho, los dos puntos:** `ImportRoundTripAndAccountsTests` exporta a CSV y a Excel con una pata del puente,
importa el archivo en un teléfono vacío y comprueba que la pata no se crea, que se cuenta (`groupRowCount == 1`) y que
las columnas de reparto se ignoran. Con el filtro por nombre desactivado (mutante), el caso cae. No se tocó código.
