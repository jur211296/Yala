---
id: groups-ghost-tx-on-delete
status: done
priority: high
area: "groups, sync, backend, bridge, integridad-datos"
created: 2026-08-02
updated: 2026-08-28
source: YalaWiki/Bugs/qa_groups-tx-fantasma-al-borrar-gasto-de-grupo.md
---

> Sync 18 ago (Iris, Mac SSOT). Cola A A2 (f) y A3 (g): READY Mini 17 ago. Cola B B2 (c): Yala PR 18 MERGED a `2.0.5` merge `628bcbb9` (18 ago 07:29 Lima); corte 2.1. HOLD stale. No reabrir. (d)(e) siguen cola C (owner/device, no corrida). Ticket padre sigue `qa_` (mixto). No rename.


> [!bug] Corrida real (2026-08-02, build 9 de 2.0.5, PRODUCCIÓN, dos iPhones): el device A borra un gasto compartido. En A queda todo limpio. En B el gasto desaparece del grupo pero **la transacción puenteada a su Panel personal sobrevive**. Reproducido dos veces: gasto de 20 al 50/50 → fantasma de 10; gasto de 50 al 50/50 → fantasma de 25. Confirmado después que pasa **igual con las liquidaciones** y que es **bidireccional** (da igual quién borre). Y las huérfanas **no se pueden borrar ni editar a mano**: tocarlas lleva al grupo, y en el grupo ya no existen.

# Dinero fantasma en el Panel del otro miembro al borrar un gasto de grupo

## Qué veía el usuario

Borraba un gasto compartido desde su teléfono y en el otro teléfono el gasto desaparecía del grupo — pero el dinero seguía ahí, en el Panel, en los presupuestos y en los reportes. Un gasto de 20 a medias dejaba 10 de más que no correspondían a nada.

Y no había forma de quitarlo. Al abrirlo, la app decía que se edita desde el grupo y ofrecía ir allí; en el grupo no había nada. El botón de borrar estaba desactivado. El usuario se quedaba con cifras incorrectas y sin ninguna salida.

Un tercer gasto borrado muy rápido **no** dejó fantasma, y eso es correcto: el puente del canal nuevo es diferido, así que si el borrado llega antes de que el puente se cree, nunca hubo transacción que huerfanar.

## Implementación

### 2026-08-02 — branch 2.0.5

**Resumen:** al borrar un gasto de grupo, el teléfono que lo borra limpiaba su registro personal y el que recibía el aviso no. Ahora los dos hacen lo mismo, se reparan solos los fantasmas que ya existen, y una transacción rota deja de quedarse bloqueada.

**Archivos:**

- `Yala/Services/Groups/GroupTransactionBridge.swift` — `unbridgeDeletedRemotely(expenseIDs:settlementIDs:)`: des-puenteo EN LOTE con un solo guardado para toda la página. `freezeForSoftDelete` gana una variante por zona (el grupo puede haberse borrado ya).
- `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift` — las ramas de tombstone de gasto y liquidación acumulan lo que hay que des-puentear; `drainUnbridge` lo drena post-save. El tombstone del grupo entero pasa a congelar. `drainSoftDeleteFreeze` va por zona.
- `Yala/Services/Groups/SplitSyncManager.swift` — lo mismo en el canal CloudKit (`applyRemoteDeletion` + drenaje post-save) + seam `_testApplyRemoteDeletion`.
- `Yala/Services/Groups/OrphanedBridgedTxSweeper.swift` (nuevo) — barrido de reparación.
- `Yala/App/AppBootstrapper.swift` — lo cablea en el arranque (16.5.5), tras la quiescencia del import personal.
- `Yala/App/Logic/BridgedEditPolicy.swift` + `Yala/App/Views/Transactions/NewTransactionView.swift` — red de seguridad: el puntero tiene que RESOLVER, no solo existir.
- `Yala/Services/Metrics/MetricsService.swift` — canario `bridgedTxOrphansRepaired`.
- `YalaTests/GroupRemoteDeletionUnbridgeTests.swift` (nuevo) — 26 tests en 6 suites.
- `.claude/rules/swiftdata-cloudkit.md` — regla durable.
- `qa/coverage-index.json` — tres áreas.

**Causa raíz:** el borrado tiene DOS mitades y el camino remoto solo copió una. El borrado LOCAL hace «shares + **des-puenteo** + borrado + guardado» (`GroupExpenseService.performExpenseDeletion`, y su gemelo `deleteSettlement`). Las cuatro ramas de tombstone del sync hacían solo el borrado de la fila:

- `GroupsSyncClient.applyExpense` y `applySettlement` (canal backend, el vivo con el rollout al 100 %)
- `SplitSyncManager.applyRemoteDeletion`, casos `.splitExpense` y `.splitSettlement` (canal CloudKit)

Esa asimetría entre quien borra y quien recibe es todo el bug. **No lo introdujo el Modo Nube**: el canal CloudKit lo arrastra desde siempre — le está pasando hoy a quien no está en el rollout — y el canal nuevo copió el defecto fielmente.

Un segundo hueco, del mismo tipo, apareció al revisar el borrado del GRUPO entero: su tombstone tampoco soltaba los registros personales, y el drenaje del congelado no habría podido hacerlo aunque se le pidiera, porque re-buscaba el grupo que el propio apply acababa de borrar y obtenía nada.

**Decisiones técnicas y su porqué:**

- **El criterio lo decide lo que DESAPARECE, no el canal.** Un gasto o una liquidación sueltos → des-puenteo destructivo, por simetría con el borrado local: si quien borra destruye su registro y quien recibe lo congela, los dos Panel no convergen nunca y el congelado se queda sin dueño. El GRUPO entero → congelar (`freezeForSoftDelete`), que suelta la transacción de cuenta real y preserva la virtual: ahí los gastos sí ocurrieron y el dinero salió de una cuenta de verdad.
- **El des-puenteo va después del guardado, y solo si el guardado tuvo éxito.** No es cautela genérica: cierra con su propio guardado sobre el contexto compartido, así que con las filas del grupo aún sin persistir las comitearía bajo el autor por defecto — que es justo lo que el drenador de Grupos captura y **re-empuja al servidor** como si fuera una edición local. En el canal backend basta con ir después del `return` del `catch` (su rollback resucita el gasto: des-puentear antes se llevaría la transacción de un gasto vivo); en el canal CloudKit, que no tiene rollback, hace falta el flag explícito `didPersistBatch`.
- **Un solo guardado por página, no uno por fila.** `unbridgeExpense` guarda, recalcula la caché del widget y recarga los timelines en CADA llamada, y el apply corre en bucle por delta. El método nuevo acumula y cierra una vez; con nada que borrar no escribe nada.
- **El barrido de reparación no lleva sentinel.** Un one-shot dejaría sin cubrir cualquier hueco futuro, y el barrido es además la red del des-puenteo que no llegue a correr (el servidor no re-emite ese aviso: el cursor se guarda en la misma transacción que lo aplicó). Es idempotente por construcción y gratis cuando no hay nada puenteado.
- **El guard `zoneIsSettled` del barrido es lo que lo separa de una pérdida masiva de datos.** Los dos almacenes bajan por canales independientes: las transacciones con el import personal y los gastos con el pull de Grupos. En un teléfono recién instalado el personal puede asentarse ANTES, y entonces TODO el corpus puenteado parece huérfano; peor, soltar una transacción de cuenta real y que después llegue su gasto produce una transacción DUPLICADA. Por eso «huérfana» exige evidencia de que el grupo ya está en el device y terminó de poblarse.
- **Reparar no es lo mismo que borrar, y la asimetría con el congelado es deliberada.** Se reusa la distinción que ya existía (`classifyForSoftDelete`) pero con acciones distintas: cuenta **real** → liberar los punteros, jamás borrar (el usuario pagó de su bolsillo; el movimiento ocurrió y destruirlo por una inconsistencia de sincronización sería peor que el bug); cuenta **virtual** de sistema → borrar (es el espejo de un gasto que ya no existe, y preservarla intacta —que es lo que hace el congelado— ES el fantasma).
- **«Puntero no nulo == es de grupo» es correcto en un FILTRO y una trampa en un GUARD.** En los filtros de listado y de estadísticas sigue siendo el criterio bueno: una huérfana sigue siendo dinero que salió de un grupo. Donde BLOQUEA una acción del usuario tiene que resolver de verdad, y por eso solo se tocaron esos: la policy de edición y los dos guards del editor. Cambiar los filtros «por reflejo» habría movido cifras sin ninguna razón.
- **No se tocó el gateway** ni el borrado de la entidad del grupo, que funciona bien en los dos lados. El defecto era exclusivamente el puente.

**Regla durable añadida** (`.claude/rules/swiftdata-cloudkit.md`): al añadir un camino de borrado REMOTO, listar lo que el camino LOCAL hace ADEMÁS de borrar la fila. Es el gemelo de «duplicar un canal duplica sus escrituras, sus observaciones se quedan atrás»: aquí lo que se queda atrás es la mitad de la limpieza, y ningún test de un canal solo lo caza, porque en el teléfono que borra todo se ve bien.

### Lo que cazó la revisión adversarial

Cuatro lentes independientes (pérdida de datos, sync/races, UI y alcance, calidad de los tests) con refutación por hallazgo: 38 hallazgos, 6 sobrevivieron. Los cuatro que cambiaron el código:

1. **El orden `congelar` → `des-puentear` es load-bearing, y lo tenía al revés.** Una misma página puede traer el borrado del grupo y el de sus gastos (el servidor cascadea), y los dos criterios chocan sobre las mismas filas. Con el congelado delante gana el correcto sin coordinación extra: deja la transacción de cuenta real con los punteros ya vacíos, así que el des-puenteo —que busca por ese puntero— no la encuentra y la preserva; la virtual sí se borra, que es lo que toca cuando su gasto y su grupo han desaparecido. Al revés, destruía dinero que salió de verdad.
2. **El barrido calculaba el plan de borradores sobre transacciones que ya había mutado.** El plan decide si un borrador es un puntero redundante comparándolo con las transacciones que recibe; con los punteros ya vaciados esa comparación nunca casaba, así que ningún borrador se borraba y todos pasaban a manual — y aprobar uno de esos habría creado una transacción NUEVA junto a la recién liberada: el gasto duplicado. Habría sido una regresión respecto a no tener barrido. Ahora son dos fases: clasificar sin tocar nada, y después aplicar.
3. **Un source-scan que se satisfacía a sí mismo**: `resolveBridgedPointer()` casaba con su propia declaración, así que el test pasaba en verde con la función huérfana y sin un solo llamador — la familia de `AppAttestClient.ensureRegistered()`. Ahora ancla dentro del bloque que la llama.
4. **Otro scan semi-vacío**: comprobar el nombre `didPersistBatch` lo satisfacía la declaración de la variable aunque nadie la leyera. Ahora ancla en el guard literal y en el orden respecto al guardado.

**Verificación:** builds `Yala` + `Yala Dev` verdes, cero warnings nuevos · 33 tests nuevos en 6 suites · suite completa **5373 tests en 502 suites** verde · XCUITest de las áreas tocadas 12/12 (`TransactionsCrudUITests`, `RecordsDetailSheetUITests`, `GroupsSmokeUITests`) · `qa/validate-coverage.sh` OK, backlog sin crecer · **12 mutaciones a exit 65**: la acumulación del tombstone de gasto, la de liquidación, la del canal CloudKit, la decisión del barrido, el guard del puntero en la policy, el drenaje entero del canal backend, el call-site del editor, el guard del batch persistido, el congelado del grupo entero, el congelado por zona, el orden congelar/des-puentear, y el plan calculado antes de mutar.

**Lo que NO está verificado:** el e2e en device contra producción, en sus tres partes (hacia delante, reparación de los fantasmas que ya existen, y que una transacción con puntero muerto se pueda editar y borrar). El canal backend en producción no es ejercitable desde un test, así que la corrida con dos teléfonos es lo único que cierra este ticket — y por la regla del repo no la declara buena quien escribió el fix.

### Segunda vuelta · 2026-08-04 (`0a67929f`) — el barrido creía «al día» un canal parado

**Lo que estaba mal.** El barrido decidía que una transacción era huérfana con una sola prueba: que el
grupo existiera en este teléfono y hubiera terminado de bajar sus miembros alguna vez. Eso no dice nada de
si el canal de Grupos está funcionando **ahora**: es una marca que se pone la primera vez y ya nadie vuelve
a activar, así que un grupo que el teléfono conoce desde hace semanas cuenta como «al día» para siempre.

**Lo que le pasaba al usuario.** Con dos teléfonos suyos —el caso normal de quien tiene el de siempre y
otro—, si en uno el canal de Grupos estaba parado (porque lo apagamos desde el servidor, porque su sesión
caducó, o porque su copia de la configuración remota aún no se había refrescado), un gasto nuevo creado en
el otro teléfono llegaba a su Panel pero el gasto del grupo no llegaba por ningún lado. El teléfono parado
lo tomaba por un fantasma y lo limpiaba — **y esa limpieza viajaba al otro teléfono**, que sí tenía el
gasto y se quedaba sin su transacción. Al bajar el gasto por fin, el puente creaba un borrador nuevo y
aprobarlo dejaba el gasto **repetido**. Nadie lo había reportado; salió al revisar el barrido.

**Lo que cambia.** Ahora el barrido solo actúa cuando puede demostrar que el canal de ese grupo **terminó
de entregar** y que el grupo estaba en lo que entregó. Si no puede demostrarlo no toca nada y lo reintenta
en el siguiente arranque: dejar una limpieza para mañana se puede deshacer, borrar una transacción no.
Y el mismo criterio se aplicó al editor de transacciones, donde el mismo error dejaba **Borrar y Duplicar
activados sobre un gasto de grupo vivo** en un teléfono recién reinstalado — con el borrado viajando a los
demás.

**Decisiones técnicas, con su porqué.**

1. **El equivalente para los grupos que no están en el servidor nuevo ya existía y nadie lo leía.**
   `SplitSyncManager.enginesWithCompletedFetchCycle` registra los motores que cerraron un ciclo entero;
   su único consumidor murió con el uploader de la migración. Vale como prueba porque un ciclo entero
   recorre todas las zonas de su base, igual que una descarga agotada recorre todos los grupos.
2. **Se exigen los DOS motores y no el que corresponde a ese grupo.** Cuál corresponde lo diría
   `isOwner`, que es una propiedad de la FILA, y este repo ya tiene documentado que un grupo puede tener
   dos filas: leer la equivocada daría permiso para borrar. Pedir los dos no se puede equivocar.
3. **No basta con el criterio: había que mover el momento.** El barrido corre al arrancar, y el canal
   tarda un viaje de red en entregar. Sin una espera acotada (2 s de sondeo, tope de 60 s) el criterio
   nuevo habría conseguido que no se reparara nunca nada, y ningún test se habría puesto rojo. Lo fija un
   test que lee el código del arranque; su mutación es la única que cae, con los otros 34 en verde.
4. **El guard viejo se conserva como primer escalón**, endurecido: si el grupo tiene dos filas y una sigue
   bajando su contenido, bloquea. Así el caso que ese guard sí cubría —teléfono recién instalado— sigue
   cubierto sin tocar sus tests.
5. **Un aviso nuevo para el panel de métricas** (`bridgedTxOrphanSweepDeferred`) que se emite cuando había
   candidatas y no se tocaron. Sin él, un gate atascado y «no había fantasmas» se leen igual: cero.

**Verificación:** builds `Yala` + `Yala Dev` verdes, cero warnings nuevos · **5508 tests en 515 suites**
verde · XCUITest de `transactions-core-crud` verde · `qa/validate-coverage.sh` OK · **4 mutaciones a
exit 65**. **Sigue sin verificarse en device**, y ahora con un caso más: el escenario exige dos teléfonos
reales con el canal parado en uno.

## Hallazgo aparte (no arreglado aquí)

El borrado remoto del GRUPO entero deja además **filas hijas huérfanas** en el almacén de Grupos: `applyRemoteDeletion` (caso `groupMeta`) y `GroupsSyncClient.applyGroupMeta` borran el grupo sin cascada, mientras el camino local sí usa `cascadeDeleteGroupData`. El canal CloudKit tiene ya su propia cascada escrita (`deleteGroupCache`, para el borrado de zona) y este camino no la usa. Es un bug distinto —filas del grupo, no dinero fantasma en el Panel— y nadie lo ha reportado; queda anotado para su propio ticket.

## Guion de QA (TestFlight, 2 devices)

> **Estado al 2026-08-06 (punto de control).** Los pasos **1, 2 y 3 están CERRADOS en device** el 2026-08-04
> (build 10, `502e6cfc`) — no los repitas. Quedan **4, 5, 6, 7** y **dos nuevos, 8 y 9**, y todos necesitan un
> build nuevo: build 10 es el ya verificado y `CURRENT_PROJECT_VERSION` sigue en 10.
>
> **El paso 3 se leyó sobre un barredor que YA CAMBIÓ.** `0ca523a6` (2026-08-06) acotó las candidatas a las
> zonas del canal backend, así que su resultado sigue valiendo —las zonas de aquella matriz eran backend, con
> el rollout al 100 %— pero **las huérfanas de zonas CloudKit legacy ya no se reparan, y en silencio**: el
> `guard status.belongsToBackendChannel` de `OrphanedBridgedTxSweeper.swift:239` sale ANTES de contar el
> diferido, así que tampoco emiten el canario. Está declarado a propósito en `:232-233`. Si en el paso 3
> aparece un fantasma que no se repara, comprueba de qué canal es su grupo antes de llamarlo regresión.
>
> **🔴 EL PASO 6 NO ES EJECUTABLE COMO ESTÁ ESCRITO — medido el 2026-08-06, no lo intentes.** Dice «apagar el
> canal de Grupos para uno de los dos teléfonos (el drill del kill-switch vale)», y desde el **2026-08-03** eso
> es imposible: `gateway/src/groups/killSwitch.ts` aplica el kill **SERVER-SIDE y GLOBAL** —`percent == 0` ⇒
> rechaza con 403 a **todo el mundo**, y cualquier valor `> 0` ⇒ **no rechaza a nadie**—, porque el servidor no
> puede replicar el bucket del cliente (el seed de instalación no sale del device; calcularlo de otra cosa sería
> split-brain, y el módulo existe para evitarlo). Y peor para este guion: con el kill puesto, `/groups/push` es
> una de las cuatro rutas rechazadas ⇒ **el OTRO teléfono tampoco puede crear el gasto.** El asimétrico que el
> paso necesita ya no existe por esa vía.
>
> **Lo que hace falta antes de correrlo: elegir otra asimetría per-device.** De las tres causas reales que
> documenta `.claude/rules/swiftdata-cloudkit.md`, la única controlable a mano es **la sesión Yala** — cerrarla
> en el teléfono B deja su canal de Grupos sin JWT mientras el espejo personal (CloudKit, atado al Apple ID)
> sigue entregando, que es EXACTAMENTE la separación que el escenario quiere. **Pero no es un sustituto
> directo**: `CloudSessionSignOut.purgeGroupsSyncState` borra outbox **y** cursor, así que hay que comprobar qué
> deja en pie antes de dar el resultado por bueno. El `cloudSync.debug.remoteFlagsForceOff` que sí es per-device
> vive bajo `#if DEV_BUILD` ⇒ es de `Yala Dev`, que habla con **staging**, no con producción.
>
> **8. Sin cuenta iCloud · el tab Grupos** (nuevo, cierra el hueco de `965a4d86`). iPhone real **sin cuenta de
> iCloud** en Ajustes y con el canal ON. Abrir el tab Grupos: tiene que salir el empty state de iniciar sesión
> en Yala, **NO** el muro «Grupos necesita iCloud». En simulador solo se aproxima, por eso es de aquí.
>
> **9. Sin cuenta iCloud · el onboarding** (nuevo, cierra el hueco de `9c66c528`). El mismo teléfono, app recién
> instalada. En el paso «Propósito» elegir «Dividir gastos con amigos»: tiene que seleccionarse y avanzar al
> paso de moneda, **sin** el aviso «Activa iCloud para usar grupos». Era la única puerta del onboarding al modo
> Solo Grupos.

1. **Hacia delante · gasto.** Grupo compartido entre A y B. A crea un gasto de 20 al 50/50 y espera a que B lo vea en el grupo Y en su Panel. A lo borra. En B: desaparece del grupo **y del Panel**, sin relanzar la app. Comprobar también presupuestos y el total del mes.
2. **Hacia delante · liquidación.** Igual con una liquidación. Repetir borrando desde B (el bug era bidireccional).
3. **Reparación.** En el teléfono que ya tiene fantasmas de la build 9, instalar la nueva y abrirla. Los fantasmas de la cuenta virtual «Grupos» deben desaparecer solos; los que cuelguen de una cuenta real deben seguir ahí pero **ya editables y borrables**.
4. **Red de seguridad.** Abrir una transacción cuyo gasto ya no exista: tiene que dejar editar monto/fecha/cuenta y ofrecer Borrar, sin el aviso de «se edita desde el grupo».
5. **No-regresión.** Un gasto de grupo VIVO tiene que seguir bloqueado como antes (monto/fecha del grupo, aviso, sin Borrar).
6. **Canal parado (2026-08-04).** Apagar el canal de Grupos para uno de los dos teléfonos (el drill del kill-switch vale). En el otro, crear un gasto compartido. En el apagado: la transacción llega al Panel y **no debe desaparecer ni soltarse**. En el que creó el gasto: su transacción **sigue intacta**. Volver a encender el canal y comprobar que todo converge.
7. **Reinstalación (2026-08-04).** Reinstalar la app en un teléfono con grupos y abrir una transacción de un gasto de grupo VIVO **antes** de que el grupo termine de bajar: Borrar y Duplicar tienen que seguir **desactivados**. Cuando el grupo baje, el comportamiento normal.

migrated from YalaWiki Bugs/qa_groups-tx-fantasma-al-borrar-gasto-de-grupo.md @ 1934e8ad

## Cierre del owner 2026-08-28 (Jurgen, Lima) — PASS en device del borrado de gasto

**La corrida.** Dos teléfonos, el mismo grupo, **TestFlight 2.1 build 12** (el binario que hay en campo;
no se subió nada nuevo para esto).

1. El teléfono **A** crea un gasto de grupo (monto inusual, al 50/50) y se espera a que **B** lo vea en el
   grupo **y** en su Panel personal.
2. **A** borra ese gasto.
3. En **B**, sin reabrir A: el gasto **se va del grupo** y la transacción personal puenteada
   **desaparece de su Panel** — no queda la huérfana atascada.

**Veredicto del owner: PASS.** Con eso el ticket pasa a `done/`: era el escenario que ningún test podía
cerrar (el canal backend en producción no es ejercitable desde un test) y por la regla del repo no lo
declara bueno quien escribió el fix.

### Lo que este PASS NO cubre

- **Liquidaciones.** Estaban en el ticket original como la MISMA clase de bug (el reporte del 2026-08-02
  confirmó que pasaba igual con ellas, y bidireccional). **Hoy no se re-probaron.** Este cierre no dice
  nada de su estado.
- **Nada más allá del borrado de gasto.** De la nota de sync de arriba, **cola C (d)(e)** no recibe PASS
  aquí: lo único corrido hoy es el escenario de este apartado. Igual con «Lo que NO está verificado» de
  la sección de implementación: solo queda cubierta su primera parte (hacia delante, gasto). La
  reparación de fantasmas ya existentes y la transacción con puntero muerto **no** están en el reporte
  de hoy. El guion pedía además presupuestos y el total del mes en el paso 1; el reporte del owner llega
  hasta el Panel.
- **Sin subida y sin flip.** No hubo TestFlight nuevo hoy. **A7/M5 sigue en HOLD**, igual que App Store y
  tag de release.
