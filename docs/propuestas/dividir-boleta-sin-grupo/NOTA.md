# Maquetas: dividir una boleta por foto sin crear grupo (26-nov-2026)

Artifact para decidir (público): https://claude.ai/artifact/CyoMRjwBhUNefJG9SdA59z
Card «Espera decisión» de Jürgen en el tablero de Yala 2.3: «Elegir: dividir una boleta sin crear grupo (maquetas)».
La decisión se guarda en la base del artifact (`decisiones/dividir-boleta`: `flujo`, `imagen`, `version`, `nota`).

- `index.html`: la página publicada (iPhone 14, claro y oscuro, ejemplos almuerzo de 4 con 7 líneas y pareja con 3).
- `maquetas-claro.jpg`, `maquetas-oscuro.jpg`: la página entera tal como se ve en el artifact.

## Recomendación

**A en 2.3** («Dividir una boleta»: botón largo bajo Cámara, Fotos y Archivo, y bajo la fila de Grupos; nombres al
vuelo; por igual o por líneas; registrar mi parte o mandarla a la Bandeja en Yala completo; solo compartir en «solo
grupos») con la imagen **«Me deben»**. **C en 2.4** (cuenta del día guardada, quién ya pagó, enlace a «tu parte»).
B («entre N» sin líneas) queda como respaldo si 2.3 no admite ~2 sesiones más.

## Medido en `2.3`

- Leer la boleta y calcular no dependen de un grupo: `ReceiptSplitService.readPhoto` / `readNote` y
  `ReceiptSplitLogic.shares(_:memberIDs:)` (céntimos enteros; el céntimo que sobra va al primero).
- La revisión sí pide miembros guardados: `GroupCaptureModel(members: [SplitMember])`, y `SplitMember` es un `@Model`.
  Es el cambio principal de A: aceptar personas temporales.
- Propina, servicio e impuestos llegan sin incluir (`ReceiptExtraShare`, decisión del 2026-11-05).
- Imagen compartible existente: `GroupShareableSummaryCard` (colores fijos, pie «Hecho con Yala»).
- Entrada: `ImageSelectionView.sourceTiles` (Cámara, Fotos, Archivo) y `GroupQuickActionsRow` (Grupos).
- Cupo: rutas `receipt.photo` / `receipt.voice` del gateway, 5 al día Free y 50 Pro, aparte de las fotos personales.
