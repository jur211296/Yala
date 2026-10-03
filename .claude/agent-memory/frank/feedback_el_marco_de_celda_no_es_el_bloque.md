---
name: el-marco-de-celda-no-es-el-bloque
description: Para medir dónde cae un bloque de List en pantalla, píxeles de la captura; los marcos de celda de XCUITest y el diff «a ojo» mintieron el 3-oct.
metadata:
  type: feedback
---

Para saber dónde empieza un bloque de una `List` agrupada, mido en los píxeles de la captura (bordes en una fila
concreta) y comparo antes/después al píxel. Los marcos de `app.cells` de XCUITest no sirven: antes del arreglo
de `YalaSettingsList` daban celdas de todo el ancho (x=32…1101) mientras el sistema recortaba el bloque a 400…1101.

**Why:** el 2026-10-03 la primera sonda dio «bloque=1222» mezclando la barra lateral de detrás de la hoja, y la
segunda daba marcos que no coincidían con lo pintado. Lo que destapó el fallo (bloque pegado a la columna, 0 pt)
fue escanear la fila «Solo gastos» en la PNG. El mismo diff al píxel cazó que `safeAreaPadding` movía 2 pt las filas
del iPhone en vertical, y que la cabecera de Tutoriales ya salía cortada en el SE en `2.1`.

**How to apply:** en cualquier encargo de ancho/margen del carril adaptativo: sonda XCUITest solo para navegar y
capturar; la medida, con PIL sobre la captura girada; y el «iPhone no cambia» se demuestra con
`ImageChops.difference` contra la tanda «antes», ignorando la barra de estado. Ver [[sin-cambios-visibles-se-mide-al-pixel]].
