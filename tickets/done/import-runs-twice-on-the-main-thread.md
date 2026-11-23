---
id: import-runs-twice-on-the-main-thread
status: done
priority: medium
area: "import, performance"
created: 2026-10-29
updated: 2026-11-22
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

## Hecho (2026-11-22, lote 1 de Importar registros)

Medido primero (`ImportarLote1MedicionTests`, gateado con `YALA_MEDIR_IMPORT=1`). Cambios:

- El archivo se lee una vez: la tabla leída en la vista previa se reutiliza en el import (`PendingImport.table`).
- La vista previa ya no crea los movimientos para tirarlos: solo valida (`insertsTransactions: false`).
- Categorías, subcategorías de sistema y etiquetas se resuelven una vez por import (`ResolutionCache`).
- **Todo sigue en el hilo principal, a propósito.** Leer el archivo cuesta 0,03 s con 3.000 filas (medido) y sacarlo
  obligaba a desaislar el lector, el de Excel y los errores del import (el proyecto aísla al hilo principal por
  defecto). Insertar y guardar en un contexto de fondo es un patrón que hoy no usa ningún servicio, y el `rollback()`
  del import depende de no suspenderse. Lo que congelaba era el doble import y las consultas por fila: resuelto.

Medido en el simulador (iPhone 17 Pro, iOS 27.2, Mac mini), store en memoria, test `ImportarLote1MedicionTests`
(`TEST_RUNNER_YALA_MEDIR_IMPORT=1`), archivo sintético con la forma del caso real (dos años, diez categorías, etiquetas en
una de cada diez filas).

| | 3.000 filas antes | 3.000 filas después | 10.000 antes | 10.000 después |
|---|---|---|---|---|
| Leer el archivo | 0,03 s | 0,03 s | 0,09 s | 0,09 s |
| Vista previa | 2,44 s | 0,21-0,33 s | 12,9 s | 0,73-0,79 s |
| Importar (insertar + guardar) | 2,94 s | 1,08 + 0,32 s | 13,5 s | 10,6 + 1,06 s |
| Vista previa al reimportar (todo duplicado) | — | 0,32-0,52 s | — | 1,0 s |
| Deshacer (borrar por tandas de 100-250) | — | 5,6 s en tandas | — | 36,9 s en tandas |


Umbral fijado: con 3.000 filas, vista previa < 1 s e import < 2 s en el simulador. Se cumple. Con 10.000 filas el
insertado sigue tardando ~10 s en el hilo principal y borrar miles crece más que lineal: tickets aparte
(`import-of-ten-thousand-rows-still-blocks-the-main-thread`, `deleting-thousands-of-records-saves-slower-than-linear`).

- [x] Números antes y después en el ticket.
- [x] 3.000 filas: la interfaz no se congela; la vista previa y el import, por debajo del umbral que se fije al medir.
