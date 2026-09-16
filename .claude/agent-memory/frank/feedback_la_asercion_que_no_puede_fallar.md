---
name: la-asercion-que-no-puede-fallar
description: El control positivo por mutación valida el TEST, no cada ASERCIÓN — un caso con una aserción viva y tres vacuas sale rojo igual y parece verificado.
metadata:
  type: feedback
---

**Una aserción puede ser incapaz de ponerse roja, y el mutante no te lo dice.** El control positivo por
mutación demuestra que **el caso** caza el bug; no que cada `#expect` de dentro sirva para algo. Si una
sola aserción del caso es sensible al mutante, el caso entero sale rojo — y las demás pasan la
inspección de rebote.

**Why:** el 2026-09-08, en `chat-draft-drops-the-expense-sign`, escribí un tercer caso de test con
cuatro aserciones para vigilar que no se firmara **una sola** de las dos columnas de dinero. Corrí el
mutante, el caso salió rojo, lo di por bueno. Una lente adversarial midió después que:

- `#expect(tx.exchangeRate > 0)` **no podía fallar jamás**: producción persiste `exchangeRate:
  abs(effectiveRate)`, y ese `abs()` ya estaba antes de mi fix. Peor, su mensaje afirmaba que «si uno
  solo va firmado, sale negativa» — falso sobre este repo.
- `#expect(abs(tx.exchangeRate - 1.0) < 1e-6)` era ciega al mutante que decía vigilar: `abs(-1.0)` es
  `1.0`.
- Dos más eran copia literal de aserciones del fichero hermano, sobre el mismo escenario.

De cuatro, **una viva**. El caso salía rojo con el mutante por esa una, así que mi verificación parecía
completa. El caso entero se colapsó en el primero: menos aserciones, y una llamada menos a
`makeTestContext()`, que es recurso escaso.

**How to apply:**

- Antes de escribir un `#expect`, mira **cómo escribe producción esa columna**. Si la envuelve en
  `abs()`, la satura o le pone un default, tu aserción sobre su signo, su rango o su presencia puede
  ser tautológica. `git show HEAD:<fichero>` responde en un comando si esa defensa ya estaba.
- La prueba real de una aserción es: **¿qué mutación concreta la pone roja a ELLA?** Si no sabes
  nombrarla, sobra. Y si dos aserciones caen con la misma mutación, una sobra.
- Cuando un caso tenga varias aserciones y quieras saber si todas trabajan, el mutante tiene que ser
  **el de esa aserción**, no el del bug del ticket. Aquí eso era «firmar solo el monto nativo», que es
  distinto de «no firmar nada» — y era justo el que ninguna de las tres cazaba.
- Sospecha de la aserción que copiaste de otro fichero: si el escenario es el mismo, la cobertura ya
  existe allí y aquí solo añade ruido.

**Y hay un tercer eslabón, medido el 2026-09-08 en `chat-rows-with-unsigned-amount-have-no-repair-path`:
el mutante puede salir rojo, la aserción estar viva, y aun así estar demostrando OTRA COSA — porque el
ESCENARIO que monta el test no es el de producción.**

Justifiqué el filtro de marcadores de un barrido diciendo que sin él «el saldo inicial de las cuentas
se voltearía a −500». Escribí el test, corrí el mutante, salió rojo justo en ese caso y en ningún
otro. Parecía la demostración perfecta. Era falsa: `InitialBalanceService` **nunca asigna `category`**,
así que en producción esas filas ni entran al criterio — se salvan por otro guard, tres líneas antes.
Mi test montaba la fila con una categoría explícita porque mi helper la ponía siempre. El rojo era
real; lo que probaba era mi helper, no el mundo.

⇒ **Un mutante en rojo demuestra que el test distingue dos versiones del CÓDIGO. No demuestra que el
caso exista.** Cuando el rojo sea la prueba de una afirmación sobre producción («esta fila real caería
en el criterio»), hay que verificar aparte que el fixture **se construye como lo construye producción**
— y la vía barata es leer el sitio que la crea y comparar campo a campo con el helper del test.

**Cuarto eslabón: la aserción puede estar VIVA, medir lo correcto, y hacerlo en el MOMENTO
equivocado — porque un mecanismo posterior del propio fix tapa la divergencia. Medido el 2026-09-08
en `chat-draft-stamps-its-own-currency-not-the-account`.** Escribí un caso para el borde que una
lente adversarial había destapado (cuenta archivada entre elegir y guardar) y afirmé que «lo que se
ve es lo que se guarda» comparando el borrador con la fila **después** de `saveDraft`. Verde. Pero
`saveDraft` congela la divisa en el borrador como parte del arreglo, así que a esas alturas los dos
lados ya estaban alineados **aunque la divergencia hubiera existido**: el mutante que quitaba la
sincronización previa dejaba el caso en VERDE. El daño real —el usuario confirma una divisa y se
guarda otra— ocurre **antes** de pulsar Guardar, y ahí era donde había que medir. Movida la aserción
a ese instante, el mismo mutante lo pone rojo.

⇒ **Cuando el fix tiene varios mecanismos en cadena, el test que mide al final los mide juntos y no
distingue cuál falta.** Pregúntate en qué instante exacto el usuario sufre el bug, y afirma AHÍ. Y la
señal que lo destapa es barata: si un mutante tumba unos casos y **no** el que escribiste
específicamente para ese borde, el problema no es el mutante — es que tu caso mide tarde.

**Quinto eslabón, y es el más barato de escribir sin darse cuenta: la columna que NO CAMBIA en el
escenario. Medido el 2026-09-08 en `bulk-update-account-leaves-converted-amount-stale`.** Escribí un
caso que decía fijar «las cuatro columnas del grupo `money`» al mover una transacción a una cuenta de
otra divisa. Mutante en rojo, verificado. Una lente midió después que **solo una de las cuatro podía
fallar**:

- `preferredCurrencyCode` vale lo mismo antes y después (sale de la preferida del entorno, que la
  operación no toca), y **su default de modelo es `"PEN"`** — justo la preferida más probable del
  simulador. Pasaba aunque el recálculo no hubiera corrido nunca.
- `isExchangeRateProvisional` ya venía en `false` del fixture y en `false` se quedaba.
- `exchangeRate` lo DERIVA el recalculador como `amountInPreferredCurrency / amount`: afirmar los dos
  era afirmar el mismo número dos veces.

El caso salía rojo con el mutante por la única viva, así que la verificación parecía completa — mismo
patrón que el primer eslabón, pero por otra puerta: allí la tautología la ponía **producción** con su
`abs()`; aquí la pone **el escenario**, porque comparar el valor final contra el que el fixture ya
dejó no distingue «lo recomputó» de «no lo tocó».

**Variante del mismo eslabón, y la más barata de todas: el DEFAULT DEL MODELO.** El 2026-09-11 aserté
`#expect(after.groupCursorsJSON == "{}")` para fijar que el desasociar soltaba los cursores del pull.
`GroupSyncCursor.groupCursorsJSON` **nace valiendo `"{}"`** y mi fixture nunca ejecutaba un pull: la línea
de producción se podía borrar entera con los cinco tests en verde. Aquí la tautología no la pone ni
producción ni el fixture — la pone la **declaración del `@Model`**. ⇒ cuando aserjes que algo «se limpió»,
`git show HEAD:<modelo>` y mira su default; si coincide con lo que esperas, hay que sembrar contenido real
primero (el molde estaba al lado, en `HandoverGroupsDomainTests`, que siembra `{"g1":5}`).

⇒ **La cura es ENSUCIAR con centinelas imposibles justo antes de la operación medida** (`-999_999`,
`"XXX"`, un `true` donde se espera `false`), que es lo que ya hacía el test hermano de
`bulkUpdateAmount` con su `-999`. Con eso las cuatro pasan a medir «esta operación REESCRIBIÓ la
columna», que es lo que el ticket quería. Y la pregunta que lo destapa antes de escribirlo: **¿qué
valor tendría esta columna si el código bajo prueba no hiciera nada?** Si la respuesta es «el mismo
que espero», la aserción no existe.

**Corolario del mismo día, sobre el otro extremo del test:** todas mis aserciones leían la instancia
**en memoria**, que el bucle ya había mutado antes del `save()`. Como ese SUT se traga un guardado
fallido con un `print` bajo `#if DEBUG`, un `save()` que lanzara era indistinguible de uno que
funcionaba — y los mensajes hablaban de lo que ven Panel e informes, o sea del **store**. Un
`#expect(context.hasChanges == false)` tras la operación es lo que le da derecho a la frase.

Relacionado: [[mi-docblock-tambien-es-una-premisa]] — el mensaje de un `#expect` es un docblock más, y
el mío afirmaba algo falso sobre producción. Y [[mutante-compilado-zanja-hipotesis]], que sigue siendo
la herramienta buena: lo que esta memoria acota es **qué** demuestra exactamente.

## El sexto eslabón, y el único que un mutante NO caza: la aserción que depende de la MÁQUINA

**2026-09-09.** `sinTasaDeEseDia_cuentaComoAproximada` afirmaba `#expect(row.isExchangeRateProvisional)`
tras convertir a un `"USD"` literal. Ese flag lo escribe `recalculatePreferredCurrency`, que describe
la pata `amount → preferida`; cuando el destino **es** la preferida esa pata es la identidad, sale
`.exact` y el flag queda en `false` aunque la conversión origen→destino haya sido aproximada. Verde
en mi máquina (preferida PEN), **rojo en CI** (preferida USD). Nueve mutantes, tres lentes
adversariales y la suite completa en local pasaron por encima sin verlo: **todos corrían en el mismo
entorno**.

**Why:** un mutante prueba que el test reacciona al CÓDIGO. No dice nada de si reacciona al ENTORNO,
y `CurrencyDefaults.currentPreferred` lee `UserDefaults.standard`, que en un simulador de CI recién
creado no vale lo mismo que en el mío.

**How to apply:**

- **La pregunta gemela de la de arriba:** ¿qué valor tendría esta columna en OTRA máquina? Si un
  `#expect` toca algo que dependa de la divisa preferida, el idioma, la región, la zona horaria o la
  fecha de hoy, **derívalo en el test** en vez de escribir el literal. Aquí: leer la preferida y
  elegir un destino que no sea ella.
- **Y fija la asimetría con un test hermano.** El control
  (`haciaLaDivisaPreferida_elConteoLoDiceYElFlagNo`) hace la MISMA conversión aproximada hacia la
  preferida y exige el flag en `false`. Con los dos, la dependencia del entorno queda descrita en vez
  de descubrirse en la siguiente corrida de CI — que aquí costó **28 minutos**.
- Es la familia del helper de fecha de ese mismo fichero, que sí fijé en UTC por este motivo
  (`CurrencyConverter` deriva el `dateKey` en UTC). La diferencia es que aquélla la vi al escribirla
  y ésta no.

**Y el aviso estaba escrito.** La primera lente adversarial lo dijo con todas las letras — «pasa por
coincidencia; con destino == preferida ese `#expect` se pone rojo»— y lo dejé pasar porque el
hallazgo venía dentro de otro más grande. ⇒ **una nota de una lente sobre un test es un hallazgo,
no un comentario**: los hallazgos de los tests se atienden igual que los del código, o se pagan
enteros después. Ver [[review-adversarial-caza-lo-mio]].

## Séptimo eslabón: el CORPUS que ya no contiene el fenómeno

**2026-09-09, el banco del candado anti-atribución.** Escribí una comprobación que corría dos
hooks sobre «los últimos 400 commits» y cantaba si el mío dejaba pasar algo que el otro
rechazaba. Salió **0 divergencias** y la di por buena. Luego medí el corpus: **los últimos 400
commits de Yala tienen CERO atribución** — el más reciente con trailer estaba en la posición
**408**. La comprobación no podía fallar: no había en su corpus ni un solo caso del fenómeno
que decía vigilar. Ocho commits de distancia entre una red y un adorno.

**Why:** un corpus «los últimos N» es una muestra por RECENCIA, y el fenómeno que vigilas puede
haber dejado de ocurrir — que es justo lo que pasa cuando el corpus lo tomas después de arreglar
algo. Cuanto mejor va el repo, menos mide.

**How to apply:**

- **Elige el corpus por CONTENIDO, no por recencia**: filtra por lo que puede disparar el
  criterio (aquí, `git log --grep` de los literales que cualquiera de los dos hooks puede cazar)
  y quédate con el superconjunto. Es defendible en una frase y no caduca solo.
- **Cuenta cuántos casos del fenómeno trae el corpus, y falla si son cero.** Esa línea es la que
  convierte la aserción en algo que puede ponerse rojo: «0 casos de atribución en el corpus ⇒ esto
  no está midiendo nada» es un fallo, no un verde.
- Vale para cualquier barrido sobre historia, logs o ficheros: la pregunta gemela de siempre —
  **¿qué tendría que pasar para que esto saliera rojo, y hay algo así en lo que estoy mirando?**

## Octavo eslabón: RETIRAR un caso del dominio deja al test que lo usaba probando el caso degenerado

**2026-09-10, paso 7 del rediseño de sesiones.** El XCUITest del tap de vuelta del chip C5 salía de la
card «Solo grupos» porque ahí vivía el bug: con tres cards y un booleano de dos, `if expensesOnlyMode`
perdía el tap solo desde el TERCER modo. Retiré la card y cambié el escenario a mano: saliendo de «Solo
anotar gastos». El test siguió verde y yo dejé el docblock diciendo que cubría «la mitad no cosmética de
C5». Una lente midió que ya no podía: desde `.expensesOnly` la forma exacta del bug y el arreglo dan el
MISMO resultado. El test solo cazaba ya un tap muerto.

**Why:** el escenario de un test no es intercambiable. Se eligió porque era el ÚNICO donde la versión
buena y la mala divergían; al quitar ese caso del dominio, el sustituto «equivalente» puede ser uno donde
no divergen.

**How to apply:** al retirar un caso de un enum, una tabla o un flujo, para cada test que lo usaba de
escenario pregunta **¿con los casos que quedan, la forma del bug sigue dando otro resultado?** Si no,
baja lo que el docblock promete y señala la red que sí lo cubre (aquí, el source-scan del cableado).
Es la pregunta de siempre —¿qué haría falta para que esto saliera rojo?— aplicada a un dominio que acaba
de encoger.

## Y dos formas de mutante que no demuestran nada

Del mismo día, las dos me costaron una vuelta entera:

- **El mutante que no AÍSLA.** Quité del hook dos de sus cinco patrones esperando que dejara
  pasar los 768 commits con firma. Siguió cazándolos: esos mensajes llevan **también** el emoji,
  y ése no lo había quitado. Un mutante que borra una defensa mientras otra cubre el mismo caso
  sale verde y parece que la defensa borrada sobraba. ⇒ antes de mutar, **comprueba qué otras
  ramas cubren ese caso**, y muta hasta dejar una sola en pie.
- **El mutante que vive FUERA del árbol.** Copié el script mutado al scratchpad y lo corrí desde
  allí: calculó su raíz con `${BASH_SOURCE[0]}`, no encontró el repo y salió por una rama de
  «no aplica» sin ejecutar nada de lo que yo quería probar — dos veces, y las dos leí el verde
  como resultado. ⇒ **un mutante de un script se corre desde donde vive el original** (copia
  temporal dentro del árbol, borrada después), o no está probando el mismo código.


## Noveno eslabón: el `#require` que fija la ETIQUETA del `case` y no su CUERPO

**2026-09-14, `cloud-signout-collapses-every-groups-transient-into-permanent`.** Mi source-scan del
aviso decía —en su propio nombre— «y por el alert que toca», y comprobaba esto:

    #require(present.range(of: "case .permanent, .sessionExpired, .channelPaused, .uploadRetryLater:"))
    #require(present.range(of: "case .transient: showSignOutPendingAlert = true"))
    #expect(blocked.lowerBound != pending.lowerBound)

Una lente midió los dos defectos que hay ahí:

- **La primera fija la etiqueta y deja el cuerpo libre.** El mutante que cambia esa rama a
  `showSignOutPendingAlert = true` manda los CUATRO motivos del bloqueo al aviso que promete «un
  momento más» —sobre un servidor caído— y el test sigue **verde**. Lo probé compilado: verde.
- **La tercera no puede fallar nunca.** Son los `lowerBound` de dos literales distintos sobre la misma
  cadena: divergen en el sexto carácter, así que son distintos **por construcción**. Ocupaba el sitio
  de la aserción que debía distinguir las ramas y hacía creer que la propiedad estaba fijada.

**Why:** cuando el `switch` es el mecanismo, lo que hay que fijar es el **par** etiqueta→cuerpo. La
etiqueta sola solo dice que el motivo está pronunciado, no **qué** se hace con él — y «qué se hace»
es justo lo que el ticket vino a arreglar.

**How to apply:**

- En un scan sobre un `switch`, el literal del `#require` lleva **la etiqueta y su cuerpo juntos**, y
  se normaliza el whitespace antes (`text.split(whereSeparator: \.isWhitespace).joined(separator: " ")`)
  para que partir la línea no dé un rojo falso. Y se fija también la rama HERMANA, o el mutante que las
  une por el otro lado no rompe nada.
- **Dos `range(of:)` de literales distintos nunca se comparan entre sí.** Si la propiedad es «esta rama
  va antes que aquélla», compara posiciones de literales que puedan coincidir, o mejor: fija el
  contenido de cada rama por separado, que es lo que de verdad importa.
- La pregunta de siempre, aplicada al scan: **¿qué edición del fichero pone ESTA línea en rojo?** Si la
  respuesta es «renombrar el case», el scan vigila el nombre, no el comportamiento.

**Y el corolario de esta sesión, que es el más barato de olvidar: un mecanismo nuevo sin red se borra
entero sin romper nada.** Añadí un breadcrumb —la única forma de saber en campo qué aviso vio la
persona— y al correr el mutante «bórralo entero» salió **VERDE**. Ocho mutantes, siete muertos y ése
vivo. ⇒ cuando el cambio añade una línea que nadie consume dentro del proceso (un log, una métrica, un
testigo), **su red es un scan explícito**: el compilador no la echa de menos y ningún test de
comportamiento la toca.

## Décimo eslabón: la aserción que mira un efecto ASÍNCRONO sin soltar el actor

**2026-09-16, `groups-loop-in-backoff-ignores-the-return-to-foreground`.** Escribí el único test que
distinguía si el gate del despertar se consultaba de verdad: con el canal apagado a mitad del sueño,
llamar al wake y comprobar que el sueño **no** se cortaba.

    client.wakeLoopIfSleeping(trigger: "foreground")
    #expect(nap.cancelled.isEmpty)        // ← no puede fallar

Con el `guard shouldWake(...)` **borrado entero**, el test seguía verde. `Task.cancel()` solo **marca**
la tarea: el `catch` que escribe el testigo no corre hasta que el MainActor se suelta, y mi `#expect`
iba en la misma rebanada síncrona. La lista estaba vacía en las dos versiones del código.

**Why:** un efecto que viaja por cancelación, por un `Task`, por un `await` o por una notificación **no
ha ocurrido todavía** cuando vuelve la llamada que lo dispara. Afirmar «no pasó» justo después mide el
reloj del actor, no el código.

**How to apply:**

- Cuando el testigo lo escriba otro contexto, **espera a que el efecto TERMINE y mira CÓMO terminó**, no
  a que no haya aparecido: aquí, esperar a que el sueño acabe y exigir que acabara `false` (agotado) en
  vez de `true` (cortado). La versión mala falla, y la buena no depende de cuándo corra el scheduler.
- La señal que lo destapa es la de siempre y no se puede saltar: **el mutante**. Este test parecía el
  más cuidado de los seis y era el único inútil; lo dijo el M6, no la lectura.
- Vale igual para `#expect(x == nil)` tras disparar algo que asigna en un `Task`, y para cualquier
  «no se emitió» inmediatamente después del gesto.
