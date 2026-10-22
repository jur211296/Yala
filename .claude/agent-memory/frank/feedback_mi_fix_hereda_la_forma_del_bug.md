---
name: mi-fix-hereda-la-forma-del-bug
description: Al arreglar un bug tiendo a repetir su misma forma en el arreglo. Antes de dar por cerrado un fix, aplicarle al arreglo la pregunta que definía el bug original.
metadata:
  type: feedback
---

**Cuando arreglo un bug, el arreglo tiende a cometer el mismo error que el bug.** No uno parecido:
**el mismo**, con otras piezas. Antes de cerrar, coge la frase que describe el bug original y
pregúntasela al arreglo.

**Why:** medido el 2026-09-06 en `fx-presentation-still-shows-1to1`. El bug era *«una fuente peor
TAPA una mejor y presenta el resultado como bueno»*: una tabla de tipos de cambio incompleta
escondía los escalones de respaldo que sí tenían el dato. Mi arreglo sembraba la caché con la tabla
estática **entera** — y como esa tabla cubre todas las divisas, hacía **vacua la comprobación de
cobertura que yo acababa de escribir**: la tasa real de ayer no se usaba nunca por esa vía. Otra
fuente peor tapando una mejor, en el commit que existía para impedirlo. Medido: 24,79 por una ruta,
**40** por la otra, en el mismo instante.

Y no fue casualidad ni descuido puntual — el mismo día, la misma sesión:

- El comentario que escribí decía *«sin fila la caché se llena con la tabla estática, que cubre
  todas las divisas y convierte bien»*: **describía el bug nuevo como si fuera la solución**. Un
  comentario seguro de sí mismo es una señal, no una garantía.
- Mi test del acumulador ponía la transacción aproximada **la última**, así que pasaba igual con
  `=` en vez de `||`: medía el orden del array, no la acumulación que su propio docstring afirmaba.
- Dos de mis greps de auditoría dieron cero por el filtro (un glob sin comillas en zsh, una
  asignación multilínea que el patrón no cogía), no por el código.

**How to apply:** al terminar un fix, antes del gate:

1. **Enuncia el bug en una frase** y aplícasela al arreglo, literalmente. «¿Mi arreglo tapa una
   fuente mejor?» «¿Mi arreglo silencia algo?» «¿Mi arreglo tiene un default que miente?».
2. **Muta el arreglo y exige rojo.** No basta con que los tests pasen: el mutante que reintroduce el
   defecto tiene que ponerlos rojos. Los dos que corrí ese día cazaron los dos defectos.
3. **Lanza la review adversarial aunque el cambio te parezca cerrado.** Tres lentes cazaron cinco
   defectos míos ahí, y ninguno lo veía la suite en verde. Es la tercera vez que pasa
   ([[review-adversarial-caza-lo-mio]]): no es mala suerte, es el modo normal de fallar.

**El mecanismo concreto, medido el 2026-09-07 en
`panel-colapsa-la-seleccion-de-cuentas-a-la-primera`: al generalizar «uno → conjunto», la condición
nueva se COPIA en varios sitios, y en uno de ellos está mal.** El bug era «el Panel colapsa el
filtro a un elemento». Sustituí `selectedAccountID != nil` por `!selectedAccountIDs.isEmpty` en dos
sitios a la vez. En modo excluir esa condición es `true`, lo que bypaseaba el toggle «incluir
grupos»: **excluir una cuenta de 200 hacía SUBIR el total 300**. Un saldo que ignora lo que el
usuario configuró, en el commit que existía para que el saldo respetara lo que el usuario configuró.

Dos lentes independientes lo cazaron **las dos**; la suite en verde (6280 tests) no. El arreglo fue
darle nombre a la regla —`PanelTotalAccountsLogic.hasAccountFilter`— para que exista en **un solo
sitio** en vez de dos copias que pueden separarse.

⇒ **Cuando un fix sustituye una condición en más de un sitio, no la copies: nómbrala.** Y sospecha
de la traducción mecánica `X != nil` → `!Xs.isEmpty`: es correcta en el caso que estás mirando y
puede no serlo en el modo de al lado.

**Tercer mecanismo, y el más barato de cometer, medido el 2026-09-07 en `fx-pnl-education-card`:
cito un precedente del repo y copio sólo la mitad que confirma lo que ya iba a hacer.** Al ver que
`amountInPreferredCurrency` podía venir sellado contra otra moneda preferida, escribí un guard que
**descartaba** esas transacciones, y en el comentario cité once calculadores del repo como aval
(`BalanceHelper:46`, `CashFlowCalculator:90`). Los once tienen un `else` **que reconvierte**: me
quedé con el `if` y tiré el `else`. El comentario sonaba a medición y era una lectura a medias.

Y el arreglo repetía la forma del bug que arreglaba: el bug de fondo era «una muestra sesgada
produce un número plausible y falso», y descartar transacciones sesga la muestra **justo hacia las
más antiguas o llegadas de otro dispositivo** — es decir, hacia otro momento del tipo de cambio.

⇒ **Cuando cites un precedente para justificar una decisión, ábrelo y léelo entero.** Un `if` sin su
`else` es media regla, y la mitad que falta suele ser la que te contradice. Si el comentario dice
«como hacen los N sitios del repo», ese comentario es una afirmación verificable: mídela.


**Cuarto mecanismo, y el que menos se ve venir, medido el 2026-09-07 en
`fx-manual-writes-seal-approximate-as-final`: no lo hereda el fix, lo hereda el DETECTOR.** El bug
era «un patrón de búsqueda no ve la mitad de las escrituras, así que el conteo dice que no hay nada
que arreglar» — el ticket contaba diez sitios y eran catorce, porque su grep buscaba la asignación y
no veía las cuatro que pasan el monto por init. Escribí un test de barrido para que eso no volviera a
pasar… y su regex usaba `^` sin `.anchorsMatchLines`, así que **contaba cero inits** y declaró
«ninguna escritura» justo sobre el único fichero cuyo único sitio es un init. El detector del bug
tenía el bug.

Lo grave no es el descuido: es **que su control positivo no lo cazó**. El control traía sólo la forma
de asignación, así que pasaba en verde con el patrón de init roto. Lo destapó el barrido real un paso
después, por casualidad de que un fichero tuviera solo la forma ciega.

⇒ **Un control positivo debe contener TODAS las formas que el detector dice cubrir, no una de
muestra.** Si el escáner cuenta dos sintaxis, el fragmento sintético lleva las dos. Un control
positivo que cubre la mitad certifica la mitad, y se lee igual que uno que certifica todo.

Y el corolario que ya se cumplió dos veces el mismo día: **los dos fallos de medición que este
fichero ya tenía anotados —el glob de zsh sin comillas y el patrón que no coge la asignación
multilínea— los volví a cometer los dos**, en los primeros cinco minutos. Tenerlos escritos no basta;
la defensa que sí funcionó fue el control negativo (correr el patrón ingenuo al lado del bueno y
comparar los conteos), no el recuerdo.


**Quinto mecanismo, y es el que refuta la defensa de los otros: NOMBRAR la regla no basta si su
INPUT se calcula en dos sitios. Medido el 2026-09-08 en
`chat-draft-stamps-its-own-currency-not-the-account`.** El bug era «la divisa que se muestra y la
que se guarda no coinciden, y nadie avisa». Hice justo lo que el segundo mecanismo prescribe: le di
nombre a la regla en un solo sitio —`ChatTransactionDraft.effectiveCurrencyCode(account:)`— y la
llamaron los dos lados. Y aun así divergieron, porque **cada lado resolvía por su cuenta el
argumento `account`**: la tarjeta contra su `@Query(filter: !isArchived)` y `saveDraft` contra
`context.model(for:)`, que no filtra. Con una cuenta archivada entre proponer y guardar, misma
función, mismo nombre, respuestas distintas: el usuario confirmaba «$ 50» y se guardaba «S/ 50».
**El mismo bug, movido al borde, dentro del commit que existía para cerrarlo** — y con un comentario
mío al lado declarando ese caso imposible («`saveDraft` aborta si no encuentra la cuenta»: no
aborta).

⇒ **Una función compartida garantiza que la REGLA es una; no que el DATO lo sea.** Si dos llamadores
derivan el mismo argumento, tienes dos criterios otra vez, sólo que escondidos un nivel más abajo.
La defensa que funcionó fue quitar la derivación: guardar el valor ya resuelto en el objeto que
ambos leen —la divisa vive en el borrador, sincronizada al elegir cuenta y congelada al guardar— para
que no quede nada que derivar. **Un valor guardado no puede discrepar consigo mismo; dos
derivaciones sí.**

Y el corolario de método: esto no lo vi yo. Lo cazaron **las tres lentes a la vez**, cada una por su
lado, y una de ellas encontró además el precedente que zanjaba el diseño —el Inbox ya tiene guarda y
string propio (`inbox.errorArchivedAccount`) para exactamente este caso—. Cuando un fix consista en
«derivar aquí lo que ya se deriva allá», pregúntate antes si el valor puede simplemente **guardarse**.

**Sexto mecanismo: el arreglo copia el ALCANCE del bug. Medido el 2026-09-16 en
`reverse-upload-has-no-ceiling-and-no-exit`.** El bug era «`handle` reemplaza TODOS los efectos pendientes y se lleva
el único que importaba» (un `reverse_abort` sin ejecutar). Mi arreglo drenaba TODOS los pendientes antes de empezar
otra vuelta, y se llevaba por delante a un líder desplazado: su reconcile lanza `other_leader` en cada intento, así que
«Volver a iCloud», que era su única salida, quedaba cerrada para siempre. Una operación sobre la colección entera, en
el commit que existía porque una operación sobre la colección entera pisaba un elemento.

Lo cazaron **las dos lentes de una segunda pasada** que lancé solo sobre los arreglos de la primera; la suite, en verde.
La defensa fue la del segundo mecanismo: nombrar el elemento (`ReverseExitPending`) y que el runner y la pantalla
pregunten lo mismo.

⇒ **Si el bug es «una operación sobre todos pisa a uno», el arreglo se ciñe a ese uno.** Y una ronda de arreglos
de review merece su propia pasada: la de hoy encontró en mis arreglos un callejón nuevo.

Relacionado: [[mis-mediciones-fallan-por-el-filtro]] (el control positivo también va en los greps de
auditoría) · [[la-premisa-del-encargo-tambien-se-mide]] (medir la premisa ajena; ésta es su gemela,
medir la propia) · [[mutante-compilado-zanja-hipotesis]] (cómo comprobar que el test del fix
protege de verdad).
