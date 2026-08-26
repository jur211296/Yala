---
id: groups-approval-banner-stays
status: qa
priority: high
area: "groups, sync, backend, onboarding"
created: 2026-07-31
updated: 2026-08-26
source: YalaWiki/Bugs/qa_groups-aprobacion-no-retira-banner.md
---


> [!bug] Corrida real (2026-07-31, dos iPhones contra PRODUCCIÓN, canal de Grupos por backend): el invitado se une por enlace y ve el aviso de arriba «Esperando aprobación». El owner aprueba desde su teléfono — el tail muestra `POST /groups/rpc/approve_member - Ok` y acto seguido el cursor del pull del invitado avanza, así que los datos llegaron. Dentro del grupo ya no aparece como pendiente, pero **el aviso de arriba se queda puesto para siempre**. Hermano del ticket [[qa_groups-join-intent-reconciler]] (mismo subsistema, canal distinto).

# Validar en TestFlight: la aprobación del admin retira el aviso de «esperando aprobación»

## Qué veía el usuario

Se unió, esperó, lo aprobaron — y la app siguió diciéndole que esperase. El grupo funcionaba (podía ver y usar todo), pero el aviso de arriba no se iba **por mucho que esperase**: no era lentitud, era permanente. La única forma de quitárselo era cerrar y volver a abrir la app.

Y el mismo problema al revés: si el owner le hubiera **rechazado**, el aviso también habría seguido diciendo «esperando aprobación» en lugar de contarle que no lo dejaron entrar.

## Implementación

### 2026-07-31 — `479e8e81` (branch 2.0.5)

**Resumen:** el canal de Grupos por backend no tenía a NADIE mirando el estado del miembro después de bajar los datos, así que la aprobación llegaba al teléfono y no movía la pantalla. Se añade esa mirada, con la decisión de cuándo retirar el aviso como función pura y testeada.

**Archivos:**

- `Yala/App/Logic/GroupInviteOnboardingLogic.swift` — decisión pura nueva `shouldRepublishPhase`: solo se retira el aviso con un alta EN VUELO (zona trackeada + fase no terminal). Nunca desde `.idle` (crearía un aviso que nadie está mostrando), nunca desde `.active`/`.failed` (ya tienen salida propia).
- `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift` — `publishTrackedJoinPhaseIfNeeded` + `ownMemberStatus`: al terminar de aplicar una página del pull que trajo miembros de la zona del alta en curso, lee el estado del miembro PROPIO y lo publica al tracker.
- `YalaTests/GroupInviteOnboardingLogicTests.swift` — 4 tests puros (fases en vuelo / terminales / `.idle` y zona nula / otra zona).
- `YalaTests/CloudSync/GroupsSyncClientTests.swift` — 6 tests de cableado: aprobación propia retira el aviso, rechazo propio también, la aprobación de OTRO compañero NO lo mueve, otra zona no lo toca, un guardado fallido no publica nada, y sin alta en curso todo sigue igual.
- `.claude/rules/swiftdata-cloudkit.md` — regla durable (ver abajo).
- `qa/coverage-index.json` — áreas `groups-pending-approval-reconnect` y `groups-backend-g2-sync-channel`.

**Causa raíz — dos huecos, no uno:**

1. **El pull del canal backend no observaba nada.** El fetch del canal viejo (CloudKit) hace DOS cosas después de aplicar un lote, además de escribir: llama al reconciliador (`GroupJoinReconciler.reconcile(trigger: .remoteInsert)`) y mira el miembro para mover la fase del alta (`SplitSyncManager.processPendingRemoteChanges`, la rama `phase == .pendingApproval`). El canal nuevo heredó el apply, las notificaciones y el freeze — **y ninguna de las dos observaciones**. `GroupJoinReconciler.reconcile` no tiene un solo call-site en `GroupsSyncClient`.

2. **El intent ya estaba limpio cuando llegaba la aprobación**, así que el reconciliador no era la red que parecía: `reconcileBackendEntry` dispara `.correctAndClear` en cuanto el miembro existe localmente **aunque esté pendiente** ⇒ borra la entry ⇒ los cuatro triggers (accept / fetch / boot / foreground) salen por su `guard !entries.isEmpty`. Un intent que se limpia con el trabajo a medias deja de ser una red: el estado «pendiente» todavía tenía una transición por delante.

**Decisiones técnicas y su porqué:**

- **La publicación va POST-SAVE, no dentro del `saveWithAuthor`.** Dentro publicaría la fase de un miembro que el `rollback()` del `catch` revierte: se anunciaría una aprobación que no llegó al disco. Y va **lo antes posible** tras el guardado —junto a `markRemoteChangePending`, antes de notificaciones/freeze/bridge—: a partir de esa línea el miembro ya está en disco, y cualquier hueco es una ventana en la que el aviso sigue puesto sobre una aprobación ya aplicada. Pinneado por `apply_saveFails_doesNotPublishJoinPhase`.
- **Se publica el estado del miembro PROPIO leído del store, jamás el `status` del delta.** En el mismo pull baja la aprobación de un compañero, y el estado del wire no dice de quién es sin resolver identidad. Retirar el aviso con la aprobación de otro sería mentirle al invitado. Pinneado por `apply_member_otherUserApproved_keepsPendingApprovalPhase`.
- **La identidad se resuelve por `sub`** (`GroupJoinReconcileLogic.backendMemberMatchesCurrentUser`, la misma primitiva que el reconciliador), **nunca por `isCurrentUser`**: `GroupsSyncClient.applyMember` jamás setea ese flag, así que quien se UNE recibe su propio miembro por el pull sin él — filtrar por el flag habría dado `nil` para siempre justo en el caso que importa. Esta era la hipótesis del reporte y es real: es la razón de que el hook del canal viejo tampoco habría funcionado aquí (`GroupService.currentUserMember` filtra por `isCurrentUser`).
- **Si el estado no parsea, no se publica**, en vez de degradar a `.active` como hace `SplitMember.memberStatus`: un falso `.active` retiraría el aviso sin evidencia, y la dirección segura es dejarlo puesto.
- **Nada de temporizadores ni de ocultar el aviso «por si acaso»** — el repo ya prohíbe eso para el caso simétrico («¡Todo listo!» solo con miembro confirmado). Aquí se cumple lo mismo al revés: la fase pendiente se retira solo con evidencia real del miembro propio.
- **No se tocó `SplitSyncManager` ni el gateway.** El backend hizo su trabajo (`approve_member - Ok` y cursor avanzado), y el hook del canal viejo vive en uno de los ficheros que la Fase 3 borra enteros: cambiarlo sería churn sobre código condenado. La asimetría queda documentada en el docblock de la función pura.

**Regla durable añadida** (`.claude/rules/swiftdata-cloudkit.md`): duplicar un canal duplica sus ESCRITURAS; sus OBSERVACIONES se quedan atrás, y eso no lo caza ningún test de un canal solo. Al portar lógica de un canal al otro hay que listar lo que el viejo **observa** además de lo que escribe (fases de UI, reconciliadores, trackers `@Observable`): una escritura que falta la echa en falta el compilador o una fila que no aparece; una observación que falta no rompe nada — solo deja una pantalla mintiendo, con la suite entera en verde.

**Verificación:** builds `Yala` + `Yala Dev` (los 3 warnings de línea base, cero nuevos) · 156 unit en 8 suites verdes · `GroupInviteOnboardingUITests` 5/5 · `qa/validate-coverage.sh` OK, backlog 0 · **4 mutaciones a exit 65**: quitar la publicación, publicar el estado del delta, publicarlo dentro de la transacción, y quitar la comparación de zona.

**Lo que NO está verificado:** el e2e en device contra producción. El canal backend en producción no es ejercitable desde un test (staging corre en `observe` y con `ATTEST_ENV = development`), así que la corrida real con dos teléfonos es lo único que cierra este ticket — y por la regla del repo no la declara buena quien escribió el fix.

## Guion de QA (TestFlight, 2 devices)

1. Device A (owner) crea un grupo por el canal backend y genera un enlace de invitación.
2. Device B (invitado) abre el enlace y completa el alta. **Comprobar:** aparece el aviso de arriba «Esperando aprobación».
3. Device B se queda EN el tab de Grupos, sin relanzar la app y sin cambiar de pantalla.
4. Device A aprueba al invitado.
5. **Comprobar en B:** el aviso de arriba desaparece **solo**, en cuanto el pull baja el cambio. Si el onboarding estaba abierto, pasa a «¡Todo listo!».
6. Repetir 1–4 con **rechazo** en vez de aprobación. **Comprobar en B:** el aviso de arriba se retira y dentro del grupo aparece el aviso de rechazo con la opción de salir.
7. **Contra-prueba (que no se retire de más):** con B pendiente, que A apruebe a un TERCER miembro. El aviso de B debe seguir puesto.

migrated from YalaWiki Bugs/qa_groups-aprobacion-no-retira-banner.md @ 1934e8ad
