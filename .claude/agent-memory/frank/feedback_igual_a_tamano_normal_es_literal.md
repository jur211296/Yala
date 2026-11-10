---
name: igual-a-tamano-normal-es-literal
description: «a tamaño normal se ve igual» es al píxel, también en estados poco vistos (botón desactivado); si una API nueva del sistema los cambia, se fuerza el aspecto de antes
metadata:
  type: feedback
---

Cuando una card dice «a tamaño normal nada cambia», Jürgen lo quiere al píxel, incluido un estado que casi no se ve (el
«Guardar» desactivado). El 2026-11-05 la barra nativa (`safeAreaBar`) atenuaba ese texto de 164 a 129 y le propuse
aceptarlo como «el tono del sistema»: interrumpió y pidió mantener la barra y forzar el gris de antes cuando no hay texto
grande.

**Why:** el arreglo era para texto grande; que cambie lo de tamaño normal es un efecto colateral que no pidió.

**How to apply:** en un cambio de accesibilidad, mide con diff de píxeles CADA estado de la pantalla (vacío, desactivado,
completo), no solo el de la captura principal; si el sistema impone un cambio, recupera el aspecto previo en la rama de
tamaño normal antes de preguntar. Relacionado: [[regresion-se-mide-contra-lo-publicado]].
