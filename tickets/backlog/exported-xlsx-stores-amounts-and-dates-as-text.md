---
id: exported-xlsx-stores-amounts-and-dates-as-text
status: backlog
priority: very-low
area: "export"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H19 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# El Excel exportado guarda importes y fechas como texto

**Versión propuesta: 2.4.** Muy baja, cosmética del export: 2.4, al tocar el área. La decide Jürgen. Card: `a90i`.

## Qué ve el usuario

En Excel no se pueden sumar los importes sin convertirlos antes.

## Evidencia

`XLSXWriter.swift:201` y `:213`: toda celda es texto compartido (`t="s"`). En el caso real, 2.742 de 2.749 importes son texto.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H19.

## Propuesta

Importe como número y fecha como fecha de Excel; el import ya lee los dos.

## Criterio de hecho

- [ ] Abrir el export en Excel y sumar la columna de importes funciona sin convertir.
