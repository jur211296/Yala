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
