---
name: el-default-seguro-no-es-el-mismo-para-todos
description: Un gate con default conservador puede tener un consumidor para el que ese mismo default es el peligroso — se separa en dos lecturas NOMBRADAS, y el que alcanza datos de fuera del dispositivo lleva la estricta
metadata:
  type: feedback
---

**Antes de darle un default a un dato ausente, recorre sus consumidores UNO A UNO y pregunta hacia
dónde falla cada uno.** «Conservador» no es una propiedad del valor: es una propiedad de la pareja
(valor, consumidor).

**Why:** el 2026-09-12, diseñando el eje 1 (`PrivateSessionMark`, «¿hay sesión privada en este
teléfono?»), el default obvio para una marca ausente era `true` — fallar hacia «hay vida personal que
proteger» hace conservar y esperar de más, que es barato, y es el razonamiento con el que Jürgen
descartó derivar el eje de la presencia del store. Vale para ocho de los nueve consumidores. **El
noveno lo invierte:** `DestructiveScopeLogic.wipeSignalsAppleIDDevices` decide si «Vaciar datos»
ORDENA a los demás dispositivos del Apple ID vaciarse, así que ahí un `true` por ausencia vacía el
iPad del dueño — el daño exacto que esa función existe para impedir (review del paso 9). Un solo
default con un solo nombre lo habría metido en la dirección equivocada sin que nada lo dijera: con la
marca PUESTA las dos lecturas coinciden, así que toda la suite de comportamiento sigue verde.

**How to apply:**

1. El criterio que separa las dos familias es **hasta dónde llega el fallo**: si equivocarse alcanza
   datos que están FUERA de este dispositivo (otro teléfono, la cuenta, el iCloud de otra persona),
   ese consumidor va con la lectura estricta. Si solo hace trabajar de más aquí, con la conservadora.
2. Se exponen como **dos lecturas con nombres que dicen la dirección** (`hasPrivateSession` ausente ⇒
   `true` · `confirmedPrivateSession` ausente ⇒ `false`), no como un parámetro booleano. El nombre es
   lo que impide que alguien las unifique «porque son la misma pregunta».
3. **La red es un conteo app-wide del consumidor estricto**, no un scan del fichero donde vive: un
   segundo consumidor aparecerá en OTRO fichero, y ahí es donde hace daño. Escribir la aserción sobre
   un solo fichero y decir «en toda la app» es el falso verde de esta familia — lo cometí en el mismo
   PR y lo cazó una lente.
4. **Y comprueba que la AUSENCIA existe de verdad en producción.** En la primera versión el backfill
   del arranque reescribía la marca que el cierre de sesión acababa de borrar, en el mismo
   lanzamiento: el default estricto protegía un camino inalcanzable. Un gate cuyo caso por defecto no
   ocurre nunca no es un gate, es decoración.

Relacionado: [[feedback_un_gate_derivado_de_una_ausencia_falla_abierto]] ·
[[feedback_el_prefijo_que_elegi_tiene_dos_efectos]] · [[feedback_la_asercion_que_no_puede_fallar]]
