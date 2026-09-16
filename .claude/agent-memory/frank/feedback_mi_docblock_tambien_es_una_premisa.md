---
name: mi-docblock-tambien-es-una-premisa
description: Lo que YO escribo en un docblock mientras implemento es una afirmación sin medir; siete falsas el 8-sep y cinco más el 10-sep. Cuatro variantes: inventar una JUSTIFICACIÓN técnica, ENSANCHAR una premisa prestada, NOMBRAR UN GUARD que no cubre la superficie que digo, y CITAR UN TEST que dice lo contrario.
metadata:
  type: feedback
---

Trato mis propios comentarios como si fueran documentación de algo verificado. **No lo son mientras
los escribo: son la intención, y el código puede no cumplirla.** Mídelos antes de commitear igual que
mido los del ticket.

**Why:** el 2026-09-08, en `repair-queue-has-no-exit-for-partial-rate-rows`, escribí dos afirmaciones
falsas en docblocks nuevos y ninguna la habría cazado la suite:

1. En `FXRepairQueueLogic`: «un fallo de red no escribe la huella —eso es transitorio y merece
   reintento—». **El código no lo hacía**: `ensureRates` se tragaba el error del fetch y devolvía
   `Void`, así que el barrido no tenía forma de distinguir «el proveedor no tiene esa divisa» de «no
   llegué a preguntar», y sellaba las dos igual. Lo cazaron DOS lentes distintas, las dos citando mi
   propia frase como prueba de la intención incumplida.
2. En `TransactionItem`: «SwiftData ensucia igual, y `updatedAttributes` no compara valores». Medido
   después: `hasChanges` sí se ensucia, pero **el outbox no crece**. Había heredado la premisa del
   ticket sin comprobarla y la reescribí como si fuera un hecho conocido del repo.

La forma es siempre la misma: describo lo que el mecanismo **debería** hacer en el momento en que lo
estoy diseñando, y luego el código sale distinto o la premisa era prestada. Un docblock afirmativo
sobre comportamiento es tan verificable como una coordenada de un informe.

**How to apply:** al terminar de implementar, releer los comentarios NUEVOS buscando las frases con
forma de hecho —«no ocurre», «solo pasa si», «X no compara», «esto corta»— y, por cada una,
preguntarse si la medí o la deduje. Las que no estén medidas: o se miden (suele costar un test o un
grep) o se reescriben como lo que son. Vale doble para el docblock que justifica **por qué** existe un
mecanismo: si su porqué es falso, el mecanismo puede estar de más y nadie lo va a volver a mirar.

Relacionado: [[mi-fix-hereda-la-forma-del-bug]] — misma familia, otra superficie. Y
[[la-premisa-del-encargo-tambien-se-mide]], que cubre las premisas ajenas; ésta cubre las mías.

**Cuarta y quinta, el mismo día, en `chat-assistant-plants-exchange-rate-one` — y la cuarta estrena
una FORMA distinta: la justificación inventada.** Escribí que el guard `abs(monto) > 0.0001` estaba
ahí porque «divide, y un monto que redondee a cero daría infinito o NaN». Falso y medible en diez
segundos: la guard de entrada ya exige `isFinite` y `> 0`, y `0.000372 / 0.00005` son 7,44. La razón
REAL de esa línea es la paridad con `recalculatePreferredCurrency` — si rompes el umbral en un solo
sitio, la fila cambia de número al repararse. Escribí una razón plausible en vez de la verdadera, y
eso es peor que no comentar: el comentario aseguraba que la rama protegía de algo de lo que no
protege, y **tapaba que la rama es alcanzable y ahí escribe un número falso** (la banda
`0 < monto <= 0.0001`, que acabó siendo ticket propio). La quinta, en la cabecera del test: afirmé
que el fichero «no comparte estado» con la suite hermana — cierto para el store de SwiftData y falso
para `SessionState` y los defaults compartidos.

**How to apply:** cuando escribas *por qué* existe una línea defensiva, la prueba es intentar
refutarla con un ejemplo numérico concreto. Si no consigues construir el caso del que dices que
protege, la razón que has escrito no es la razón — y la verdadera suele ser «paridad con X», que es
además la que el yo-futuro necesita para no romperla. Y cuando escribas «esto está aislado», di
aislado *de qué*: casi siempre lo está de una cosa y no de las otras tres.

**Sexta, el mismo día, en `chat-draft-drops-the-expense-sign` — y estrena la segunda forma: la premisa
prestada que se ENSANCHA al copiarla.** El ticket decía, con razón, que Registros y Estadísticas
«muestran la transacción bien». Yo lo reescribí como «las listas cuadran y el saldo no… el saldo era el
único que no preguntaba por la categoría». La frase original era cierta del **render** de la fila; la
mía afirmaba además los **totales**, y eso es falso: eligen el bucket por categoría pero acumulan CON
SIGNO (`expense -= amount`), así que un gasto guardado en positivo restaba del total de gastos y el KPI
se desviaba el doble. Copié una verdad estrecha y la devolví ancha.

Lo grave no es el error de hecho: es que esa frase **es exactamente la creencia que produjo el bug**
—«solo el saldo lee el signo»— y yo la estaba re-imprimiendo en el comentario que el siguiente iba a
leer, en la cabecera del test y en el propio ticket. La cazaron dos lentes independientes citando la
misma línea.

**How to apply:** cuando reescribas con tus palabras una premisa del ticket, marca de qué era cierta la
original. Si el ticket dice «se muestra bien», pregúntate *¿mostrarse o sumarse?* — y si tu versión
cubre más superficie que la que medió quien la escribió, la has ensanchado y hay que medir la
diferencia. El riesgo es peor de lo normal cuando la premisa explica **por qué nadie vio el bug**: esa
frase es la teoría del caso, y si es falsa, el siguiente hereda el punto ciego entero.


**Tercera variante, y la más peligrosa porque promete protección: NOMBRAR UN GUARD QUE VIGILA OTRA
SUPERFICIE. Medido el 2026-09-08 en `bulk-update-account-leaves-converted-amount-stale`.**

Borré un método muerto y dejé en su sitio una nota larga explicando el porqué. La cerraba así:
«cualquier reimplementación debe bloquear transferencias y llamar `recalculatePreferredCurrency`. **Lo
fija `RecordsViewModelBulkAccountCurrencyTests`.**» Los tres casos de esa suite eran buenos, medían
comportamiento real y tenían mutante en rojo. Y la frase era **falsa**: ninguno de los tres toca
`TransactionService`. Si alguien repegaba el método borrado tal cual, los tres seguían verdes.

Es peor que las otras dos variantes porque no describe un mecanismo —eso se mide leyendo el código—
sino una **relación entre un fichero y su red**, y esa relación no está escrita en ningún sitio donde
se pueda tropezar con ella. La cazó una lente adversarial, no la suite.

⇒ **Cuando escribas «esto lo fija <suite>», comprueba que la suite TOCA el fichero donde lo escribes**
— `grep <NombreDelFichero> <suite>` — y si no lo toca, o quitas la frase o escribes el guard que la
hace verdad. Aquí escribí el guard: un source-scan que vigila **por método** (el fichero ya contenía
un `recalculatePreferredCurrency` en otro método, así que un barrido por FICHERO habría pasado en
verde con el método malo dentro — que era exactamente el estado del árbol) y con su mutante propio:
repegar el método lo pone rojo y deja verdes los tres de comportamiento.

**Y la regla general que deja:** un test de comportamiento sobre la ruta A no protege un borrado en la
ruta B, por parecidas que sean. Borrar código sin llamador es seguro; lo que hay que vigilar es que no
VUELVA, y eso es un source-scan, no un test de comportamiento.

## Cuarta variante, y la más tramposa: **cito un test como prueba y el test me refuta** (2026-09-10)

En el bloque [I] escribí una rama agrupada con este comentario: «inalcanzables por esta puerta, y no es
una promesa: lo afirma `soloTresDestinosSalenDelWelcome`». El primer caso de esa rama era
`.adoptAsComplete` — **el destino más frecuente de esa puerta**, y el test citado lo tiene
explícitamente en su lista de permitidos. O sea: invoqué como prueba justo al test que decía lo
contrario, y la frase sobrevivió porque **el código era correcto**: la rama hace `break` y sigue al
guard, que es lo que `.adoptAsComplete` necesita. Solo mentía el comentario.

Es peor que las otras tres porque **añadir una referencia a un test da sensación de rigor**: parece que
lo he verificado precisamente porque lo nombro. La comprobación es leer el test citado, no citarlo.

En la misma tanda cayeron cuatro más del mismo día, todas de un grep: «el motor compartido» con un solo
llamador (mientras el Welcome conservaba su copia de la secuencia, y las dos ya cacheaban distinto) ·
«el belt lo cierra de inmediato» cuando ya hacía un viaje de red · un valor cableado justificado con
«esta pantalla solo se alcanza desde el Welcome», premisa que **mi propio cambio** rompía en la misma
sesión · y «tiene ticket propio» sin ticket.

**How to apply:** al escribir un docblock que nombra un test, un símbolo o un conteo, ábrelo. Y cuando
justifiques un valor cableado con «aquí solo se llega desde X», comprueba si el cambio que estás
haciendo añade una puerta — dos de las cinco eran premisas que yo mismo invalidaba en el mismo diff.

**Séptima, el 2026-09-16 en la tarjeta de Ajustes: «quien ya está dentro conserva su panel».** La escribí en cinco sitios
(docblock, regla, ticket, Paso 0) midiendo la MÁQUINA —`isEngaged` queda fuera del término— y no lo que la PANTALLA
deriva. Un adopt que quedó pendiente tras el claim vuelve a `notStarted` con el efecto por ejecutar, y `derive` lo pinta
`.idle`: sin App Attest pierde la tarjeta sin ver progreso. Dos lentes lo tumbaron por separado.

**How to apply:** cuando escribas que alguien «conserva» o «ve» una pantalla, recorre el derivador del estado de UI con
cada fase **y** cada efecto pendiente, no la definición del flag que usas en la puerta.
