---
name: la-correccion-de-la-lente-reintroduce-el-bug
description: Aplicar el arreglo que una lente propone sin recorrer la población entera puede devolver el bug — y el rediseño que nace de una review necesita SU PROPIA review: la del 11-sep cazó dos ALTAS en mi corrección
metadata:
  type: feedback
---

**Cuando una lente adversarial dice «el predicado X está mal, usa Y», aplicar Y no cierra el hallazgo:
hay que recorrer la población ENTERA con Y puesto.** La corrección hereda la forma del bug con la misma
facilidad que el arreglo original.

**Why:** el 2026-09-10, paso 4 del rediseño de sesiones. La lente de CloudKit cazó que el gate de la
puerta usaba `SwiftDataConfiguration.isICloudAvailable()` —`ubiquityIdentityToken`, que mide iCloud
**Drive**— y que con Drive apagado el mount `.localNoMirror` adjunta el espejo igual: el bug del ticket,
vivo, por el predicado elegido para matarlo. Su corrección era buena y la apliqué:
`personalStoreMountedDecision.attachesCloudKitMirror`, el testigo de si este arranque espeja.

Y ese término devuelve **`false` para `.neutralNoMirror`**, que es el mount de toda instalación fresca —
o sea el 100 % de la población de la puerta. La corrección apagaba la validación justo en el caso
principal del ticket. Lo encontré yo releyendo el flujo entero, no la lente: ella había mirado el
predicado, no a quién se le aplica.

Dos preguntas parecidas y un solo término para las dos, que es de donde salía el lío: «¿el espejo está
puesto AHORA?» (aviso tardío: sí, `attachesCloudKitMirror`) y «¿el iCloud de este Apple ID tiene datos
que van a acabar aquí?» (la puerta: eso solo lo contesta CloudKit).

**How to apply:**

- Tras aplicar la corrección de una lente, **evalúa el término nuevo contra cada valor del dominio**, no
  contra el caso que la lente citó. Aquí eran cinco `PersonalStoreDecision`, y el que rompía era el que
  la lente no había nombrado.
- Enuncia la pregunta que el predicado contesta **en una frase**, y comprueba que es la misma que la
  pantalla necesita. Dos preguntas parecidas comparten término hasta que una de las dos se rompe.
- El pin va en el CALL-SITE, no solo en la propiedad: mi test fija que `measure()` **no** contiene
  `mirrorWillSync`, con el control de que el camino tardío **sí** lo contiene. Un test de la propiedad
  sola habría pasado con el bug puesto.
- Y la misma pasada me encontró un segundo hueco de la misma familia: el borrado reanudado no retiraba
  su arm, así que se reanudaba en cada arranque. Ninguna lente lo vio — lo introduje yo al unificar los
  dos caminos DESPUÉS de que las lentes leyeran el diff. **Lo que se escribe después de la review no
  está revisado**, aunque lo haya escrito la review.

**Otra vez el 2026-09-11 (paso 8), con otra forma.** Para cerrar el hallazgo «re-puentear liquidaciones
borra las patas reales» escribí una convergencia nueva… que descartaba el retorno de
`bridgeRemoteExpenses` (los ids ATENDIDOS) y retiraba su intención con gastos sin atender dentro. El repo
ya tenía un test que documenta exactamente ese bug-class (`GroupsPendingBridgeDurabilityTests`, «el canal
backend descartaba el valor de retorno…»). No lo cazó ninguna lente: lo cazó escribir el test de
comportamiento contra el bridge REAL. ⇒ **al reusar una API desde código escrito tras la review, lee sus
tests existentes antes que su firma**: cuentan qué se hizo mal con ella la última vez.

Relacionado: [[lentes-adversariales-se-contradicen]], [[mi-fix-hereda-la-forma-del-bug]],
[[el-prefiltro-tapa-al-criterio]] — este caso es literalmente un pre-filtro tapando al criterio, puesto
por la corrección de un pre-filtro que tapaba al criterio.


---

## Y si la corrección es un REDISEÑO, pásale una lente propia: la del 2026-09-11 cazó dos ALTAS

En `detach-failure-looks-like-success`, tres lentes me obligaron a cambiar el diseño —el reintento pasó
de «repetir el gesto» a un método acotado, con una marca durable nueva—. Eso no es aplicar una
corrección: es escribir código nuevo, y **ese código no lo había revisado nadie**. Le pasé una cuarta
lente acotada al delta y salieron dos hallazgos ALTOS, los dos de la misma familia que el ticket:

- **La marca durable no iba sellada**, así que el botón «Terminar de soltar la cuenta» borraba el dominio
  de la cuenta asociada EN ESE MOMENTO — incluida una viva, si la persona volvía a entrar entre medias.
- **El boot-wipe del cierre de sesión no se la llevaba**: nombra a sus tres hermanas y se olvidaba de
  ella, así que el siguiente humano veía un botón para terminar algo que nunca empezó.

Y un tercero de método que vale por sí solo: **mi propio docblock afirmaba que la función del wipe
«barre ese prefijo», y es una LISTA de keys**. El namespace `groups.*` era convención, no mecanismo.

**How to apply:** cuando una review te obligue a rediseñar y no solo a parchear, vuelca el diff y lánzale
una lente acotada AL DELTA, con las preguntas concretas del rediseño («¿este estado durable lo limpia
alguien?», «¿este guard nuevo puede quedar inalcanzable?»). Cuesta una corrida y es exactamente donde el
resto de lentes ya no está mirando. Y dile que compare contra `git show HEAD:<fichero>`: el refactor que
saca código a un método nuevo **se lleva las líneas fuera del alcance de los escáneres que las vigilaban**
—aquí, las cuatro afirmaciones del remate—, y eso deja tests verdes sobre un método que nadie mira.
