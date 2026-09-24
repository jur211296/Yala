---
id: displaced-migration-leader-keeps-uploading-after-a-takeover
status: qa
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `migration-takeover-uploads-without-a-lineage-check` (2026-09-24), lente de bypass"
---

# El teléfono que perdió el relevo de una activación vuelve y sigue subiendo sus datos a la cuenta

## El problema, en lenguaje de usuario

Empiezo a activar la nube en el teléfono A y se queda sin conexión más de una hora. Mientras tanto, otro teléfono B entra en
la misma cuenta y termina la activación él. Cuando A recupera la red, sigue subiendo sus datos donde se quedó, encima de
los de B. Si A y B no tenían los mismos datos, la cuenta acaba con una mezcla. A solo se para al final, cuando el servidor
le dice que otro dispositivo tomó el relevo, y para entonces lo suyo ya subió.

## Lo medido (2026-09-24, leído en el código por la review, sin ejecutar)

- La comprobación de linaje de `migration-takeover-uploads-without-a-lineage-check` protege a quien TOMA el relevo (B), en
  la identidad. A no vuelve a pasar por la identidad: su journal sigue en `uploadingSnapshot`.
- `MigrationRunner.driveUpload` no mira el lease. El heartbeat que recibe `other_leader`
  (`MigrationWorkExecutor.sendLeaseHeartbeatIfDue`) solo deja un rastro.
- `/sync/push` (`gateway/src/sync/routes.ts`) solo comprueba `reverse_frozen_at`, no quién lidera la migración.
- A solo sale en `cutover(.pending)` con `ForwardStepBlocker.otherDevice`. B, en su `verify()`, hace un pull y mete las filas
  de A en su store; el Merkle cuadra y B puede terminar con los dos corpus mezclados.
- Existía antes de ese ticket: no lo abre, pero tampoco lo cierra.

## Candidatas (sin medir)

- Que el `other_leader` del heartbeat corte la subida (definitivo), con un heartbeat SIN throttle al empezar cada pasada: un
  relevo exige 60 min de silencio, así que dentro de una pasada viva no puede ocurrir.
- O una guarda de lease en el servidor para `/sync/push` mientras `migration_in_progress` (el push tendría que llevar el
  `device_id`; toca el Worker).

## Criterios de aceptación

- [x] Un teléfono que perdió el lease de la migración no sube ni una página más a la cuenta (unit + mutantes; device-QA pendiente).
- [x] Sale con el texto de «otro dispositivo tomó el relevo», sin esperar al cutover (unit; device-QA pendiente).

## Qué se hizo (2026-09-24)

**El teléfono que perdió el relevo ya no sube nada más a la cuenta, y sale en el acto con «otro dispositivo con tu cuenta
tomó el relevo».** Las decisiones, con su porqué, están en el Paso 0 del encargo
(`encargos/lanzados/2026-09-24-displaced-migration-leader-keeps-uploading-after-a-takeover.md`).

- **Puerta del lease en el cliente, antes de CADA página y de cada verificación de la ida**
  (`MigrationWorkExecuting.confirmMigrationLease`, llamada en `driveUpload` y `driveVerify`). Pregunta con la acción
  `heartbeat` que ya existía, sin throttle, y una confirmación vale 60 s contados desde la pregunta (`ContinuousClock`).
- **`other_leader` o `not_in_progress` → salida inmediata** (`MigrationEvent.migrationLeaseLost` → `failedRollback` +
  `.rollback`) con `forwardStepExitReasonRaw = otherDevice`: el texto `storage.failed.stepOtherDevice`, que ya existía.
- **La red, un 5xx, `no_profile`/`bad_action` o un 401 con sesión guardada no suben y esperan** como la red de cada fase;
  la sesión borrada, como `sessionExpired`. Nada se cachea.
- **La subida deja de llamar a `sendLeaseHeartbeatIfDue`**: la puerta late con la misma cadencia y lee la respuesta.
- **Sin cambio de servidor.** Medido: el Worker de producción (versión del 2026-09-10) ya acepta `heartbeat`, y el cuerpo
  vivo de `migration_progress` contesta `not_in_progress` antes que `other_leader` cuando la migración ya terminó.
- **La confirmación caduca también a media página** (lo cazó la review): una página son varios trozos de 50 filas, y la
  app congelada entre dos más de una hora mandaba el siguiente sin volver a preguntar. El push corta antes de cada trozo
  y la verificación no pide el pull si la confirmación tiene más de 30 min (`MigrationLeaseWitness`).
- **El lease cambia de significado, a propósito** (lo cazó la review): antes solo latía una página confirmada; ahora
  late cada pasada que pregunta. Dice «el líder está vivo»: el líder sin red lo pierde igual a los 60 min; el conectado
  cuyo push falla lo conserva hasta su techo en vez de cedérselo a otro y volver a subir encima.
- **Verificado:** 23 mutantes muertos en dos tandas; review de tres lentes (bypass, falsos positivos del líder legítimo,
  consumidores/tests/regla). De sus hallazgos: dos arreglados (la media página, la regla que decía «misma cadencia»),
  uno medido y refutado (el Worker de staging también acepta `heartbeat`, desplegado el 2026-09-10), docblocks
  corregidos, y uno previo a ticket propio.
- **Descartado:** la guarda de lease en `/sync/push`. Exigiría `device_id` en el push, los builds en la calle no lo mandan,
  y metería el lease en el camino caliente de todos los teléfonos en nube.

## Qué queda fuera

- La bienvenida pinta esta salida (y la del cutover, desde antes) como error de conexión →
  `welcome-shows-a-takeover-exit-as-a-connection-error` (low).
- El `cutover(.pending)` conserva su techo de 15 min para el mismo `other_leader`: fuera del encargo.
- El líder que pierde el lease DESPUÉS del cutover (esperando el marcador o el relanzamiento) sube su residual en el
  reconcile de `done` → `leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile` (medium, previo).
- Aceptados sin ticket (bajos, de la review): con `identifierForVendor` nulo el teléfono manda otro `device_id` y sale
  en el acto con «otro dispositivo» (antes, a los 15 min en el cutover); y en la verificación una puerta sin confirmar
  gasta reintentos de red como lo haría la propia verificación.

## Guion de device-QA

Lo que el simulador no puede montar: dos teléfonos con la misma cuenta y 61 min de silencio real del primero.

**Montaje**

1. Dos iPhone con la misma cuenta de Yala (Apple o Google), los dos con este build de TestFlight y en iCloud (sin nube).
2. En el teléfono A, mete datos de sobra para que la subida dure (la cuenta de pruebas con varios cientos de movimientos
   vale). En el teléfono B, datos distintos o los mismos: da igual para esta prueba.

**Prueba**

1. En A: Ajustes → Almacenamiento → «Migrar a la nube». Cuando la barra pase del 55 % (subiendo tus datos), pon A en modo
   avión **antes** de que termine.
2. Espera **61 minutos** con A en modo avión y Yala abierta o en segundo plano, da igual.
3. En B: Ajustes → Almacenamiento → «Migrar a la nube», y deja que termine entero (o al menos que pase del 55 %).
4. Quita el modo avión en A y abre Yala → Ajustes → Almacenamiento.

**Qué debe pasar**

- A no avanza la barra ni un paso más: sale en unos segundos con la tarjeta «No pudimos activar la nube desde este
  dispositivo: otro dispositivo con tu cuenta tomó el relevo. Tus datos siguen aquí, sin cambios.»
- En B (o en la web), lo que hay en la cuenta es lo de B más lo que A alcanzó a subir **antes** del modo avión, y nada más.
- En A, «Reintentar» y volver a «Migrar a la nube» no suben los datos de A: la cuenta ya es de B, y el claim lo dice
  (el aviso de cuenta existente de «Migrar»).

**Qué sería un fallo**

- A sigue subiendo tras quitar el modo avión (la barra avanza del 55 %).
- A sale con otro texto («dejó de avanzar», «revisa tu conexión»).
