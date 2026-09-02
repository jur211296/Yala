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
