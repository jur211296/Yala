---
name: sin-cambios-visibles-se-mide-al-pixel
description: «A tamaño por defecto, sin cambios» se prueba con diff píxel a píxel antes/después, no mirando capturas; el ojo dio por bueno un cambio que truncaba texto en el SE
metadata:
  type: feedback
---

**Cuando un encargo dice «cero cambios visibles a tamaño X», la prueba es un `magick compare -metric AE` de cada
fotograma antes/después, con control positivo y negativo del comparador.** Mirar las capturas no basta.

**Why:** el 2026-09-28 (`iphone-large-text-sizes-break-layouts`) revisé a ojo el ProMax y lo di por idéntico. El
diff del SE sacó que la tarjeta de grupo truncaba el nombre («Viaje a Cu…») y una fila partía otra palabra: el
`HStack` anidado que yo había metido repartía distinto el ancho con compresión. En el ProMax, con holgura, no se
veía. La regla del código quedó en `.claude/rules/swiftui-ds.md`; esto es el método.

**How to apply:**
- Compara los PNG originales, no los JPG reducidos, y recorta lo que pinta el sistema (indicador de inicio abajo).
- Las diferencias que quedan se clasifican una a una con `-connected-components`: scroll distinto tras deslizar,
  animaciones, barra de pestañas minimizada, buscador desplegado. Si una cifra se repite IGUAL en dos corridas, no
  es ruido del scroll: míralo.
- El dispositivo estrecho es el que delata; si solo hay tiempo para uno, el SE.

Relacionado: [[mis-mediciones-fallan-por-el-filtro]] · [[el-diseno-que-no-puedo-medir-no-es-el-diseno]].
