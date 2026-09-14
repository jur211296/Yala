---
updated: 2026-09-13
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-13 (Lima)

**Rama** `2.1` — Merge #153: **«Es mi primera vez → privado» vuelve a avisar de los datos que ya hay
en el teléfono.** TestFlight build **13** (CPV 13). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión (#153 · el aviso de datos que se perdía por el relanzamiento)

**Desde una sesión solo-grupos, elegir «Es mi primera vez → Tu cuenta en tu iCloud privado» montaba un
onboarding de cero sin decir que aquí ya había datos**: los grupos y las categorías de la etapa anterior
seguían dentro, y en el arranque siguiente subían al iCloud de tu cuenta de Apple. Ahora sale el aviso,
con doble confirmación, y si confirmas el teléfono queda limpio de verdad — grupos incluidos, con el
dominio **sellado** para que no vuelvan a colarse en tus cuentas.

**El aviso se perdía por una premisa que dejó de ser cierta.** Con el store personal montado NEUTRO esa
rama sale por el relanzamiento y nunca llega al callback que preguntaba «¿hay datos?». El comentario que
lo justificaba —«el mount neutro exige que no haya archivo de store»— valía con los dos términos viejos
del neutro; el tercero, el de una sesión solo-grupos, rompió la equivalencia: ahí el archivo existe, con
datos dentro, y monta neutro igual.

**La cadena que describía el ticket ya no existe** (`performPrivateReset` se fue con el paso 9), pero el
hueco sí. El camino limpio que lo alcanza hoy es un **wipe remoto sobre un dispositivo solo-grupos**:
`wipeAllUserData` deja vivos los grupos y repone los dos flags de onboarding.

**El aviso se enciende SOLO con el mismo predicado que el relanzamiento, y eso no es simetría:** su
borrado quita FILAS, y con el espejo montado los deletes se exportan — vaciarían el iCloud de la persona
en todos sus dispositivos. El mount neutro es `cloudKitDatabase: .none` explícito.

**La review adversarial cazó ONCE defectos y los once eran míos, cinco de ellos ALTA.** El peor no era el
del párrafo de arriba: el arm que reusé **escalaba un borrado LOCAL a uno REMOTO** — un kill a mitad
dejaba un testigo que `runLateICloudMirrorCheck` reanuda a ciegas borrando la zona de iCloud del Apple ID,
sobre una pantalla cuyo copy promete que iCloud no se toca. Y el borrado **se saboteaba a sí mismo**: al
tocar los flags de onboarding, el arranque consumía el destino del relanzamiento y montaba un segundo
cover encima del terminal «reabre Yala». También cazó que el copy prometía lo que el código no cumple
(«no se puede deshacer», «tus datos siguen intactos») y que **un solo token** reintroducía el ticket
entero con la suite en verde.

**Una afirmación del ticket, medida y falsa:** decía que el corpus de grupos «se re-descarga» tras la
purga. Eso es del canal CloudKit, que ya no existe; con el backend **el cursor sobrevive a propósito** y
no vuelve a bajar.

**Verificado:** build ×2 con cero warnings nuevos —medidos contra un worktree del árbol base— · **6797
unit en 691 suites**, 0 fallos · **25 XCUITest en 6 suites** con el centinela en 0 · audit limpio ·
ratchet OK. Y **19 mutantes puestos, los 19 los mata su test.**

**Lo que falta y es tuyo:** el device-QA **NO es simulable**, y el motivo está medido — la puerta sale de
largo bajo `-uitest` (hermeticidad antes de la red) y ningún seed arma la marca del neutro solo-grupos.
Guion de 9 pasos en `tickets/qa/device-qa-private-gate-device-corpus.md`. Deja **tres tickets**, los tres
`medium`.

## Las de antes (#152 · el kill-switch de Grupos y el aviso que mentía)

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

## Las de antes

Los partes de los merges #144 a #152 viven en sus PR y en `git log`; aquí se quedan solo los dos últimos
mientras su device-QA siga abierto.

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

**Lo primero de la cola técnica sigue siendo el board de testing**: los cuatro de
`nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo` llevan dos noches rojos y ya no se sostienen como
«flaky de runner frío» (ver Bloqueo).

**El board: 345 en disco = 345 en `docs/TICKETS.md`**, cero desajustes de estado.

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
