---
name: apagar-una-voz-destapa-el-residual-de-la-otra
description: Cuando una superficie cede el sitio a otra, la que queda hereda la pantalla con SUS residuales — el spinner que mentía tapaba el hueco aceptado del aviso, y al quitarlo quedó silencio; mide los momentos de refresco de las dos antes de escribir «coinciden como mucho un tick»
metadata:
  type: feedback
---

**Si un cambio hace que A se calle cuando habla B, lista los momentos en que cada una se refresca y
recorre las transiciones que NO disparan los de B. Ahí está el hueco o la co-aparición, y lo que A
tapaba antes pasa a verse.**

**Why:** el 2026-09-17 (#189) el spinner «Descargando tus datos…» pasó a esconderse con el veredicto
de App Attest terminal para dejar solo el aviso del #177. Lo hice leer el veredicto vivo en su tick de
1 s, y escribí en el Paso 0 que spinner y aviso «coinciden como mucho un segundo». Era cierto cuando
el veredicto cambia por una ESCRITURA de la racha, que notifica. No lo era cuando cambia por el RELOJ
(las 24 h se cumplen con la app delante): nadie escribe, el aviso espera a su siguiente refresco y el
spinner ya se ha ido, así que no sale ninguno. Ese hueco ya era un residual aceptado del aviso; antes
lo tapaba el spinner con una mentira, y mi cambio lo convirtió en silencio. Lo cazaron las dos lentes
por separado.

**How to apply:**

- Antes de afirmar cuánto coinciden dos superficies, escribe sus disparadores de refresco (aquí:
  tick de 1 s frente a montar / notificación / volver a primer plano). Luego enumera los cambios de
  estado que no pasan por ningún disparador de la que queda: el reloj, el reloj hacia atrás, un
  escritor que no notifica.
- Para cada transición, di si deja un hueco (ninguna habla) o una co-aparición (hablan las dos), y
  elige a sabiendas. Aquí se prefirió el hueco breve: la alternativa, leer con el cableado del aviso,
  daba co-aparición, que era justo lo que el ticket pedía evitar.
- El residual heredado se escribe donde vive el residual original (la rule del área), no solo en el PR.

Relacionado: [[el-consumidor-lee-una-copia]] · [[mi-docblock-tambien-es-una-premisa]] ·
[[review-adversarial-caza-lo-mio]].
