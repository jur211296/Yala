---
id: xlsx-with-inline-text-cannot-be-opened
status: backlog
priority: medium
area: "import"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H3 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# Un Excel con el texto dentro de cada celda no se abre

**Versión propuesta: 2.2.** Flujo con salida (guardar otra vez), media; barata y es el caso real de Jürgen: 2.2. La decide Jürgen. Card: `7wh5`.

## Qué ve el usuario

«No pudimos abrir el archivo de Excel», también con el archivo real de Jürgen (`Yala_Registros_27-oct-2026_con-transferencias.xlsx`, escrito con openpyxl). Abrirlo y guardarlo en Excel lo arregla, pero nadie lo sabe.

## Evidencia

`XLSXReader.swift:61-63` exige `sharedStrings.xml`; la cabecera (`:79-81`) solo lee esa tabla, aunque las filas ya leen el texto en línea (`:199-200`). Medido en el caso real: sin esa tabla, todas las celdas `inlineStr`. Vecinos: solo la primera hoja (`:66-71`); la fecha de Excel solo se convierte en la columna 0 (`:210-216`).

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H3.

## Propuesta

Sin tabla compartida, seguir con una vacía y leer el texto en línea también en la cabecera. Convertir la fecha en la columna `date` (no en la 0). Con varias hojas, la primera con cabecera reconocible.

## Criterio de hecho

- [ ] Test con un `.xlsx` de `inlineStr` generado en el propio test: se lee igual que uno con tabla compartida.
- [ ] El caso real pasa de «no se puede abrir» al error de cabecera (o a importarse, si ya entró `exported-csv-cannot-be-imported-back`).
