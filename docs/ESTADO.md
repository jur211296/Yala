---
updated: 2026-09-16
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-16 (Lima)

**Rama** `2.1` — Merge #182: **Sin App Attest, Ajustes no ofrece la tarjeta de la nube.**
TestFlight build **13** (CPV 13). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión (#182 · sin App Attest, Ajustes no ofrece la tarjeta de la nube)

**Un teléfono sin App Attest ya no ve la tarjeta de la nube en «Dónde viven tus datos».** Ni «Migrar a la nube» ni
«Activar la nube en este dispositivo», la cara que sale en un segundo dispositivo cuando la cuenta ya se migró desde otro:
tu decisión de las 7:1x, porque sin token las dos acaban en el mismo reintento sin fin, y «Migrar» además dejaba la cuenta
creada en el servidor. La pantalla se queda con «iCloud privado» y, si aplica, Grupos, sin texto nuevo. Con App Attest no
cambia nada, y quien ya está en la nube o tiene una migración a la vista conserva su pantalla. Es la tercera puerta del
día, después de #180 y #181.

**La review cazó tres cierres de más sin red, y una frase mía falsa.** Una segunda lectura de la capacidad en el botón, el
guard de aborto invertido o una copia de la declaración bajo `#if DEBUG` le quitaban la tarjeta a un iPhone con App Attest
con todo en verde: ahora tienen red. Y «quien ya está dentro conserva su panel» era falso para quien tocó «Activar en este
dispositivo» antes del cambio: se queda sin tarjeta mientras el adopt reintenta en segundo plano.

**Dos cosas van a otros tickets.** La frase de Grupos «Se decide en Ajustes» ya no lleva a ninguna tarjeta sin App Attest:
la anoté, como elegiste, en `groups-block-has-no-route-to-storage-settings`, que la va a cambiar por un botón. Y un defecto
anterior va a ticket nuevo: `groups-only-session-storage-screen-says-data-lives-in-icloud`.

Gate: build ×2 sin warnings en lo tocado · **unit 7052 casos en 725 suites** · **XCUITest 15 casos** con el centinela en 0
(14 verdes y `test_extremeMinimumAmountSaves`, el flaky conocido, verde aislado 2 de 2) · **mutation-tested ×13**, cada uno
en rojo en su test · tres lentes · **CI verde** (build y los 7052 unit).

**En `qa`, con un paso en iPhone real**: con App Attest la tarjeta sigue saliendo. Comparte montaje con los de #180 y #181.

## Sesión anterior (#181 · sin App Attest, la pantalla de entrar no ofrece crear cuenta)

**Un teléfono sin App Attest ya no se da de alta en la nube por ninguna puerta del Welcome.** Después del #180 quedaban
dos: «Crear mi cuenta» tras «No encontramos una cuenta» y «Crear cuenta con…» del mismatch. Ahora pasan por la misma puerta
que la tarjeta, `WelcomeNewOptionsGate.offersCloudSignUp`: App Attest, el kill del alta y el resto de la card. Sin ella, «No
encontramos una cuenta» ofrece **«Volver»** —tu decisión de esta mañana, con el texto que ya existía— y el mismatch se queda
con «Iniciar sesión con…». Con App Attest no cambia nada. Encargo nocturno, opción 1.

**La review cazó otra vez el fallo caro en MIS tests.** Medían que los botones de crear cayeran dentro de la puerta, no que
la puerta fuera su única condición: un `if` más o un `#if DEBUG` le quitaba el botón a un iPhone con App Attest con la suite
en verde. Ahora fijan el cuerpo entero de las dos pantallas. Cazó también que mi primera versión dejaba «No encontramos una
cuenta» con la flecha de la esquina sola —el callejón que quitó el bloque [I]— y un guion de device-QA que el faro de
iCloud podía dar por FAIL.

**El simulador ya no crea cuentas en la nube sin `YALA_DEV_SHARED_SECRET`**, por ninguna vía. El montaje del #175 queda
reescrito con el secreto, y ese secreto **no está en `~/Secrets`**: es de Wrangler en staging y no se lee de vuelta. Lo
tienes tú, o hay que rotarlo.

Gate: build ×2 sin warnings en lo tocado · **unit 7048 casos en 725 suites** · **XCUITest 18 casos** con el centinela en 0 ·
**mutation-tested ×22**, todos en rojo en su test · dos lentes + la regla de attest · **CI verde** (build y los 7048 unit).

**Quedaba en backlog `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`**: «Migrar a la nube» era el único
camino al alta completa que no miraba la puerta. Lo cierra #182.

## Sesión #180 · sin App Attest, el alta no ofrece la nube

**Un teléfono que no puede conseguir App Attest ya no ve «Tu cuenta en la nube».** Antes la elegía, apuntaba sus gastos y
nada llegaba nunca a su cuenta: el motor corta en su puerta de attest antes de subir. Ahora «Es mi primera vez» va directa a
«Tu cuenta en tu iCloud privado», el recorrido de cuando la nube está apagada, sin texto nuevo. Lo mismo en «Activar Yala
completo», y «Crear otra cuenta» enseña la elección con la tarjeta privada sola. Con App Attest no cambia nada. Era la
decisión del owner del 2026-07-06 —bloquear por adelantado—, que vivía en `AttestSyncGate.shouldOfferCloudOnly` sin un solo
llamador y con dos docblocks que decían lo contrario. Encargo nocturno, opción 1.

**«Tener App Attest» lo define un solo sitio, y es lo que cree el cliente**: `AppAttestClient.canObtainSessionToken`, la
primera decisión de `performRefresh` en un booleano (`isSupported`, o en DEBUG el bypass con secreto). **El simulador no
tiene App Attest y no se le exime**: sin `YALA_DEV_SHARED_SECRET` en `Yala Dev` ya no ofrece la nube, a propósito, para que
QA y producción decidan igual. Si en el simulador «no sale la nube», no es la configuración remota.

**La review adversarial cazó el fallo caro en MI test, no en el código.** El scan de la entrada del attest fijaba un prefijo
sin su coma, y un término pegado detrás dejaba a todo iPhone sin la nube con la suite entera en verde: en el host de test la
capacidad vale `false` y nada más podía verlo. Ahora compara el cuerpo entero. Cazó además dos aserciones que no podían
fallar y que «Crear otra cuenta» no hacía bypass ni tenía test.

Gate: build ×2 sin warnings nuevos · **unit 7045 casos en 725 suites** · **XCUITest 20 casos** con el centinela en 0 · dos
lentes + la regla de attest contra el diff · **CI verde** (build y los 7045 unit). **Mutation-tested ×14**, todos en rojo en su caso; el control sin
el seam mide que en XCUITest el simulador de verdad no tiene App Attest.

**Deja dos decisiones tuyas en backlog, las dos nacidas de medir el alcance** (las dos cerradas después, en #181 y #182).
`cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`: «Crear mi cuenta» tras «No encontramos una cuenta» y
«Crear cuenta con…» del mismatch también dan de alta sin mirar el attest (ni el kill del alta, que es anterior); cerrarlas
vuelve pared dos pantallas que tú abriste. `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`: «Migrar a la
nube» tampoco lo mira, aunque por lo inferido no atrapa a nadie. Y un tercer productor del «volver» mal calculado de la
puerta de iCloud, anotado en `private-icloud-gate-back-lands-on-the-wrong-branch`.

## Sesión #179 · volver a la app adelanta la subida de grupos

**Quien recupera la conexión y vuelve a Yala ya no espera al reintento.** Me quedo sin red con la app abierta,
salgo, la red vuelve y entro otra vez: antes mis cambios de grupos seguían parados hasta que venciera el
reintento pendiente —5, 10, 20… hasta **cinco minutos**—, salvo que guardara algo o tirase hacia abajo para
refrescar. Ahora vuelven a subir en el acto. Es la decisión de Jürgen del 2026-09-15, opción 1: copiar lo que
el motor personal hace desde I9, que al volver a primer plano corta el sueño en curso y cicla ya.

**Dos ventanas, dos mecanismos, y entre las dos no queda hueco.** El sueño de cada vuelta del loop pasa a
vivir en una tarea propia que el foreground cancela; el foreground que llega **mientras el ciclo corre** no
tiene sueño que cortar y lo sirve una marca que pone a cero el delay de esa vuelta y solo de esa. Despertar
**no borra la racha de fallos**: adelantar un reintento no significa volver a empezar por 5 s, y lo fija una
aserción. Entra por el mismo `startIfEligible(trigger:)` que ya llamaba el bootstrapper, en el `else` donde
antes no pasaba nada — así ningún call-site futuro puede olvidarse de despertar.

**La review adversarial cazó un defecto serio que era MÍO, y las tres lentes coincidieron.** Sacar el sueño a
una tarea aparte le quitaba dos garantías del contenedor. Una, la cancelación: un `Task {}` no hereda la de
quien lo crea, así que `stopLoop()` —los cinco caminos de cierre de sesión— habría esperado el backoff entero;
lo cierra un `withTaskCancellationHandler` con test propio. La otra, la identidad del handle: `stopLoop()`
despublica el loop en el acto pero el viejo sigue dentro de su request, y al morir le borraba el handle al que
había nacido detrás — dos loops vivos, un `stopLoop` posterior cancelando `nil` y un despertar que dejaba su
línea en el log **sin cortar nada**, o sea el bug del ticket resucitado e invisible. Cada loop lleva ahora su
generación. El mismo defecto estaba en el `defer { loopTask = nil }` **anterior a este cambio**.

Y cazó **una aserción mía que no podía fallar**: miraba el efecto de un `cancel()` sin soltar el MainActor, y
el `catch` que lo registra no corre hasta entonces — salía verde también con el gate borrado. Lo destapó el
mutante, no la lectura.

Gate: build ×2 sin warnings nuevos · **unit 266 casos en 19 suites** · **XCUITest 4 casos** con el centinela
del simulador en 0 · tres lentes + las rules de área contra el diff · **CI verde**. **Mutation-tested ×7**, los
siete en rojo. **Sobrevive uno y va declarado**: publicar el sueño sin comprobar la generación, cuyo escenario
exige que el loop nuevo duerma antes que el viejo. **Sin device-QA**: reproducirlo pide cortar la red con
cambios sin subir y esperar a que el backoff crezca; no hay seam de simulador que lo monte y el efecto no tiene
superficie visual. El rastro en Console.app es `GroupsSync loopWoken trigger=foreground sleeping=true`.

**Deja un ticket nuevo y dos residuales escritos.**
`groups-has-no-cadence-when-the-personal-runtime-is-stopped`: con el motor personal parado
(`.stoppedUntilRelaunch`), Grupos se abstiene de su loop porque el gate mira `canRunDomain()` y ése no mira el
estado del runtime — ahí no hay loop que despertar y volver a la app tampoco lo mueve. Los residuales, para no
re-litigarlos: el despertar corta también la cadencia sana de 60 s (igual que el personal en `.running`), y sin
red cada vuelta a la app suma un escalón de backoff (misma aritmética que el personal).

## Sesión #178 · sin conexión, el cierre ya no dice que está guardando algo

**Quien intenta cerrar sesión sin conexión ya no oye que se está guardando algo.** Antes esperaba 45 s mirando
«Guardando tus cambios pendientes…» y al final leía «Un momento más · Todavía estamos terminando de guardar
unos cambios. Espera unos segundos y vuelve a intentarlo». Nada de eso pasaba: faltaba la red, y volver a
intentarlo costaba otros 45 s de lo mismo. Ahora el aviso sale **al primer intento** y dice lo cierto — los
cambios **no llegaron al servidor**, siguen guardados en este teléfono y no se pierden. El texto de «un
momento más» se queda donde siempre fue verdad: el guardado que todavía se asienta, que sigue reintentando
sus 45 s porque ahí esperar es justo lo que hace que el gesto termine solo. Es la decisión de Jürgen del
2026-09-15: separar las dos causas, una con su texto.

**Cuatro superficies y cero keys de l10n nuevas.** Ajustes y la hoja del cambio de Apple ID ya estaban
enrutadas. El desasociar y la puerta de Grupos del Welcome lo estrenan, y al segundo le hacía falta rama
propia: su `switch` no es exhaustivo, así que `.uploadRetryLater` habría caído en el catch-all que dice
«vuelve y entra con esa cuenta» — el consejo contrario para quien no tiene red. Lo anticipaba el propio
docblock del motivo, escrito el 14-sep «para el día en que naciera un segundo productor».

**La review adversarial refutó mi arreglo, y esa es la mitad no obvia.** Mapeé `CadenceOutcome.transient`
entero a «la subida falló» tras inventariar sus 40 productores… y la conclusión era la equivocada, porque no
miré **quién escribe el valor que estaba clasificando**: `syncCycleOnce` corta con el outcome del push solo
si el push PARA, así que en el caso normal el veredicto es **el del pull**. Con la subida perfecta y el pull
caído yo decía «tus cambios no llegaron al servidor»; y al `save()` local de una página —que es
H-2026-07-18-6, el caso que motivó los 45 s— le quitaba encima el reintento que sí lo cura. De ahí sale
`GroupsSyncClient.lastCycleFailedUpload` + `stoppedByFailedUpload(for:)`, molde exacto de sus dos hermanos:
se baja al entrar en el ciclo y lo enciende el push y solo el push, en los nueve puntos donde se choca con el
servidor. La marca es POSITIVA: marcar de menos deja el aviso conservador de siempre, marcar de más acusa al
servidor de algo que pasó en este teléfono.

Gate: build ×2 sin warnings nuevos · **unit 7029 en 725 suites** · **XCUITest 3 clases y 10 casos** ·
review de tres lentes + las rules de área contra el diff · **CI verde**. **Sin device-QA**: reproducirlo
exige cortar la red con cambios de grupos sin subir y una sesión viva, y no hay seam de simulador que lo
ponga; el ticket cierra en `done`.

**Deja un ticket y un colateral que conviene saber.**
`sign-out-block-reason-is-only-logged-on-the-cloud-path`: el motivo del bloqueo solo se registra en el camino
de la nube, justo donde este cambio mueve población entre dos avisos distintos. Y
**`signout-alert-fires-on-detach-blocks-it-did-not-cause` empeora**, anotado allí con su medición: al
desasociar sin red, el aviso colateral de Ajustes pasa de «Un momento más» —impreciso pero neutro— a **«No
pudimos cerrar tu sesión»**, que nombra un gesto que nadie pidió. No se arregló a propósito: cortar por
motivo dejaría sin aviso al cierre de verdad, y el discriminador correcto es el GESTO, que el coordinador no
publica. **Es una decisión de producto que espera a Jürgen.**

De paso, el disco había bajado a 12 GB —los XCUITest habrían empezado a fallar con errores que no mencionan
el disco—: 13 GB recuperados de DerivedData de dos worktrees ya retirados.

## Sesión #177 · la app avisa cuando este teléfono no puede sincronizar tus datos

**Quien tiene sus datos en la nube y este teléfono no consigue la verificación de seguridad ya se entera solo.**
Antes no se lo decía nadie: apuntaba gastos, no llegaban a su cuenta, y solo lo descubría si intentaba cerrar
sesión. Ahora, mientras el veredicto sea terminal, el **Panel** enseña un aviso fijo con el mismo título que ese
cierre —«Este teléfono no puede sincronizar tus datos»— y un cuerpo que añade lo que nadie decía: **lo apuntado
sigue guardado en este teléfono**. Sin X y sin botón, como el hermano de Grupos. Es el ticket que dejó el #176.

**Van DOS superficies porque la segunda mentía.** La opción menos intrusiva era el estado de sync de «Dónde viven
tus datos»… que pintaba un check verde **«Todo al día» con el motor parado**: `refreshSyncBanner` solo mira
`.stoppedUntilSignIn`, y el attest terminal deja el runtime en `.stoppedUntilRelaunch`, que caía al `else`. El
`else` fallaba ABIERTO. Las dos caras comparten una sola decisión y un solo copy, y la rama del attest va **antes**
que la de volver a entrar: re-firmar no arregla un attest roto.

**La review adversarial cazó tres cosas mías y dos cambiaron el producto.** (1) El copy **mandaba a un paywall**:
decía «en Perfil puedes exportar tus datos», y el wizard capa los períodos largos a quien no es Pro — justo la
población que ve el aviso, porque el Modo Nube es gratis. La exportación completa y gratuita existe desde el #175,
pero solo se alcanza al cerrar sesión; el copy ya no la menciona. (2) Faltaba una **cuarta condición**: sin ella,
quien vuelve a iCloud *precisamente porque sus datos dejaron de subir* veía «usa otro teléfono», el consejo
contrario a lo que estaba haciendo. (3) `hasSession` **lee el Keychain** y se evaluaba en cada re-render, también
en los teléfonos que nunca tendrán aviso.

Gate: build ×2 sin warnings nuevos · **unit 7019 en 724 suites** · **XCUITest 8 clases y 20 casos** con cola y
centinela («estuviste solo», 96 muestreos) · **12 mutantes, 12 muertos** · review de tres lentes · **CI verde**.
**Sin device-QA**: el aviso es visual y determinista, y el ticket cierra en `done`.

**Deja dos tickets y un agujero que conviene saber.** `cloud-hydration-spinner-never-gives-up-without-attest` (el
«Descargando tus datos…» que gira para siempre y ahora contradice al aviso), y una anotación dentro de
`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`: **el canal personal no distingue su propio 401
de attest**, así que a quien el gateway le rechaza el token la app le sigue diciendo «vuelve a iniciar sesión» y el
aviso nuevo **no puede salir**, por construcción. De paso, `docs/TICKETS.md` estaba desfasado en un ticket ajeno;
índice y disco cuadran ahora en 407.

## Sesión #176 · la pestaña Grupos avisa cuando este teléfono no puede sincronizar

**Quien apunta gastos de un grupo desde un teléfono que no consigue App Attest ya se entera.** Antes no se lo decía
nadie: editaba, nadie del grupo lo veía, y el aviso solo aparecía al intentar cerrar sesión, desasociar la cuenta o
salir del grupo. Ahora, mientras el veredicto sea terminal, encima de la lista hay un aviso fijo con el **mismo
título** que esos gestos —«Este teléfono no puede sincronizar tus grupos»— y un cuerpo que ofrece lo único cierto:
usar otro teléfono. Sin X y sin botón, porque describe un estado que sigue ahí después de leerlo y reintentar es
justo lo que lleva un día fallando. Es tu decisión del 15-sep, opción 1.

**Son CUATRO condiciones, no «mientras el veredicto sea terminal».** La racha describe al TELÉFONO: sobrevive al
cierre de sesión a propósito y desde el #175 la escribe también el motor personal, que no sube un gasto de grupo. Con
el enunciado literal, el aviso le mentiría a quien cerró sesión, a quien no tiene Grupos compilado y a quien todavía
no aceptó el consent.

**La review adversarial cazó tres cosas mías y una era el bug del ticket, vivo.** (1) El término del canal iba por el
getter compuesto, que es fail-closed sin snapshot de remote-config: un teléfono **restaurado desde una copia de
iCloud** —que hereda la racha y no la key de attest— se quedaba **sin aviso** en su primer arranque mientras el
cierre de sesión sí se lo enseñaba. Va por la capacidad compilada, como los cuatro teardowns. (2) El aviso se quedaba
mudo con la pestaña delante: medido en el simulador, con la racha escrita un segundo después del arranque no salía
hasta salir y volver — y eso es justo cuando llega el 401. Ahora avisa el **escritor** de la racha. (3) El seam de QA
dejaba el veredicto terminal puesto para todo arranque **manual** del simulador; bajo uitest la racha va ahora a una
suite propia.

Gate: build ×2 sin warnings nuevos · **unit 199 en 33 suites** · **XCUITest 27 clases y 67 casos** con cola y
centinela («estuviste solo», 234 muestreos) · **9 mutantes, 9 muertos** · review de tres lentes · **CI verde**.
**Sin device-QA**: el aviso es visual y determinista, y el ticket cierra en `done`.

**Deja un ticket nuevo:** el mismo aviso fijo para la nube personal, que sigue sin tenerlo. Y anota en
`unit-tests-clear-the-attest-streak-of-a-device-qa-in-progress` que el desvío de uitest **no** lo cubre: los unit
tests corren sin `-uitest`.

## Sesión #175 · sin App Attest en la nube: exportar y salir perdiendo lo personal, con confirmación)

**En la nube, un teléfono que lleva más de un día sin conseguir App Attest ya puede cerrar sesión aunque le
queden cambios suyos sin subir.** Es tu decisión del 15-sep (opción 1). Antes el cierre le mandaba a revisar una
conexión que funcionaba, y así durante días. Ahora Ajustes dice «Este teléfono no puede sincronizar tus datos»,
cuenta los cambios que no llegaron y ofrece tres cosas: exportar todos los movimientos a un CSV, cerrar sesión
perdiéndolos, o dejarlo. Exportar no toca el cierre y devuelve al aviso. Elegir perderlos no borra nada al
momento: el cierre intenta subir una vez y lo que no suba se va con el borrado del arranque. Con cambios de
grupos también, salen los dos avisos seguidos. Y si el attest volvió pero la subida falla por otra cosa, el
cierre se para como siempre en vez de perderlos — también en la salida de grupos del #173, que tenía el hueco.

**Contestaste las tres preguntas de producto con la recomendada:** un aviso con tres botones, exportación directa
de todo sin asistente ni límite de plan, y dos avisos seguidos cuando también hay cambios de grupos.

**La racha de rechazos pasa a ser del TELÉFONO y la escriben los dos canales.** El motor personal nunca manda una
subida sin attest, así que no ve el 401: cuenta el error de su propia puerta cuando habla del attest, y un token
la borra. Sin red o con el gateway caído el veredicto no se acerca. Con dos rachas, aceptar perder lo personal
dejaba los cambios de grupos en «en un rato».

**Una premisa escrita era falsa:** la puerta que no ofrecería la nube a un teléfono sin App Attest **no tiene
llamador**, y dos docblocks decían que sí. Hoy esta salida es la única red para esa gente, y queda su ticket.

**Y media sesión se fue en un rojo que no era del cambio.** Un XCUITest de la hoja del Apple ID cayó 3 de 3 aquí
y pasó en un árbol base: nueve corridas de bisección construyeron una causa falsa, hasta que repetir la MISMA
compilación dio pasa/falla/pasa y el árbol de partida acabó pasando 4 de 4 sin tocar una línea. Es el entorno
—16 sesiones de Claude Code vivas, el sistema matando tandas de tests por memoria— y queda medido en su ticket,
con la corrección de que no es solo «el simulador frío». La lección de método está en la memoria de Frank.

Gate: build ×2 sin warnings nuevos · **unit 6.876 en 699 suites** (por lotes: entera no cabía en memoria) con un
rojo preexistente del resumen de Registros que **pasa aislado** y solo cae junto a las suites de grupos y FX ·
**31 mutantes, 31 muertos** · **XCUITest 71 casos en 31 clases** con cola y centinela, con el rojo del entorno
clasificado en 19 corridas · review de tres lentes · **CI verde**. **Device-QA: no se puede montar aquí**, y el
ticket queda en `qa` con su guion.

**Deja seis tickets nuevos**, uno alto: la puerta del onboarding que no ofrece la nube y no tiene llamador.

## Sesión #173 · un teléfono sin App Attest recibe su veredicto y puede cerrar sesión perdiendo los cambios)

**Un teléfono que lleva más de un día sin conseguir App Attest deja de oír «inténtalo en un rato».** Es tu decisión
del 15-sep (opción 2). Pasadas 24 h con al menos 3 rechazos del servidor —como mucho uno por hora— y ningún acierto,
Grupos dice «Este teléfono no puede sincronizar tus grupos». Si al cerrar sesión quedan cambios de grupos sin subir,
Ajustes, la hoja del cambio de Apple ID y la puerta del Welcome ofrecen «Cerrar sesión y perderlos» con la cifra; a
quien entra por una invitación, no. Desasociar y salir de un grupo enseñan el veredicto sin salida. Elegir perderlos
no borra nada al momento: el cierre intenta subir una vez más, y lo que no suba se va con el borrado del arranque.

**Contestaste las cuatro preguntas con la recomendada:** 24 h y 3 rechazos, solo los cierres ofrecen salir, un botón
que nombra la pérdida, y el aviso fijo en la pestaña Grupos a ticket.

**La review adversarial (tres lentes) cazó uno alto, mío.** Lo aceptado era una cifra, y aceptar «2 cambios» cubría
cualquier par: un cambio nuevo se perdía sin aviso. Ahora son las filas que contó el aviso. Además, 3 rechazos los
cumplía un solo gesto (ahora cuenta uno por hora), y dos tests de pantalla no detectaban sus mutantes. **Y una premisa
del ticket era falsa:** el canal personal no tiene banner terminal, solo un canario.

**El #174 corrige un guion mío.** El device-QA pedía dos lanzamientos separados por 24 h, que dejan la racha en dos y
nunca llegan al aviso; ahora el primero dura algo más de dos horas.

Gate: build ×2 sin warnings nuevos · **unit 1026 en 120 suites**, y la suite completa **6977 en 715** antes de mergear ·
**25 mutantes, 25 muertos** · **XCUITest 89 casos en 38 clases** con el centinela · tres lentes. **Device-QA: solo la
racha** (0-terdecies de la cola); la salida con pérdida no se puede montar en ningún dispositivo.

**Deja dos tickets, los dos con decisión tuya** (ver «Siguiente»).

## Sesión #172 · un 401 por App Attest ausente deja de leerse como «Tu sesión caducó»)

**Con la sesión buena y sin App Attest, ninguna pantalla dice ya «Tu sesión caducó», y el sync de grupos no se
para.** Es tu decisión del 15-sep (opción 1): el 401 `yala_attest_required` es pasajero. Salir de un grupo pide
volver a intentarlo, aceptar una invitación ya no reabre el inicio de sesión, y los cierres de sesión enseñan el
aviso de lo pasajero, como sin red desde el #171. Con el JWT caducado de verdad se sigue pidiendo volver a entrar.

**El cliente de membresía tenía lo mismo**, y se arregla con el mismo criterio.

**La review adversarial (tres lentes) cazó cosas mías.** Una nota daba el caso por «solo en carrera» en el canal
personal, y la migración sube sin esa puerta. Y había huecos en los tests: la re-emisión del pull, un test de loop
que podía colgar y el attest caducado en el gateway. Todo arreglado o con ticket; cuatro costes aceptados quedan
escritos en `.claude/rules/gateway-attest.md`.

Gate: build ×2 sin warnings nuevos · **unit 858 en 86 suites** · **11 mutantes, 11 muertos** (6 iOS, 5 gateway) ·
**XCUITest 5 casos en 2 clases** con el centinela · gateway 20/20 · tres lentes. **Device-QA: parcial** (0-duodecies de la cola).

**Deja cuatro tickets, uno con decisión tuya** (ver «Siguiente»).

## Sesión #171 · sin conexión, «Tu sesión caducó» deja de salir a quien sigue con la sesión viva

**Sin red y con el token caducado, ninguna pantalla dice ya «Tu sesión caducó» ni manda a volver a entrar.** Es tu
decisión del 15-sep: separar en el cliente «sin conexión» de «sesión caducada». Al cerrar sesión en la nube sale al
momento «Los últimos cambios de tus grupos no llegaron al servidor…»; en el «equipo», en solo grupos, en la hoja del
Apple ID y en la puerta del Welcome, tras ~45 s de reintentos, el aviso de lo pasajero. Con la sesión borrada de
verdad se sigue pidiendo volver a entrar. **Y el sync de grupos ya no se para sin red:** reintenta solo.

**Te pregunté tres cosas y elegiste las tres recomendadas:** el mismo mensaje en Ajustes, la hoja y el Welcome;
salir de un grupo y aceptar invitaciones, a ticket; y subir en el siguiente reintento, sin vigilante de red.

**La review adversarial cazó tres cosas mías.** Con el predicado invertido, los tests de loop **colgaban** en vez de
fallar (ahora llevan fusible); el caso del mismo token tras un 401 no estaba fijado; y una premisa mía era falsa:
escribí «Modo Nube apagado» y la tarjeta de alta en la nube se ofrece en producción desde el 9-sep.

Gate: build ×2 sin warnings nuevos · **unit 946 en 105 suites** · **5 mutantes, 5 muertos** · **XCUITest 22 casos
en 8 clases** con el centinela (dos corridas cortadas por memoria) · contrato del SDK ejecutado · tres lentes ·
CI verde. **Device-QA: sí, y no es simulable** (0-undecies de la cola).

**Deja cinco tickets, tres con decisión tuya** (ver «Siguiente»).

## Sesión #170 · se retira el sello que apagaba el canal de Grupos hasta relanzar la app

**No cambia nada en pantalla.** El canal de Grupos tenía un freno: si el servidor decía que la cuenta no
estaba disponible, dejaba de sincronizar hasta matar y reabrir la app. Desde el 13-sep ninguna respuesta
real lo echaba —solo un 409 que `/groups/push` no emite—, y **tu decisión 4A fue retirarlo**. Ahora
cualquier parada del canal se vuelve a intentar en el siguiente arranque, vuelta a la app o inicio de sesión.

**La review adversarial cazó dos huecos míos en los tests, y los dos están arreglados.** El único cambio de
conducta —el 409 ya no cierra el canal— no lo fijaba ningún test, así que volver a poner el freno salía verde.
Y al quitar la aserción sobre el seam, el test del apagado del canal dejó de cubrir el save local y el silent
push.

Gate: build ×2 sin warnings nuevos · **unit 555 en 59 suites** · **3 mutantes, 3 muertos** (el freno
retirado, puesto tal cual, cae) · XCUITest 4 casos en 2 clases con el centinela · dos lentes adversariales ·
CI verde. **Device-QA: no aplica.**

**Un rojo de XCUITest que no era de este cambio:** `test_extremeMinimumAmountSaves` cayó una vez y pasó la
siguiente con el mismo binario; la base pasó con el mismo comando, y el test no ejecuta el código tocado. La
medición va a `edgecases-extreme-minimum-flaky-under-load`.

**Deja un ticket `low`:** `groups-loop-restart-docs-cite-a-retired-mount-guard`, tres comentarios que
prometen un guard de la sesión de visita que ya no existe.

## Sesión #169 · al cerrar sesión en la nube, una sesión de grupos caducada ya pide volver a entrar

**Cuenta en la nube, cambios de grupos sin subir y la sesión caducada: «Cerrar sesión» ya no dice «revisa tu
conexión».** Dice «Tu sesión caducó. Vuelve a iniciar sesión e inténtalo de nuevo.», como las otras tres formas
de cerrar sesión. Es tu opción 1 del ticket. El bloqueo no cambia: nada se sube, nada se borra y la sesión
sigue abierta.

**Medir antes de escribir sacó dos decisiones tuyas, las dos `medium`.** El aviso afirma más de lo que el
motivo sabe:

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry`: «Tu sesión caducó» también sale **sin
  conexión**, con el token caducado. Ya pasaba en el «equipo», en solo grupos, en el desasociar y en el
  Welcome; desde hoy, también en la nube. Recomendación: separar los dos casos en el cliente.
- `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`: en la nube, «vuelve a iniciar sesión» no
  dice dónde. La única puerta es «Nuevo grupo», solo si el SDK borró la sesión, y no está medido que exija la
  misma cuenta.

Gate: build ×2 sin warnings nuevos · **unit 198 en 22 suites** · **3 mutantes, 3 muertos** · **XCUITest 5
casos en 2 clases** · una lente adversarial, que no encontró acciones que cambien y matizó el segundo
hallazgo. **Device-QA: sí, y no es simulable** (0-decies de la cola).

**Y un rojo intermitente de XCUITest, con ticket `low`:** en la primera corrida tras arrancar el simulador, la
oferta en cola no apareció al cerrar la hoja del Apple ID. Pasó 3 de 4 con el mismo binario
(`queued-offer-after-dismiss-flakes-on-a-cold-simulator`).

## Sesión #168 · si el cierre por cambio de Apple ID se bloquea, ya se ve y se sale

**Cambias de cuenta de iCloud, tocas «Cerrar sesión y quitarlos», y si el cierre no puede completarse Yala
ya lo dice.** Hasta hoy el aviso se cerraba y no pasaba nada visible —sin red con una cuenta de grupos, con
los grupos en pausa o con cambios de grupos de una sesión caducada—, y encima el teléfono se quedaba sin
poder cerrar sesión desde ningún otro sitio hasta reabrir la app. Ahora el aviso es **una hoja con fases**:
la pregunta, un progreso y, si se bloquea, **el motivo con el mismo texto que Ajustes, «Reintentar» y «Ahora
no»**, que deja libre el cierre.

**Una segunda puerta del mismo síntoma que el ticket no nombraba:** el botón leía el interruptor de Grupos
compuesto y el coordinador el compilado, así que con el kill remoto de Grupos el tap no hacía nada.

**La review y los mutantes cazaron cosas mías.** La review, un progreso eterno con Ajustes abierto debajo:
las hojas de las pestañas no entran en la matriz del shell. Los mutantes de XCUITest, dos afirmaciones falsas
del propio test: el manejador de interrupciones de XCTest reconocía el bloqueo por el test, y en iOS 26.5
otra hoja no sirve para medir que la matriz retiene la cola. Las dos trampas están en
`.claude/rules/testing.md`.

Gate: build ×2 sin warnings nuevos · **unit 6921 en 708 suites** · **21 mutantes unit, 21 muertos**, y de
XCUITest 2 muertos y 1 vivo explicado · **XCUITest 111 casos en 47 clases**, todas las que pide el
cruce del índice, con el centinela sin intrusos. **Device-QA: sí, y no es simulable**: recorrido 5 de
`device-qa-apple-id-change-closes-private-session`.

**Te deja una decisión de copy, con recomendación:**
`apple-id-close-notice-does-not-say-what-else-the-close-does`. El aviso no dice que el cierre también quita
del teléfono los grupos.

**Y un hallazgo del cierre**, `generated-index-lands-above-yaml-frontmatter` (`medium`): `indexar_doc.py`
pone su índice encima del frontmatter. Hay 7 ficheros así, entre ellos la rule `git-hooks.md`, que podría
estar cargándose sin respetar sus `paths:`.

## Las de antes
- **#167 · las preferencias ya no cruzan entre el dueño y un móvil prestado.** Quien entra por un grupo en un
  móvil prestado ya no le cambia el idioma ni los ajustes al dueño, ni al revés (`OwnerKeyValueGate`). Dejó dos
  decisiones tuyas y un `medium`. Device-QA en la cola (0-nonies).
- **#166 · el hueco del vaciado remoto se cierra con el número, no con código.** Quien entró por un grupo
  antes del 10-sep no lleva la marca del eje, y el ticket daba dos salidas: Jürgen zanjó **población cero**,
  medida por cuatro vías independientes (telemetría, backend, App Store y builds distribuidos). No cambia nada
  en pantalla; un test fija las dos escrituras de la marca y el censo de armadores. Device-QA: no aplica.
- **#164 · el aviso de datos borrados ya no aparece encima de lo que estuvieras mirando.** Ahora espera su
  turno en la cola de avisos, así que ya no tumba la pantalla que tuvieras delante ni deja la app sin avisos.
  Quedan `orphan-alerts-behind-fullscreen-covers`, la segunda celda de
  `wipe-data-does-not-cancel-the-remote-wipe-grace` y el desarme de la red, probado solo a mano. Device-QA: no
  aplica.
- **#162 · el aviso de datos borrados ya no le habla de iCloud a quien no lo tiene en juego.** Tras
  «Vaciar datos», el aviso de «borrado desde otro dispositivo» ya solo sale en la sesión cuyos datos viven
  en el iCloud de este Apple ID. La premisa del ticket era falsa: lo que se cerró fue el aviso
  auto-infligido. Device-QA: no aplica.
- **#161 · vaciar tus datos ya no promete que se borran de todos tus dispositivos.** La hoja
  prometía un borrado en todos tus dispositivos que el #157 había dejado de cumplir; hoy promete solo lo
  que se cumple, fijado por unit desde el camino de producción. Sin decisiones.
- **#160 · «Empezar desde cero» sin iCloud ya vuelve a Restaurar y no promete nada.** Si la app no
  conseguía mirar tu iCloud te decía «Seguir así», te llevaba al onboarding y tus datos viejos seguían
  enteros: un borrado anunciado que nunca ocurrió. Y te dejaba apuntado para el aviso del espejo tardío,
  cuyo botón se lleva el dominio de Grupos — o sea que activar Yala completo para conservar los grupos
  podía acabar sin ellos. Hoy dice que no pudo mirar, que no borró nada, y te devuelve atrás.
- **#159 · cambiar el Apple ID del teléfono ya cierra la sesión privada.** La app no se enteraba del
  cambio de cuenta de iCloud y seguía enseñando los datos de la anterior; hoy lo detecta y pregunta.
  «Ahora no» no toca nada, y volver a tu cuenta anterior lo silencia solo. Dejó vivo un ticket
  **high**, `apple-id-close-blocked-has-no-visible-outcome` (si el cierre se bloqueaba, nadie lo enseñaba
  y el coordinador quedaba tapiado), que cerró el **#168**.
- **#158 · «Empezar desde cero» al activar Yala completo ya borra de verdad.** Ese botón no borraba
  NADA y el corpus viejo se re-exportaba a iCloud; hoy pasa por la puerta que pregunta a iCloud, enseña
  las cifras y exige un segundo gesto. Los grupos, el nombre y la divisa no se tocan.

El **#157** (vaciar tus datos ya no vacía el teléfono que prestaste) dejó su parte en el PR y en
`git log`; lo vivo de él es su device-QA. Los partes de los merges #144 a #156 viven igual en sus PR — el
del **#156** (un fallo pasajero de grupos ya no dice «revisa tu conexión») deja 4 tickets. Del **#155**
(«Empezar desde cero» en Restaurar ya borra) queda vivo su device-QA (cola, 0-quinquies) y un ticket,
`private-icloud-gate-back-lands-on-the-wrong-branch` (`medium`).

## Marketing (Lola · #142 · el estudio de vídeo)

**Ya hay sistema para sacar vídeo del producto sin dibujar la app**: `marketing/remotion/`, con dos
formatos —una presentación 16:9 por escenas y clips 9:16 por función— sobre grabaciones reales.
**Espera tu ojo** y tres decisiones cortas (`marketing/remotion/out/`, se regenera con
`bun run render:presentation` y `bun run render:reels`).

## Tu cola

0-quindecies. **Device-QA del #181, dos pasos**
   (`tickets/qa/cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest.md`). **A, en el simulador** con Yala Dev
   y sin el secreto: «Ya tengo una cuenta» → «Entrar con Google» con una cuenta sin Yala. Tiene que salir «Volver» y **no**
   «Crear mi cuenta» (o el mismatch sin «Crear cuenta con…»). **B, en un iPhone** con el TestFlight, mismo montaje que el
   0-quattuordecies: el mismo recorrido enseña el botón de crear, **sin tocarlo**. Borrar la app se lleva lo que no esté en
   tu iCloud o en la nube.

0-quattuordecies. **Device-QA del #180, un solo paso en iPhone real**
   (`tickets/qa/cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest.md`). Con el primer TestFlight tras el
   merge: borra Yala, instálala, espera unos segundos con conexión y toca «Empezar» → «Es mi primera vez» (si sale «Entra a
   tu cuenta», «Crear otra cuenta»). Tienen que salir **las dos** tarjetas, «Tu cuenta en la nube» incluida. Si sale una
   sola, la nube habría desaparecido para todos: es lo único que el simulador no puede probar.

0-terdecies. **Device-QA del #173, solo la racha**
   (`tickets/qa/groups-phone-that-never-attests-is-told-to-retry-forever.md`). Scheme **Yala** (no Dev) en el
   simulador, con tu cuenta de Grupos y la consola filtrada por `GroupsSync`. Primer lanzamiento: la app en primer
   plano **algo más de dos horas**, con `attestRequired edge=pull` repetido. Segundo, pasadas 24 h: **una sola vez**
   `attestTerminal rejections=N hours=H`. La salida «Cerrar sesión y perderlos» no se puede montar: sin App Attest no
   baja ningún grupo.

0-duodecies. **Device-QA del #172, parcial**
   (`tickets/qa/groups-sync-reads-a-missing-attest-401-as-a-session-expiry.md`). Scheme **Yala** (no Dev) en el
   simulador, que no tiene App Attest contra producción, con tu cuenta de Grupos. La consola tiene que decir
   `attestRequired edge=pull` cada vez más espaciado y **nunca** `loopStopped reason=session-expired`; y abrir un
   enlace de invitación no puede reabrir el inicio de sesión.

0-undecies. **Device-QA del #171, y NO es simulable**
   (`tickets/qa/groups-push-reads-an-offline-token-refresh-as-a-session-expiry.md`, siete pasos con Yala Dev).
   Gasto de grupo en modo avión, token caducado y **sin quitar el modo avión** al cerrar sesión. En la nube tiene
   que decir al momento «no llegaron al servidor»; en «equipo» o solo grupos, «Un momento más» tras ~45 s;
   **nunca** «Tu sesión caducó». Y el control: con la sesión borrada en staging, sí. Comparte montaje con el
   0-decies.

0-decies. **Device-QA del #169, y NO es simulable**
   (`tickets/qa/cloud-signout-collapses-a-groups-session-expiry-into-permanent.md`, seis pasos contra staging
   con Yala Dev). Cuenta en la nube con un gasto de grupo hecho en modo avión, sus sesiones borradas en el
   Supabase de staging y el token caducado. Al cerrar sesión, el aviso tiene que decir «Tu sesión caducó…», no
   «Revisa tu conexión». Comparte montaje con el 0-sexies.

0-nonies. **Device-QA del #167, y NO es simulable** (`tickets/qa/icloud-kv-prefs-cross-sessions-on-a-lent-phone.md`).
   Dos dispositivos del **mismo Apple ID**: uno con tu sesión privada y otro «prestado» que cierra sesión y
   entra por «Vengo por un grupo» con **otra** cuenta. Cambias el idioma en uno y compruebas que el otro no
   se entera, en los dos sentidos. **Lo que más importa:** que un dispositivo privado **siga recibiendo** los
   cambios de otro privado del mismo Apple ID — si no llegan, la puerta se habría cerrado para el dueño.

0-octies. **Device-QA del #159, y NO es simulable**
   (`tickets/qa/device-qa-apple-id-change-closes-private-session.md`, cinco recorridos). Hacen falta **dos
   Apple ID de verdad**: el simulador no tiene cuentas de iCloud reales, así que `userRecordID()` da
   `notAuthenticated` y el predicado sale por la rama que NO cierra. **Lo que más importa es el paso 8 del
   recorrido 1:** tras confirmar el cierre, vuelve a tu Apple ID anterior y comprueba que «Ya tengo cuenta
   → iCloud» **restaura tus datos** — si no están, el borrado se llevó el contenedor de iCloud y eso es
   grave. Y el **control negativo** del recorrido 2, que es el que prueba que la detección no se hizo con
   el predicado equivocado: **apagar iCloud Drive sin cambiar de cuenta NO debe disparar el aviso.**
   **El recorrido 5 cubre también el #168:** sin red, la hoja enseña el bloqueo con «Reintentar» y «Ahora no»,
   y Ajustes no queda tapiado; con red, lo que quedaba sin subir sube antes de borrar.

0-ter. **Device-QA del #158, y NO es simulable** (`tickets/qa/device-qa-activation-restore-start-fresh.md`,
   cinco recorridos). `ICloudPersonalCorpusProbe` no tiene ni un seam de `uitest`, así que el estado
   «Encontramos tus datos» de la puerta no existe en simulador — y a la pantalla de Restaurar de la
   activación solo se llega desde ahí. **Lo que hay que mirar siempre, porque es el fallo más probable
   del PR: tras borrar, abre el selector de subcategorías y comprueba que hay categorías y que está
   «Ajuste de saldo».** Y dos cosas más que la review dejó apuntadas: que los gastos de tus grupos
   **vuelvan al Panel al reabrir la app** (no antes — los repone la convergencia del bridge), y que con
   un corpus grande la zona de iCloud **no vuelva a llenarse** tras sincronizar.
0-bis. **Marketing · el estudio de vídeo espera tu ojo** (`marketing/remotion/out/` se regenera con
   `bun run render:presentation` y `bun run render:reels`). Tres decisiones cortas: fondo de la
   presentación **oscuro o blanco**; el **guion de 8 líneas** en `copy.ts`; y cuándo grabas los **clips por
   función** desde QuickTime, en Liquid Glass y sin la píldora roja. Sin eso, la presentación sigue
   repitiendo el mismo mp4 del piloto.
0. **Device-QA del eje 1 (#150), y NO es simulable.** El simulador no tiene sesión de nube, así que
   las dos celdas que deciden datos hay que verlas en device con dos teléfonos del mismo Apple ID:
   **cerrar sesión en «equipo»** (privada + cuenta de grupos) y **eliminar la cuenta de grupos sin
   sesión privada**. Lo que hay que mirar es que la hoja prometa exactamente lo que el borrado hace.

0-ter. **Device-QA de la RETIRADA de la visita (#151), y NO es simulable.** Hay que verlo en un
   teléfono que SÍ llegó a tener una sesión de visita, o sea un build **DEV contra staging** — el parque
   de TestFlight nunca pudo crear esos archivos, así que en el simulador no hay ni un
   `YalaModel-Secondary` que borrar. Lo que se comprueba: que al actualizar desaparezcan los tres stores
   `-Secondary` y el cajón `yala.session.*`, y que el widget deje de pintar los saldos de la otra
   persona. **Y lo que la retirada NO alcanza, con ticket propio**: la sesión de nube que la visita
   dejara en el Keychain sobrevive (`secondary-session-retirement-leaves-the-guest-cloud-session`).


0-quater. **Device-QA del aviso de datos del teléfono (#153), y NO es simulable.** La puerta sale de
   largo bajo `-uitest` —la hermeticidad va antes de la red— y ningún seed arma la marca del neutro
   solo-grupos, así que las cuatro pantallas nuevas solo existen en device. El montaje pide **dos
   teléfonos del mismo Apple ID**: uno en solo-grupos y otro que vacíe sus datos, para que la señal de
   wipe remoto devuelva al primero a la bienvenida **con los grupos dentro**. Guion de 9 pasos en
   `tickets/qa/device-qa-private-gate-device-corpus.md`. Lo que solo se ve ahí: que el corpus de la etapa
   de grupos **no** aparezca en el iCloud del Apple ID después.

0-quinquies. **Device-QA de «Empezar desde cero» en Restaurar (#155), y NO es simulable.** CloudKit no
   existe en el simulador, así que el estado «encontramos tus datos» con corpus real solo se ve en un
   iPhone. Cinco recorridos en `tickets/qa/restore-start-fresh-keeps-the-imported-corpus.md`. **El que de
   verdad cierra el criterio**: tras borrar, instalar Yala en OTRO dispositivo con el mismo Apple ID y
   comprobar que ya no encuentra nada. Dos pruebas nacen de la review y conviene no saltárselas: que tras
   borrar **no salga un tercer alert**, y que lo restaurado por «Traer mis datos» **siga ahí un par de
   arranques después**.

0-sexies. **Device-QA del aviso pasajero al cerrar sesión (#156), y NO es simulable.** Hace falta que el
   servidor falle de verdad: no hay seam que provoque un fallo del canal de grupos ni que pueble su
   outbox en una sesión de nube. Montaje: cuenta en la nube con un gasto de grupo sin subir **y el
   outbox personal vacío** —si quedan filas personales, bloquea el paso 1 y sale el aviso viejo, que es
   otro ticket—, hacer que `/groups/push` devuelva 5xx, y cerrar sesión. Lo que se mira: que el aviso
   salga **al momento** y diga «no llegaron al servidor», no «revisa tu conexión». Guion en
   `tickets/qa/cloud-signout-collapses-every-groups-transient-into-permanent.md`.

0-septies. **Device-QA del vaciado remoto (#157), y NO es simulable — es el SEGUNDO que pide dos
   teléfonos.** No hay seam que escriba `lastWipeTimestamp` en el iCloud-KV y `bootstrap()` no corre bajo
   `-uitest`, así que la señal solo viaja entre dispositivos reales del mismo Apple ID. Montaje: **A**
   privado con datos, **B** entrando por invitación de grupo. Vacías en A y **compruebas que B NO se
   vacía** (en su consola, `sessionObeys=false`). **El control positivo es obligatorio**: repetir con B en
   sesión privada, donde sí tiene que vaciarse. Guion en
   `tickets/qa/remote-wipe-signal-honored-by-any-session.md`.

1. **Cierra sesión en el iPhone y recrea los grupos de prueba.** Es lo ÚNICO que falta para el device-QA
   del paso 3: el móvil apunta a la cuenta que borró el fresh start y cada llamada da 409/502. **Mira antes
   el orden del punto 2-quinquies.**
2. **Device-QA del paso 3** — los cuatro recorridos del ticket. Sal del bloqueo **por swipe y por
   «Entendido»**, no solo por el botón; y en el recorrido 1 **fuerza el cierre de la app** antes de darlo
   por bueno. Más los device-QA de los pasos 4, 5, 6, 8 y 9.
2-bis. **Device-QA del paso 4, y empieza por su punto BLOQUEANTE** (`welcome-private-fresh-start-skips-icloud-check`,
   guion dentro): comprobar que la sonda de CloudKit **no lanza**. Baja una lista de `desiredKeys` única
   sobre una zona multi-tipo, y si el servidor la validara contra el schema de cada tipo, la rama privada
   quedaría en «reintentar» para siempre. El plan B está escrito. Después, los cinco recorridos —y el
   feo: **mata la app a mitad del borrado** y comprueba que al reabrir vuelve a preguntar.
2-quater. **Device-QA del paso 5** (`groups-only-second-launch-mounts-icloud-mirror`, guion dentro). **NO
   es simulable**: sin cuenta de iCloud no hay espejo que adjuntar. Cuatro recorridos, y el que más caro
   sale es el **tercero** —la no-regresión—: restaurar de iCloud tiene que seguir trayéndote tu histórico.
   Si en vez de eso te pide reabrir la app una y otra vez, es el fallo grave de este cambio.
2-quinquies. **Device-QA del paso 6** (`beacon-routes-only-never-blocks`, guion dentro). Necesita un
   TestFlight con este cambio, y su mitad de sign-in real **NO es simulable**. Su recorrido 1 usa el faro
   que dejó el fresh start en tu iPhone, y **el orden importa**: si recreas los grupos del punto 1 con el
   build 13, el faro sigue ahí; con el TestFlight nuevo, entrar con Apple por Grupos ya lo limpia —a
   propósito: el motor lo hace en toda puerta— y el recorrido 1 se comprueba en Console.app en vez de en
   pantalla.
2-sexies. **Device-QA del paso 8** (`full-mode-activation-must-ask-where-personal-data-lives`, guion de 10
   recorridos dentro). **NO es simulable.** Antes, **reinstala** si tu sesión solo-grupos es de antes del
   10-sep: si no, verás el aviso de reinstalar —correcto— y no el chooser. El que más caro sale es
   **restaurar**: los gastos de grupo tienen que salir UNA vez, y los que ya habías clasificado conservan
   su cuenta y su nota.
2-septies. **Device-QA del paso 9** (`session-exits-one-verb-per-session`, guion dentro). **NO es
   simulable**: sin cuenta de iCloud no hay espejo, y el testigo del export solo se prueba en device.
   **Empieza por su spike de tres supuestos**, que ningún test puede medir: que el espejo firme sus
   importaciones con su autor, que emita un evento de export tras cada save, y que un export con éxito
   haya subido todo lo anterior a su inicio. **Si falla el primero, todo cierre privado acaba en la
   salida de emergencia diciendo «1 cambio»** —falla seguro, pero inservible—. Y una decisión tuya
   dentro: qué hacer con cambios de grupos que ya no tienen a dónde subir
   (`groups-outbox-rows-without-a-live-session-have-no-exit`).
2-octies. **Device-QA de la mitad 2 del paso 5** (`groups-entry-on-a-mirrored-store-still-blocks-the-owner`,
   guion de cinco recorridos dentro). **NO es simulable**: sin cuenta de iCloud no hay espejo. El que más
   caro sale si falla es el **segundo**: después de que la puerta devuelva el teléfono al neutro,
   «Restaurar desde iCloud» tiene que traerte TODO el histórico. Y el quinto es el que prueba la otra
   mitad del bug: con el teléfono vacío pero aún espejando, crea el grupo tras el relanzamiento y
   comprueba en otro dispositivo del mismo Apple ID que ese gasto **no aparece** en tu Panel personal.
2-nonies. **Device-QA del paso 10** (`device-qa-groups-account-association`, guion de siete recorridos
   dentro). **NO es simulable**: el simulador no tiene sesión de nube. El que más caro sale es el
   **quinto**: desasocia en un teléfono, abre el otro del mismo Apple ID, y comprueba que la asociación
   **sigue soltada**. Si reaparece, el tombstone no está llegando y el gesto se deshace solo. El tercero
   es el que prueba lo demás: re-asocia la misma cuenta y **cuenta los movimientos del Panel** — tres
   gastos tienen que seguir siendo tres, no seis. **Y desde hoy hay un octavo, que es el más caro de todos
   y necesita DOS personas**: desasocia, **mata la app y vuélvela a abrir** —el daño estaba en el arranque
   siguiente, no en el gesto—, re-asocia, y comprueba en el teléfono del OTRO miembro que sus gastos siguen
   ahí. Si desaparecen sin que él toque nada, para el release.
2-decies. **Device-QA del #144** (`detach-failure-looks-like-success`, dentro de su ticket). **NO es
   simulable**, y necesita provocar el fallo: desasocia con el borrado roto y comprueba que la app lo DICE
   y que la pestaña Grupos sigue entera; que «Terminar de soltar la cuenta» funciona **sin sesión viva**;
   y que re-asociar después **no duplica** los gastos que elegiste conservar — tres siguen siendo tres.
2-undecies. **Device-QA del #146** (`device-qa-cloud-killswitch-groups-door`, cuatro recorridos dentro).
   **Éste SÍ es simulable**, al revés que todos los de arriba: el toggle «Simular remote OFF» del panel
   DEBUG en un build **Yala Dev**, y el panel se alcanza desde Ajustes → iCloud, sin pasar por la pantalla
   que se va a mirar. El que importa es el **tercero**: tras desasociar, la fila tiene que DESAPARECER —si
   sigue ahí, el término no es un término, es un `true`.
2-ter. **Device-QA de la reversa born-cloud → iCloud** (`reverse-cutover-cerrado-para-cuentas-born-cloud`).
   Dos cosas: el **contador de testigos con `ckRecordName`** del panel DEBUG tiene que pasar de 0 a cubrir
   tus filas vivas —ése es el único testigo real de que la subida ocurrió—, y **borra 2-3 transacciones
   antes de empezar**: lo que no debe pasar es que reaparezcan.
3. **Física, la de siempre**: push APNs real (4), RPC de producción (3), sign-in real SIWA/Google (6),
   Apple Pay y carreras de red (4).
4. **De FX quedan cuatro** · **tres veredictos de QA caducos** · **el build 13 no llega al grupo externo**
   hasta pasar beta review.
5. **DMARC el 15-sep** · **cobertura de UI el 22-sep**. Esperan al calendario.

## Siguiente

**El #173 te deja dos decisiones.** En la nube, un teléfono sin App Attest con cambios **personales** sin subir sigue
sin poder cerrar sesión: la salida con pérdida es solo para los de grupos
(`cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`, `medium`). Y si la pestaña Grupos avisa de
forma fija de que este teléfono no puede sincronizar (`groups-tab-does-not-say-this-phone-cannot-sync-groups`, `low`).
Del #172 siguen `groups-join-intent-expires-silently-after-transient-failures` (`medium`) y dos `low`.

**El rediseño de sesiones llega al final de su lista.** El paso 12 está cerrado con el #151: la shell
deriva de un solo eje y M1 no existe. Lo que queda del ADR son los device-QA acumulados, que son tuyos
y en su mayoría **no son simulables**.

**El rediseño de sesiones no deja nada abierto en código.** Lo que queda son device-QA tuyos, y el del
#153 se suma a la lista: es el único que necesita **dos teléfonos** del mismo Apple ID.

**El #157 te deja cuatro `high`, y tres son decisiones tuyas, no tareas.** (1) El arreglo del vaciado
remoto **no alcanza a toda su población**: un alta solo-grupos anterior al 10-sep sigue obedeciendo la
señal, porque no tiene la marca del mount neutro y el backfill le escribe «tiene sesión privada»
(`remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark` — mide primero si esa población
existe). (2) La hoja de «Vaciar datos» sigue prometiendo que el borrado alcanza a **todos** tus
dispositivos, y eso **no es computable desde el emisor**: el iCloud-KV no lleva inventario de sesiones
(`wipe-sheet-still-promises-every-apple-id-device`, tres opciones escritas). (3) **CERRADO en #162**, y de paso se midió que la celda que lo motivaba no era la que disparaba:
lo que salía era el aviso auto-infligido tras «Vaciar datos» en solo-grupos. (4) **CERRADO en #167**: las preferencias —eran 36,
no 37— ya no cruzan con un móvil prestado; deja dos decisiones tuyas (ver «Esta sesión»).

**El #162 te deja uno `high` y es una decisión tuya.** El aviso de datos borrados se enciende desde una
tarea de cinco segundos escribiendo estado de la vista directamente, en vez de pasar por la cola de avisos
— y su hermano, el intent de la misma señal, sí pasa. Como ese flag además **bloquea la cola entera**, si
el sistema descarta la presentación la app deja de mostrar cualquier aviso (bandeja, invitaciones, Pro)
hasta que se la mata (`remote-wipe-alert-skips-the-router`). Es preexistente; el #162 solo estrecha quién
llega. Con él van dos `medium`: la causa de fondo del caso que hoy tapa el eje
(`wipe-data-does-not-cancel-the-remote-wipe-grace`) y la asimetría entre cómo leen el eje la shell y el
aviso (`shell-and-wipe-alert-read-the-session-axis-differently`).

**Y un hallazgo medido que no es decisión, es hecho:** widget, Siri y notificaciones locales cuelgan del
**cierre de sesión**, no del borrado, así que un vaciado que llega por el espejo no las toca. En claro:
**los recordatorios de pagos del dueño se siguen entregando, con sus montos, en el teléfono que prestó**, y
su widget sigue pintando el saldo. Anotado con coordenadas en
`after-session-redesign-review-widgets-siri-applepay-and-web-copy`, que hasta hoy era una lista sin medir.

**Lo primero de la cola técnica sigue siendo el board de testing**: los cuatro de
`nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo` llevan dos noches rojos y ya no se sostienen como
«flaky de runner frío» (ver Bloqueo).

**El #158 deja cuatro tickets, uno `high`:**
`activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable` — tres salidas de la puerta
(`.noICloud`, `.unreachable`, `.proceed`) llaman a `onProceed()` **sin pasar por el borrado**. En la puerta
del chooser es un daño menor; en la nueva las filas importadas **ya están en el teléfono**, así que quien
confirma «empezar de cero» sin red sigue con todo. Y el aviso del espejo tardío que llega después usa el
scope del handover, o sea que **purgaría los grupos**. Los otros tres:
`activation-discard-loses-the-group-history-question` (`medium`, la pregunta «¿traemos tus gastos de
grupo?» se mide después del borrado y da 0),
`private-gate-wipe-failure-copy-claims-icloud-is-intact` (`medium`, el copy del fallo parcial dice que
iCloud sigue entero cuando la zona ya no está — el copy correcto ya existe traducido) y
`activation-resume-returns-to-restore-on-an-emptied-zone` (`low`).

**El #171 te deja tres decisiones y dos tickets de trabajo.** Decisiones: qué dice el aviso sin red fuera de la
nube, y si la espera de 45 s tiene sentido sin red (`signout-pending-copy-says-wait-seconds-when-offline`); el
401 por App Attest ausente, que también dice «caducó» (`groups-sync-reads-a-missing-attest-401-as-a-session-expiry`,
`medium`); y despertar el sync de grupos al volver a la app (`groups-loop-in-backoff-ignores-the-return-to-foreground`).
Trabajo, con tu criterio ya decidido: salir de un grupo sin red (`groups-actions-read-an-offline-token-refresh-as-a-session-expiry`)
y el canal personal, que en `.cloud` frena también a Grupos (`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`,
que sube a `medium` porque Modo Nube no está apagado).

**El board: 398 en disco = 398 en `docs/TICKETS.md`** (medido el 15-sep, tras el #173), cero desajustes de estado. El
#173 pasa su ticket a `qa/` y suma dos.

## Bloqueo

**La nocturna del 11-sep confirma que los cuatro de
`nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo` siguen rojos**, tres de ellos 3/3 reintentos en dos
noches distintas. Eso ya no se sostiene como «flaky de runner frío».

Los otros dos de testing: `shared-state-guard-misses-wipelocalgroupsdomain` (el guard del trait de
aislamiento busca `wipeAllUserData(` y se le escapa el otro escritor del espejo) y
`spike-r3-eje-4b-flaky-en-suite-completa` (rojo en la suite completa, verde en solitario; su control
negativo afirma un modo de fallo que cambia según lo que corriera antes).

**Y lo que deja el #144, por orden de lo que más cuesta si falla:**
`groups-purge-save-crosses-two-stores-without-atomicity` — el borrado del dominio Grupos promete «todo o
nada» y su `save()` cruza **dos archivos**; si el segundo falla después del primero queda el par que la
regla de área marca como peligroso, «cursor borrado + filas vivas». Y
`uitest-seam-for-a-seeded-groups-association` (**medium**): sin un seam que siembre la asociación hay dos
estados de la pantalla que **nadie puede probar en simulador** — la celda del segundo móvil, sin cobertura
desde el paso 10, y el botón «Terminar de soltar la cuenta» de hoy.
