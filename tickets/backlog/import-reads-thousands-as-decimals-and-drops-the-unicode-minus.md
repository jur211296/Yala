---
id: import-reads-thousands-as-decimals-and-drops-the-unicode-minus
status: backlog
priority: high
area: "import"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H1 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# Importar lee el separador de miles como decimal y pierde el signo «−»

**Versión propuesta: 2.2.** Cifra financiera equivocada en silencio: alta por `docs/criterios-de-version.md` §2, bloquea la salida. La decide Jürgen. Card: `jvgc`.

## Qué ve el usuario

Un extracto con «1,500» o «1.500» entra como 1,50; «1.234.567» como 1,23; «−12,50» (el signo de Numbers y de algunas webs de banco) entra como ingreso. Ni la vista previa ni el resumen lo avisan.

## Evidencia

`normalizeAmountString` (`TransactionCSVImportService.swift:840-884`) toma como decimal el último `,` o `.`; `parseDecimal` (`MoneyParsing.swift:56-57`) filtra todo lo que no sea `0-9 . ,` y se lleva el U+2212. Medido con las dos funciones copiadas tal cual.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H1.

## Propuesta

Decidir el separador decimal por archivo (si alguna fila trae decimales, ése manda en todo el archivo). Un `1,500` o `1.500` sin más pistas va como fila dudosa en la vista previa con la lectura propuesta. «−» y «–» cuentan como signo.

## Criterio de hecho

- [ ] Tests con la tabla medida de la auditoría (H1): miles sin decimales, `1.234.567`, «−», y los que ya funcionan siguen igual.
- [ ] Un archivo con `1,500` sin decimales en ninguna fila sale en la vista previa como dudoso, no importado en silencio.
- [ ] Las cuatro rutas (CSV y Excel, simple y multidivisa) pasan por el mismo cambio.
