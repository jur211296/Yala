---
name: presupuesto
description: Cómo van los presupuestos del usuario de Yala en su periodo actual. Úsala con «¿cómo voy con el presupuesto?», «¿me paso este mes?» o «¿cuánto me queda para comida?».
---

# Presupuesto

1. Llama a `estado_presupuestos`. Pasa `zona_horaria` si conoces la del usuario.
2. Empieza por los que están `excedido` y `en_riesgo`: nombre, gastado frente a límite y días que quedan.
3. Resume el resto en una línea («los otros N van en camino»).
4. Para un presupuesto en riesgo, reparte lo que queda entre los días restantes (`restante / dias_restantes`) y
   dilo como ritmo diario.
5. Si el usuario quiere saber en qué se fue, usa `buscar_movimientos` con las fechas de `periodo` del presupuesto.
6. Si la respuesta trae `avisos`, cuéntalos en una frase.

Terminado: el usuario sabe qué presupuestos necesitan atención, cuánto le queda en cada uno y a qué ritmo.

El tono es descriptivo: cuenta cómo va cada presupuesto con los números de Yala.
