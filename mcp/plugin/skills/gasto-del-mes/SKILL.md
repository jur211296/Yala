---
name: gasto-del-mes
description: Cuánto ha gastado el usuario de Yala en un periodo y en qué. Úsala con «¿cuánto llevo gastado este mes?», «¿en qué se me va el dinero?» o para comparar un mes con el anterior.
---

# Gasto del mes

1. Llama a `resumen_periodo` con `periodo: "mes_actual"`. Si el usuario compara, llama también con `"mes_pasado"`.
   Pasa `zona_horaria` si conoces la del usuario.
2. Da primero la cifra: gastos, ingresos y neto del periodo, en la divisa que devuelve la herramienta.
3. Explica el gasto con `top_categorias_gasto` y `top_comercios_gasto`: las tres primeras bastan.
4. Si el usuario pregunta por una categoría o un comercio concreto, baja al detalle con `buscar_movimientos`
   (`categoria` o `texto`, con `desde` y `hasta` del mismo periodo).
5. Si la respuesta trae `avisos`, cuéntalos en una frase: dicen cuándo una cifra es aproximada o qué no está sumado.

Terminado: el usuario tiene la cifra del periodo, de dónde sale, y cualquier aviso que la matice.

Las cifras son de Yala y se presentan tal cual. Describir el gasto está dentro; recomendar productos financieros
o inversiones, fuera: si lo pide, dile que eso es cosa de un profesional.
