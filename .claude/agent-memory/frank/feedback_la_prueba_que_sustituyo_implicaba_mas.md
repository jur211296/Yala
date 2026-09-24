---
name: la-prueba-que-sustituyo-implicaba-mas
description: Al aceptar una prueba ALTERNATIVA a otra, enumera lo que la vieja garantizaba DE HECHO por su orden o su momento, no solo lo que afirmaba — el marcador implicaba «llegaron las identidades».
metadata:
  type: feedback
---

**Una prueba que sustituye a otra tiene que cubrir también lo que la vieja garantizaba sin decirlo.**
El 2026-09-24 (PR #240) di al adopt una segunda prueba de linaje: «alguna fila viva de la cuenta está
en local», la misma que ya guarda el relevo. Medí bien lo que el marcador AFIRMABA (este corpus es de
esa cuenta) y la sustituta lo cubría. No medí lo que el marcador IMPLICABA por su momento: se exporta
DESPUÉS de las identidades que el líder asignó, así que traerlo era traerlas. Con la exportación del
líder parada —justo el caso del ticket— la cuenta se compartía (`shortcutID` nace con la fila) y los
movimientos seguían sin `syncID`: el backfill los subía **duplicados**. Lo cazó la lente del
dispositivo legítimo; mis tests no, porque todos sus fixtures tenían las identidades ya puestas.

**Why:** la prueba vieja parecía una comprobación de identidad y en realidad era también un testigo de
«la cola de iCloud llegó hasta aquí». El daño de olvidarlo no era un bloqueo, era un libro duplicado.

**How to apply:** antes de aceptar una prueba alternativa, pregunta «¿qué más era cierto siempre que
la vieja pasaba?» (orden de exportación, momento del ciclo, quién la escribe) y exige eso aparte, con un
test cuyo fixture NO lo traiga de serie. Relacionado: [[el-mecanismo-que-reuso-trae-sus-precondiciones]],
[[review-adversarial-caza-lo-mio]].
