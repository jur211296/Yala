---
id: csv-import-silently-swallows-rows-and-only-reads-utf8
status: backlog
priority: medium
area: "import"
created: 2026-10-29
updated: 2026-10-29
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
