---
id: ci-verde-con-la-suite-en-rojo
status: done
priority: high
area: platform
created: 2026-09-02
updated: 2026-09-04
source: revisión del QA del CI a petición del owner (2026-09-02)
---

# El CI reporta verde con ocho tests en rojo, y así lleva semanas

Los tres pasos de test de `qa.yml` llevan `continue-on-error: true` (líneas 175, 197, 215).
**GitHub marca esos pasos como `success` aunque el comando salga con error**, así que la API —y
la interfaz— muestran el run entero en verde mientras `xcodebuild` termina en `exit code 65`.

## Medido

Descargado el log completo del run `33670068455` (commit `80880f2d`, 2026-09-02 19:04):

```
** TEST EXECUTE FAILED **
##[error]Process completed with exit code 65
```

Y antes de esa línea, `Failing tests:` con **ocho tests distintos** (algunos repetidos por
`-retry-tests-on-failure`):

| Test | Estado |
|---|---|
| `HeroBucketsCalculatorTests.periodPreviousInterval_thisWeek_returnsFullTrailingWindow` | **arreglado el 2026-09-02** (`8168987a`) |
| `WidgetDataServiceIntervalTests.lastMonth_ssot_excludes_midnight_of_first_day_of_this_month` | rojo, causa identificada abajo |
| `WidgetDataServiceIntervalTests.lastYear_ssot_excludes_midnight_of_first_day_of_this_year` | ídem |
| `WidgetDataServiceIntervalTests.lastMonth_ssot_end_is_exactly_one_second_before_this_month_start` | ídem |
| `WidgetDataServiceIntervalTests.parity_widgetReplica_matches_ssot_for_all_non_weekly_periods` | ídem |
| `GroupCreateRoutingWiringTests.splitGroupHasNoLegacyProducerInProduction` | **sin diagnosticar** |
| `NewTransactionViewModelTests.splitDescriptionShares` | **sin diagnosticar** |
| `HandoverGroupsDomainTests.wipeLocalGroupsDomain_killsTheOutbox_butKEEPSTheCursor` | **sin diagnosticar** |

**No es un run aislado:** los runs de `1ed8224d`, `eebde759`, `f84eb7eb`, `a31d740d` y `9a35b57a`
tienen **dos bloques de `TEST EXECUTE FAILED` cada uno** — o sea, dos de los tres pasos fallando —
y los cinco figuran como `success`.

## El coste, con nombre y apellidos

**El CI llevaba cazando el rojo de `.thisWeek` desde el 2026-08-17.** La red funcionaba; estaba
amordazada. Se encontró el 2026-09-02 por el `/gate` local, dos semanas y media tarde, y mientras
tanto ese rojo tapaba cualquier regresión nueva de su fichero.

## Causa raíz de los cuatro de `WidgetDataServiceIntervalTests` (confirmada por lectura, NO ejecutada en UTC)

`WidgetDataServiceIntervalTests` fija `TimeZone(identifier: "America/Lima")` en su
`makeCalendar()` (:53-55) para construir `now` y las expectativas, pero compara contra
`DetailPeriod.dateInterval(now:)`, que internamente usa `userConfiguredCalendar()`
(`SharedModels.swift:9-15`) = **`Calendar.current`, o sea la zona horaria del dispositivo**.

- En la Mac del owner el simulador hereda Lima ⇒ las dos mitades coinciden ⇒ **verde en local**.
- En el runner de GitHub el simulador va en UTC ⇒ el `startOfMonth` del SSOT no es el que el test
  calculó ⇒ **rojo en CI**.

La cabecera del propio fichero (:25) ya anticipa la dependencia. **Son deterministas y
dependientes del entorno, NO flaky** — categoría distinta del `EXC_BREAKPOINT` de SwiftData que
justifica el `continue-on-error` en el comentario de `qa.yml:122`.

Fix probable: inyectar el calendario en el SSOT bajo test, o fijar la TZ del simulador en CI. Hay
que elegir: inyectar prueba el algoritmo; fijar la TZ prueba además que el algoritmo no depende
del entorno, que es lo que el usuario real experimenta.

## Las tres banderas están puestas a propósito (medido hoy en el árbol)

Antes de proponer «quitar los `continue-on-error`»: el propio `qa.yml` explica por qué están, y la
explicación cambia cuál es el arreglo.

Medido en `.github/workflows/qa.yml` de HOY: los tres `continue-on-error: true` están en las líneas
**175** (unit pure-logic), **197** (unit context-based) y **215** (UI), y cada uno lleva su
justificación inmediatamente encima:

- **:168-173** — «Bloquear aquí = rojos aleatorios. `-retry` no converge. **Volver a bloqueante exige
  resolver ese crash primero**».
- **:193-195** — «no bloquean por el insert-trap flaky de SwiftData en el runner de CI».
- El crash que las dos citan está descrito en **:126-132** (`EXC_BREAKPOINT` de SwiftData in-memory,
  aleatorio por run, alcanza también a tests pure-logic que instancian `@Model` sin contexto), y el
  **`TODO(@jur, 2026-07-15)` de :141-142** lo declara «prerequisito para CUALQUIER paso de test
  bloqueante».

⇒ **Quitar las tres banderas sin arreglar ese crash no arregla nada: cambia un verde mentiroso por
rojos aleatorios, y entonces alguien vuelve a ponerlas.** Ya pasó una vez —el intento de dejar
pure-logic bloqueante (`264e25f8`) se revirtió tras el crash del run `26963873224`, según :138-140—.
El arreglo real empieza por el crash, no por la bandera. Esto es exactamente por lo que el punto 3 de
abajo va DESPUÉS del 1 y el 2.

## Dos rojos más, que el CI no ve (rescatados de un ticket que se archiva hoy)

`tickets/discarded/rescue-discarded-groups-pull.md` —que pasa a `discarded` en **este mismo commit**—
dejaba en su sección «Fuera de alcance, detectado de paso» (:237) un residual que, si no se traslada
aquí, desaparece del tablero:

> `ProUpsellServiceOneShotTests` (2 tests) falla bajo el scheme `Yala Dev` […] Efecto colateral: hoy
> NINGÚN scheme corre la suite de unit entera en verde (con `Yala` fallan las dos suites que exigen
> `DEV_BUILD`). Chip creado: `task_6bbda818`.

**No entra en la tabla de arriba**, y la distinción importa: los ocho de la tabla salen del log del
CI; éste es un rojo **local**, del scheme `Yala Dev`, que el CI no ve.

### Y la medición de hoy NO lo sostiene — por eso no escribo aquí «ningún scheme corre la suite entera en verde»

Comprobado en el árbol de hoy, sin correr nada (lectura de código):

- `YalaTests/ProUpsellServiceOneShotTests.swift` tiene **6 tests**. Los **4** que dependen del tier Pro
  **inyectan el predicado** (`isProUser: { false }` / `{ true }`, en :30, :45, :60 y :74); los otros 2
  (:50 y :80) sólo llaman a `mark*` y leen sus propios defaults aislados. **Ninguna aserción del
  fichero lee `FeatureGateService.shared`.**
- Ese predicado inyectable entró en `Yala/App/Services/ProUpsellService.swift:26-32` con el commit
  **`d48c5dad` (2026-08-05)**, y la cabecera del test lo documenta en :9-13.
- Los **dos** mecanismos que la documentación nombra como causa de ese rojo actúan los dos a través de
  `FeatureGateService.shared`: (a) `dev.forceProTier` que `-uitest-pro` dejaba persistido —cerrado en
  `StoreKitManager.applyUITestProTier` (`Yala/App/Services/StoreKitManager.swift:607-622`) y pinneado
  por `YalaTests/UITestProTierIsolationTests.swift`, 2 tests vivos—; y (b) la transacción de StoreKit
  sandbox persistida en el simulador, que concede Pro por carrera del singleton (`docs/DECISIONS.md`,
  entrada del **2026-07-13**, gotcha (a)).
- Fechas: el ticket que arrastra el residual es `created: 2026-07-27`, y su texto llegó a este repo en
  la migración masiva del **2026-08-26** (`2c0f482a`, «migrated from YalaWiki … @ 1934e8ad»), así que
  la fecha de **redacción** del párrafo es la del vault, no la del import. `d48c5dad` cae en medio.

**INFERIDO** (no medido: no corrí la suite, está fuera del alcance de esta sesión): si esos dos rojos
siguen existiendo hoy, ya **no** los causa el mecanismo que ambas fuentes nombran. Lo único que queda
tocando un singleton en ese servicio es `shouldShowPeriodicBanner` (vía `isVoluntaryChurn` →
`StoreKitManager.shared.wasProUser`, `ProUpsellService.swift:144-148`), y **ningún test del fichero lo
llama** — el `.serialized` de :23 sigue puesto por eso, según :15-16.

**Qué hacer con esto: una corrida, no un diagnóstico.** Correr `YalaTests` bajo `Yala Dev` y ver.
Si sale verde, el residual está cerrado desde el 2026-08-05 y se cierra el chip `task_6bbda818`; si
sale rojo, hay causa NUEVA y ésa sí es un hallazgo. Lo que no se puede es seguir citando la frase
«ningún scheme corre la suite entera en verde» como hecho: **la mitad que se puede medir sin ejecutar
está en contra**, y la otra mitad (las suites que exigen `DEV_BUILD` bajo el scheme `Yala`) tampoco la
he medido.

## Qué hacer, en este orden

1. **Ver el rojo primero.** Correr la suite completa y separar los ocho en «rojo real», «divergencia
   de entorno» y «test stale». NO promover ningún paso a bloqueante antes de esto: bloquearía todos
   los push desde mañana.
2. **Hacer visible el fallo sin bloquear.** El problema no es `continue-on-error`, es que no deja
   rastro. Un paso final que lea el resultado y avise —el webhook a Grok ya funciona y está
   probado— convierte «advisory» en «informa pero no para», que es lo que se pretendía en junio.
3. **Promover los dos pasos de unit a bloqueantes**, después de 1 y 2. Su premisa —el
   `EXC_BREAKPOINT` de SwiftData in-memory, `qa.yml:122`— se **diagnosticó el 2026-07-04**
   (acumulación de `ModelContainer`, no instanciar `@Model`) y sus dos contramedidas están en el
   árbol: reuso de container por `#fileID` (`TestHelpers.swift:38,62`, con tests que lo pinnean) y
   `-parallel-testing-enabled NO` en los tres pasos. El comentario que las justifica es del
   2026-06-04, **anterior al diagnóstico**. Hay un `TODO(@jur, 2026-07-15)` que lo da por sin
   resolver: verificar cuál de los dos está al día antes de tocar nada.
4. **Sacar el paso de UI del camino del push.** Cuesta **1 h 14 min – 1 h 41 min** de runner macOS
   (medido en cuatro runs) por cada cambio que toque `Yala/`, y siendo advisory hoy no puede
   bloquear nada. A nocturno o `workflow_dispatch`. Ojo: **no hay guardián nocturno** que lo cubra
   —comprobado: sólo existen `qa.yml` y `avisar-grok-push-principal.yml`, ningún `schedule:`, ni
   cron ni launchd en la Mac—, así que sacarlo del push sin poner el nocturno deja la suite UI
   sin ninguna corrida automática.

**Lo que NO hay que hacer:** quitar el `continue-on-error` sin hacer el punto 1. Hoy es lo único que
permite que el repo siga mergeando.

## No verificado

- No se corrió la suite en UTC para confirmar la causa de los cuatro del widget; es lectura de
  código, no medición.
- No se diagnosticaron los otros tres (`GroupCreateRouting`, `NewTransactionViewModel`,
  `HandoverGroups`).
- No se revisó cuántos runs hacia atrás llega el patrón: se comprobaron seis, todos con fallos.
- El `TODO(@jur, 2026-07-15)` de `qa.yml` puede estar al día o caducado; no se comprobó cuál.
- **`ProUpsellServiceOneShotTests` no se ha corrido.** Lo de arriba es lectura del árbol de hoy: dice
  que la causa documentada ya no está en el código, no que la suite pase. Falta la corrida.
- **Tampoco se ha corrido `YalaTests` bajo el scheme `Yala`**, así que «fallan las dos suites que
  exigen `DEV_BUILD`» sigue siendo una cita del ticket de origen, no una medición de esta sesión.

---

## Sesión del 2026-09-02 (noche) — pasos 1 y 2 hechos

Alcance acordado con el owner: **hasta el paso 2**. Los tres `continue-on-error` **siguen puestos**;
no se promueve nada a bloqueante (paso 3) ni sale la suite UI del push (paso 4).

### Paso 1 · el rojo, medido — y la tabla de arriba estaba equivocada en su forma

Corrida local (`-scheme Yala`, iPhone 17 Pro, TZ del Mac = `America/Lima`, verificada con
`systemsetup -gettimezone`), sin `-quiet` y comprobando el conteo:
`Test run with 108 tests in 5 suites failed after 1.044 seconds with 1 issue`.

**Un solo rojo local, no ocho.** Los ocho del CI se reparten en TRES categorías, no en una:

| Test | Local | Categoría real |
|---|---|---|
| `WidgetDataServiceIntervalTests` (×4) | **verde** | Divergencia de entorno (TZ). Confirmado: el Mac está en Lima, el runner en UTC |
| `NewTransactionViewModelTests.splitDescriptionShares` | **verde** | Divergencia de entorno (**IDIOMA**, no TZ) |
| `HandoverGroupsDomainTests.wipeLocalGroupsDomain_killsTheOutbox_butKEEPSTheCursor` | **verde** | Fuga de estado entre tests, sensible al orden |
| `GroupCreateRoutingWiringTests.splitGroupHasNoLegacyProducerInProduction` | **ROJO** | **Rojo real y reproducible en cualquier máquina** |
| `HeroBucketsCalculatorTests.periodPreviousInterval_thisWeek…` | verde | Ya arreglado (`8168987a`) |

⇒ **«pasa en la Mac del owner» era falso para el cuarto.** Falla aquí también. No se había visto
porque `/gate` sólo corre las suites del área tocada, y el commit que lo rompió no tocaba la suya.

### Las tres causas, con su arreglo

**(a) Los cuatro del widget — zona horaria.** Diagnóstico del ticket confirmado por medición.
Arreglo elegido por el owner: **fijar la TZ del runner**, no inyectar el calendario. Va con control
positivo: si `systemsetup` no aplica la zona, el job para ahí en vez de dejar cuatro rojos sin
explicación veinte líneas más abajo.

**(b) `splitDescriptionShares` — idioma, y esto NO estaba en el ticket.** El test exigía
`contains("2 de 5")`, un literal en español, contra un string que `ls()` resuelve por `Bundle.main`
= idioma del simulador (`en` en el runner ⇒ `"2 of 5 shares"`). Pinneaba una traducción, no la
lógica. Ahora compara contra `L10n.Split.descShares(2, 5)` y conserva lo único que el literal sí
protegía —que `myValue` y `divisor` no viajen intercambiados— con un segundo `#expect` contra
`descShares(5, 2)`. Que el string exista en los 16 idiomas ya lo cubre la batería de l10n.

**(c) `wipeLocalGroupsDomain_killsTheOutbox…` — el helper de aislamiento filtraba.**
`wipeAllModels` (`YalaTests/TestHelpers.swift`) prometía «todas las instancias de cada `@Model` del
schema» y su docblock decía «22 modelos». **Medido: el schema tiene 31 y borraba 22.** Los nueve que
faltaban son los de sync y migración (`GroupSyncCursor`, `GroupSyncOutbox`, `SyncOutbox`,
`SyncCursor`, `SyncQuarantine`, `SyncDanglingRef`, `SyncUnitClock`, `MigrationState`,
`CloudMigrationMarker`). Como `makeTestContext()` **reusa** el container por `#fileID`, un
`GroupSyncCursor` sobrevivía de un test al siguiente del mismo fichero; `.serialized` garantiza que
no se solapen, **no** en qué orden corren, así que el test contaba 2 donde esperaba 1. Añadidos los
nueve, y pinneado con `WipeAllModelsCoverageTests` para que no vuelva a divergir en silencio.

**(d) `splitGroupHasNoLegacyProducerInProduction` — el rojo real.** El escáner impide que nazca un
`SplitGroup` fuera del canal backend, y su allowlist tenía un hueco: `DevSeedTransactions.swift:648`
construye uno en `createDeadPointerFixture`. Medido: el fichero va del `#if DEBUG` de `:8` al
`#endif` de `:676`, **que es su última línea** — entero bajo DEBUG, el mismo criterio con el que
`DevSeedGroups.swift` ya estaba permitido. Y el propio código deja escrito en `:640-641` que no
setea `isBackendGroup` **a propósito**. Entró con `2f6cb24f` el **2026-08-18** y estuvo quince días
en rojo sin que nadie lo viera. Arreglo: la allowlist del test.
Comprobado que no hay más instancias: de los seis ficheros de `Yala/` que contienen `SplitGroup(`,
dos son líneas de comentario (`GroupZoneCacheGate.swift:24`, `SplitGroupZone.swift:24`) que el
escáner ya descarta bien.

### Paso 2 · que el fallo deje rastro

En `.github/workflows/qa.yml`:

1. Paso nuevo que fija `America/Lima` en el runner, **con control positivo**.
2. `id:` en los tres pasos advisory (`unit_pure`, `unit_context`, `ui`), para poder leer su
   `outcome` — que es lo que de verdad devolvió el comando. `conclusion` es el campo que
   `continue-on-error` pinta de verde, y leerlo era justo el error que mantuvo esto oculto.
3. Paso final que avisa a Grok cuando alguno sale en `failure`, con el molde ya probado de
   `avisar-grok-push-principal.yml` (verifica el código HTTP: un `curl` que no lo mira no es una
   entrega, es una esperanza).

**Cambio no pedido, declarado:** se quitó `-quiet` de los tres pasos de test. Sin él no sale
`Test run with N tests in M suites`, y sin esa línea una corrida que ejecutó **cero** tests —filtro
mal expandido, nombre de suite inexistente— sale con `exit 0` y `TEST SUCCEEDED`. Un aviso que no
puede distinguir ese caso miente igual que el verde que este ticket viene a arreglar. Se revierte
en una línea.

### Lo que sigue sin hacer

- **Paso 3** (promover unit a bloqueante) y **paso 4** (sacar UI del push): fuera de alcance por
  decisión del owner. El paso 4 sigue teniendo su peaje sin resolver: no hay guardián nocturno.
- El `TODO(@jur, 2026-07-15)` de `qa.yml` sigue sin comprobar si está al día.
- **No se ha medido si el arreglo de la TZ pone verdes los cuatro del widget EN EL RUNNER.** Aquí ya
  estaban verdes; la comprobación real es el próximo run de CI. Es una predicción, no una medición.

### Verificación (corrida real, no lectura)

**`xcodebuild test -scheme "Yala Dev" -only-testing:YalaTests -parallel-testing-enabled NO`**
⇒ `✔ Test run with 5964 tests in 592 suites passed after 78.479 seconds` · `** TEST SUCCEEDED **`

Se corrió la suite ENTERA, no las suites tocadas, porque `wipeAllModels` lo usan **60 ficheros de
test**: verificar sólo lo tocado no habría probado nada. Cero regresiones en las 592 suites.

Control positivo de cada pieza (que la suite corriera, no sólo que compilara):

- `◇`/`✔ Suite "Aislamiento · wipeAllModels cubre el schema entero (source-scan)"` — el pin nuevo
- `✔ Test "MUTACIÓN (e): ningún camino de producción construye un SplitGroup fuera del canal backend"`
- `✔ Test "splitDescription for shares type"`
- `✔ Test wipeLocalGroupsDomain_killsTheOutbox_butKEEPSTheCursor()`

**Y cierra la pregunta abierta que el ticket dejaba planteada.** Pedía «una corrida, no un
diagnóstico» sobre `ProUpsellServiceOneShotTests` bajo `Yala Dev`:

- `✔ Suite "ProUpsellService one-shots" passed after 0.010 seconds` ⇒ **el residual está cerrado** y
  con él el chip `task_6bbda818`.
- Y la frase heredada del ticket de origen —«hoy NINGÚN scheme corre la suite de unit entera en
  verde»— queda **medida y es falsa**: `Yala Dev` corre las 592 suites en verde. Esa cita ya no se
  reusa.

**Lo que esta corrida NO prueba:** que el `EXC_BREAKPOINT` flaky de SwiftData esté resuelto. Es un
fallo de ~1 de N runs; una corrida verde no es evidencia de ausencia. La premisa de los
`continue-on-error` sigue sin refutar, y por eso el paso 3 sigue sin hacerse.

### Control positivo de la TZ — el diagnóstico deja de ser lectura

El ticket decía, honestamente, «confirmada por lectura, **NO ejecutada en UTC**». Ya está ejecutada,
sin tocar la configuración del Mac (`TEST_RUNNER_TZ`, que `xcodebuild` propaga al proceso de test):

| Zona | `YalaTests/WidgetDataServiceIntervalTests` |
|---|---|
| `America/Lima` (la del Mac) | `✔ Test run with 10 tests in 1 suite passed` |
| `TZ=UTC` (la del runner) | `✘ Test run with 10 tests in 1 suite failed … with 10 issues` |

Los tests en rojo son **exactamente los cuatro de la tabla de arriba**, ni uno más:
`lastMonth_ssot_end_is_exactly_one_second_before_this_month_start`,
`lastMonth_ssot_excludes_midnight_of_first_day_of_this_month`,
`lastYear_ssot_excludes_midnight_of_first_day_of_this_year` y
`parity_widgetReplica_matches_ssot_for_all_non_weekly_periods` (éste con 7 issues — barre todos los
períodos —, de ahí que el total sean 10 issues y no 4).

⇒ La causa está probada y el mecanismo elegido ataca la causa. Lo que sigue sin medir es la otra
mitad: **que el runner de GitHub herede la zona que le fija el paso nuevo.** Eso lo dice el próximo
run, y para eso está su control positivo — si `systemsetup` no la aplica, el job para ahí y lo dice.

### Y la otra mitad que faltaba: el scheme `Yala`

El ticket dejaba escrito «**Tampoco se ha corrido `YalaTests` bajo el scheme `Yala`**, así que
"fallan las dos suites que exigen `DEV_BUILD`" sigue siendo una cita del ticket de origen, no una
medición». Corrido:

| Scheme | Resultado |
|---|---|
| `Yala Dev` | `✔ Test run with 5964 tests in 592 suites passed after 78.479 s` |
| `Yala` | `✔ Test run with 5964 tests in 592 suites passed after 75.536 s` |

**Conteo idéntico en los dos.** La cita heredada es falsa: no fallan dos suites bajo `Yala`, no falla
ninguna. Con esto la frase «hoy NINGÚN scheme corre la suite de unit entera en verde» queda medida y
descartada **por completo** —no a medias— y deja de citarse.

---

## Sesión del 2026-09-03 — los ocho están verdes, y el arreglo del paso 1 se retira

### Los ocho rojos: CERRADOS, y medidos en el runner (no por lectura)

Lo que este ticket dejaba escrito como pendiente —«**No se ha medido si el arreglo de la TZ pone
verdes los cuatro del widget EN EL RUNNER**. Es una predicción, no una medición»— ya está medido.

Run `33794198525` (commit `85ba0077`, 2026-09-03 19:04, `macos-26`). Es el único de los medidos en
que el paso de la zona horaria SÍ aplicó (`Zona horaria del runner: America/Lima`), y con eso los
dos pasos de unit corrieron enteros:

```
✔ Test run with 5885 tests in 587 suites passed after 195.129 seconds   (pure-logic)
✔ Test run with 94 tests in 7 suites passed after 1.483 seconds         (context-based)
```

Cero fallos. Los ocho de la tabla son todos de `YalaTests` ⇒ **los ocho quedan cerrados**. La
predicción del paso 1 se confirma como medición.

### Pero el propio arreglo abrió un agujero mayor, y por eso se retira

El paso `Fijar zona horaria del runner` **no llevaba `continue-on-error`**, así que cada vez que
fallaba tumbaba el job `tests` entero y GitHub saltaba el build y los tres pasos de test.

Medido sobre los 9 runs en que el paso llegó a ejecutarse: **aplicó la zona en 3**. Los otros 6
murieron ahí. Consecuencia: entre `85ba0077` y `584aacba` entraron en `2.1` **cuatro commits que
tocan código** —`6ddc4367`, `9f5fb2f8`, `6bf0f588`, `7d9f6d17`— y ninguno tiene una sola corrida de
tests en CI. No salieron en rojo: **no se ejecutaron**. Durante esas horas la cobertura de CI fue
*peor* que con el verde mentiroso de agosto — entonces los tests corrían y nadie los leía; después
ni corrían.

### La causa del fallo de `systemsetup` NO es la que parecía, y queda sin cerrar

El paso imprimía `### Error:-99 … InternetServices.m Line:395` en cada run rojo, lo que invitaba a
leerlo como «el runner no da permiso». **Falso, y medido**: ese mismo `Error:-99` aparece **idéntico
en los tres runs que SÍ aplicaron la zona**, una sola vez por run. No discrimina. La imagen del
runner también es la misma en verdes y rojos (`macos-26-arm64`).

El delta entre `-settimezone` y `-gettimezone` correlaciona pero **no explica**:

| Run | Δ set→get | Zona resultante |
|---|---|---|
| 33812015056 | 41 ms | GMT |
| 33810993958 | 34 ms | GMT |
| 33806661444 | 37 ms | GMT |
| 33801694764 | 38 ms | GMT |
| 33796674124 | 61 ms | GMT |
| 33777488891 | **331 ms** | **GMT** |
| 33789018825 | 120 ms | America/Lima |
| 33756063332 | 105 ms | America/Lima |
| 33794198525 | 562 ms | America/Lima |

331 ms falló y 105 ms pasó ⇒ **no hay umbral que esperar**. Es consistente con que `systemsetup`
aplica el cambio de forma asíncrona y no fiable, pero **la causa última no queda cerrada** y por eso
no se intentó un reintento con espera: sería una apuesta, no un arreglo.

### El mecanismo nuevo: `TEST_RUNNER_TZ` a nivel de job

Decisión del owner (2026-09-03), sustituye a la del 2026-09-02: **fuera el paso `systemsetup`**, y la
zona se fija con `TEST_RUNNER_TZ: America/Lima` en el `env:` del job `tests`. `xcodebuild` retira el
prefijo `TEST_RUNNER_` al propagar la variable, así que el proceso de test recibe `TZ=America/Lima`.

Va a nivel de **job** y no de paso a propósito: un paso de test nuevo lo hereda solo. Olvidarse de
aplicarlo es exactamente el modo de fallo que este bloque arregla.

Verificado hoy en esta Mac, con el mecanismo EXACTO del fix (la variable en el entorno del proceso
`xcodebuild`, no en la línea de comandos), misma máquina y mismo binario:

| `TEST_RUNNER_TZ` | `YalaTests/WidgetDataServiceIntervalTests` |
|---|---|
| `UTC` | `✘ Test run with 10 tests in 1 suite failed … with 10 issues` |
| `America/Lima` | `✔ Test run with 10 tests in 1 suite passed` |

Los fallos bajo `UTC` son **exactamente los cuatro de la tabla original**, ni uno más. El conteo
`10 tests in 1 suite` es el control de que la suite corrió de verdad y no cero tests.

**Lo que este cambio pierde, y se dice:** la decisión del 2026-09-02 eligió fijar la zona del
*sistema* porque así se probaba además que el algoritmo no depende del entorno. `TEST_RUNNER_TZ`
fija la zona del *proceso de test*. No toca el código (el SSOT sigue resolviendo con
`Calendar.current`, sin calendario inyectado), pero la propiedad «probado bajo la zona del sistema»
ya no se sostiene. Es el precio de tener CI que corre.

### El aviso a Grok también mentía, un escalón más arriba

`if: always()` estaba bien puesto: el paso SÍ corría. Lo que fallaba era la lectura — un paso que no
llega a ejecutarse deja `outcome` en `skipped`, no en `failure`, y la condición solo miraba
`!= "failure"`. Así que en los seis runs con cero tests el aviso imprimió:

```
::notice title=Suite en verde::Ningun paso advisory fallo. No se avisa.
```

Es **el mismo error que este ticket vino a arreglar**, un escalón más arriba: comprobar el resultado
de los tests sin comprobar antes que los tests llegaran a correr.

Arreglado con una rama `sin_correr` que trata cualquier `outcome` distinto de `success`/`failure`
como motivo de aviso, con un texto propio («la suite NO llegó a correr»). Verificado ejecutando el
script del paso con los tres escenarios:

| `outcome` de los tres pasos | Antes (HEAD `584aacba`) | Ahora |
|---|---|---|
| `success` ×3 | «Suite en verde», exit 0 | «Suite en verde», exit 0 |
| uno en `failure` | avisa «tests en rojo» | avisa «hay tests en rojo» |
| `skipped` ×3 | **«Suite en verde», exit 0** | **avisa «la suite NO llegó a correr»** |

La fila de abajo es el bug, reproducido contra el fichero de `HEAD` y ausente en el nuevo.

### Lo que sigue sin hacer

- **El paso 3 sigue sin tocar** (promover algún paso a bloqueante): su prerequisito es el
  `EXC_BREAKPOINT` de SwiftData in-memory, sin resolver. Sin cambios.
- **Por qué `systemsetup` aplicaba la zona 3 de 9 veces.** Se retira el mecanismo, no se diagnostica.
  Si algún día hace falta fijar la zona del sistema en CI, esto sigue abierto.
- **El paso de UI (`YalaUITests`) salió en `TEST EXECUTE FAILED`** en el único run que llegó a
  ejecutarlo (`33794198525`, 43 fallos sobre 156 tests, 24 tests distintos). Es advisory y está
  documentado como flaky en runner frío, así que **no distingo flaky de rojo real sin correrlo**. No
  se ha corrido. Es lo primero que dirá el próximo run ahora que el job vuelve a llegar hasta ahí.

---

## Sesión del 2026-09-04 — el paso de UI, diagnosticado; y el gate que lo dejó pasar

Cierra el último «no verificado» que quedaba arriba: **«el paso de UI salió en `TEST EXECUTE
FAILED` […] no distingo flaky de rojo real sin correrlo»**. Corrido. No era flaky.

### Los 16 en rojo: ninguno es un bug de la app

El paso de UI del run `33815722522` dio 42 fallos. Son **issues de aserción, no tests**: los tests
únicos son **16** (21 entradas con los reintentos). Repartidos, con su causa medida:

| Causa | Tests | Qué pasó |
|---|---|---|
| Rediseño del Panel (`a4445a26`, 2026-09-02) | 11 en 7 suites | El FAB solo se monta al hacer scroll; los tests lo buscaban al arrancar |
| Entorno y seed | 5 en 4 suites | Idioma heredado del dispositivo, `onboardingMode` filtrándose entre tests, y una carrera de arranque |

**Cero bugs de producto.** Verificado en simulador antes de tocar nada: lanzada con los launch
arguments reales del test, la app arranca en el Panel con el seed cargado y el «+ Nuevo registro» a
la vista. Lo que dejó de describir la app eran los tests.

**Y NO era el «flaky en runner frío»** que la Lista Negra les atribuía: fallaban igual en la Mac del
owner, en simulador, sin runner de por medio y sin `-retry`. Esa hipótesis queda refutada.

Arreglado en `910409be` (las 7 del FAB, con un helper `revealPanelFAB()` en el harness) y en
`13ee8ab8` (los 5 de entorno). Medición final: **las 11 suites juntas, 29 tests, 0 fallos.**

### Por qué el gate dio verde sobre un cambio que rompió siete suites

Es el hallazgo que trasciende este ticket. `/gate` corre los XCUITest «de las áreas tocadas» y
decide qué área lo está con los `codeGlobs` de `qa/coverage-index.json`. `a4445a26` tocó
`PanelView.swift` — y **ninguna** de las siete áreas rotas lo listaba entre sus globs. Para el gate,
nadie las había tocado.

Auditadas las 59 áreas con cobertura xcuitest: **30 no cubrían el código del que dependen**. El caso
mayor, `FABStackView.swift` —la puerta por la que 21 áreas llegan a su pantalla— no figuraba en los
globs de ninguna.

Arreglado en `7fcd8c1c`, y la segunda mitad es la que importa: no basta con añadir el fichero donde
vive el identificador, hay que añadir **el que monta esa vista**, porque ahí está la condición que
puede ocultarla. Medido antes de darlo por bueno: con la primera pasada sola, el arreglo habría
cazado **1 de las 4** áreas rotas; con las dos, las 6.

### Lo que sigue sin hacer

- **Pasos 3 y 4 del plan**, sin cambios y fuera del alcance acordado. El 3 (promover unit a
  bloqueante) sigue esperando al `EXC_BREAKPOINT` de SwiftData; el 4 (sacar UI del push) sigue
  necesitando un nocturno que no existe.
- **Por qué `systemsetup` aplicaba la zona 3 de 9 veces.** Se retiró el mecanismo, no se
  diagnosticó. Sigue abierto si algún día hace falta fijar la zona del sistema en CI.
- **La carrera de `GroupsRetentionUITests` no está cerrada**, solo tiene margen: `uitest_ready`
  señala bootstrap y seed, no que el cover esté presentado. Cerrarla exigiría que `markReady()`
  aguardase al cover, y eso haría esperar a todos los tests por algo que casi ninguno presenta.
- **Cuatro áreas del índice se quedaron sin `lastVerified` nuevo** a propósito: dependen además de
  suites que no se corrieron (`GroupsEmptyState`, `GroupExpenseSuccess`, `PaywallInboxAlertRouting`
  y cinco de `settings-profile-general`).

### Nota de método

Dos errores propios que costaron tiempo y conviene que consten. Un `TEST EXECUTE FAILED` sin una
sola línea de `Executed` **no es un test en rojo: es que no arrancó** — encajaba con el síntoma de
disco lleno de la Lista Negra y estuvo a punto de irse por ahí, pero el error completo decía que
faltaba el runner, borrado al liberar espacio y no reconstruido porque `xcodebuild build` no compila
los targets de test. Y una medida de disco recién liberado no es fiable: tras `simctl erase`, APFS
tardó en reclamar y los «12 GiB» por los que casi se para el trabajo eran 34.

---

## CERRADO · 2026-09-04 — el alcance acordado está completo y verificado

Cerrado por el owner con el alcance que él mismo fijó: **hasta el paso 2**. No se cierra por
cansancio ni por caducidad; se cierra porque lo acordado está hecho y medido en el árbol.

**Verificado en esta sesión, contra el árbol de hoy (no contra lo que este ticket afirma):**

- El mecanismo de zona horaria es el aprobado el 2026-09-03: `TEST_RUNNER_TZ: America/Lima` en el
  `env:` del job `tests` (`qa.yml:172-173`), a nivel de job y no de paso. El paso `systemsetup` ya no
  existe: su único rastro es un comentario histórico en `:164`.
- `wipeAllModels` cubre los **31** modelos del schema (`TestHelpers.swift:149-161`), que son
  exactamente los 31 de `SwiftDataConfiguration.swift:56-88`, y está pinneado por
  `WipeAllModelsCoverageTests`.
- El resto de afirmaciones técnicas del ticket se comprobaron una a una y se sostienen.

**Lo que este ticket decía de sí mismo y NO era cierto** (queda escrito, porque es el patrón que el
`CLAUDE.md` advierte y este ticket lo cometió sobre su propio arreglo):

- Las coordenadas `175/197/215` del encabezado están caducadas. Hoy los tres `continue-on-error`
  están en **201, 223 y 241**: el propio commit de este ticket (`815385b3`) desplazó el fichero 26
  líneas y el encabezado no se re-midió. **Citaba líneas de un árbol anterior a su propio commit.**
- Dos cifras del hallazgo del índice de cobertura son incorrectas (`FABStackView` estaba ya en 4
  áreas, no en 0; el commit tocó 56 áreas, no 30). La conclusión aguanta; los números no.

**Dónde sigue el trabajo:** `tickets/backlog/ci-warns-but-does-not-block.md`, que recoge los pasos 3
y 4 con sus prerequisitos medidos —incluido el que importa: **no existe ningún pase nocturno**, así
que sacar la suite de UI del push la dejaría sin corrida automática— y los cuatro residuales menores.
Nada de lo que quedaba abierto se pierde con este cierre.
