---
id: personal-clock-ahead-wins-every-conflict-until-real-time-catches-up
status: qa
priority: low
area: "modo-nube, sync"
created: 2026-09-26
updated: 2026-10-07
source: "`personal-clock-rollback-wedges-the-drain-forever` (2026-09-26): el precio del arreglo, gemelo personal de `groups-clock-ahead-wins-every-conflict-until-real-time-catches-up`"
---

# Un teléfono que tuvo la hora adelantada gana los conflictos de tus datos en la nube hasta que la hora real lo alcanza

## El problema, en lenguaje de usuario

Adelantas la hora de tu iPhone una semana, apuntas algo y la devuelves. Durante esa semana, lo que cambies en ese iPhone
gana siempre a lo que cambies en tu otro dispositivo en los mismos datos (un movimiento, una cuenta, una preferencia): si
editas ese movimiento desde el iPad, tu cambio desaparece en el siguiente refresco, sin aviso. Con la hora puesta años
adelante, dura años.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- Desde `personal-clock-rollback-wedges-the-drain-forever` el drain personal (`CloudSyncEngine.appendRow`) y las
  preferencias (`PrefsOutbox.enqueue`) estampan con `HLCClock.sendLocal`, que sigue al reloj lógico del teléfono aunque
  vaya por delante de la hora real. Es lo que conserva el orden de sus propios cambios. Antes ese teléfono dejaba de subir
  nada; ahora sube, con HLC del futuro.
- El reloj lógico del canal personal vive en `SyncCursor.clockLatestHLC`; el de las preferencias, en el `lastIssuedHLC` de
  `PrefsOutbox`. Mientras la hora real no los alcance, todo lo que ese teléfono emita va por delante del resto.
- **El otro dispositivo puede quedarse divergente, no solo perder** (review adversarial, lente HLC): B baja la edición de
  A (HLC `L+1`, un mes por delante); su `receive` lanza por la deriva y su reloj no avanza, pero la fila se aplica. B edita
  esa fila después de haberla visto, estampa con su hora real, pierde el LWW en el servidor, recibe `applied`/`noop` y
  purga su fila; como el servidor no cambió, B no vuelve a bajar nada y sigue mostrando su valor mientras el servidor y A
  tienen el de A. Dura hasta que alguien vuelva a editar la fila. En las preferencias es más directo: `PrefsOutbox` no
  tiene `receive`. Que la fila perdedora no mueva `server_seq` es inferido (el RPC no está en el repo).
- No se midió si el backend personal pone tope a un HLC futuro. Y con grep no aparece quién borra
  `SyncCursor.clockLatestHLC` al cerrar sesión (en Grupos, `CloudSessionSignOut.purgeGroupsSyncState` borra el
  `GroupSyncCursor`): si nadie lo borra, el adelanto pasa a la siguiente cuenta que entre en ese iPhone.
- Mientras el reloj lógico va más de 5 min por delante, `receiveRemoteClock` rechaza cada HLC remoto (su guarda de
  deriva) y deja un rastro `cloudSyncClockReceiveRejected` por fila aplicada. No pierde datos —el reloj local ya va por
  delante de ellos—, pero ensucia ese canario durante todo el adelanto.

## Qué habría que decidir

- Lo mismo que en Grupos, y conviene decidirlo una vez para los dos canales: ¿tope en el servidor a un HLC futuro, o se
  acepta el precio? Recortar rompe el orden propio; rechazar vuelve a dejar el teléfono sin subir.
- ¿Silenciar el canario de `receive` cuando la deriva la causa el reloj propio y no el remoto?

## Criterios de aceptación

- [x] Decisión escrita, común con `groups-clock-ahead-wins-every-conflict-until-real-time-catches-up` (Paso 0 del encargo).
- [x] Medido: el backend personal NO limitaba un HLC futuro (sonda de staging, 2026-10-07: +10 min `applied`; el perdedor sale `noop` sin mover `server_seq`). `SyncCursor.clockLatestHLC` muere con el archivo sync-meta que el cierre de sesión borra (`CloudSessionSignOut.swift:13-19`).
- [x] Test: `PersonalPullIntegratesTheClockTests` (la edición tras ver la fila acotada sale por encima: gana y converge; control sin tope: sale por debajo) y `PrefsPullIntegratesTheClockTests`.

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

Montaje: dos iPhones A y B con la misma cuenta de Yala en la nube. Los dos con «Ajuste automático» de la hora
encendido al empezar.

1. En A: Ajustes del iPhone → General → Fecha y hora → apaga «Ajuste automático» y pon la fecha **una semana después**.
2. En A, abre Yala y cambia el nombre de un movimiento a «Prueba A». Espera a que suba (tira hacia abajo para refrescar).
3. En A, vuelve a encender «Ajuste automático» (la hora vuelve a la real).
4. Espera **dos minutos**.
5. En B, refresca, comprueba que ves el cambio de A y cambia el nombre de ese mismo movimiento a «Prueba B». Refresca.
6. En A, refresca.
7. **Esperado:** A y B muestran el cambio de B. Antes del arreglo, A seguía mostrando el suyo y B el suyo, o el de B
   desaparecía en el siguiente refresco.
8. Repite 1-3 y, sin esperar, en A cámbialo dos veces seguidas («A1» y luego «A2»): tiene que quedar «A2» (orden propio).
