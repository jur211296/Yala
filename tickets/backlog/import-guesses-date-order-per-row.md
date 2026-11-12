---
id: import-guesses-date-order-per-row
status: backlog
priority: medium
area: "import, dates"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H10 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# La fecha se adivina fila a fila

**Versión propuesta: 2.4.** Media (población: archivos con formato de EE. UU. o zonas UTC+12/13): tema del import, 2.4. La decide Jürgen. Card: `wsgn`.

## Qué ve el usuario

«03/04/2026» de un banco de EE. UU. entra el 3 de abril; «10/27/26» entra en el año 26; «27/10/99» se descarta como futura. En Nueva Zelanda en verano, cada fecha entra un día después. La plantilla, con calendario budista, sale con fechas de 2569 que se descartan.

## Evidencia

`TransactionCSVImportService.swift:745-817`: con `/` siempre día/mes; los formatos de respaldo aceptan `/` también; el año de dos cifras solo se corrige en la ruta de `/`; la fecha se guarda a las 12:00 UTC. Plantilla: `ImportIntroSheet.swift:426-429` sin calendario. Medido con `parseDate` copiada tal cual.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H10.

## Propuesta

Orden día/mes por archivo (si alguna fila lo decide, manda; si no, el del idioma del teléfono, y la vista previa lo enseña). Años de dos cifras en todas las rutas. Mediodía local, no UTC. Plantilla con calendario gregoriano.

## Criterio de hecho

- [ ] Tests con las fechas medidas en la auditoría (H10).
- [ ] Una fecha importada en `Pacific/Auckland` se ve el mismo día.
