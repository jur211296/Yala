---
id: migration-activation-drops-pending-effects-it-never-restores
status: qa
priority: medium
area: "modo-nube, migración"
created: 2026-09-16
updated: 2026-09-27
qa-status: needs-testing
source: "review adversarial de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (lente de máquina y runner, hallazgo 3), 2026-09-16"
---

# Tocar «Activar la nube» tira los pendientes de la fase de origen, y cancelar no los devuelve

## El problema, en lenguaje de usuario

Vuelvo a iCloud sin conexión: la app termina en iCloud, pero la llamada que le dice al servidor que la vuelta acabó se
queda pendiente. Antes de que se reintente, toco «Activar la nube» sin red y veo «No pudimos comprobar tu cuenta. No
cambiamos nada». Sí cambió algo: esa llamada ya no se reintenta nunca, y la cuenta se queda en la nube a medio cerrar.

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- El cierre de la vuelta a iCloud journalea `icloudActive` con `[.deleteCloudKitMarker, .clearCloudBeacon,
  .persistICloudMode, .completeReverseServer]` (`MigrationStateMachine`, `(.reverseUpload, .reverseUploadCompleted)`).
  Sin red, `.completeReverseServer` queda pendiente; es lo único que llama a `reverse_complete`
  (`MigrationWorkExecutor`), que escribe `reverted_at` y `kind = 'groups_only'`.
- `(.icloudActive, .userActivated)` y `(.notStarted, .userActivated)` pasan a `consent` sin efectos, y
  `MigrationRunner.handle` **reemplaza** los pendientes al journalear (`state.setPendingEffects(nextPending)`). Solo la
  vuelta a iCloud guarda y repone los del origen (`ReverseOriginPendingEffects`); la ida no.
- Las salidas de la ida vuelven a `notStarted` sin efectos: `consentDeclined`, `signInFailed` y, desde el ticket de
  origen, `claimRefusedExistingAccount`.

**No es una regresión de ese ticket**: la pérdida ya ocurría con «Cancelar» en el consentimiento o con un inicio de
sesión fallido. La comprobación nueva añade otra salida por la que pasa, y un aviso que dice «No cambiamos nada».

## Qué se espera

Aplicar a la ida el molde de la vuelta: guardar los pendientes del origen al tocar y reponerlos en toda salida que
vuelva antes del claim (`consentDeclined`, `signInFailed`, `claimRefusedExistingAccount`). Es la lección de
`.claude/agent-memory/frank/feedback_mi_arreglo_deja_el_mecanismo_sin_productor.md`: una salida que deshace un gesto
devuelve lo que la entrada tiró.

## Criterios de aceptación

- [x] Con `.completeReverseServer` pendiente en `icloudActive`, tocar «Activar la nube» y salir antes del claim deja el
      pendiente en el journal, y el siguiente `resume` lo ejecuta.
- [x] Un claim que sí empieza la migración no repone nada (test con el executor falso).

## Hecho (2026-09-27)

**Qué cambia para quien usa la app.** Si tocas «Activar la nube» y sales antes de que la nube conteste —cancelas, falla el
inicio de sesión, no se pudo comprobar tu cuenta, la cuenta ya tenía datos o cancelas al 22 %—, lo que el teléfono tenía
pendiente vuelve a estar pendiente y se termina en cuanto haya red. El caso que mordía: el aviso al servidor de que tu vuelta
a iCloud terminó ya no se pierde, y la cuenta ya no se queda en la nube a medio cerrar.

- **Molde de la vuelta.** `ForwardOriginPendingEffects.step` decide: guarda el toque que entra en la ventana previa al claim
  (`dryRun`/`consent`/`authenticating`/`claimingMigration`), repone en toda vuelta a `notStarted` sin claim contestado
  (también un kill, por el `resume`), y descarta con el claim contestado o a `failedRollback`. El self-hold del claim no
  toca nada.
- **Sin schema nuevo.** Reusa `reverseOriginPendingEffectsData`: las dos ventanas son excluyentes por fase.
- **El adopt pendiente no se guarda** (hallazgo medio de la review): la activación nueva lo sustituye, y guardado, «Cancelar»
  ejecutaba el adopt recién cancelado.
- **El aviso del rechazo se anota dentro del paso**: `handle` drena lo repuesto en el acto, y si lanza sin red, «Migrar a la
  nube» volvía al inicio sin su aviso.

**Verificado.** `ForwardOriginPendingEffectsTests` (tabla pura) y 13 casos en `MigrationRunnerTests` («Activar la nube»):
las cinco salidas con el pendiente que lanza sin red y el `resume` que lo ejecuta al volver la red, kills en `dryRun`/`consent`/
`authenticating`, el claim `created`, el seguidor y el adopt sin reponer, el techo a `failedRollback`, y controles. 11/11
mutantes muertos. Review adversarial de tres lentes: un medio (el adopt, arreglado) y bajos.

**Fuera, con ticket.** `migration-activation-ceiling-drops-origin-pending-effects` (el techo del claim descarta) y
`pending-reverse-complete-runs-with-whatever-session-is-live` (el efecto no va atado a una cuenta). Aceptado sin ticket: el
aviso del rechazo se anota antes del `save` del paso, como en la vuelta; con un `save` que falla, sale un aviso de una salida
que no llegó a disco.

**Por qué `qa`.** Una vuelta a iCloud que termina sin red no se monta en el simulador. Guion: bloque E del
`qa/guion-tanda.md`, paso E2 (oportunista).
