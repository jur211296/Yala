---
id: import-preview-hides-what-it-will-create
status: backlog
priority: low
area: "import"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H17 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# La vista previa no dice qué va a crear

**Versión propuesta: 2.4.** Baja, mejora: 2.4. La decide Jürgen. Card: `1j8u`.

## Qué ve el usuario

Categorías, etiquetas y transferencias sueltas aparecen después del import sin que la vista previa lo dijera.

## Evidencia

`ImportPreviewLogic.swift`: cuenta filas, cuentas, fechas, totales, 3 de muestra, filas malas y futuras. Nada de lo que crea ni de lo que queda por revisar.

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H17.

## Propuesta

Sección «Esto también se creará» (cuentas, categorías, subcategorías, etiquetas) y «A revisar» (transferencias sueltas, posibles duplicados, montos o fechas dudosos, líneas saltadas). Es donde viven las decisiones de los demás tickets del import.

## Criterio de hecho

- [ ] La vista previa de un archivo con categorías nuevas las lista antes de importar.
