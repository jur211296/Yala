MODO AUTÓNOMO (override Jürgen 2026-09-22, vigente): la regla del repo «espera aprobación si >3 archivos» / «¿Sigo?» tras el plan queda SUSPENDIDA. Implementa de punta a punta — plan → código → gate → PR → merge a 2.1 → /cerrar-total — sin preguntar si continúas. AskUserQuestion de producto/acceso solo 06:00–21:00 Lima y solo si es decisión real de producto o acceso; estamos en NOCTURNO (03:10 Lima): NO uses AskUserQuestion; elige la opción robusta / buena práctica y sigue. Si algo es demasiado consecuente para asumir, aparca el ticket y cierra limpio — no inventes producto.

## Contexto
Ticket medium Cola A (riesgo real: pérdida silenciosa de datos de grupo). Tras «Empezar de cero» en la puerta privada, `DataWipeService.wipeLocalGroupsDomain` borra `GroupSyncOutbox` y purga `GroupsOutboxMirror` sin avisar. En el camino nuevo el humano puede ser el mismo: esos gastos pendientes de subir son suyos y se pierden. El copy enumera gastos/cuentas/presupuestos/categorías/grupos y no nombra el outbox. También se van sin decirlo: `groupPrefs_*`, overrides del bridge por grupo, desbloqueo beta de Grupos.

Cola A sigue armada solo para mediums cloud/sync con riesgo real (pérdida, overwrite/duplicación silenciosa, wipe incorrecto, usuario sin salida, copy de seguridad engañoso). Este cierra una pérdida silenciosa en wipe/fresh-start.

## Qué se pide
Arreglar el wipe de «Empezar de cero» / fresh-start de grupos para que no se lleve en silencio las escrituras de grupo aún no subidas.

Decisión de noche (robusta, sin AskUserQuestion): NO te limites a avisar. Haz lo que ya hace el cierre de sesión en la misma situación: **el borrado espera a que el outbox de grupos se vacíe** (drenaje / quiescencia), usando lo que ya existe (`CloudSessionSignOut.liveGroupsPendingCount` y el camino de sign-out que espera al outbox). Si el drenaje no puede completarse (sin red, techo, fallo), falla cerrado con copy claro y salida — no borres el outbox a escondidas. Preferible robusto sobre lo más barato (solo actualizar el aviso).

Cubre también, con el mismo rigor o con copy explícito si aplica: `groupPrefs_*`, overrides del bridge por grupo, desbloqueo beta — no dejes pérdidas hermanas silenciosas si el arreglo las toca.

Tests: unit del contador/drenaje/guard; mutantes acotados al target de tests. Device-QA puede quedar apuntado en el cierre (avión → gasto → wipe) sin bloquear el merge si el canario de unit cierra el hueco.

## Qué NO
- No abras el ticket diferido `sign-out-exits-do-not-verify-the-cloud-session-closed` (necesita decisión de Jürgen; sin prisa).
- No rediseñes el flujo entero de session-exits / paso 9.
- No pidas «¿Sigo?» ni esperes aprobación por >3 archivos.
- No AskUserQuestion de noche.
- No toques credenciales, secrets, ni producción.

## Cómo se sabe
- Con gastos de grupo pendientes en outbox, «Empezar de cero» / wipe de grupos NO los borra en silencio: o drenan y suben, o el gesto se para con aviso y salida.
- El copy no promete un wipe limpio mientras haya pendientes propios.
- Unit/canario verde en YalaTests; gate/PR/merge a 2.1; /cerrar-total forma 4 limpia.
- Residual tmux se puede matar tras cierre (Frank lo hará).

## Paso 0 (auto-contestado, nocturno)

- **Dónde se entrega:** worktree → rama `encargo/…` + PR a `2.1`, merge propio con CI verde.
- **Qué borrados cubre:** los tres escritores de `wipeLocalGroupsDomain` — el alert «Borrar todo y continuar»
  (`ShellDataAlertsModifier`), `performDeviceCorpusWipe` y `performICloudCorpusWipe(.handover)` (puerta privada,
  aviso del espejo tardío y su reanudación ciega al arrancar).
- **Mecanismo:** antes de tocar NADA, el borrado sube el outbox de grupos con el mismo push-all y el mismo presupuesto
  de reintentos que el desasociar (`CloudSessionSignOut`). Sin la fase del coordinador: el gesto no es un cierre de
  sesión y `.working`/`.blocked` los leen seis pantallas.
- **Si no drena:** no se borra nada; la pantalla dice cuántos cambios de grupos faltan y por qué (copy por motivo de
  `SignOutBlockedCopy`), con «Reintentar» y «Dejarlo por ahora».
- **SIN salida «perderlos»** (asumido): es la decisión de Jürgen del 2026-09-15 para el otro gesto que purga el dominio
  sin cerrar sesión, el desasociar (`lossExit: nil`). Quien no puede subir nunca (teléfono sin App Attest) tiene la
  salida del cierre de sesión, que sí la ofrece.
- **Cinturón en el escritor:** `wipeLocalGroupsDomain` lanza si quedan filas VIVAS en el outbox (las dead-letter no
  cuentan), y los callers lo comprueban antes de `wipeAllUserData` para no dejar medio borrado.
- **El alert del shell usa UN intento** (sin los 45 s): tras el alert no hay pantalla montada que enseñe un progreso.
- **Hermanas (`groupPrefs_*`, overrides del bridge, desbloqueo beta):** no se tocan. Son ajustes del dominio que se va
  entero, el copy dice «Borrar todo», y el desbloqueo se recupera al volver a adoptar Grupos. Va al PR como medido.
