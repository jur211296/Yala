---
name: reference-artifact-publico-con-muchas-imagenes
description: Compartir públicamente un artifact falla si lleva demasiadas imágenes insertadas (600 logos); se arregla con una lámina única y pares antes/después en una sola imagen.
metadata:
  type: reference
---

Medido el 17-nov (artifact «Logos de comercios»): con ~610 imágenes `data:` (un logo por comercio y cada captura
aparte), el diálogo Compartir de claude.ai dejó «Cualquier persona con el enlace» elegido pero dijo que la versión
«tiene más imágenes insertadas de las que se pueden revisar para compartir públicamente», y `artifact-publico
comprobar` siguió dando «privado». Con 7 imágenes (todos los logos en UNA lámina JPEG usada como `background-image`
con `background-position` por celda, y cada antes/después en una sola imagen) se compartió a la primera.

**How to apply:** un artifact con muchas miniaturas se arma con lámina (sprite) desde el principio; el umbral exacto no
está medido. Relacionado: [[reference-artifact-publico-lo-frena-el-clasificador]].
