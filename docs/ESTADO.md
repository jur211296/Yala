---
updated: 2026-09-15
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-15 (Lima)

**Rama** `2.1` — Merge #168: **Si el cierre por cambio de Apple ID se bloquea, ya se ve el motivo y se puede salir.**
TestFlight build **13** (CPV 13). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión (#168 · si el cierre por cambio de Apple ID se bloquea, ya se ve y se sale)

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

## Sesión anterior (#167 · las preferencias ya no cruzan entre el dueño y un móvil prestado)

**Quien entra por un grupo en un móvil prestado ya no le cambia nada al dueño, y lo del dueño ya no le
llega.** El idioma, la moneda, el nombre, los ajustes del Panel y el interruptor de avisos de pagos
cruzaban en los dos sentidos por el iCloud del Apple ID del teléfono: el guard que lo impedía se retiró el
13-sep con la premisa «solo hay una sesión por teléfono», que la celda solo-grupos del ADR desmentía.
**Decisión de Jürgen: cada cuenta, sus preferencias.** Para una sesión privada no cambia nada.

**La puerta** (`OwnerKeyValueGate`) se cierra cuando el teléfono afirma no tener sesión privada, o cuando
empezó un alta solo-grupos y todavía no lo ha dicho. Cerrada, nada llega al iCloud-KV y lo que se lee de él
viene vacío — **salvo las dos señales del Apple ID**, que todo teléfono tiene que ver para darlas por
procesadas.

**La review adversarial cambió el diseño dos veces, y las dos por algo mío.** (1) La primera versión dejaba
la puerta ABIERTA en una activación de Yala completo cancelada a medias: el bug entero de vuelta. (2)
Ocultar también las señales hacía que la sesión privada recién nacida obedeciera un vaciado pendiente y se
borrara. Y dos de la prosa: **son 36 preferencias, no 37**, y el escáner que la cabecera citaba como red se
había borrado con el guard — no existía. Vuelve, fijando las sentencias de los dos lectores crudos en vez de
eximir su fichero.

Gate: build ×2 sin warnings nuevos · **unit 6893 en 705 suites** · **19 mutantes, 19 muertos** · XCUITest 10
casos en 5 clases con el centinela sin intrusos · CI verde. `test_freshInstallShowsFourSectionsByDefault`
falló una vez tras una corrida matada por memoria y pasó las otras tres sobre el mismo árbol: es la
intermitencia que ya tenía `nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo`. **Device-QA: sí, y no es
simulable** (cola, 0-nonies).

**Te deja dos decisiones, con recomendación en cada ticket.**
`neutral-boot-hands-owner-prefs-to-whoever-signs-in-next`: tras «Cerrar sesión», el primer arranque aplica
las preferencias del Apple ID antes de que nadie elija, y quien entra luego por un grupo las hereda — la
puerta no puede saber quién va a entrar. `full-activation-local-state-never-reaches-the-apple-id-kv`: lo que
«Activar Yala completo» escribe con la puerta cerrada no sube a iCloud cuando nace la sesión privada. Y un
`medium` sin decisión: `language-override-bypasses-the-cloud-prefs-channel`.

## Sesión #166 · el hueco del vaciado remoto se cierra con el número, no con código

**No cambia nada en pantalla, y ese es el resultado.** Quedaba declarado un hueco: quien entró por un
grupo **antes del 10 de septiembre** no lleva la marca que distingue esa situación, así que a su teléfono
se le seguiría diciendo «aquí hay una vida personal» y **seguiría obedeciendo la orden de vaciado** que
llega desde otro dispositivo del mismo Apple ID — justo el daño que el arreglo del #157 existe para
impedir. El ticket daba dos salidas y **Jürgen zanjó el fork: población cero, sin señal inventada ni
predicado local al receptor.**

**Las cuatro mediciones, independientes entre sí.** (1) Telemetría propia de producción, sus 90 días de
retención —que cubren entera la vida del camino, nacido el 11-ago—: **cero** altas `groupsOrganizer` y
**cero** `groupInvite`, contra 5 altas personales y 1 migración a la nube; con control negativo y
positivo corridos. (2) El backend de Grupos al que apunta un build de release: **cero** identidades,
perfiles, grupos, miembros, invitaciones y consentimientos — y las dos altas **exigen sesión remota**
antes de escribir nada. (3) La App Store pública sirve **2.0.4**, anterior al camino; el alta solo viajó
en TestFlight 11/12/13, con **3 testers** (2 instalados). (4) **Ningún build distribuido trae el eje
compilado**, así que ese backfill no ha corrido nunca fuera de un simulador.

**Por qué no se tocó el eje, que era la otra salida.** Las señales candidatas para reconocer a un
solo-grupos antiguo derivan el eje de una AUSENCIA, y un gate así **falla ABIERTO**: si el almacén tarda
en montar, le esconde las cuentas a alguien que sí tiene su vida entera aquí. Coste real contra población
cero.

**La red que sostiene el cierre, que es lo que lo hace caducar con aviso.** La celda del bug necesita la
marca del eje AUSENTE, y hoy **las dos altas solo-grupos la escriben en el acto** además de armar el
mount neutro — por eso el backfill ni la mira. El test fija las dos escrituras, su orden y el **censo de
armadores (3)**, así que un alta nueva que se olvide de cualquiera rompe el test en vez de repoblar la
celda en silencio. **3 mutantes, 3 muertos.**

**Un rojo HEREDADO de `2.1`, arreglado aquí:** el censo de lecturas de `confirmedPrivateSession` decía
**6** y eran **7** desde el PR #164 (la re-lectura del drenaje del aviso). Lo vi ejecutando la suite, no
por aritmética — el reparto queda escrito: cada vez que este eje gobierna algo asíncrono se lee en los
dos extremos de la espera.

**Dos candidatos a bug, MEDIDOS y refutados** (por eso no abren ticket): la invitación marca el alta para
todo desenlace que no sea «rechazar», pero el `guard hasTappedJoin` hace inalcanzables las pantallas de
abandono sin pasar antes por el alta que arma el neutro; y el relevo de humano deja el eje ausente, pero
sus tres call-sites barren también el flag de alta, así que el gate del backfill cierra.

Gate: build ×2 sin warnings nuevos · **unit 455 en 58 suites** · **XCUITest 7 en 3 clases**, centinela 0 ·
CI verde. **El diff de producción es 100 % comentarios** (medido), así que el binario no cambia y el lote
de XCUITest se acotó al área del eje en vez de correr las 34 suites que casan con `ContentView`.
**Device-QA: no aplica.**

## Sesión #164 · el aviso de datos borrados ya no aparece encima de lo que estuvieras mirando

**Yala tiene una cuenta atrás interna de cinco segundos: si tus datos personales desaparecen del
teléfono y siguen sin volver, te avisa de que te los han borrado desde otro dispositivo.** Ese aviso se
encendía sin mirar qué había en pantalla, así que si vencía mientras estabas viendo otra cosa —el aviso
del espejo de iCloud, la oferta de prueba, las novedades, el selector de idioma, la activación—, **esa
pantalla desaparecía sola**. Y si en el intento no llegaba a mostrarse, la app **dejaba de enseñar
cualquier otro aviso** —bandeja, invitaciones de grupo, oferta de Pro— hasta cerrarla y abrirla. Ahora
espera su turno en la misma cola que el resto y solo sale con la pantalla libre. Sus dos botones dicen a
dónde llevan: «Empezar de cero» va a la bienvenida (con «Restaurar de iCloud» a un toque) y «Seguir
esperando» te deja donde estabas, que ahora es verdad.

**La premisa del encargo acertaba la VÍA y erraba el case.** Decía «reusa `.remoteWipe`, como el otro
productor»; medido, ese intent no presenta el aviso: **borra**. Reusarlo habría convertido una pregunta
en un borrado silencioso. El aviso va por la cola con un case propio, y el drenaje re-mide las tres
condiciones vivas —filas ausentes, onboarding completo, eje de sesión— porque el intent no es transitorio
y afirma un hecho sobre AHORA.

**El brick y su cura están MEDIDOS en simulador, con dos mutantes.** Sin la red, el blocker se queda
puesto y un paywall en cola no presenta **nunca** (25 s); con ella se suelta a los ~10 s y el paywall
entra. Un tercer mutante dejó un residual anotado en la rule: si la sonda de UIKit se equivocara, los
toggles dejan el alert dibujado aunque el estado se apague — un XCUITest vigila eso.

**La review adversarial (tres lentes) cazó una ALTA que era MÍA:** al reescribir un bloque perdí la
cancelación de la cuenta atrás en el camino de la señal explícita, y el comentario nuevo **afirmaba que
seguía ahí**. Sin ella vuelve el «double-alert»: los dos canales no tienen orden garantizado, así que el
aviso podía preguntar por unos datos que la app acababa de restaurar. Más dos MEDIA (el censo de
escritores del flag, que se había caído de la suite; el canario ausente del índice de QA) y una BAJA.

Unit 225 en 14 suites · **XCUITest 86 en 35 clases** en el gate, centinela 0 en las tres tandas. El rojo
de `PaywallInboxAlertRouting` en una repetición fue **latencia** (45 s agotados vs. 15,6 s en el lote
repetido). **Device-QA: no aplica** — lo que cambia es la vía de presentación y se recorre en simulador.

**Lo que queda, con su sitio:** `orphan-alerts-behind-fullscreen-covers` sigue aparte (el mecanismo
general, ahora con un molde escrito al lado); `wipe-data-does-not-cancel-the-remote-wipe-grace` gana una
**segunda celda** (el restore remoto con `skipOnboarding`, donde el eje NO tapa el aviso); y el desarme
de la red solo está probado a mano — ticket propio con la receta.

## Las de antes
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

**El board: 381 en disco = 381 en `docs/TICKETS.md`** (medido el 15-sep), cero desajustes de estado y cero
rutas rotas. El #168 pasa su ticket a `done/` y suma dos: la decisión de copy y
`generated-index-lands-above-yaml-frontmatter`.

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
