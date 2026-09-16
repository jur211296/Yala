---
id: reverse-claim-rejection-has-no-way-out-in-the-client
status: qa
priority: high
area: "modo-nube, migración"
created: 2026-09-10
updated: 2026-09-16
source: "review adversarial de `reverse-cutover-cerrado-para-cuentas-born-cloud` (2026-09-10), lente de backend — hallazgo A2"
---

# Si el backend rechaza «Volver a iCloud», la barra se queda en 15 % y no hay forma de salir

## El problema, en lenguaje de usuario

Pulso «Volver a iCloud», paso las dos confirmaciones, y la barra se detiene en el 15 % con «Volviendo a
iCloud…». No hay mensaje de error, no hay «no se pudo», no hay vuelta atrás. El botón «Retomar» vuelve a
intentar lo mismo y recibe lo mismo. La app se queda así **entre arranques**, porque la fase está
journaleada.

## Por qué pasa

El claim de la reversa tiene cinco resultados y **solo uno tiene salida**:

- `Yala/Services/CloudSync/MigrationRunner.swift` · `driveReverseClaim()`:
  `case let .rejected(reason)` → un breadcrumb (`migrationClaimNoSuccess`) y `return false`. No hay
  evento, no hay terminal, y no se puebla `lastClaimBlocker` (compárese con `driveClaim`, que sí lo hace
  para el claim de la IDA y por eso su pantalla puede decir algo honesto).
- `Yala/Services/CloudSync/MigrationStateMachine.swift` declara la fase transitoria y **por qué existe
  una salida**: «*without this exit the journal would sit in `reverseClaimLeader` forever → BGTasks
  (reports) suppressed indefinitely*». Esa salida es `reverseOtherLeader`, y existe **solo** para
  `other_leader`.
- `CloudMigrationController` mapea `reverseClaimLeader` a `fraction = 0.15`, y de ahí el 15 %.

⇒ Un rechazo cualquiera del RPC deja el journal en `reverseClaimLeader` de forma indefinida, con los
BGTasks de informes suprimidos como efecto colateral.

## Por qué no dolía antes, y por qué ahora sí

Los motivos que este branch podía recibir eran dos, y ninguno era permanente **ni alcanzable**:

| motivo | antes | ahora |
|---|---|---|
| `migration_in_progress` | transitorio: acaba cuando la ida termina | igual |
| `not_migrated` | **inalcanzable desde la UI**: el gate del cliente ocultaba el botón a quien no tenía mapa CloudKit, que es exactamente esa población | ya no existe |
| `not_complete` (nuevo, `g15_02`) | — | **alcanzable y permanente** |

`reverse-cutover-cerrado-para-cuentas-born-cloud` cambió el guard del RPC a `kind='complete'` **o**
`reverted_at` no nulo. Con eso, `not_complete` le llega a una cuenta de solo grupos que nunca revirtió
— y para esa cuenta la respuesta **nunca va a cambiar**, porque no hay ninguna ruta de app que la vuelva
`complete` teniendo ya `personal_claimed_at`.

**Cuán alcanzable es hoy, medido:** la card de la reversa solo se pinta con `storageMode == .cloud` +
fase estable, y una cuenta de solo grupos no escribe `.cloud` para lo personal, así que el camino es
estrecho. Lo que hace este ticket `high` no es la población de hoy: es que **el único motivo permanente
que existe ya no tiene red**, y que la salida cuesta poco comparada con lo que evita.

## El arreglo, con su molde ya escrito en el repo

Un evento `reverseIneligible(returnTo:)` espejo de `reverseOtherLeader` (el precedente exacto está en
`MigrationStateMachine`, con su `origin` journaleado en `reverseOriginRaw`), más un `lastClaimBlocker`
para que la vista deje de mostrar una barra que no va a moverse. La reversa **no tiene copy por motivo**
—lo dice su propio código: «La reversa no cambia»— así que hace falta decidir qué se le enseña.

## Criterios de aceptación

- [ ] Un `.rejected` del claim de la reversa lleva el journal a un terminal, no lo deja en
      `reverseClaimLeader`.
- [ ] La pantalla dice algo verdadero en vez de una barra al 15 %.
- [ ] Los BGTasks dejan de estar suprimidos tras el rechazo.
- [ ] Test del mapeo motivo → terminal, con mutante: quitar la salida tiene que dar rojo.

## Qué dejó hecho el gemelo, medido el 2026-09-16

`reverse-upload-has-no-ceiling-and-no-exit` resolvió su salida. **El mecanismo no se traslada tal cual aquí**,
y el motivo es de fase:

- Allí la salida es post-montaje y con el backend congelado: necesita `.rearmMirrorOff` (y un relanzamiento) y
  `.reverseRollback`. Aquí no hay nada de eso: en `reverseClaimLeader` el espejo nunca se montó y el backend no
  se congeló. La salida de este ticket es la de `reverseOtherLeader`: volver al origen **sin efectos**.
- Lo que SÍ se puede reusar es la mitad visible: `MigrationState.reverseAbortReasonRaw` (el porqué journaleado,
  que sobrevive a la vuelta al origen) y la nota de la tarjeta de «Volver a iCloud»
  (`ReverseUploadWaitingCopyLogic.abortNote`). Un motivo nuevo para el rechazo iría en
  `ReverseUploadAbortReason`, con su copy en los 16 idiomas.

**Y la población deja de ser tan estrecha** (review adversarial del gemelo, 2026-09-16). Arriba se razona que una
cuenta de solo grupos no escribe `.cloud`, así que el camino casi no se recorre. La salida de `reverseUpload` lo abre:
en el 2.º dispositivo de una cuenta que ya volvió a iCloud, el claim fresco resetea `reverted_at`, la salida llama a
`reverse_abort`, y la persona queda en `.cloud` + fase estable + `not_complete` al reintentar. Ticket:
`reverse-exit-on-a-reverted-account-rejects-the-retry`.

## Relacionado

- `reverse-upload-has-no-ceiling-and-no-exit` — el gemelo dos fases más adelante: la misma ausencia de
  salida, pero por una espera en vez de por un rechazo, y ahí el backend además queda congelado.
- La decisión de `g15_02` y su §Paso 0: `tickets/qa/reverse-cutover-cerrado-para-cuentas-born-cloud.md`.

## Lo que se decidió (2026-09-16)

Jürgen contestó las cuatro preguntas de producto, las cuatro con la recomendada:

1. **El motivo pasajero también sale.** Si el servidor dice que la migración a la nube de esa cuenta aún tiene su lease
   (`migration_in_progress`), la app vuelve a la nube al momento y avisa «vuelve a intentarlo en un rato». Esperando, si
   Yala se cierra y se abre en ese rato el motor de la nube no arranca, y el lease puede durar 60 min o más.
2. **Dos notas**: la pasajera y la permanente, y la permanente da el correo de soporte.
3. **Alerta en el momento** si el rechazo viene del toque, y la nota fija en la tarjeta «Volver a iCloud» hasta el
   siguiente intento, como la de la espera.
4. **`other_leader` también avisa**: hasta hoy volvía a la nube en silencio.
5. **Los textos, en pasado** (tras la review): valen igual para la alerta y para la nota de días después, y el permanente
   ya no dice «Tus datos siguen en la nube», que era falso con la cuenta borrada desde otro dispositivo.

El árbol completo, con las ocho técnicas y su motivo, está en el Paso 0 del encargo
(`encargos/lanzados/2026-09-16-reverse-claim-rejection-has-no-way-out-in-the-client.md`) y viaja al PR.

### Lo que la medición cambió de este ticket

- **Los motivos son tres, y `not_migrated` ya no existe.** Leído en el cuerpo vivo de producción (md5 `14fc5e2c…`):
  `no_profile`, `not_complete` y `migration_in_progress`, y los tres salen del RPC antes de cualquier UPDATE. Por eso la
  salida va sin `reverse_abort`, como la de `other_leader`.
- **El daño era mayor que el de la tabla de arriba.** Con `reverseClaimLeader` journaleada el motor de la nube no
  arranca (`CloudSyncRuntime.canRunDomain`): tras cerrar y abrir Yala el teléfono dejaba de sincronizar, no solo difería
  los informes. En el mismo proceso el bucle que ya corría sigue: no re-mira la fase en cada ciclo.
- **Hay otro camino al `not_complete` permanente**, del backend: en una cuenta ya revertida, un claim fresco con éxito
  cuya respuesta se pierde. Anotado con su medición en `reverse-exit-on-a-reverted-account-rejects-the-retry`.

## Qué cambia para la persona

- **Si el servidor no deja empezar «Volver a iCloud», la app vuelve a la nube al momento** y sigue sincronizando. Ya no
  hay barra al 15 % ni un «Retomar» que no hace nada.
- **Lo dice en una alerta** si tiene la pantalla delante —al tocar, al tocar «Retomar» o si el rechazo llega mientras
  mira—, y la misma frase queda en la tarjeta «Volver a iCloud», con un triángulo, hasta el siguiente intento. Sobrevive a
  cerrar y abrir Yala.
- **Tres frases, según el motivo:**
  - «No pudimos empezar a volver a iCloud: tus datos todavía estaban terminando de pasar a la nube. Vuelve a intentarlo
    en un rato.»
  - «No pudimos empezar a volver a iCloud: tu cuenta no lo permitía. Ese intento no cambió nada. Escríbenos a
    admin@yala-app.pe y lo revisamos contigo.»
  - «No pudimos empezar a volver a iCloud: otro de tus dispositivos ya estaba volviendo. Cuando termine, podrás hacerlo
    en este.»
- **Si a este teléfono le quedaba por cerrar su paso a la nube**, un intento que el servidor no concede no se lo lleva: lo
  termina de cerrar al volver. Antes, en ese caso, la cuenta se quedaba marcada en el servidor como «migrando» y otro
  dispositivo que entrara esperaba sin fin.
- **Un teléfono que ya estaba clavado al 15 %** con un build anterior sale solo al abrir Yala o al volver a ella, y deja
  la nota. Sin alerta: no la pidió un toque.
- **La red y la sesión caducada no cambian**: siguen reintentando. La sesión caducada tiene su propio ticket.

## Qué se tocó

- `MigrationStateMachine`: evento `reverseClaimRejected(returnTo:)`, de `reverseClaimLeader` a la fase origen sin efectos.
- `ICloudCutoverGateLogic.swift`: `ReverseUploadAbortReason` pasa a `ReverseAbortReason` (el `rawValue` viaja y no
  cambia; el nombre no), con `claimRetryLater`, `claimRefused`, `otherDeviceReverting` y `forClaimRejection(serverReason:)`.
- `MigrationRunner`: `journalReverseClaimExit` para las dos salidas del claim (el porqué en `reverseAbortReasonRaw`, el
  origen limpio) y `lastReverseClaimExit`, la secuencia en memoria que decide la alerta. Guarda los pendientes del origen
  al empezar la vuelta y los repone en toda vuelta al origen antes de conceder la reserva (`ReverseOriginPendingEffects`).
- `MigrationState` (schema v5): `reverseOriginPendingEffectsData`.
- `CloudMigrationController`: `announceReverseClaimExit`, la alerta de una salida nueva, en `startReverse` y en `resume`.
- `L10n.Storage.ReverseAbort.note(for:)`: la única traducción del motivo, que usan la nota, la tarjeta de relanzar y la
  alerta. Sale de `StorageSettingsView`. Tres claves nuevas en los 16 idiomas.
- `MetricsService`: canario `cloudReverseClaimRejected`, con el motivo del servidor acotado a forma de código.
  `CloudSyncBreadcrumb.reverseClaimRejected`.
- Regla nueva en `.claude/rules/swiftdata-cloudkit.md`; `coverage-index` en las cinco áreas que toca.

## Residuales, con ticket

- `reverse-exit-on-a-reverted-account-rejects-the-retry` — el `not_complete` permanente de un 2.º dispositivo. Es del
  backend, y ahora tiene los dos caminos medidos.
- `reverse-before-mount-stays-stuck-with-an-expired-session` — nuevo: con la sesión caducada, las fases anteriores al
  montaje siguen paradas al 15/30/50/62 % sin decir que hay que volver a entrar.
- `reverse-tap-is-lost-while-a-resume-is-running` — nuevo, preexistente: el toque no hace nada si la app está retomando
  algo por su cuenta en ese momento.
- `reverse-claim-exit-with-a-restored-failing-effect-keeps-the-engine-off` — nuevo, aceptado: un teléfono con la migración
  a medias que falla siempre puede quedarse sin sincronizar hasta reabrir Yala tras un rechazo.

## QA en iPhone

**Por qué en iPhone:** hace falta una cuenta en la nube de verdad, y el simulador no la crea sin el secreto de attest
(`.claude/rules/gateway-attest.md`). **Y hace falta que el servidor rechace**: eso se prepara en staging con SQL, y cada
montaje se deshace al terminar.

**Montaje común:**

1. Un iPhone de pruebas con un build que incluya este cambio (`Yala Dev` desde Xcode, contra staging), con una cuenta en
   la nube y algunos movimientos.
2. El id de esa cuenta: en el SQL Editor de Supabase (proyecto de staging),
   `select id from auth.users where email = '<correo de la cuenta>';`. Apunta también lo que hay ahora:
   `select kind, reverted_at, migration_in_progress, reverse_in_progress, leader_device_id from public.profiles where id = '<id>';`

**Caso A · el permanente (`not_complete`).** Montaje, en una sola ejecución (el trigger de `kind` solo se abre dentro
de la misma transacción):

```sql
begin;
select set_config('yala.kind_write', txid_current()::text, true);
update public.profiles set kind = 'groups_only', reverted_at = null where id = '<id>';
commit;
```

1. **Ajustes → «Dónde viven tus datos» → «Volver a iCloud»** y pasa las dos confirmaciones. La barra aparece un instante
   y sale una alerta: «No pudimos empezar a volver a iCloud: tu cuenta no lo permitía. Ese intento no cambió nada.
   Escríbenos a admin@yala-app.pe…». Captura.
2. Toca OK. La pantalla vuelve a «Tu cuenta en la nube», y la tarjeta «Volver a iCloud» lleva la misma frase con un
   triángulo naranja. Captura.
3. **La nube sigue viva:** anota un gasto y comprueba que sube (panel DEBUG «Modo Nube · Auth»: el outbox baja a 0).
4. **Cierra Yala del todo y ábrela.** La nota sigue en la tarjeta y no hay barra de progreso.
5. **Vuelve a tocar «Volver a iCloud».** Sale la alerta otra vez.

**Caso B · el pasajero (`migration_in_progress`).** Deshaz el A
(`begin; select set_config('yala.kind_write', txid_current()::text, true); update public.profiles set kind = 'complete' where id = '<id>'; commit;`)
y monta:
`update public.profiles set migration_in_progress = true, migration_updated_at = now() where id = '<id>';`

6. Toca «Volver a iCloud». Alerta: «…tus datos todavía estaban terminando de pasar a la nube. Vuelve a intentarlo en
   un rato.» Captura. Deshaz: `update public.profiles set migration_in_progress = false where id = '<id>';`

**Caso C · otro dispositivo (`other_leader`).** Monta:
`update public.profiles set reverse_in_progress = true, leader_device_id = 'qa-otro-dispositivo', migration_updated_at = now() where id = '<id>';`

7. Toca «Volver a iCloud». Alerta: «…otro de tus dispositivos ya estaba volviendo. Cuando termine, podrás hacerlo en
   este.» Captura. Deshaz: `update public.profiles set reverse_in_progress = false, leader_device_id = '<el que apuntaste>' where id = '<id>';`

**Sin rechazo (el camino de siempre no cambia).**

8. Con todo deshecho, toca «Volver a iCloud». La barra pasa del 15 % y la nota de la tarjeta desaparece. Para no
   completar la vuelta, cancélala en la espera con «Cancelar y seguir en la nube».

### Criterios de aceptación de QA

- [ ] Con cada rechazo, la app vuelve a la nube y lo dice con su frase, en la alerta y en la tarjeta.
- [ ] Tras el rechazo, lo que se anota sube a la nube.
- [ ] La nota sobrevive a cerrar y abrir Yala, y desaparece al empezar otra vuelta.
- [ ] Sin rechazo, la vuelta avanza como antes.
