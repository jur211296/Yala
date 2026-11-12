---
id: import-runs-twice-on-the-main-thread
status: backlog
priority: medium
area: "import, performance"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H14 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# El import se hace dos veces y en el hilo principal

**Versión propuesta: 2.4.** Media hasta medir: 2.4. Si la medición da decenas de segundos con 3.000 filas, sube a alta y adelanta. La decide Jürgen. Card: `rh1i`.

## Qué ve el usuario

Con miles de filas, la app se congela al preparar la vista previa y otra vez al importar (inferido: no medido).

## Evidencia

Servicio `@MainActor` (`TransactionCSVImportService.swift:153`, `:1088`, `:1446`, `:1607`). La vista previa hace la importación entera aparte (`ImportPreviewService.swift:37-71`) y al confirmar se repite (`ImportIntroSheet.swift:684-698`). Por fila: dos consultas de categoría (`CategoryImportHelper.swift:115-122`) y, con etiquetas, todas las etiquetas más una (`:594-616`). Al final, todos los movimientos (`:235-238`).

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H14.

## Propuesta

Medir primero: test de rendimiento con 3.000 y 10.000 filas sintéticas. Después, diccionarios en memoria para categorías y etiquetas, leer y validar fuera del hilo principal, y reutilizar lo validado de la vista previa.

## Criterio de hecho

- [ ] Números antes y después en el ticket.
- [ ] 3.000 filas: la interfaz no se congela; la vista previa y el import, por debajo del umbral que se fije al medir.
