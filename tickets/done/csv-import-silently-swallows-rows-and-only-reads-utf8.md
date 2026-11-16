---
id: csv-import-silently-swallows-rows-and-only-reads-utf8
status: done
priority: medium
area: "import"
created: 2026-10-29
updated: 2026-11-12
source: "auditoría del import 2.2 (sesión S27j), H13 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# Una comilla suelta se traga filas y el CSV solo se lee en UTF-8

**Versión propuesta: 2.4.** Media (pérdida silenciosa en un caso estrecho): tema del import, 2.4. La decide Jürgen. Card: `6gh7`.

## Qué ve el usuario

Una nota como `Tele de 50" nueva` hace que las filas siguientes desaparezcan dentro de esa nota, sin error. Una línea sin separador se salta sin contarla. Un CSV guardado por Excel en Windows (Windows-1252) no se lee. El tabulador no vale como separador.

## Evidencia

`splitCSVIntoRows` (`TransactionCSVImportService.swift:975-1006`) cambia de estado con cualquier `"`; medido: cuatro filas se leen como dos, y las comas de más se pegan a la nota (`:401-408`). Líneas sin separador: `:372-374`. Solo UTF-8: `:292`, `:1032`, `:1220` (medido con Windows-1252). Separadores: `:822-831`.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H13.

## Propuesta

Al partir filas, una comilla solo abre al principio del campo (como ya hace `splitCSVFields`, `:931-971`). Contar en la vista previa las líneas saltadas. Si UTF-8 falla, probar Windows-1252. Detectar el tabulador.

## Criterio de hecho

- [ ] Test con la nota de la comilla suelta: las cuatro filas entran.
- [ ] Test con un CSV en Windows-1252 y otro separado por tabuladores.

## Hecho (2026-11-12)

- [x] Una comilla solo abre un campo al principio del campo, también al partir filas (`TransactionCSVImportService.splitCSVRows`). La nota `Tele de 50" nueva`: entran las cuatro filas (`ImportCSVReadingRobustnessTests.strayQuote_keepsEveryRow`, y de punta a punta `ImportExportFidelityTests.strayQuoteAndTotal_endToEnd`).
- [x] Una comilla de apertura sin cierre, o que se «cierra» con la de otra fila más abajo, ya no se traga las filas de en medio (hallazgo de la review): `unterminatedQuote_*`.
- [x] Una línea con texto y sin separador ya no se salta: sale en «filas que no entraron» con su número, que es la línea física del archivo (las líneas en blanco ya no desplazan el número).
- [x] CSV en Windows-1252, UTF-16 con BOM y Latin-1; un UTF-8 con un byte roto sigue leyéndose como UTF-8: `windows1252`, `utf16AndUtf8`, `mostlyUTF8_withOneBadByte`.
- [x] Tabulador como separador, sin desplazar celdas vacías al principio o al final: `tabSeparated`.
- [x] Mutantes: quitar cada arreglo tumba su test.
- [x] QA en el simulador: antes entraba 1 de 4 movimientos sin avisar (`antes-1.png`); después entran los 4 y «Fila 6: no la pudimos leer porque no tiene columnas» (`despues-1.png`). El CSV de Excel en Windows: antes «No pudimos leer el archivo» (`antes-2.png`), después la vista previa con sus tildes y miles (`despues-2.png`). Evidencia en `~/Claude/entregas/2026-11-12-importar-exportar-sin-perder-datos/evidencia`.
