---
id: groups-clock-ahead-wins-every-conflict-until-real-time-catches-up
status: qa
priority: low
area: "groups, sync"
created: 2026-09-26
updated: 2026-10-07
source: "review adversarial de `groups-clock-rollback-wedges-the-drain-forever` (2026-09-26), lentes HLC y regresión"
---

# Un teléfono que tuvo la hora adelantada gana todos los conflictos de sus grupos hasta que la hora real lo alcanza

## El problema, en lenguaje de usuario

Ana adelanta la hora de su iPhone una semana, apunta un gasto de grupo y la devuelve. Durante esa semana, lo que Ana
cambie en un gasto del grupo gana siempre: si Bruno edita o borra ese mismo gasto después, su cambio desaparece en el
siguiente refresco, sin aviso. Con la hora puesta años adelante, dura años.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- Desde `groups-clock-rollback-wedges-the-drain-forever` el drain de Grupos estampa con `HLCClock.sendLocal`, que sigue
  el reloj lógico del teléfono aunque vaya por delante de la hora real: es lo que conserva el orden de sus propios
  cambios (sin eso, su edición de después perdería contra la suya de antes). Antes ese teléfono dejaba de subir nada;
  ahora sube, con HLC del futuro.
- El servidor (`apply_group_delta`) compara el HLC como texto y no pone tope a uno futuro. El cambio de otro miembro sale
  `all_units_stale`, `stale_tombstone` o `stale_over_tombstone`; el cliente lo trata como aplicado y lo borra del outbox
  (`GroupsSyncClient`, rama `noop` de `applyResults`), y el pull le devuelve la versión del teléfono adelantado.
- El orden propio tampoco es completo: vive en `GroupSyncCursor.clockLatestHLC`, que el cierre de sesión borra. Tras
  volver a entrar el reloj arranca en la hora real, y una edición de una fila que el teléfono selló adelantada sale
  `all_units_stale`. En el sentido contrario, sin relanzar, el reloj en memoria sobrevive al cierre y la cuenta siguiente
  hereda el adelanto.

## Qué habría que decidir

- ¿Tope en el servidor (rechazar o recortar un HLC más de X por delante de `now()`)? Recortar rompe el orden propio del
  teléfono adelantado; rechazar lo vuelve a dejar sin subir, ahora con dead-letters.
- ¿Que el pull de Grupos haga avanzar el reloj con los HLC que baja (un `receive` sin la guarda de deriva), para que el
  orden propio sobreviva al cierre de sesión?
- ¿Avisar a quien pierde un conflicto por `noop`?

## Criterios de aceptación

- [x] Decisión escrita sobre el tope del servidor (Paso 0 del encargo: recortar a `now() + 60 s`, trigger, sin rechazar).
- [x] Test (`GroupsPullIntegratesTheClockTests.afterSignOutClearedTheClock_editOfARowSealedAhead_isStampedAboveIt`, con su control sin tope): con el reloj persistido borrado tras un cierre de sesión, una edición de una fila sellada adelantada no se
  pierde en silencio.

## Resolución (2026-10-07)

Decisión de Jürgen (2026-10-04): **tope en el servidor**. Los detalles los decidió la sesión en el Paso 0 de
`encargos/lanzados/2026-10-07-clock-ahead-wins-every-conflict-server-cap.md`, común a los dos canales:

- **Se recorta, no se rechaza.** Un trigger (`qa/cloud/hlc01_cap_future_hlc.sql`, en las 22 tablas sincronizadas)
  guarda todo HLC acotado a `now() + 60 s`. Nada se rechaza ni va a dead-letter. El teléfono adelantado gana como
  mucho a lo que se escriba en el minuto siguiente; después, gana quien escribe más tarde.
- **El orden propio no cambia**: el servidor decide con el HLC sin acotar, así que el segundo cambio del teléfono
  adelantado sigue ganando al primero.
- **El otro dispositivo deja de quedarse divergente**: los tres pulls (personal, Grupos y preferencias) integran el
  HLC de lo que bajan. Tras ver una fila, su cambio siguiente sale por encima y gana. Personal ya integraba y fallaba
  por la deriva; Grupos y preferencias integran desde este cambio.
- **No se avisa a quien pierde por `noop`**: perder contra un cambio más nuevo es el contrato LWW.
- Lo ya guardado con HLC del futuro lo normaliza la propia migración.

**Pendiente de Jürgen: aplicar la migración** (staging → sonda → producción), pasos en `docs/RUNBOOK-staging-ddl.md`,
sección `hlc01_cap_future_hlc.sql`. Sin ella, el cliente nuevo se comporta como el de antes.

Verificado: banco local `bash qa/cloud/hlc01-cap-test.sh` (33/33 con `apply_group_delta` real; el control sin la
migración reproduce el bug; 9 mutantes muertos), sonda de staging antes de aplicar (1/4: el bug existe hoy),
`YalaTests/CloudSync/ClockAheadServerCapTests`.

## Guion de QA (dos iPhones, tras aplicar la migración y con un build que lleve este cambio)

Montaje: dos iPhones A y B, cada uno con su propia cuenta de Yala, los dos miembros activos del mismo grupo. Los dos
con «Ajuste automático» de la hora encendido al empezar.

1. En A: Ajustes del iPhone → General → Fecha y hora → apaga «Ajuste automático» y pon la fecha **una semana después**.
2. En A, abre Yala y cambia el importe de un gasto del grupo. Espera a que suba (tira hacia abajo para refrescar).
3. En A, vuelve a encender «Ajuste automático» (la hora vuelve a la real).
4. Espera **dos minutos**.
5. En B, refresca, comprueba que ves el cambio de A y cambia el importe de ese mismo gasto a otro valor. Refresca.
6. En A, refresca.
7. **Esperado:** A y B muestran el cambio de B. Antes del arreglo, A seguía mostrando el suyo y B el suyo, o el de B
   desaparecía en el siguiente refresco.
8. Repite 1-3 y, sin esperar, en A cambia ese gasto dos veces seguidas: tiene que quedar el segundo importe (orden propio).
