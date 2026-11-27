---
name: atribuir-render-con-interruptores
description: Para saber qué pieza cuesta pasadas fuera de pantalla, una sola build con interruptores por argumento y quitar de uno en uno; el coste no es aditivo.
metadata:
  type: feedback
---

Medir el render pieza por pieza con una compilación por variante cuesta ~10 min cada una. Lo que funcionó (lote 5 de
eficiencia, 26-nov): todos los candidatos en una copia de perfilado, cada uno con un interruptor temporal
(`-perfTempRenderViejo <pieza>`) que lo devuelve a como estaba, y una pasada corta (Panel + Registros, 3 rondas, ~4 min)
por variante. Retirar los interruptores antes del PR.

**Why:** el coste no se suma. Quitar la sombra de la fila sola no movía nada, quitar el cristal del FAB solo tampoco
del todo, y sin los dos Registros volvía de 18 a 52: cada cristal encima recalcula las sombras de debajo. Atribuir
añadiendo piezas a la base vieja habría descartado las que importan.

**How to apply:** atribuir QUITANDO de uno en uno desde el conjunto completo; después medir el conjunto mínimo que se
va a entregar antes de dar por buena la elección. La mediana del Panel varía ±5 entre corridas iguales: lo que no mueve
más que eso es ruido.
