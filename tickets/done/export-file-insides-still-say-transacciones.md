---
id: export-file-insides-still-say-transacciones
status: done
priority: very-low
area: "export, copy, l10n"
created: 2026-10-19
updated: 2026-10-25
source: "lote decidido 2.2 · 03 (L20-4), visto fuera de lo decidido"
---

# Por dentro, el Excel sigue diciendo «Transacciones» y el archivo de grupos lleva la hora en cifras

## Qué ve el usuario

Desde L20-4 el archivo se llama `Yala_Registros_17-oct-2026.xlsx`, con la palabra y la fecha en el idioma de la app. Al
abrirlo en Excel, la pestaña de la hoja se llama «Transacciones» en todos los idiomas (`XLSXWriter.swift`, `<sheet
name="Transacciones" …>`), y el archivo de «Incluir mis grupos» y el de solo grupos siguen como
`Yala_Grupos_20261017_093512.csv` (`GroupsExportBuilder.swift`).

## Por qué no se tocó

La decisión de Jürgen nombra el archivo, no la pestaña ni el de grupos. Es el mismo criterio (lo que la persona busca,
con sus palabras), así que conviene decidirlo junto: pestaña con `l20d.export.fileStem` del idioma y
`Yala_Grupos_<fecha legible>` con `ExportRecordsLogic.fileName`.

## Hecho cuando

La pestaña del Excel y el archivo de grupos usan las palabras y la fecha del idioma de la app, con test.

## Resuelto (lote 12.4, 2026-10-25)

- La pestaña del Excel se llama con la palabra del archivo en el idioma de la app (`l20d.export.fileStem`: «Registros», «Records», «Einträge», «记录»…), limpia de lo que Excel rechaza (`[]:*?/\`, más de 31 caracteres) y escapada en el XML. La plantilla de importación hereda el mismo nombre.
- El CSV de grupos se llama `Yala_Grupos_17-oct-2026.csv` con `ExportRecordsLogic.fileName` (palabra `groups.title` y fecha del idioma), como el de Registros.
- Lo fija `ExportFileInsidesTests` (XML de la pestaña, nombre válido en los 16 idiomas, nombre del CSV y orden de en-US).
