---
updated: 2026-09-13
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-13 (Lima)

**Rama** `2.1` — Merge #152: **un canal de Grupos en pausa deja de anunciarse como un problema de tu cuenta.**
TestFlight build **13** (CPV 13). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión (#152 · el kill-switch de Grupos y el aviso que mentía)

**Con el canal de Grupos apagado por un incidente, soltar la cuenta decía que el problema era tu
cuenta.** Y no había reintento: el aviso cerraba la puerta hasta que alguien volviera a subir el flag.
Ahora dice la verdad — «Es algo de nuestro lado: los grupos están en pausa. Tus cambios siguen en este
teléfono y no se pierden; vuelve a intentarlo en un rato» — y el gesto se puede repetir cuando el canal
vuelva. Con el outbox vacío, que es el caso dominante, sigue completando sin pedir red.

Tu decisión del 13-sep, la opción **(a)**: distinguir ese 403 del resto. La (b) —soltar dejando lo
pendiente sin subir— quedó descartada, y el orden «lo pendiente sube ANTES de cortar» no se tocó.

**La señal ya existía y se perdía una capa antes de la pantalla.** El cliente del canal ya distinguía
los dos 403 —el loop la usaba para no sellarse— pero era privada. Ahora viaja ligada a su ciclo, y el
término va **sin valor por defecto**: el compilador obligó a cada sitio a pronunciarse, y así salió uno
que nadie había mirado, el del motor personal.

**Sin reintento automático, y es decisión tuya escrita, no un olvido:** el kill se levanta con un
deploy, así que dentro de los 45 s del presupuesto no se mueve. Reintentar gastaría ~22 peticiones
contra un 403 seguro **en pleno incidente** y retrasaría 45 s un aviso que ya se puede dar.

**La review adversarial cazó cuatro defectos ALTA y todos eran míos.** El mayor: una **cuarta pantalla**
mentía igual y no estaba en el ticket — la puerta por donde se acepta una invitación de grupo aconsejaba
«vuelve a entrar con esa cuenta», que bajo un 403 del servidor no sube nada. Y cuatro mutantes
atravesaban mi red de pruebas devolviendo el bug entero en verde. También midió dos afirmaciones que yo
había escrito y eran falsas: el gateway emite **exactamente dos 403** y ninguno es «cuenta suspendida».

**Verificado:** build ×2 con cero warnings nuevos · **6779 unit en 690 suites**, 0 fallos · **24
XCUITest en 8 suites** con el centinela en 0 · CI entero en verde · audit limpio · ratchet OK. Y **11
mutantes puestos, los 11 matan su test.**

**Lo que falta y es tuyo:** el device-QA **NO es simulable** — el kill se sirve server-side, así que
pide bajar `GROUPS_BACKEND_ROLLOUT_PERCENT` a 0 en el gateway. Guion de 7 pasos en `tickets/qa/`. Y
deja **cuatro tickets**, uno `high`: un 403 de **infraestructura** (un WAF por delante del Worker) apaga
el canal como si tu cuenta ya no valiera, y lo sella hasta relanzar la app — el cliente hermano del
mismo endpoint ya lo trata como transitorio, por escrito.

## Las de antes (#151 · el paso 12, PR-B: el barrido)

**La sesión de visita (M1) ya no existe, y la shell tiene una sola fuente.** Para quien usa Yala no
cambia nada visible: cambia de dónde sale la respuesta a «¿esta persona tiene vida personal en este
teléfono?». `ShellModeLogic.effective` pasa de tres flags a **un solo término**, el eje 1
(`PrivateSessionMark`). Prestar el móvil sigue teniendo camino, el que ya existía: cierras sesión, la
otra persona entra con la suya, y luego restauras.

**En producción es byte-neutro y está medido**: el encendido compilado estaba en `false` desde el
12-sep, el percent de producción en 0 y el flag remoto era fail-closed ⇒ `isActive()` era constante
`false` en Release. Lo que se borra es andamiaje: **26 ficheros**, el percent del gateway y los dos
flags de onboarding (`OnboardingMode`, `UsageFocus`). La única pieza que no es un borrado es
`SecondarySessionRetirement`, una purga one-shot del arranque —kill-safe **y** failure-safe— que limpia
lo que la visita pudo dejar en disco.

**La review adversarial cazó cinco defectos y los cinco eran míos.** El peor: el backfill se apoyaba en
una premisa tuya —«no hay usuarios solo-grupos»— que la lente midió y era **falsa**
(`GROUPS_BACKEND_ROLLOUT_PERCENT = "100"` en producción). Te la llevé y elegiste derivarlo de la marca
del mount neutro. Sin eso, a un teléfono solo-grupos se le habría escrito «tiene vida personal» para
siempre.

**Y el día se fue en ocho XCUITest rojos que NO eran el código: era el simulador.** Una key pegada
(`cloudSync.groupsOnlyNeutralMount`) hacía que el backfill apagara el eje en cada arranque. Tres
hipótesis medidas y caídas antes de dar con ello; lo zanjó `simctl erase` en tres minutos. **La lección
queda escrita**: cuando un `removeObject` no tiene efecto y la key no está en ningún dominio
enumerable, no hay escritor que buscar — es el simulador, y el `erase` va primero, no al final.

**Verificado:** build ×2 con **cero warnings nuevos** (base 13 → PR 9, cuatro cerrados) · **6764 unit
en 689 suites, 0 fallos** · **30 XCUITest en 10 suites, 0 fallos** con el centinela en 0 · gateway 271
tests · audit limpio · ratchet OK.

**Lo que falta y es tuyo:** el device-QA de la retirada **NO es simulable** (pide un build DEV contra
staging; el parque de TestFlight no pudo crear esos archivos). Y deja **cinco tickets** en el backlog,
todos de hallazgos de camino — el más llamativo: el grep de símbolos retirados da cero, pero **94
líneas de prosa** siguen hablando de la visita.

## Las de antes (#150 · #149)

El eje 1 ganó fuente propia: una marca positiva persistida (`PrivateSessionMark`) con dos lecturas de
direcciones de fallo OPUESTAS, que es lo que hacía ejecutable el barrido del #151. Su device-QA sigue
pendiente y **NO es simulable** (pide dos dispositivos del mismo Apple ID). Y antes, el #149 retiró la
puerta que elegía en qué `UserDefaults` escribía la app — resolvía al mismo sitio para el 100 % del
parque.

## Las de antes (#147 · la cola del simulador)

**Dos sesiones que lleguen al gate a la vez ya no se derriban.** Catorce worktrees compartían un solo
iPhone 17 Pro; ahora el gate dice `[cola] … ESPERA` y arranca cuando le toca. Tu decisión del 11-sep, la
opción (2). El precio aceptado: serializa el gate de todas las sesiones. **Ya está en uso y funcionó**:
las corridas de hoy esperaron su turno y el centinela salió 0.

## Las de antes (#146 · #145 · #144)

Con el kill-switch de la nube bajado, la fila «¿Dónde viven tus datos?» ya no desaparece si hay una
cuenta de grupos que soltar (#146). Los 7 XCUITest del Welcome estaban **sanos** — era un `high` falso,
`discarded` con tres mediciones dentro (#145). Y «Desasociar» ya no finge que soltó la cuenta (#144); su
device-QA sigue pendiente y **NO es simulable**.

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

**Lo primero de la cola técnica es el board de testing**, que lleva dos noches diciendo lo mismo: los
cuatro de `nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo` siguen rojos y ya no se sostienen como
«flaky de runner frío» (ver Bloqueo).

**El board: 336 en disco = 336 en `docs/TICKETS.md`**, cero desajustes de estado.

## Bloqueo

**`groups-killswitch-403-blocks-detach-forever` (high).** Con el kill de **Grupos** servido como 403 y
cambios de grupos sin subir, desasociar queda **imposible** —`.permanent`, sin un solo reintento— y el
aviso le dice al usuario que el problema es su cuenta. El #146 abrió la puerta para que ese gesto exista
durante un incidente de la nube; por el eje de Grupos la puerta está abierta y el gesto no funciona. Pide
decisión: distinguir el 403 de kill-switch del resto de lo permanente, o dejar soltar sin subir lo
pendiente (que hoy es una decisión deliberada del orden del gesto).

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
