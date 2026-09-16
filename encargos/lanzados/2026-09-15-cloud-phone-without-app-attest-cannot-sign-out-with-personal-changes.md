# Sin App Attest en la nube: exportar y salir perdiendo lo personal, con confirmación

## Contexto
Ticket: `tickets/backlog/cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes.md` (medium).
Hermano de `groups-phone-that-never-attests-is-told-to-retry-forever` (PR #173). En grupos ya hay veredicto terminal + salida con pérdida confirmada. En la nube, si hay cambios personales sin subir y el teléfono no tiene Attest, el cierre sigue bloqueado.

## Decisión Jürgen (2026-09-15) — YA TOMADA, no repreguntar
**Opción 1:** ofrecer exportar los datos y, después, una salida con pérdida confirmada también para lo personal (texto honesto + confirmación explícita).

## Que se pide
Implementar esa decisión. Gate, commit, board (`tickets/` + `docs/TICKETS.md`), PR, merge a 2.1, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real no cubierta arriba.

## Día / AskUserQuestion (6:00–21:00 Lima)
Sesión DIURNA. Si aparece decisión de producto/acceso nueva, usa AskUserQuestion. No inventes.

## Que NO hay que tocar
marketing/. El aviso fijo de la pestaña Grupos es ticket hermano (`groups-tab-does-not-say-this-phone-cannot-sync-groups`, ya decidido opción 1) — no mezclar salvo colateral mínimo de copy compartido.

## Como se sabe que esta bien
Sin Attest + cambios personales pendientes: se puede exportar y luego salir con confirmación de pérdida; copy honesto; tests; ticket cerrado; PR mergeado; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
(1) decisión de producto/acceso; (2) PR/preview listo; (3) /cerrar-total con resumen usuario; (4) idle sin paso claro — una vez.
NO por test rojo a reclasificar, build a reintentar, CI advisory.

## Paso 0 — decisiones

> Las tres de producto las contestó Jürgen en la sesión (AskUserQuestion, 2026-09-15, 16:10 Lima): dos con la
> recomendada y la exportación con otra. Las técnicas son de Frank, medidas en este árbol, y se discuten en el PR.

**Hechos medidos antes de decidir.**

- **Solo Ajustes cierra una sesión en la nube.** La hoja del cambio de Apple ID corre C y D
  (`AppleIDCloseNoticeLogic.closeRequest`) y la puerta de Grupos del Welcome devuelve `.unavailable` para
  `.cloudSecureSignOut`.
- **El motor personal nunca manda una subida sin attest.** `CloudSyncRuntime.performCycle` corta en `resolveAttest` antes
  de tocar `/sync/*`, así que el 401 que alimenta la racha de Grupos no llega por aquí. Lo que el motor ve es el error de
  `AppAttestClient`: `.network` (URLSession), `.server(tipo)` (el gateway respondió: `yala_attest_invalid`,
  `yala_bad_request`, un 5xx, `decode`…), `.unknownKey`, `.unavailable` (sin soporte y sin bypass) o un `DCError` de
  DeviceCheck, que cae en el `catch` genérico.
- En la nube Grupos cicla dentro del motor personal, después de esa puerta: un teléfono sin attest acumula cambios en los
  dos outbox, y la racha de Grupos solo la alimentan los gestos (guardar en un grupo, el cierre, las RPC).
- `pushAllPendingForSignOut` declara `attestUnavailable: false`, y el paso 1 del cierre escribe `.permanent` a pelo.
- Cada edición encola una fila nueva de `SyncOutbox` (dedup por `syncID` + `hlc` + `op`, con su `clientMutationID`):
  comparar por filas detecta un cambio nuevo.
- El CSV de Ajustes lleva gastos e ingresos (`TransactionsExportService`), no cuentas, categorías ni presupuestos. Sin Pro,
  el asistente llega como mucho al último mes (`DetailPeriod.isProExportPeriod`).

**Producto (Jürgen).**

**P1 · Flujo** → un aviso con tres botones: «Exportar mis movimientos», «Cerrar sesión y perderlos» y «Ahora no». Al
cerrar la exportación vuelve el aviso. Mismo umbral que Grupos: 24 h y 3 veces.

**P2 · Qué exporta** → exportación directa de todos los movimientos, sin asistente y para todos: el botón genera el CSV y
abre compartir. Frank recomendaba el asistente con los periodos abiertos.

**P3 · Con cambios personales y de grupos** → dos avisos seguidos, cada uno con su cifra. La salida de grupos del #173 no
se toca.

**Técnicas (Frank).**

**D1 · Qué cuenta como fallo del attest en lo personal** → la puerta del motor falla con un error que habla del attest:
`.unavailable`, `.unknownKey`, `.server("yala_attest_invalid")` o un `DCError`. No cuentan `.network`, los demás `.server`
ni otros errores.
Por qué: sin red o con el servidor caído el veredicto no se acerca, que es lo que hace seguro al 401 de Grupos.
Alternativa descartada: contar cualquier fallo, con lo que un teléfono sin red durante un día vería la pérdida ofrecida.

**D2 · Qué reinicia la racha** → un token conseguido en esa puerta.
Por qué: el gateway solo lo acuña tras verificar el attest. Alternativa descartada: solo el 200 de Grupos, que en la nube
no llega a quien no usa grupos.

**D3 · Dónde vive** → en la racha del teléfono que ya usa Grupos (`GroupsAttestStreakStore`), sin cambiar su clave ni su
umbral.
Por qué: la racha describe al teléfono. Con dos, un cierre en la nube podía aceptar perder lo personal y quedarse después
en «inténtalo en un rato» con los cambios de grupos, y P3 exige que llegue el segundo aviso. Alternativa descartada: una
racha propia del canal personal.

**D4 · El veredicto exige un fallo de AHORA** → `CloudSyncRuntime.stoppedByUnavailableAttest(for:)`: el ciclo que acaba de
correr paró en la puerta con un fallo que cuenta, su outcome es `.transient` o `.accountUnavailable` (la parada terminal de
`AttestSyncGate`), y la racha es terminal. Molde `GroupsSyncClient.stoppedByUnavailableAttest`.
Por qué: una racha vieja no puede disfrazar un corte de red de hoy.

**D5 · El motivo** → `BlockReason.personalAttestUnavailable`, al final del enum, slug `personal-attest-unavailable`.
`classify` devuelve `.attestUnavailable` también para `.accountUnavailable` con el testigo, y solo el paso 1 del cierre en
la nube lo traduce al motivo personal. El resto de motivos del paso 1 siguen en `.permanent`
(`cloud-signout-collapses-the-personal-push-all-reason-into-permanent`).
Por qué: su aviso y su salida son otros, y un `switch` sin `default` obliga a cada pantalla a pronunciarse. Alternativa
descartada: reusar `.attestUnavailable`, cuyo texto habla de grupos.

**D6 · La salida** → `CloudSessionSignOut.exitDiscardingUnsyncedPersonalChanges(context:)` retoma el cierre en la nube con
las FILAS de `SyncOutbox` que contó el aviso (por `clientMutationID`) como lo aceptado. El paso 1 intenta subir una vez y
sigue si lo que queda está entre lo aceptado; el recuento final, igual. Una fila nueva vuelve a avisar. Lo aceptado
sobrevive al aviso de grupos, y lo retiran «Ahora no» y un gesto nuevo. Nada se borra en sesión: el boot-wipe de siempre.
Por qué: es el molde de `exitDiscardingUnsyncedGroups`, que ya pasó una review, y la comparación por filas es la misma
función pura, con nombre neutro.

**D7 · La cifra** → filas vivas de `SyncOutbox`, la misma cuenta que ya bloquea el cierre; un recuento fallido sale sin
cifra.

**D8 · La exportación** → `TransactionsExportService.export` en CSV, con todo el tiempo, todas las columnas y sin filtros,
y la hoja de compartir del export (`ShareSheet`). Al cerrarla vuelve el aviso; un error enseña el aviso de error del export
y vuelve también. Exportar no toca el coordinador: el cierre sigue parado.

**D9 · Canarios** → `cloudSignOutAttestUnavailable` (se ofreció el aviso), `cloudSignOutAttestExported` (se generó el
archivo) y `cloudSignOutAttestDiscarded` (el cierre siguió sin subir), con sus rastros.

**D10 · Verificación** → unit (lógica pura, testigo del motor con su doble de sesión, racha aislada), source-scans del
cableado y mutantes; XCUITest de las áreas tocadas como regresión.

**D11 · Review adversarial** → sí, con tres lentes: coordinador y datos, canal y racha, pantallas y exportación.

**D12 · Lo durable** → `.claude/rules/gateway-attest.md` (la racha es del teléfono y la escriben los dos canales) y el
ticket.

## Review adversarial — tres lentes (2026-09-15)

Coordinador y datos, canal y racha, pantallas con la exportación y los textos. Ningún hallazgo contradice una decisión de
producto. Cada uno se comprobó contra el código antes de tocar nada, y cuando dos lentes discreparon se midió:

| Hallazgo | Lente | Qué se hizo |
|---|---|---|
| Al retomar un cierre con la pérdida aceptada, con el attest ya recuperado, un 5xx, un 403 o la sesión caducada se llevaban cambios que un reintento subiría. Pasaba en el paso 1, en el paso 2 y en `pushGroupsForSignOut` | coordinador (media) | `continuesAfterBlockedUpload`: lo aceptado solo cubre un bloqueo que siga siendo el attest, en los tres sitios |
| El error de la exportación salía en español y, sin movimientos, hablaba de «filtros» | pantallas (media) | dos textos propios en los 16 idiomas; el mismo defecto del asistente, a ticket |
| Cinco mutantes de la pantalla sobrevivían: sin turno de espera, error mudo, reconocer el bloqueo por el alias, canario apagado y botones cruzados en un idioma | pantallas (media) | cuerpo entero de la exportación fijado, y paridad de los botones en los 16 idiomas |
| «Cerrar sesión y perderlos» se leía como perder los movimientos recién exportados | pantallas (baja) | el mensaje acaba nombrando «esos cambios», en los 16 idiomas |
| La exportación bloquea el hilo principal sin nada en pantalla | pantallas (baja) | indicador mientras dura |
| Exportar rellenaba el espejo de etiquetas, eso creaba filas por subir y el aviso volvía con otra cifra | pantallas (baja) | `scheduleTagBackfill: false` en esa exportación. La lente del coordinador decía que ese campo no emite: medido en `EntityEmissionMap`, sí emite |
| Una aserción del testigo por ciclo no podía fallar | canal (baja) | un ciclo sin red entre el fallo y el acierto, con la racha terminal |
| El gateway responde `yala_attest_invalid` también cuando falla su escritura en D1, y eso cuenta | canal (baja) | documentado, y ticket `attest-gateway-reports-a-storage-failure-as-an-invalid-attestation` |
| La documentación de la racha seguía diciendo que solo cuenta el 401 de Grupos | canal (baja) | cabecera de `GroupsAttestVerdictLogic`, regla y matiz en `attest-session-token-rejected-by-the-gateway-stays-cached` |
| Un caso de `GroupsSyncHardeningTests` corre el runtime sin aislar la racha | canal (baja) | al inventario de `unit-tests-clear-the-attest-streak-of-a-device-qa-in-progress` |
| `DCError.serverUnavailable` cuenta aunque el fallo sea de Apple | coordinador (nota) | aceptado y documentado: lo acota el umbral de 24 h |

**Tickets nuevos de esta sesión:** `unit-tests-clear-the-attest-streak-of-a-device-qa-in-progress`,
`cloud-signout-drops-unsynced-preference-changes-without-counting-them`,
`cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`,
`attest-gateway-reports-a-storage-failure-as-an-invalid-attestation` y `export-errors-are-hardcoded-in-spanish`.
