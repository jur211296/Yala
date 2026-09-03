---
id: ci-verde-con-la-suite-en-rojo
status: backlog
priority: high
area: platform
created: 2026-09-02
updated: 2026-09-02
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
