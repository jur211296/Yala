---
name: la-review-y-los-mutantes-no-comparten-arbol
description: Dos fallos de proceso míos del 12-sep — una lente leyó un fichero MUTADO y reportó el mutante como defecto grave, y escribí dos scripts de parche que nunca ejecuté y di por aplicados
metadata:
  type: feedback
---

**Una review adversarial y una tanda de mutantes no pueden correr sobre el mismo árbol, y un script
de parche escrito no es un script de parche aplicado.** Los dos me pasaron el 2026-09-12, en la misma
sesión, y los dos producen conclusiones falsas que parecen sólidas.

**Why:**

- **La lente leyó el mutante.** Lancé tres lentes sobre `qa/scripts/sim-libre.sh` mientras una
  batería de mutantes lo estaba mutando y revirtiendo cada dos minutos. Una lente reportó, como
  hallazgo grave y con cita de línea, que «el comentario promete un invariante que el código no
  implementa» y que un `if` era inalcanzable. **Las dos cosas eran el mutante M5**, no el código. Se
  refutó en un minuto leyendo el fichero real, pero un hallazgo así invita a «arreglar» algo que ya
  estaba bien — o peor, a desconfiar del resto de la cosecha, que sí era buena (diez defectos míos).
- **Escribí `numeros.py` y `lente3.py`, no los ejecuté, y seguí como si sí.** Las dos veces me
  interrumpió una notificación de tarea de fondo justo entre el `Write` y el `Bash`. Lo descubrí una
  hora después, cuando un `assert` de otro parche falló buscando texto que «ya debía estar». Durante
  esa hora escribí encima de un fichero que creía actualizado.

**How to apply:**

- **Congela el árbol para la review.** Copia los ficheros a revisar a un directorio aparte y pásale
  ESAS rutas a las lentes — que es lo que hice para dos de las tres, y por eso solo una se confundió.
  Si una lente tiene que mirar el repo vivo (para grepear, contar, comprobar punteros), entonces no
  se corren mutantes a la vez: una cosa o la otra.
- **Un parche no está aplicado hasta que su salida lo dice.** El patrón `Write` → `Bash` se rompe en
  cuanto llega una notificación. Escribe el script y **ejecútalo en el turno siguiente sin nada en
  medio**; si algo se cruza, vuelve a mirar si se ejecutó antes de seguir.
- **El síntoma barato de que un parche no se aplicó**: un `assert` posterior que no encuentra el
  texto que «ya debía estar». No lo trates como un cambio de contexto — mira primero si el parche
  anterior corrió.
- Y la razón por la que esto se nota tarde: **mis parches son idempotentes y con `assert`**, así que
  no fallan al aplicarse dos veces ni corrompen nada. Eso es bueno, pero también significa que
  **no ejecutarlos no da ningún error**. Es la familia del «cero casos con exit 0».

Relacionado: [[review-adversarial-caza-lo-mio]] · [[cola-del-simulador]] ·
[[mutante-compilado-zanja-hipotesis]] · [[revertir-sin-commit-destruye]]

**Lo que funcionó el 2026-09-25 (#243):** copiar los ficheros limpios y el diff al scratchpad y decirle a cada lente
«no leas estos dos del árbol: están aquí». Las tres revisaron con la tanda corriendo y ninguna leyó un mutante. Y si la
review cambia el código, la tanda se para y se repite ENTERA sobre el final: los mutantes de antes miden otro código.
