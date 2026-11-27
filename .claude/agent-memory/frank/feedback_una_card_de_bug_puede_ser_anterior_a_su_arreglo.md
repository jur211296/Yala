---
name: una-card-de-bug-puede-ser-anterior-a-su-arreglo
description: Antes de perseguir un bug de una card, compara cuándo nació la card con el commit que ya lo arregló; el tablero no se cierra solo
metadata:
  type: feedback
---

Una card de bug del tablero puede ser **anterior** al arreglo que ya entró: Tim la crea con el reporte de Jürgen y
nadie la mueve cuando el PR aterriza. El encargo la trae como «bug abierto» y con el tono de un hecho.

**Why:** 27-nov-2026, sesión de trabas. «Convertir a compartido un registro leído de imagen no se marca» venía en el
encargo con «reprodúcelo y confirma la causa». La card ya estaba en el tablero el 20-nov a las 13:53 (lo dijo una
copia del tablero en `~/Claude/tmp-frank/r14/tab.txt`) y el arreglo (`a3823b34b1`, «lo convertido a gasto compartido
queda marcado como guardado») entró a las 19:53 de ese día. En el simulador, con uno y con dos leídos, no se reproducía.
`tablero ver --json` no da la fecha de creación: hay que buscarla en copias o en transcripts.

**How to apply:** antes de montar la reproducción, `git log --format="%h %ad %s" -- <ficheros del flujo>` y busca un
`fix(...)` del mismo síntoma posterior al reporte. Si existe, la reproducción sigue siendo obligatoria (el encargo la
pide), pero la hipótesis de partida es «ya arreglado» y el entregable útil es la prueba del caso que no estaba cubierto.
Relacionado: [[la-premisa-del-encargo-tambien-se-mide]].
