---
id: import-guesses-date-order-per-row
status: done
priority: medium
area: "import, dates"
created: 2026-10-29
updated: 2026-11-22
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

## Hecho (2026-11-22, lote 1 de Importar registros)

- `ImportDateLogic`: el orden día/mes se decide **por archivo** (un número mayor que 12 decide; si el archivo se
  contradice o no decide nada, el orden del idioma del teléfono, y la vista previa lo enseña con un ejemplo: «Las fechas
  se leen como mes/día, el orden de tu teléfono: 03/04/2026 es el 4 mar 2026»). Años de dos cifras en todas las rutas
  (`/`, `-`, `.`), con el siglo que deja la fecha en el pasado. Días que no existen (31/02) son fecha inválida.
- La fecha se guarda al mediodía **local**, en gregoriano; `ImportRecordFieldsLogic.combine` lee el día en la zona del
  teléfono. Una fila es futura por día (hoy sin hora entra aunque aún no sea mediodía).
- Plantilla con calendario gregoriano y `en_US_POSIX`.
- Pruebas: `ImportarLote1LogicaTests` (las fechas medidas en la auditoría: 03/04/2026 con archivo de EE. UU., 10/27/26,
  27/10/99, ISO con hora, Auckland) y `ImportarLote1ImportTests` (de punta a punta en Pacific/Auckland y Lima).

- [x] Tests con las fechas medidas en la auditoría (H10).
- [x] Una fecha importada en `Pacific/Auckland` se ve el mismo día.
