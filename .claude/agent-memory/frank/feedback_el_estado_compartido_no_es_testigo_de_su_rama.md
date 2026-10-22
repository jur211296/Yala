---
name: el-estado-compartido-no-es-testigo-de-su-rama
description: Un campo de estado que varias ramas escriben no puede servir de testigo de UNA de ellas — lo apaga cualquiera de las otras y el falso negativo es invisible; cómo medirlo antes de apoyarse en él
metadata:
  type: feedback
---

Antes de usar un campo de estado como testigo de «está pasando X», **cuenta quién lo escribe**. Si
lo escriben varias ramas, no describe a ninguna: describe **la última que pasó por ahí**.

**Why:** el 2026-09-21, en `leaving-and-reentering-restore-renews-the-hard-cap`, apoyé el testigo de
«el import sigue bajando» en `iCloudSyncService.status.isImporting`. Lo midió una lente de la review
y el reparto era demoledor: **lo enciende UN sitio y lo apagan TRECE**, entre ellos el terminal de un
export cualquiera y el `.idle` con que se traga un error transitorio. `status` es un escalar único
que comparten import, export y setup. Consecuencia medida: un export de diez segundos en el minuto 0
de una bajada de siete minutos deja `isImporting == false` los **6 m 50 s** restantes — el terminal
del import que sigue bajando no vuelve a `.importing`, va a `promoteToIdleOrStalled`.

Y el falso negativo era exactamente el bug del ticket hermano: quien volvía a Restaurar a los siete
minutos con su descarga viva heredaba un reloj caducado y la app le decía que sus datos eran de otra
persona.

**How to apply:**

- **Cuenta escritores antes de leer**: `grep -n "<campo> = " <fichero>` y mira cuántas ramas
  distintas lo tocan. Un ratio 1:13 no es un testigo, es una casualidad.
- **El docblock del campo miente por omisión.** El de `status` describe lo que significa cada valor,
  no quién lo pisa. Esa segunda pregunta la contesta el grep, no la prosa.
- **Si el campo es compartido y aun así lo necesitas, no lo uses solo.** El arreglo fue un segundo
  término —un sello con fecha propio del import— y una frescura lo bastante ancha para cubrir los
  huecos que el escalar deja. Los dos juntos, cada uno con su test y su mutante.
- **El control positivo del test tiene que afirmar el pisado**, no solo el resultado: mi test del
  export afirma primero `#expect(!servicio.status.isImporting)` — si el escalar dejara de ser
  compartido, ese caso deja de medir lo que dice y quiero enterarme.
- Y el corolario general: **medir la premisa con el bool pasado a mano prueba la función, no el
  mundo**. El test que «cubría» esto pasaba `isImportingNow: true` a mano, o sea asumía la
  conclusión. Los dos casos que lo cazaron construyen el estado con el servicio real.

Relacionado: [[un-registro-no-prueba-la-eleccion]], [[el-prefiltro-tapa-al-criterio]],
[[dos-getters-que-parecen-sinonimos]].
