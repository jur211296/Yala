---
id: pdf-pages-render-without-a-pixel-ceiling
status: backlog
priority: low
area: stability
created: 2026-11-12
updated: 2026-11-12
source: encargo 2026-11-12-memoria-produccion-yala-ios-b (review adversarial)
---

# Las páginas de un PDF se pintan sin techo de píxeles

`PDFPageImport.render` pinta cada página al doble de su `mediaBox`, sin tope. Un PDF hecho a partir de una foto, con el
`mediaBox` en píxeles (p. ej. 8064×6048 pt), se pintaría a 16128×12096: unos 780 MB por página, y hasta diez por tanda.
Inferido por lectura del código, no medido: falta comprobar qué `mediaBox` produce «Crear PDF» de Archivos con una foto.

Arreglo probable: acotar el tamaño de render al mismo lado mayor que `PhotoIntake.currentIntakeMaxEdge()`. Con test de
memoria pintada como `PhotoIntakeTests.paintedPhotosStaySmall`.
