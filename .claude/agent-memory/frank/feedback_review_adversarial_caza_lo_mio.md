---
name: review-adversarial-caza-lo-mio
description: La review adversarial no es para auditar código ajeno: en el ticket del invitado (2026-09-05) cazó cuatro defectos que introducía MI cambio, incluido el propio defecto del ticket colado por la puerta de atrás. Cómo montarla para que sirva.
metadata:
  type: feedback
---

**La review adversarial se corre sobre lo que acabo de escribir yo, y esperando que encuentre algo.** No
es un trámite de calidad sobre código heredado.

**Why:** en `groups-invite-skips-unirme-sheet-if-onboarded` (2026-09-05) tenía el fix implementado, 127
tests verdes y la mutación hecha. Dos lentes independientes encontraron **cuatro defectos que introducía
ese mismo cambio**, y el peor era el defecto del propio ticket colado por la puerta de atrás: confirmar
UNA invitación sellaba TODAS las demás, porque el CTA llamaba a `reconcile` sin decir de qué grupo
hablaba. Mi test de esa propiedad estaba **verde** — probaba el store llamando a la función a mano, no el
camino real. Además refutaron una afirmación que yo había escrito en tres sitios como si la hubiera
medido, y que era falsa.

**Y el 2026-09-07, en `groups-budget`, cuatro lentes encontraron ~20 y una evitó romper OTRA pantalla.**
El editor del tope tenía un botón condicional dentro del `actions` de un `.alert` — el patrón que
`swiftui-ds.md` tiene medido como «no rompe la alerta: rompe la app», con la víctima en un área que
ningún cruce de `codeGlobs` habría señalado. Dos más que ninguna suite podía ver: un tope de 15 dígitos
se perdía **en silencio** (el codec del wire lanza a partir de 1e14, quien traga el throw no crea la fila
de outbox y su log vive bajo `#if DEBUG`), y añadir una columna al manifest de Grupos ponía en
divergencia falsa al parque entero. ⇒ **con cuatro lentes, dos convergieron en el hallazgo más grave y
ninguna de las otras dos lo vio**: el reparto por especialidad no es redundancia, es cobertura.

**2026-09-07, `fx-pnl-education-card`: tres lentes, diez defectos, todos míos — y dos cambiaban el
SIGNO del número.** No la magnitud: el signo. La tarjeta anunciaba ganancia a quien había perdido,
por dos vías independientes (un gasto arrastrando el coste de entrada, y un traspaso entre cuentas
propias contando como compra). El cálculo se reescribió entero a media sesión.

**Y aquí las lentes CONVERGIERON en vez de contradecirse, que es la señal contraria a
[[lentes-adversariales-se-contradicen]] y hay que saber leerla:** dos lentes distintas, con encargos
distintos (una de corrección aritmética, otra de coherencia entre superficies), llegaron al MISMO
defecto de fondo por caminos distintos y con escenarios numéricos distintos. Cuando eso pasa, no es
redundancia ni casualidad: es que el defecto está en el **diseño**, no en una línea. Un hallazgo que
sólo ve una lente puede ser su especialidad; uno que ven dos por rutas distintas es estructural, y
la respuesta correcta suele ser rediseñar, no parchear.


**El patrón que más se repite en lo que cazan, y ya van tres sesiones: mi TEST del borde elige el
fixture que no puede fallar.** Aquí `gastarJustoElTopeNoEsPasarse` usaba UN gasto de 1000 — el único
caso donde el `>` de `Double` y el `>=` decimal coinciden trivialmente. Con tres importes que suman
1.000,00 exactos, la coma flotante da 1000.0000000000001 y la tarjeta decía «te pasaste por 0,00» en
rojo; el 16,5 % de los repartos caen ahí. Es la familia de `.claude/rules/testing.md` L72, cometida por
mí, en un test escrito para proteger justo eso. ⇒ **al escribir el test de un borde numérico, construye
el caso con VARIOS sumandos**, no con el número redondo que hace verdad la aserción por accidente.

**How to apply:**

- **Las dos lentes coincidieron, sin verse, en los dos hallazgos gordos.** Esa coincidencia es la señal
  de que un hallazgo es real; lo que solo dice una lente merece que yo lo mida antes de creerlo. Y de
  hecho **medí la refutación yo mismo antes de corregir** — la lente también puede equivocarse.
- **Dales una lente distinta a cada una, no «revisa esto».** Lo que funcionó: una sobre la máquina de
  estados (¿bucles?, ¿caminos donde no aparece?, ¿qué pasa si mata la app aquí?) y otra sobre regresiones
  y daño colateral en preferencias (¿qué escribe?, ¿a qué dominio?, ¿viaja cross-device?).
- **Pídeles que refuten su propio hallazgo antes de reportarlo, y que digan si sobrevivió.** Las dos
  descartaron cosas por su cuenta y marcaron una con «confianza media», que resultó ser real y estrecha.
- **Y el corolario que más duele:** un test verde escrito por mí sobre una propiedad que yo mismo definí
  puede estar montando el estado a mano y saltarse justo al caller que lo rompe. Cuando el test llama
  directamente a la función que quiero proteger, **no está probando el camino**.

Relacionado: [[mutante-compilado-zanja-hipotesis]] (la mutación prueba que el test vale; la review prueba
que el test mira donde hay que mirar — no se sustituyen) · [[mis-mediciones-fallan-por-el-filtro]].

**Refuerzo medido el 2026-09-06** (`groups-leave-rpc-error-10`, tres lentes: SwiftData/concurrencia,
producto/UX, y la mía de patrón). Cazó **seis** defectos míos, y dos hacían el fix **peor que el bug**:
(1) el reconciliador de ownership se convertía en una cárcel — tras el primer rechazo, el guard local
cortaba todo intento futuro antes de la red y ningún pull reabre `isOwner`; (2) un `save()` fallido
dejaba el flag vivo EN MEMORIA, con la UI ya ofreciendo una acción irreversible sobre un dato que no
estaba en disco. Los otros cuatro: copy circular que mandaba a la pantalla en la que ya estabas, un
comentario que prometía una reanudación que no ocurre, un docblock cierto para la función y falso como
efecto, y un doc-comment que mi propia inserción se había comido.

Dos cosas que aprendí del formato: **la lente refuta además de acusar** —me confirmó que NO debía usar
`saveUnderOutboxAuthor` (habría marcado con autor de eco ediciones ajenas pendientes, que el drain
descarta) y que el `incrementDataVersion` no ciclaba—, y eso vale tanto como los hallazgos. Y **una
lente de PRODUCTO encuentra lo que las técnicas no ven**: el callejón del dueño con deuda ajena y el
copy que apuntaba a una pantalla inalcanzable no los vio ninguna lente de código.


**Tercer refuerzo, 2026-09-07** (`welcome-privacy-branch-has-no-secondary-door`, tres lentes: flujo del
Welcome, el seed y los datos del alta, aislamiento de sesión). Y trajo una variante nueva que conviene
tener presente: **el defecto que más importaba NO estaba en mi diff**.

Una lente siguió el camino del usuario un tap más allá de mi pantalla nueva y encontró que
`clearResidualPreferencesForFreshStart` —que corre justo detrás del CTA— borraba el nombre y la divisa
del **dueño del teléfono**, y que la visita entra siempre por esa rama. Deuda previa, no la introduje
yo. Pero mi pantalla dice *«lo tuyo no se mezcla con lo suyo»*, así que **mi copy era falso una pantalla
después**: si no lo arreglaba, mi fix heredaba la forma del bug que venía a arreglar.

- **Al pedir la lente, di el camino, no solo el diff.** Lo que la encontró fue el encargo explícito de
  «recorre qué escribe cada salto y en qué dominio», no «revisa estos ficheros».
- **Un hallazgo fuera del diff puede ser tuyo igualmente**, si tu cambio lo pone en el camino o hace
  una promesa que él incumple. Ése se arregla; los demás van a ticket.
- **Y la lente también refutó bien**: descartó cuatro candidatos con la medición que los mataba —el
  portal que no puede desviar en secundaria, el `initialStep` que nadie escribe, el presupuesto cuya
  rama está muerta— y corrigió DOS frases mías que eran imprecisas, incluida una de un ticket que
  acababa de escribir. Pedir la refutación por escrito es lo que hace eso posible.

---

## Segunda vez, y el defecto grave venía envuelto en un razonamiento MÍO (2026-09-07)

`reentry-killswitch-closes-both-doors`. Tres lentes (sync/carrera, producto, regresión), **cuatro
defectos, los cuatro introducidos por mí**, con 6291 tests en verde y el mutante ya verificado.

El grave: reusé una fase de pantalla existente (`.bornCloudReady`) para la re-entrada, y **escribí en
el docblock la justificación** — «no son dos hechos distintos sino el mismo por dos caminos, con el
mismo copy, el mismo `canGoBack` y la misma salida». Sonaba a análisis. Era falso: lo que las separa
no es el camino sino la **precondición**. La re-entrada llega con `hasCompletedOnboarding` ya marcado
por `onAdoptStarted` —que existe *literalmente* para que «el seed del onboarding jamás corra sobre una
cuenta existente»— así que mi CTA mandaba al onboarding de 8 pasos a alguien con datos: cuenta
duplicada, categorías sembradas, y **subiendo al backend** porque el mismo chip acababa de arrancar el
motor en sesión. Estaba deshaciendo una defensa explícita del código mientras explicaba por qué era
seguro.

**Why (lo que esto añade a la ficha):** un razonamiento escrito con seguridad es la forma en que mis
defectos pasan desapercibidos, incluida a mí mismo al releer. La lente de regresión no discutió mi
argumento: fue a mirar **quién más escribe ese flag** y encontró la línea que lo invalidaba.

**How to apply:**
- **Reusar un caso/fase/estado existente porque «es el mismo hecho» es una hipótesis, no un diseño.**
  La prueba no es que compartan copy o pantalla: es que compartan **precondiciones y salida**. Si el
  callback único tuviera que adivinar cuál de dos estados tiene delante, son dos casos.
- **Cuando justifiques un reuso, busca quién más escribe el estado del que depende** (`grep` del
  setter, no del lector — es el caso 17 de [[mis-mediciones-fallan-por-el-filtro]]). En este chip la
  respuesta estaba a cuatro líneas del call-site, en un comentario que decía para qué existía.
- **Las tres lentes encontraron cosas distintas y ninguna sobró**: producto cazó el botón que no podía
  cambiar su desenlace, sync el guard que tiraba la mitad de su dato, regresión la salida al
  onboarding y el poll que no paraba. Con dos lentes me habría faltado una.
- Y una que ya sabía y volvió a cumplirse: **dos de los cuatro los había cazado yo antes** (el
  `force: true` lo encontré leyendo el patrón del repo). La review no sustituye la auto-revisión;
  encuentra la clase de cosa que la auto-revisión no ve porque es donde yo *creo* que ya pensé.

## 2026-09-07 — ocho defectos, y el peor era una decisión que yo había razonado al revés

Recordatorio de liquidación (PR #89). Tres lentes: cálculo, ciclo de vida, producto. **Los ocho eran
míos**, con el build en verde y 6316 tests pasando.

**El grave repite la forma del 2026-09-06: no era un descuido, era un razonamiento explícito y
equivocado, escrito con confianza en un comentario.** Decidí respetar `simplifyDebts` «para que el
aviso diga lo mismo que la pantalla», y suena bien. La lente no discutió el principio: **montó el
caso numérico**. Con simplificación, la arista «yo → X» no la produjo ningún gasto entre X y yo —
es un enrutado de mínimo flujo de caja sobre saldos de **terceros** — así que el aviso podía decir
«lleva semanas quieta» sobre dinero de anoche, con un importe **7,6× el real**; y de paso rompía el
rate-limit, porque su clave (`Debt.id`) cambiaba cuando dos personas **que no soy yo** se pagaban
algo. Coherencia con la pantalla era el criterio correcto para un *saldo* y el equivocado para una
*afirmación temporal*, que es lo que este feature añade.

**Y el que peor se habría escondido:** mi espera de frescura salía en el primer poll porque un solo
grupo legacy en el store cuenta como `.fresh` incondicional. El feature habría quedado **mudo en el
arranque, en verde y sin un solo síntoma** — exactamente el modo de fallo del que el docblock del
repo avisa, reintroducido por mí **en el mismo commit en que copié ese docblock para citarlo**.

**Lo que me llevo, y es nuevo:** cuando reuso una primitiva ajena, la pregunta no es «¿la estoy
llamando bien?» sino **«¿mi pregunta es la misma que la suya?»**. `GroupChannelFreshness` contesta
«¿puedo afirmar que esto NO EXISTE?»; yo preguntaba «¿está completa mi foto de deudas?». Mismo
`isFresh`, significados opuestos para una zona sin canal. El conteo de call-sites que debía cazar el
cuarto consumidor **no se puso rojo**: su lista de ficheros es explícita y un fichero nuevo le es
invisible. ⇒ **un escáner de cableado prueba que el cambio se aplicó, nunca que sea correcto**, y
ese punto ciego concreto —lista explícita de ficheros— hay que mirarlo antes de confiar en él.

---

**2026-09-07, `fx-manual-writes`: tres lentes. Un defecto de producto y CUATRO puntos ciegos de la
red que yo mismo acababa de escribir. Y el primero de ellos es el párrafo de arriba, incumplido dos
días después de escribirlo.**

El escáner que escribí ese día enumeraba cinco ficheros. La advertencia decía, literal, que un
escáner con lista explícita de ficheros no ve el fichero nuevo. La había escrito yo. ⇒ **cuando vaya
a escribir un escáner de cableado, la lista va invertida por defecto: se barre el árbol y se exime
nombrando.** No es una consideración a sopesar cada vez; es el punto de partida.

Tres lecciones nuevas, todas sobre cómo se diseña el detector:

- **Un centinela que no puede fallar no guarda nada.** Eximí `DevSeedTransactions.swift` del barrido
  «porque es código de desarrollo» y puse como centinela la cadena `"DevSeed"` — que aparece en el
  nombre del propio tipo. Certificaba que el fichero se llama como se llama. El centinela tiene que
  ser **la razón** de la exención (`#if DEBUG`), no algo correlacionado con ella. Prueba: ¿qué
  edición realista lo pondría rojo? Si no hay ninguna, no es un centinela.
- **Ampliar un detector cambia una ceguera por un falso positivo, y la salida no es volver atrás.**
  Mi detector enumeraba receptores (`currencyConverter.convert(`) y era ciego a `converter.convert(`.
  Al buscar el nombre del método a secas, empezó a acusar una **mención en un comentario**. La
  tentación es volver a enumerar; lo correcto es **acotar el dominio** —buscar sobre código sin
  comentarios— y quedarse con el patrón ancho.
- **Un conteo agregado no ve un cruce.** Mi barrido comprobaba «decisiones ≥ escrituras» por fichero.
  En una función con dos conversiones y cuatro escrituras, cruzar las patas (`inTransaction` usando
  `outOutcome`) deja el conteo intacto. Lo demostré con mutación, y lo que lo hace concluyente es que
  **el test de conteo siguió VERDE mientras el nuevo se ponía rojo**. ⇒ si un fichero tiene dos
  fuentes de verdad para el mismo campo, hace falta una comprobación de EMPAREJAMIENTO, no de volumen.

Y una del lado bueno, que conviene recordar para no sobrecorregir: la lente que intentó falsear el
censo de catorce escrituras —siete patrones, con controles positivos, incluyendo widgets, share
extension e intents— **no encontró un decimoquinto sitio**. Cuando una lente adversarial busca en
serio y no encuentra nada, ese silencio sí es información.

---

## 2026-09-08 — cuatro lentes, siete defectos míos, y la que más valió fue la que refutó el TICKET

`repair-queue-has-no-exit-for-partial-rate-rows`. Cuatro lentes (sync/HLC, «¿cierra el bucle?»,
«¿el anti-spin bloquea curas?», regresiones en call-sites). Gate en verde y 16 tests propios cuando
las lancé.

**Lo nuevo, y cambia cómo enfoco la review: una lente puede refutar la PREMISA del ticket, no solo mi
código.** El ticket afirmaba que reescribir las columnas del grupo `money` con el mismo valor emite
al canal nube, y de ahí colgaba dos de sus tres daños. Una lente midió que en todo el repo
`updatedAttributes` aparece cuatro veces y **ninguna lo afirma ni lo niega** — o sea, la premisa no
estaba apoyada en nada— y señaló que mi test medía `context.hasChanges`, que es **otra señal**. Lo
medí con el motor real: `hasChanges` sí se ensucia, el outbox **no crece**. El daño nº 2 no existía.
⇒ **cuando una lente diga «esto no está medido en ningún sitio», eso ya es el hallazgo**: no hace
falta que además tenga razón sobre el comportamiento.

**Y una contradicción entre dos mediciones MÍAS que resultó no serlo.** El mutante decía que la
asignación idéntica ensucia; el test de outbox decía que no emite. Parecían incompatibles y no lo
eran: son dos señales distintas del mismo `save()`. ⇒ antes de elegir entre dos mediciones que se
contradicen, comprobar que están midiendo lo mismo — a menudo la contradicción **es** el hallazgo.

**Los otros seis, todos míos y ninguno visible para la suite**, con un patrón que se repite: **el
mecanismo nuevo que corta trabajo inútil acaba cortando trabajo útil.** Mi anti-spin sellaba como
«imposible» también los fallos de RED; era ciego a las tasas que llegan por CloudKit (contaba
escrituras nuestras en vez de mirar el disco); y con el contador de «curadas» como único criterio, un
barrido que mejoraba montos sin poder sellarlos no se guardaba **y encima se marcaba estéril**. ⇒ al
diseñar un freno, la pregunta no es «¿corta el bucle?» sino **«¿qué trabajo legítimo cae con él, y
cómo distingo el fallo permanente del transitorio?»**.

**Dos hallazgos eran regresiones que mi propio cambio hizo alcanzables**, y ésa es la clase que no
busco por mi cuenta: `ensureRates` nunca troceó a los 365 días que la API acepta —inofensivo mientras
preguntaba por existencia de fila, porque nunca pedía rangos largos— y el recorrido día a día podía
no generar la última fecha si las horas diferían. **Un camino muerto que tu cambio revive trae sus
bugs intactos**, así que al ampliar lo que una función alcanza hay que auditar lo que ya había dentro.

**Reparto que funcionó:** dos lentes convergieron en el fallo de red (señal de que es estructural,
como en la nota de arriba) y las otras dos aportaron cada una un hallazgo único que nadie más vio.
Cuatro lentes sobre un cambio de seis ficheros no fue exceso.


## 2026-09-08 (PR del desbloqueo): 11 hallazgos, y uno era una REGRESIÓN con la suite en verde

Lo más importante de esta tanda no es el número: es **cuándo** la cacé. Los 6448 tests estaban en
verde, el build limpio y el coverage-index al día cuando lancé la lente. El hallazgo alta era una
**regresión que mi propio cambio introdujo**: el «Disponible» del Panel perdía el «≈» justo en el
caso peligroso —dos lados grandes cada uno bajo el umbral, y un neto pequeño con una incertidumbre
49 veces mayor que él—. Con el código anterior sí marcaba. **Ningún test lo cubría porque ningún test
existía para el neto.**

**Y el patrón que la lente nombró mejor que yo:** mi fichero nuevo **citaba a `FXPnLLogic` como
motivación y hacía lo contrario que él**. `FXPnLLogic` ya había rechazado el numerador con signo
(«posiciones que se cancelan… cualquier céntimo pasa el filtro») y adoptado `Σ|costBasis|`. Yo
acumulé con signo, así que un gasto aproximado y su reembolso aproximado se anulaban y el número
salía limpio precisamente cuando menos lo estaba. Es [[mi-fix-hereda-la-forma-del-bug]] en su forma
más cara: **citar el precedente no es haberlo leído**.

**How to apply:** cuando un cambio toque un cálculo que ya tiene un primo resuelto en el repo, la
lente que más paga es la que compara los dos **línea a línea**, no la que revisa el mío solo. Y si mi
docblock nombra a otro fichero como modelo, ese fichero entra en la review.

## 2026-09-09: refutó el DISEÑO, no un descuido — y el criterio que lo zanjó ya estaba escrito

Las tres lentes dieron 12 hallazgos y el que importaba era de fondo: mi `isApproximate` propagaba un
booleano y metía el **neto** en el numerador del umbral. No era un olvido ni un borde: era la forma
del arreglo, ya compilada, verde y con nueve tests que la fijaban como correcta.

Lo decisivo fue que **el criterio estaba escrito** —el docblock del helper, con el mismo ejemplo
numérico— así que no hubo que consultar a Jürgen: había decisión suya del 8-sep y la lente la estaba
citando. Es el reverso de la nota de [[el-denominador-de-una-resta-es-el-numero-que-se-ve]]: cuando
una lente contradice una decisión escrita, gana la decisión; cuando la **invoca**, gana la lente y no
hay pregunta que hacer.

**How to apply:** si la review propone cambiar el diseño y no solo un detalle, busca **el criterio
escrito** antes de decidir si es tuyo o de Jürgen. Y rehaz los tests: los nueve que tenía pasaban con
las dos implementaciones — el caso que las distingue casi nunca es el del ticket, hay que construirlo
(aquí, dos: parte pequeña y parte grande).

**2026-09-10 (reversa a born-cloud): 4 lentes, 7 hallazgos, y los DOS graves eran defectos de diseño
míos** — no despistes. Uno abría el guardarraíl justo para la población que protege; el otro dejaba
colgado al segundo dispositivo del usuario, para siempre. Ninguno de los dos lo habrían visto mis tests:
los dos vivían en el caso en que la señal falla, y yo había razonado el caso normal.

Dos cosas que funcionaron y repito: **una lente por lado del sistema** (gate del cliente · SQL y backend ·
tests y goldens · las rules leídas contra el diff) en vez de cuatro genéricas, y **pedirles que refuten
MIS afirmaciones del prompt**, no solo el código — la lente del backend refutó la premisa con la que yo
justificaba media decisión, y la del cliente me corrigió una frase del docblock que era falsa en general.

**2026-09-10 (paso 6, el faro): 4 lentes, NINGÚN grave, ~16 hallazgos — y lo que valió fue la dirección
peligrosa.** La lente de tests encontró que ningún test del motor distinguía el método de la sesión: con un
`?? "apple"` (que el repo usa en otros dos sitios) un Google sin cuenta habría borrado el faro de una cuenta
Apple viva en todos los dispositivos, con la suite verde. Dos lentes (flujo y producto) convergieron, sin
verse, en el mismo defecto de un flag que el faro deja puesto — señal de que era estructural. Dos cosas de
método que repito: **no apliqué mutantes mientras las lentes leían** (les habría enseñado código mutado), y
**un test que fija varias defensas no puede validar varias mutaciones a la vez: se tapan entre sí** — partí
los scans en un test por defensa antes de mutar, y los 19 mutantes unitarios cayeron cada uno en un test que
solo él tumbaba (tres tandas: las mutaciones del motor que se tapaban entre sí fueron por separado).

Y un aviso de método: **la lente de tests dijo que dos de mis aserciones nuevas eran decorado, y tenía
razón** (sobrevivían a reordenar los guards, y el cableado no tenía NINGÚN test). La forma de zanjarlo no
fue discutirlo: fue escribir el mutante y verlo caer. Tres mutantes, uno por aserción, cada uno cayendo
solo en su test.

## 2026-09-12 · diez míos en un candado, y dos eran llaves maestras

Tres lentes sobre `sim-lock.sh` (la cola del simulador). **Diez defectos eran de mi código de esa
misma sesión**, y los dos peores hacían correr **sin lock y sin un solo mensaje** — el modo de fallo
exacto que el candado venía a impedir, entrando por la puerta de atrás:

- **`YALA_SIM_LOCK_HELD=0` era un pase libre universal**: la marca de reentrada se fiaba de un PID y
  `os.kill(0, 0)` señala al propio grupo de procesos, así que nunca falla. Con el PID de un proceso
  de otro usuario, el `PermissionError` se leía como «vivo, es mi ancestro»: lo mismo.
- **`--quiet --vigilar PID` apagaba el centinela**: el parseo miraba solo `$1`, caía a la foto
  instantánea y salía **0 sin vigilar nada**. La única forma de pedir un centinela silencioso era la
  que lo desactivaba.
- Y **el caso estrella de mi propio banco daba verde sin datos**: el comparador devolvía «no pude
  medir» y el `if` lo metía en la rama del ✓.

**La lección que vale para la próxima:** cuando lo que escribo es un CANDADO, la lente que más rinde
es «¿por dónde se ejecuta esto sin el candado puesto?», y hay que recorrer **todas** las ramas que
conceden permiso — las de error incluidas. Un `except PermissionError: pass` es una concesión.


## 2026-09-14 · once míos, y el primero era que MI ARREGLO NO ARREGLABA

`restore-start-fresh-keeps-the-imported-corpus`. Tres lentes (flujo y kill-safety · presentaciones
SwiftUI con `swiftui-ds.md` contra el diff · tests con `testing.md`). Cuando las lancé tenía: build
verde, 6 tests propios, **5 mutantes ya verificados**, y el recorrido **visto en el simulador**.

**El hallazgo nº1 fue que la pieza central del PR no hacía nada.** Bajaba dos `@State` para apagar un
alert, y quien lo levanta recibe esa señal **por valor** (`let`, no `@Binding`) sin suspensión de por
medio ⇒ seguía leyendo la copia vieja. Ficha aparte: [[el-consumidor-lee-una-copia]].

**Lo que esto añade, y es lo caro:** ni el mutante ni la captura del simulador podían verlo. El mutante
prueba que el test caza el cambio que hice; la captura prueba el camino feliz (allí no había datos, así
que el alert no salía de todos modos). **Ninguno de los dos comprueba que el mecanismo tenga efecto** —
y yo tenía los dos, así que llegué a la review más confiado de lo que tocaba.

Los otros dos graves eran guards ajenos que mi camino nuevo dejaba inertes (ficha:
[[mi-arreglo-rompe-la-premisa-de-otro-guard]], sección del 14-sep). Y la lente de tests encontró que
**cuatro de mis aserciones no podían fallar como decían**: cambiar el borrado por el de OTRO objeto
dejaba la suite verde con el ticket entero deshecho.

**Y una que conviene fijar: una lente me impidió una regresión grave.** Mi primer diseño quitaba un
guard de mount para que la puerta preguntara por el corpus del teléfono; el repo tenía escrito, en el
propio test que lo pinnea, que con el espejo montado ese borrado por filas **exporta los deletes y vacía
el iCloud de la persona en todos sus dispositivos**. La lente no lo dedujo: leyó el test. ⇒ **cuando
vayas a quitar un guard, lee su TEST antes que su código** — el porqué suele estar en el mensaje de la
aserción, no en el docblock.

## 2026-09-14 · la puerta del iCloud-KV: validé contra CELDAS y falló en TRANSICIONES, dos veces

`icloud-kv-prefs-cross-sessions-on-a-lent-phone`. Cuatro lentes (regresión del dueño · fuga en el móvil
prestado · tests y mutantes · la rule de área y la prosa). Suite completa en verde cuando las lancé. **Los dos
defectos graves eran de diseño y míos**, y los dos pasaban mis seis celdas de la tabla:

- **El predicado cerraba con «neutro armado y sin eje afirmado»**, y «Activar Yala completo» levanta el neutro
  al relanzar mientras el eje sigue en `false`. «Volver» desde Restaurar deja esa activación pendiente sin
  límite: la puerta quedaba ABIERTA en una sesión solo-grupos, el bug entero de vuelta. Esa celda no está en
  la matriz del ADR: es un estado INTERMEDIO de un flujo.
- **Enmascarar lecturas convirtió «ver la señal y darla por procesada sin obedecerla» en «obedecerla después».**
  Con la lectura de `lastWipeTimestamp` oculta, el teléfono solo-grupos no marcaba el vaciado ajeno, y la
  sesión privada que nacía de la activación lo obedecía al abrirse la puerta: se borraba recién creada. Lo
  vieron DOS lentes por separado — estructural, no un despiste.

**How to apply:**
- Una puerta sobre marcas persistidas se recorre contra los estados intermedios de cada flujo que las escribe
  (reanudaciones, `keepPending`, kill entre dos escrituras), no solo contra las celdas del ADR.
- Si la puerta cierra LECTURAS de un canal compartido, lista quién MARCA estado al leer (centinelas de
  procesado, one-shots) y recorre la transición cerrada→abierta: lo que no se marcó mientras estaba cerrada se
  ejecuta al abrirse.
- **Antes de mover un fichero central detrás de una puerta por pureza, mide lo que arrastra en el gate**:
  `ContentView` casaba con 29 áreas del índice (~20 suites de XCUITest). Fijar sus sentencias exactas en el
  escáner dio la misma red sin tocarlo — y la lente de tests había cazado que eximirlo por FICHERO dejaba pasar
  una escritura cruda nueva.
