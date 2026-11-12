---
esfuerzo: high
release: no
---
# Quién creó o editó un gasto de grupo viaja al otro teléfono y los avisos lo respetan

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `grupos-autor-del-gasto` · Sesión cola **S35q** · al cerrar → **S35r** (`fluidez-extra`).

## Contexto
Jürgen aprobó este plan el 31-oct a las 22:03 (Lima): «Sí, aplícalo así». Su regla del 2026-10-30 es que todo entra en 2.2 antes del barrido QA, nada a backlog.

Zona: el manifiesto del canal de Grupos y los avisos locales de gastos.

Cards:
- `tablero ver tablero-grupos-quien-creo-o-edito-un-gasto-no-vi-xi74` — Grupos: quién creó o editó un gasto no viaja por el canal y el iPad del autor puede avisarle de lo suyo
  - Problema: Hallazgo del PR #705 (card sztn). lastEditedByMemberID no está en group_capability_manifest.json, así que en otro dispositivo el aviso local atribuye el gasto al pagador. Si Jürgen apunta en su iPhone un gasto que pagó Ana y en el que él tiene parte, su iPad (misma cuenta) puede enseñar «🧾 Ana agregó 'X' — te toca Y». Arreglo: columna nueva del canal (since v3+, GroupsSyncCapability.columnSince) y que GroupNotificationRecipientLogic la use.
  - Hecha cuando: El aviso local nunca sale en un dispositivo del autor de la acción; test que lo fija.

## Qué se pide
1. Lee cada card y su ticket, si tiene. Busca la causa raíz antes de tocar código.
2. Cumple el «hecha cuando» de cada card, con tests (unitarios, source-scan o XCUITest según el caso) y, si es visual, vídeo o capturas antes y después en `capturas/` y en el digest.
3. Pasa las cards a «in qa» de Jürgen al abrir el PR (con `--agente` de la sesión).

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Nada fuera de las cards de esta sesión.
- marketing/ ni Web/ (salvo el README de marca, si está en las cards).
- No lances otras sesiones Yala.
- Ningún otro PR ni rama.

## Cómo se sabe que está bien
- Cada card cumple su «hecha cuando».
- Los tests están verdes.
- Se hizo una review adversarial del diff.
- El PR va a 2.2 con auto-merge.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.

Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.

Al cerrar, Frank publica el digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

## También: al editar un gasto que pagaste, cambiar la cuenta no mueve tu registro (card tablero-grupos-al-editar-un-gasto-que-pagaste-ca-8933)
En Nuevo gasto de Grupos, al EDITAR un gasto que pagaste tú, se puede elegir otra cuenta de la misma moneda. Pero `GroupTransactionBridge` (rama Caso A con registro existente, ~línea 430: «NUNCA pisar account») deja la cuenta vieja: la pastilla enseña la cuenta B y el dinero sigue saliendo de la A. Si cambia la moneda, borra el registro y deja un borrador en la Bandeja.
Se sabe que está hecho cuando editar la cuenta deja el registro en la cuenta elegida, o la pantalla no la ofrece, con test.

## También: francés y alemán mezclan tú y usted en Nuevo gasto de Grupos (card tablero-frances-y-aleman-nuevo-gasto-de-grupos-m-truj)
En fr y de, la mayoría de las cadenas `groups.*` tutean, pero las opciones rápidas de un grupo de dos hablan de usted («Vous avez payé», «%1$@ vous doit %2$@», «Sie haben bezahlt»).
Se sabe que está hecho cuando las cadenas `groups.*` de fr y de usan un solo tratamiento (tú), con un test de paridad si cabe.

## También: el widget de Grupos no se actualiza con un push silencioso en segundo plano (card tablero-widget-de-grupos-un-gasto-que-llega-por-dvg6, prioridad alta)
`WidgetGroupsRefresh` rehace la foto 400 ms después de subir `dataVersion`. Pero con la app en segundo plano, `YalaAppDelegate` llama al `completionHandler` del push apenas vuelve `syncNowFromPush` (≈ YalaAppDelegate.swift:139). iOS suspende la app y la comprobación no llega a correr. Además, un pull cortado a medias (`GroupsSyncClient`: saved == false, error transitorio o tope de páginas) no sube `dataVersion`, y `ensureCurrentUserMemberExists` (GroupService ~1177/1198) guarda sin subirlo.
Qué hacer: forzar `WidgetGroupsRefresh.check()` sin espera antes del `completionHandler`, y decidir con criterio si esos dos caminos suben `dataVersion`. Comparte la sincronización y los avisos de grupo con el resto de esta sesión.
Se espera que sea solo del cliente. Si hace falta tocar el servidor (Worker o Supabase), primero se prueba en staging y solo después se pasa a producción.
Se sabe que está hecho cuando un gasto de grupo recibido por push silencioso, con la app en segundo plano, cambia el widget sin abrir la app (probado en iPhone con dos cuentas).

Termina con /cerrar-total.

## Añadido 2026-11-01 15:30 (cierre de saldo-inicial-rechazo-servidor, PR #732)
Dos cards más de Grupos en 2.2 entran en esta sesión:
- tablero-medir-si-en-un-grupo-migrado-la-app-ofre-hfhs: medir si en un grupo migrado la app ofrece editar el saldo inicial a quien el servidor no ve como admin; si pasa, que el botón no salga.
- tablero-los-repartos-de-un-saldo-inicial-nuevo-q-m76a: los repartos de un saldo inicial nuevo que el servidor rechaza quedan huérfanos en el servidor y en el teléfono; limpiarlos (servidor en staging antes de producción).
Lee el contexto de cada card con `tablero ver`.

## Paso 0 (resuelto por Frank, 2026-11-02, modo autónomo)

Ficheros previstos (nota, no pregunta): manifest de Grupos + `gateway/` (copia), `qa/cloud/g29_01_*.sql` + script remoto +
`supabase-groups-staging.ddl`, `GroupsSyncCapability`, `GroupEntityEmissionMap`, `GroupsSyncClient` (apply, pull parcial,
barrido de repartos huérfanos), `GroupTransactionBridge`, `OpeningBalancePermissionLogic` + sus dos llamadores,
`WidgetGroupsRefresh` + `YalaAppDelegate`, `GroupService`, fr/de `Localizable.*`, tests, `qa/coverage-index.json`, reglas.

1. **xi74 · autor del gasto.** Columna nueva del canal `split_expenses.last_edited_by_member_key` (texto en claro, como
   `paid_by_member_key`) con `since: 3`, y **también** `split_settlements.recorded_by_member_key`: es el mismo patrón
   (eco «X te pagó» en el iPad de quien registró la liquidación) y comparte la subida a v3; dos subidas de versión
   costarían el doble. Orden: DDL staging → Worker staging → probar → DDL prod → Worker prod (precedente g28_01 del
   2026-11-01). La app sube `clientManifestVersion` a 3; contra un Worker v2 declara 2 y lo filtrado se re-emite al subir.
   La columna del autor **viaja con cada edición** del formulario (se cuelga de los keypaths que el formulario escribe):
   si no, un gasto cuyo autor ya era yo antes de v3 no la volvería a emitir (reescribir el mismo valor no emite).
2. **8933 · cuenta al editar.** Se mueve el registro a la cuenta elegida (no se quita la opción): el formulario preselecciona
   la cuenta actual, así que solo cambia si la persona la cambia. Solo en edición LOCAL (`!isRemoteSync`) con cuenta de la
   misma moneda; con moneda nueva y cuenta de esa moneda, se rehace el registro en la cuenta elegida en vez de mandarlo
   a la Bandeja.
3. **truj · fr/de.** Tuteo en todo `groups.*` (es el registro mayoritario de la app), con test de registro.
4. **dvg6 · widget.** El push silencioso fuerza la comprobación pendiente antes del `completionHandler`. Un pull cortado
   con páginas ya guardadas sube `dataVersion` (lo guardado es real); `ensureCurrentUserMemberExists` lo sube cuando guarda.
   La prueba con dos cuentas en iPhone queda en el guion de QA de Jürgen.
5. **hfhs · admin en grupo migrado.** Se mide con test. Si divergen, en un grupo del backend la app decide como
   `is_group_admin`: dueño, o CUALQUIER fila con mi `user_id` activa y admin (no la fila canónica, que puede ser la heredada).
6. **m76a · repartos huérfanos.** Opción (a), solo cliente: tras descartar un saldo rechazado, cuando el re-pull de su
   grupo termina y el gasto no volvió (era nuevo), sus repartos locales se borran con el autor normal → suben como
   tombstones (el trigger no juzga repartos sin gasto y la RLS deja borrar al miembro activo). Grupo cerrado: solo local.
