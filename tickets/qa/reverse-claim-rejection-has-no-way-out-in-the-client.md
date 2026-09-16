---
id: reverse-claim-rejection-has-no-way-out-in-the-client
status: backlog
priority: high
area: "modo-nube, migración"
created: 2026-09-10
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
