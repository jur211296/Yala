---
id: reinstall-mid-migration-has-no-exit-from-the-identity-gate
status: qa
priority: medium
area: "modo-nube, settings"
created: 2026-10-09
updated: 2026-11-06
source: "Paso 0 (D7) de `settings-migrate-blocks-a-second-device-before-its-marker`, 2026-10-09"
---

# Si reinstalas Yala (o cierras sesión) a mitad de activar la nube, ese iPhone no puede volver a intentarlo

## El problema, en lenguaje de usuario

Empiezo a activar la nube en mi iPhone y, antes de que termine, borro Yala y la vuelvo a instalar. Al tocar «Activar la nube»
otra vez, Yala me dice «Otro de tus dispositivos está llevando tus datos a la nube: termina la activación allí o, si se
detuvo, reinténtala allí». No hay otro dispositivo: era este. Y reintentar aquí me devuelve el mismo aviso. Mis datos
siguen a salvo en mi iCloud privado, pero ya no puedo llevarlos a la nube con esa cuenta.

## Lo medido (2026-10-09, rama `encargo/2026-10-09-settings-migrate-blocks-a-second-device-before-its-marker`)

- La cuenta queda `complete` con `migration_in_progress = true` y este iPhone de líder desde el claim de la ida
  (`qa/cloud/g15_01_account_kind.sql`, `claim_account`).
- Lo que deja reintentar al líder vive en `UserDefaults` y se va con la app: el sello `.proceedMigration` y la marca del claim
  sin respuesta (`CloudClaimActionStore`). El `device_id` (`identifierForVendor`) también cambia al reinstalar, así que el
  servidor ya no le devuelve `created`.
- La puerta de «Migrar a la nube» (`StorageMigrationIdentityGateLogic.check`) para toda cuenta `complete` que este
  dispositivo no reclamó. Desde `settings-migrate-blocks-a-second-device-before-its-marker` el aviso dice «otro de tus
  dispositivos» cuando la cuenta tiene una ida en curso y el faro de iCloud-KV nombra la cuenta. Tras reinstalar, el faro
  sigue ahí (viaja por el Apple ID), así que sale ese aviso, con una salida que aquí no existe.
- El servidor sí daría el relevo: con el lease vencido (60 min sin latido) y sin `migrated_at`, un claim con `migration` de
  otro `device_id` recibe `created`. Pero la puerta para antes del claim.

## Las otras poblaciones con el mismo hueco (review adversarial del 2026-10-09)

Lo que tienen en común: el iPhone que empezó la ida pierde la prueba de que la empezó él, y el faro sigue nombrando la cuenta.

- **Cerrar sesión o «Empezar desde cero» con la ida abandonada** (inferido de dos reglas, piezas medidas por separado):
  `CloudSessionRetirement.arm` olvida los sellos de claim de todas las cuentas (`forgetAllClaims`), y el faro sobrevive.
  Al volver a entrar con la misma cuenta, este iPhone oye «reinténtala en ese dispositivo» y no hay otro.
- **`identifierForVendor` nulo** (raro): cada claim sale con un `device_id` aleatorio, así que el reintento del propio líder
  recibe `claiming_in_progress` y la segunda capa dice «otro dispositivo».
- **Ida cancelada o fallida en el otro iPhone**: no hay RPC que aborte la ida, así que `migration_in_progress` se queda en
  `true` y el título habla en presente semanas después. Aquí la salida del cuerpo sí existe («si se detuvo, reinténtala
  allí»), pero el título no dice que se detuvo.

## Opciones, sin decidir

- **A · Guardar el sello donde sobreviva a reinstalar** (el Llavero, por `sub`). El líder reinstalado vuelve a ser líder y
  su «Reintentar» funciona. Falta decidir cómo recupera el `device_id` del claim (el servidor compara con `leader_device_id`).
- **B · Dejar pasar al claim cuando la ida lleva más de 60 min sin latido** y el faro nombra la cuenta: el servidor decide el
  relevo, y el relevo ya prueba el linaje (`MigrationWorkExecutor.checkForwardLineage`). Exige exponer la edad del lease en
  `/account/exists` y revisar la decisión D18 del 2026-09-16 («parar y avisar»).
- **C · Aceptarlo y cambiar el texto** para que no nombre otro dispositivo cuando no se sabe cuál es.

## Criterios de aceptación

- [ ] Tras reinstalar a mitad de la ida, el aviso no promete una salida que no existe.
- [ ] Hay una forma de terminar la activación en ese iPhone, o el caso queda decidido y documentado como aceptado.
- [ ] Una cuenta con finanzas de otra persona sigue sin poder recibir la migración.

## Decisión y arreglo (2026-11-06, lote nube 2.3)

**Jürgen eligió la opción B, en su forma solo-cliente** (vía bot, 2026-11-06): dejar que decida el servidor. Medido en
`qa/cloud/g15_01_account_kind.sql`: `claim_account` ya da el relevo (`created`) a un claim de migración cuando el lease
del líder lleva más de 60 min sin latir y no hay `migrated_at`, y devuelve `created` al mismo `device_id`. No hace falta
exponer la edad del lease ni tocar el gateway: basta con que la puerta deje llegar al claim.

**Qué cambia:**
- `StorageMigrationIdentityGateLogic.check`: una cuenta `complete` con ida en curso y el faro de este Apple ID ya no se
  bloquea; pasa al claim. Las dos redes siguen: otra cuenta de grupos asociada, y la sesión que puede ser de antes de
  «Empezar desde cero». Sin el faro, sigue «ya tiene finanzas personales».
- El claim decide: cerrar sesión (mismo `device_id`) → `created`; reinstalado con el lease vencido → relevo, que la
  identidad comprueba por linaje (`checkForwardLineage`); lease vivo → `claiming_in_progress` y el aviso.
- El aviso (`migrationInProgressOnAnotherDevice`, en 16 idiomas) ya no nombra «otro dispositivo»: «Hay una activación a
  medias con esta cuenta. Si la empezaste en este dispositivo, vuelve a intentarlo en una hora. Si fue en otro de tus
  dispositivos, termínala allí.» («dispositivo» y no «iPhone»: también corre en iPad.)
- La tarjeta no recuerda ese rechazo (`refusalToRemember`): con el botón apagado el resto de la sesión, el reintento que
  promete el aviso no existía.

**Criterios:** 1 (el aviso no promete una salida que no existe) cumplido; 2 (hay forma de terminar en ese iPhone)
cumplido: tras cerrar sesión, al momento; tras reinstalar, en cuanto el lease vence; 3 (una cuenta con finanzas de otra
persona sigue sin recibir la migración) cumplido: sin el faro de este Apple ID nada cambia, y el relevo prueba el linaje.

**Coste aceptado:** con el lease vivo, la persona ve el consentimiento antes del aviso (la parada pasa al claim, que va
después). La ida cancelada o fallida en el otro iPhone sigue sin RPC de abort, pero ahora tiene salida: a la hora, relevo.

**Tests:** `StorageMigrationIdentityGateLogicTests` (pasa al claim salvo las dos redes, el caso literal del ticket, no se
recuerda, el texto en español) y `StorageMigrationIdentityBlockUITests` (hoja con el texto nuevo, botón activo después).

**QA en el iPhone (Yala Dev, staging):** empezar «Activar la nube» con datos, borrar Yala a mitad, reinstalar y volver a
tocarlo: antes de una hora sale «Hay una activación a medias con esta cuenta…»; pasada la hora, la activación sigue y
termina. Con «Cerrar sesión» en vez de reinstalar, sigue al momento.
