---
updated: 2026-09-14
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-14 (Lima)

**Rama** `2.1` — Merge #157: **vaciar tus datos ya no vacía el teléfono que prestaste.** TestFlight build
**13** (CPV 13). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión (#157 · vaciar tus datos ya no vacía el teléfono que prestaste)

**Vacías tus datos en tu iPhone privado. Hasta hoy, cualquier otro dispositivo del mismo Apple ID con el
onboarding hecho se vaciaba también, mirara lo que mirara.** También el iPad que tenías con una sesión en
la nube —y ahí el motor **subía esos borrados a SU cuenta**— y también el móvil que le prestaste a alguien
que entró con su cuenta de grupos, que perdía su perfil y sus preferencias sin haber tocado nada. Ahora
**solo obedecen la señal los dispositivos cuya sesión es privada**, que son los únicos cuyos datos son los
de ese Apple ID.

**El paso 9 cerró el EMISOR; esto es el RECEPTOR, y su predicado es el mismo por el otro extremo del
canal.** `wipeSignalObeyedByThisSession` **delega** en `wipeSignalsAppleIDDevices` en vez de copiar su
cuerpo: contestan la misma pregunta —¿los datos de este dispositivo son los del Apple ID?— y dos cuerpos
iguales que «siempre van juntos» divergen en el commit siguiente, en silencio y hacia el lado que borra.
El parámetro **no tiene valor por defecto a propósito**: un default devolvería a los call-sites futuros el
derecho a no pronunciarse, que es la forma exacta de este bug.

**La premisa del ticket estaba a medias, y las dos mitades no están igual de vivas.** El móvil prestado es
un caso **real hoy** (Grupos al 100 % en producción). La nube completa es **preventiva**: sus dos puertas
están cerradas por el kill-switch remoto (`CLOUD_MODE_ROLLOUT_PERCENT = 0`), **no por diseño** — se abre en
cuanto subas el percent. El docblock de `CloudSyncFlags.storageMode` que dice «SIEMPRE `.icloud` (DARK)»
está caducado: hay tres escritores de `.cloud` alcanzables desde el Welcome y desde «Activar Yala completo».

**La review adversarial (3 lentes) cazó cuatro cosas en MIS PROPIOS TESTS, y la primera dejaba el bug vivo
con la suite en verde.** Un `||` colgado del cálculo del eje pasaba los dos `contains` del source-scan,
porque **un `contains` no puede cerrar el extremo derecho de una expresión**; el scan compara ahora la
sentencia entera por igualdad. Las otras tres: un default en la firma y un `#if DEBUG` alrededor del guard
pasaban los 16 casos de la matriz —los 16 los pasan explícitos—, y el conteo de consumidores solo miraba
dos ficheros. **14 mutantes, 14 muertos.** Un test se **retiró**: no podía fallar de forma única.

**Y dejó mintiendo cinco docblocks, en los que coincidieron los tres agentes.** El que más importa: el
backfill del eje 1 llamaba a su residual «el barato de los dos», y dejó de serlo en cuanto el mismo eje
gobierna un borrado.

**Device-QA NO simulable:** no hay seam que escriba `lastWipeTimestamp` en el iCloud-KV
(`OwnerKeyValueStore` no contiene ni una referencia a `uitest`) y `bootstrap()` no corre bajo `-uitest`.
Hacen falta **dos teléfonos reales**. Guion con control positivo en `tickets/qa/`.

**Lo que este PR NO cierra, y son cuatro `high`.** El arreglo **no alcanza a toda su población**: un alta
solo-grupos anterior al 10-sep no tiene la marca del mount neutro, el backfill le escribe «tiene sesión
privada» y sigue obedeciendo (`remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark`). Y tres
que piden decisión tuya: la hoja sigue prometiendo que el vaciado alcanza a todos tus dispositivos
(`wipe-sheet-still-promises-every-apple-id-device`), el aviso «Datos no disponibles» ahora sale en el móvil
prestado y su botón expulsa al onboarding
(`wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`), y las 37 preferencias siguen cruzando
entre el dueño y quien usa el teléfono (`icloud-kv-prefs-cross-sessions-on-a-lent-phone`).

## Sesión anterior (#156 · un fallo pasajero de grupos ya no dice «revisa tu conexión»)

**Tienes una cuenta en la nube con grupos y cambios sin subir. Pulsas «Cerrar sesión», falla algo del
lado del servidor —un 5xx, un cortafuegos, la red— y la app decía siempre lo mismo: «revisa tu conexión
e inténtalo de nuevo».** Cuando el problema no es tu conexión, y esa es la mayoría de las veces, te
mandaba a buscar un fallo que no existe sin decir lo único cierto: que esperes y lo vuelvas a intentar.
Ahora ese caso tiene su aviso: **«Los últimos cambios de tus grupos no llegaron al servidor. Siguen
guardados en este teléfono y no se pierden; inténtalo de nuevo en un rato.»** Sale **al momento**, sin
hacerte esperar 45 s, y por el mismo aviso que el canal en pausa. Decisión tuya (opción 2), mismo
criterio que el kill-switch el 13-sep.

**La premisa del ticket era falsa, y se medía con un grep.** Decía que aquí se perdía el presupuesto de
reintento de 45 s; este camino **nunca** consulta `GroupsSignOutRetryDecision` —llama al push-all
directo; el presupuesto es de `pushGroupsForSignOut`, que usan los otros tres caminos—. No había
reintento que perder: lo único roto era el aviso.

**El ternario se fue y en su sitio hay un `switch` exhaustivo** (`cloudSignOutGroupsBlockReason`). No es
cosmético: el ternario no obligaba a nadie a pronunciarse, y por eso el bug pudo nacer en silencio.
Ahora el compilador no deja añadir un motivo sin decidir qué se enseña.

**La review adversarial (4 lentes) cazó tres cosas mías, y dos estaban en MIS PROPIOS TESTS.** Un
`#require` fijaba la etiqueta del `case` y no su cuerpo: el mutante que manda los cuatro motivos al
aviso equivocado —«un momento más» ante un servidor caído— pasaba verde. Y una aserción comparaba los
índices de dos literales distintos: no podía fallar nunca. La tercera, un docblock falso a 100 líneas
del cambio que seguía afirmando el colapso que este PR retira. **Ocho mutantes, ocho muertos** — y uno
sobrevivió a la primera vuelta: borrar el breadcrumb entero no rompía nada.

**Device-QA NO simulable:** provocar un fallo pasajero del canal exige un servidor que falle, y no hay
seam (34 launch args, ninguno lo hace). Guion en `tickets/qa/`.

**Lo que este PR NO cierra, con ticket propio.** El paso 1 del mismo cierre —el push-all PERSONAL—
descarta el motivo con `_`, y **es el que dispara primero** ante un corte de red con filas personales
pendientes: `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`. Y `.sessionExpired`
sigue colapsado en el paso 2, porque su copy manda a «volver a iniciar sesión» a quien acaba de pedir lo
contrario — decisión tuya: `cloud-signout-collapses-a-groups-session-expiry-into-permanent`.

## Las de antes

Los partes de los merges #144 a #155 viven en sus PR y en `git log`; aquí se quedan solo los dos últimos
mientras su device-QA siga abierto. El del **#155** («Empezar desde cero» en Restaurar ya borra) salió hoy:
lo que queda vivo de él son su device-QA (cola, 0-quinquies) y sus dos tickets,
`activation-restore-start-fresh-keeps-the-imported-rows` (`high`) y
`private-icloud-gate-back-lands-on-the-wrong-branch` (`medium`).

## Marketing (Lola · #142 · el estudio de vídeo)

**Ya hay sistema para sacar vídeo del producto sin dibujar la app**: `marketing/remotion/`, con dos
formatos —una presentación 16:9 por escenas y clips 9:16 por función— sobre grabaciones reales.
**Espera tu ojo** y tres decisiones cortas (`marketing/remotion/out/`, se regenera con
`bun run render:presentation` y `bun run render:reels`).

## Tu cola

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

**Y el #155 deja dos tickets, uno de ellos `high`:**
`activation-restore-start-fresh-keeps-the-imported-rows` — el mismo «Empezar desde cero» desde «Activar
Yala completo» borra la zona de iCloud y el store, que espeja, la vuelve a llenar. Cerrarlo pide un
borrador de filas personales **sin tocar preferencias**, que hoy no existe: `wipeAllUserData` hace las dos
cosas de un gesto y su reset va mucho más allá de quitar keys (router, ProTour, checklist, App Group).
Partirlo es un objeto propio sobre un método destructivo que comparten «Vaciar datos» y el wipe remoto.
El otro es `private-icloud-gate-back-lands-on-the-wrong-branch` (`medium`).

**El board: 362 en disco = 362 en `docs/TICKETS.md`**, cero desajustes de estado y cero rutas rotas.
Suben 9 con el #157 y el ticket del vaciado remoto pasa a `qa/`.

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
