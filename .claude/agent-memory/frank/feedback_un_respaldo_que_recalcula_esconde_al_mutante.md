---
name: un-respaldo-que-recalcula-esconde-al-mutante
description: Si la función bajo prueba tiene un respaldo que recalcula lo que falta, comparar solo resultados no caza que falte: compara también el estado intermedio
metadata:
  type: feedback
---

Una prueba de paridad que compara solo el resultado final no ve un dato intermedio perdido si el código tiene un
respaldo que lo recalcula y da lo mismo. Lote 8 (27-nov): el mutante «cada tanda de tasas pisa a las anteriores» en
`BalanceValuation.LecturaDeTasas` salió VERDE, porque `value()` pide sola la tasa de un día que no se leyó y da el mismo
número. Cayó (9 de 9) al comparar además las tasas leídas, día a día.

**Why:** el respaldo hace que el bug no cambie la cifra en la prueba, pero sí el coste (una consulta por día): justo lo
que el cambio venía a quitar.

**How to apply:** en un cambio de rendimiento que precarga o reparte trabajo, la paridad compara también lo precargado
(o cuenta las llamadas al respaldo), no solo la cifra. Antes de dar por buena una prueba, el mutante tiene que ponerla
roja. Relacionado: [[mutantes-se-revierten-por-texto]].
