# «Activar la nube» ya no tira los pendientes de la fase de origen si cancelas antes del claim

## Contexto
Cola A autónoma (riesgo real · migración). Ticket `tickets/backlog/migration-activation-drops-pending-effects-it-never-restores.md` (medium). Residual medido de la review de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`.

Tras una vuelta a iCloud sin red, `.completeReverseServer` queda pendiente en `icloudActive` (es lo único que llama a `reverse_complete` y deja la cuenta en `groups_only` / `reverted_at`). Si la persona toca «Activar la nube» y sale antes del claim (`consentDeclined`, `signInFailed`, `claimRefusedExistingAccount`, o el aviso «No pudimos comprobar tu cuenta. No cambiamos nada»), `MigrationRunner.handle` reemplaza los pendientes y esa llamada ya no se reintenta: la cuenta se queda a medio cerrar en la nube. La vuelta ya guarda/repone con `ReverseOriginPendingEffects`; la ida no.

Rama base: `2.1` (lleva #274). Device-QA pendiente del cierre anterior (#274 D7) NO pausa este lanzamiento.

Horario Lima nocturno (21:00–6:00; ahora ~02:55): elige la opción robusta / recomendada sin AskUserQuestion. Solo aparca en ticket propio si la decisión es demasiado irreversible para asumirla.

## Que se pide
- Aplicar a la ida el molde de la vuelta: guardar los pendientes del origen al tocar «Activar la nube» / `.userActivated` y reponerlos en toda salida que vuelva antes del claim (`consentDeclined`, `signInFailed`, `claimRefusedExistingAccount`).
- Criterios del ticket: con `.completeReverseServer` pendiente en `icloudActive`, activar y salir antes del claim deja el pendiente en el journal y el siguiente `resume` lo ejecuta; un claim que sí empieza la migración no repone nada (test con executor falso).
- Tests del writer/runner + controles; hallazgo residual → ticket propio.
- Mover el ticket en `tickets/` y actualizar `docs/TICKETS.md`.
- Gate, mutantes del área, review adversarial de tres lentes, PR a `2.1`, merge cuando CI verde, board al día, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Implementa de punta a punta sin pedir «¿Sigo?» ni parar por la regla de «>3 files → wait for approval». La lista de ficheros es una nota, no un gate. Sigue hasta gate / commit / PR / merge a `2.1` / board / `/cerrar-total`. No dejes el PR abierto «para que Jürgen mire». No preguntes por continuar tras el plan.

Norma día/noche (vigente): entre 06:00–21:00 Lima, AskUserQuestion solo si hay decisión real de producto o acceso; de 21:00–6:00 Lima decide lo recomendado/robusto sin AskUserQuestion y solo aparca si es demasiado consequential para asumir.

## Que NO hay que tocar
- marketing/, store, tags, releases.
- clinicas-dentales-bi ni datos de salud.
- No relanzar encargos [EN CURSO].
- No reabrir el cierre privado de #274 ni el guard de Apple ID salvo compartir un predicado imprescindible.
- No ampliar a `adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check` (decisión de producto sin prisa) ni a Cola B / rediseño UI.
- No prod Supabase.

## Como se sabe que esta bien
- Criterios del ticket marcados; con pendiente `.completeReverseServer`, activar+salir antes del claim lo conserva; claim que arranca no repone.
- Gate verde del área; mutantes del cambio cazados o justificados.
- Review adversarial sin altos/medios abiertos sobre el diff (o con ticket).
- PR mergeado a `2.1`, ticket fuera de backlog, `docs/TICKETS.md` al día, `/cerrar-total` limpio.

## Paso 0 (auto-contestado, 03:10 Lima)

1. **Dónde se guarda lo del origen.** Se reusa el campo del journal de la vuelta (`reverseOriginPendingEffectsData`),
   sin subir el schema. Las dos ventanas son excluyentes por fase (ida: `dryRun`/`consent`/`authenticating`/
   `claimingMigration`; vuelta: `reverseConfirm`/`reverseClaimLeader`), y todos los cierres que ya lo limpian
   (`notStarted`, `failedRollback`, `icloudActive`, «Reintentar») cubren también la ida. Un campo nuevo pedía schema 17,
   su propia entrada en `isJournalUndecodable` y limpiarlo en cada cierre.
2. **Cuándo se guarda.** Solo el toque que ENTRA en la ventana desde fuera (`userActivated` desde una fase que no es de
   la ventana). `dryRun → consent` no pisa lo guardado con los `[]` de `dryRun`.
   Tras la review: el `.adoptBackendAccount` no se guarda; la activación nueva lo sustituye (como antes del ticket).
3. **Cuándo se repone.** Toda vuelta a `notStarted` sin un claim contestado: las tres del ticket, «Cancelar» al 22 % y la
   normalización del `resume` desde `dryRun`/`consent`/`authenticating`.
4. **Cuándo se descarta.** Al salir de la ventana con un claim contestado (`assigningIdentity`, `waitingForLeader`,
   `notStarted` + adopt): la migración empezó. Y a `failedRollback` (techo del claim), como la vuelta con su
   `fatalError`: reponer ahí podía ejecutar un `.adoptBackendAccount` guardado en un terminal de fallo. Ese residual
   (raro: el claim se alcanza con red, que es cuando el `reverse_complete` pendiente ya drena) va a ticket propio. El
   self-hold del claim no descarta nada.
5. **Riesgo de reponer tras un claim cancelado.** Medido en `qa/cloud/g15_01_account_kind.sql`: sobre una cuenta con la
   vuelta sin completar (`migration_in_progress` falso), `claim_account` personal contesta `existing_stable`, nunca
   `created`, así que no hay reserva nueva que `reverse_complete` pise.
6. **Fuera:** que la ida desde `icloudActive` vuelva a `notStarted` y no a `icloudActive` (comportamiento previo, no lo
   pide el ticket).
