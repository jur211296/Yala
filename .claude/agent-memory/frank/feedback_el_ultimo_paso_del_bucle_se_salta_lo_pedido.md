---
name: el-ultimo-paso-del-bucle-se-salta-lo-pedido
description: Un efecto que una iteración deja PEDIDO para «la vuelta siguiente» no ocurre si esa iteración era la última del bucle.
metadata:
  type: feedback
---

Si una página del bucle deja pedido algo que cumple «la vuelta siguiente», las salidas de «última página» y «página
vacía» tienen que mirar esa petición antes de terminar.

**Why:** 2026-10-18, entrega 1 de la tarjeta multidivisa. La subida de versión del manifest se cumplía al principio de
cada vuelta del bucle del pull; la página que la anunciaba solía ser la ÚLTIMA (menos filas que el límite) y el bucle
devolvía `.completed` sin cumplirla. En la verificación de una migración, el Merkle comparaba justo después con filas
que bajaron sin la columna. Lo cazó MI test (esperaba dos peticiones, hubo una); la review no lo había visto porque
miraba el `continue` que yo acababa de quitar por «cinturón».

**How to apply:** al añadir un efecto diferido a un bucle con varias salidas, recorre TODAS las salidas (no solo la
del final del cuerpo) y pon un test cuya respuesta única sea la que lo pide. Y antes de quitar un `continue` «que
sobra», pregunta qué salida evitaba. Relacionado: [[la-limpieza-por-si-acaso-enmascara-mutantes]].
