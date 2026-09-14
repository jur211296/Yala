---
updated: 2026-09-14
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-14 (Lima)

**Rama** `2.1` — Merge #160: **«Empezar desde cero» sin iCloud vuelve a Restaurar y no promete nada.**
TestFlight build **13** (CPV 13). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión (#160 · «Empezar desde cero» sin iCloud vuelve a Restaurar y no promete nada)

**Activabas Yala completo, en «Restaurar» tocabas «Empezar desde cero», y la app no conseguía mirar tu
iCloud —red caída, o iCloud apagado en el teléfono—.** Te decía «Seguir así», te llevaba al onboarding, y
tus datos viejos seguían enteros: un borrado que nunca ocurrió, anunciado como si hubiera ocurrido. Ahora
te dice que no pudo mirar, que **no borró nada**, y te devuelve a la pantalla anterior con las dos
opciones abiertas. Quien abre Yala por primera vez no ve ningún cambio: en el Welcome esa pantalla sigue
dejando seguir, y tiene que hacerlo — allí no hay app detrás a la que volver.

**El daño de detrás era el peor y no se veía.** Aquel «Seguir así» dejaba la app **apuntada** para el
aviso del espejo tardío, cuyo botón de borrar se lleva las preferencias y **el dominio de Grupos**. O sea
que quien activaba Yala completo justo para conservar sus grupos podía acabar sin ellos, arranques
después, por una red que se cayó dos segundos.

**La premisa del ticket era falsa y ensanchó el alcance.** Decía que el estado «sin cuenta de iCloud» era
inalcanzable por ese camino. Medido: `WelcomeRestoreView` ofrece «Empezar desde cero» desde cuatro estados
y **tres no afirman que haya datos** —`notFoundView`, `iCloudDisabledView` y `wipedView`—, que llaman
directo sin diálogo. Y otro dato que zanja hipótesis futuras: **el chooser de la activación no tiene
«Restaurar»**; a esa pantalla se llega por `onRestore` de la puerta privada (que exige haber encontrado
datos) o por el resume.

**La review adversarial (3 lentes) cazó SEIS defectos míos, tres con cambio de código, y el peor lo
introdujo mi propia extensión del alcance:** llevar el «vuelve» al estado K creaba un **camino muerto de
dos pantallas** — la puerta devolvía a Restaurar, y Restaurar con iCloud apagado solo ofrece «Abrir
Ajustes» y «Empezar desde cero», que trae de vuelta aquí. Es el mismo camino muerto que una review
anterior le había cazado a la fase de al lado, tres líneas más arriba en el mismo fichero. Hoy esa fase
ofrece «Reintentar» y su cuerpo dice la causa. Los otros: el **chevron** salía sin retirar el arm del
borrado, a dos centímetros de un botón que sí lo retiraba; el cuerpo compartido repetía el título y tiraba
la causa; nadie miraba el copy por desenlace; nada fijaba el «sin default» del parámetro; y una errata en
un accessor salía como clave cruda sin que la paridad la viera. **Y un séptimo lo cazó un mutante y era
del test**: su tramo llegaba al final del cuerpo y se cumplía desde el `case` de al lado.

**14 mutantes verificados**, suite unit completa (6869 en 698 suites) y XCUITest del área 13/13 con el
centinela confirmando que estuve solo.

**Device-QA no simulable** (`tickets/qa/device-qa-discard-gate-returns-to-restore-without-icloud.md`):
`measure()` sale por `isUITesting` antes de la sonda y `ICloudPersonalCorpusProbe` no tiene seam. Cuatro
recorridos, uno el control negativo del Welcome. Deja dos tickets `low`:
`discard-gate-proceed-leaves-the-imported-rows-behind` (la rama que mide la zona vacía con filas ya
importadas) y `welcome-discard-gate-says-carry-on-right-after-asking-to-wipe` (la misma puerta en el
Welcome sigue diciendo «Puedes seguir»; ahí el mecanismo es correcto, es copy).

**Y una consecuencia que espera decisión tuya:** con iCloud apagado, la rama privada de la activación ya
no se puede terminar por «Empezar desde cero» sin encenderlo — antes seguía, mintiendo. La pantalla lo
dice y ofrece el remedio, y cancelar sigue devolviendo a la app de grupos. Si prefieres que ahí siga
adelante, es un valor en un call-site.

## Sesión anterior (#159 · cambiar el Apple ID del teléfono cierra la sesión privada)

**Usabas Yala con tus datos en tu iCloud privado y cambiabas la cuenta de iCloud del teléfono. La app no
se enteraba:** seguía enseñando los movimientos, las cuentas y los presupuestos de la cuenta anterior como
si nada. Si el teléfono había cambiado de manos, la persona nueva veía las finanzas de la anterior. Ahora
Yala lo detecta y **lo pregunta**: esos datos son de la cuenta de iCloud anterior, ahí se quedan
guardados, y ofrece quitarlos de este teléfono. «Ahora no» no toca nada y vuelve a preguntar en el
arranque siguiente; **si vuelves a tu cuenta anterior, deja de preguntártelo solo**. Quien usa Yala solo
para grupos no ve nada de esto.

**La premisa del ticket no se sostenía, y eso cambió el trabajo entero.** Decía que
`checkForICloudMismatch` ya avisaba del cambio de cuenta y solo había que «alinearlo». Medido: ese aviso
pregunta «¿monté sin espejo y **ahora hay** iCloud?», que puede ser cierta con la misma cuenta de
siempre — y **la app no guardaba ningún testigo del Apple ID con el que montó**, así que no había con qué
comparar. No había nada que alinear: había que construir la detección. El aviso viejo se queda, correcto;
lo único que se le añadió es que se calle mientras el nuevo decide.

**La identidad sale de `userRecordID()` del contenedor personal, no del token de ubiquity.** Ese mide
iCloud **Drive**: con Drive apagado y la sesión viva vale `nil` mientras CloudKit funciona, así que
usarlo habría leído «cambiaste de cuenta» y **borrado los datos de quien no cambió nada** — el bug que el
ticket arregla, reintroducido por el predicado elegido para arreglarlo.

**La review adversarial (3 lentes) cazó 14 defectos MÍOS, cinco con cambio de código, y el peor no lo
veía ningún test.** El testigo del Apple ID **sobrevivía a «Empiezo de cero»**: el dueño entregaba su
teléfono, la persona nueva terminaba su onboarding, y en el arranque siguiente la app le ofrecía cerrar
la sesión y **borrarle SUS datos** diciéndole que eran de la cuenta anterior. Mi docblock afirmaba que el
eje «muere en un solo sitio» y el docblock de al lado decía que son dos. Hoy el borrado vive **dentro**
de `PrivateSessionMark`, el embudo de sus nueve escrituras. Los otros cuatro: el cierre se ejecutaba sin
`confirmedPath` (con el modo en la nube habría cerrado **la cuenta de Yala** bajo un texto que habla de
iCloud); el router se liberaba justo cuando empezaba el borrado; este aviso y el del espejo tardío salen
del mismo disparador y se encadenaban —dos `.alert` del mismo anchor, el molde de brick—; y un contador
del eje me obligó a decidir con qué lectura contesta cada consumidor nuevo: aporto **dos** de la estricta
y **una** de la ancha, con signos opuestos.

**Device-QA no simulable** (`tickets/qa/device-qa-apple-id-change-closes-private-session.md`): el
simulador no tiene cuentas de iCloud reales. Cinco recorridos, y dos salen de la review — el **control
negativo** (apagar iCloud Drive NO debe disparar el aviso) y si el espejo sube el corpus viejo a la
cuenta nueva cuando se dice «Ahora no». Deja un ticket **high**:
`apple-id-close-blocked-has-no-visible-outcome` — si el cierre se bloquea, nadie lo enseña desde este
camino y el coordinador queda tapiado para el resto del lanzamiento.

## Las de antes
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

0-octies. **Device-QA del #159, y NO es simulable**
   (`tickets/qa/device-qa-apple-id-change-closes-private-session.md`, cinco recorridos). Hacen falta **dos
   Apple ID de verdad**: el simulador no tiene cuentas de iCloud reales, así que `userRecordID()` da
   `notAuthenticated` y el predicado sale por la rama que NO cierra. **Lo que más importa es el paso 8 del
   recorrido 1:** tras confirmar el cierre, vuelve a tu Apple ID anterior y comprueba que «Ya tengo cuenta
   → iCloud» **restaura tus datos** — si no están, el borrado se llevó el contenedor de iCloud y eso es
   grave. Y el **control negativo** del recorrido 2, que es el que prueba que la detección no se hizo con
   el predicado equivocado: **apagar iCloud Drive sin cambiar de cuenta NO debe disparar el aviso.**

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
(`wipe-sheet-still-promises-every-apple-id-device`, tres opciones escritas). (3) En el móvil prestado
aparece ahora «Datos no disponibles» y su botón expulsa al onboarding
(`wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`). (4) Las 37 preferencias siguen cruzando
entre el dueño y quien usa el teléfono: el guard que lo impedía se retiró sobre una premisa que la celda
solo-grupos contradice, y el propio fichero dice dónde reponerlo
(`icloud-kv-prefs-cross-sessions-on-a-lent-phone`).

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

**El board: 367 en disco = 367 en `docs/TICKETS.md`**, cero desajustes de estado y cero rutas rotas. Suben
5 con el #158 y `activation-restore-start-fresh-keeps-the-imported-rows` pasa a `done/`.

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
