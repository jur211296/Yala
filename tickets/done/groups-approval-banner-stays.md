---
id: groups-approval-banner-stays
status: done
priority: high
area: "groups, sync, backend, onboarding"
created: 2026-07-31
updated: 2026-08-28
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

## Cierre del owner 2026-08-28 (Jurgen, Lima) — PASS: la aprobación retira el aviso sin relanzar la app

**La corrida.** Dos teléfonos, grupo NUEVO, **TestFlight 2.1 build 12** (el binario que hay en campo; no
se subió nada nuevo para esto). **A** = owner, su cuenta personal. **B** = cuenta de prueba **ya
creada** — no fue instalación limpia.

1. **B** se une por el enlace y queda pendiente: ve **«1 solicitudes pendientes»** y el aviso de arriba
   **«Esperando la aprobación del administrador»**.
2. **A** aprueba.
3. **B se queda en la hoja de Grupos**: no fuerza el cierre de la app ni la reabre.
4. Al rato, **el aviso y el mensaje naranja se van solos**. El grupo queda normal, con **2 miembros
   activos**.

**Veredicto del owner: PASS.** Y es exactamente el paso que ningún test podía dar: el propio ticket
dejaba escrito en «Lo que NO está verificado» que el canal backend en producción no es ejercitable desde
un test y que **la corrida real con dos teléfonos es lo único que cierra este ticket** — más la regla del
repo de que no lo declara bueno quien escribió el fix. El punto 3 es el que convierte la corrida en
prueba: el bug original se quitaba de encima cerrando y reabriendo la app, así que un PASS con relanzado
no habría valido.

**Este cierre es de QA, no un fix nuevo.** Cero Swift hoy y ninguna subida a TestFlight.

### Que el binario probado lleva el fix — medido, no supuesto

- `479e8e81` (el fix del 2026-07-31) es **ancestro** de `f4cf3d2b` («Build 12 para TestFlight de 2.1»,
  2026-08-22), y `Yala.xcodeproj/project.pbxproj:543` marca `CURRENT_PROJECT_VERSION = 12` con
  `MARKETING_VERSION = 2.1` (`:561`) ⇒ el build 12 del device del owner **contiene** el código que este
  ticket valida.
- Las dos piezas siguen vivas en el árbol de hoy: `GroupInviteOnboardingLogic.shouldRepublishPhase`
  (`Yala/App/Logic/GroupInviteOnboardingLogic.swift:126`) y `GroupsSyncClient`
  `publishTrackedJoinPhaseIfNeeded` (`:2104`) + `ownMemberStatus` (`:2132`), con su call-site en `:1932`.

### Las dos cadenas que citó el owner, identificadas

El aviso de arriba es `groups.invite.waitingApproval.banner`. La cita del owner —«Esperando la
aprobación del administrador»— es **literalmente** el valor de es-ES
(`Yala/Resources/es-ES.lproj/Localizable.strings:102`); en es/es-419 el mismo key dice «Esperando
aprobación del admin» (`es-419.lproj/Localizable.strings:4050`), que es la forma corta con la que está
escrito el cuerpo de arriba. El contador es `groups.member.pendingCount`, y su cita literal («1
solicitudes pendientes») es el valor **plano** de es-ES/es-AR
(`Yala/Resources/es-ES.lproj/Localizable.strings:185`), mientras es/es-419 no tienen ese key en su
`.strings` y lo resuelven por `Localizable.stringsdict`
(`es-419.lproj/Localizable.stringsdict:405-420`, singular «%d solicitud pendiente» en `:416`). **INFERIDO** (no
medido en el device): la corrida fue en es-ES. Aquí no se cambia ninguna cadena y no se abre nada de
l10n por esto.

### Lo que este PASS NO cubre

- **El rechazo (paso 6 del guion): no se corrió hoy.** El ticket abría también con el caso simétrico: si
  el owner hubiera **rechazado**, el aviso habría seguido diciendo «esperando aprobación» en vez de contar
  que no lo dejaron entrar. Ese lado tiene test de cableado
  (`YalaTests/CloudSync/GroupsSyncClientTests.swift:1394`,
  `apply_member_ownRejection_retiresPendingApprovalPhase`), y un test no es un device.
- **La contra-prueba del paso 7: no se corrió.** Con B pendiente, que A apruebe a un **tercer** miembro y
  el aviso de B siga puesto. También tiene unit (`:1429`,
  `apply_member_otherUserApproved_keepsPendingApprovalPhase`), y también sin device.
- **La transición «¡Todo listo!» del cover abierto** (segunda mitad del paso 5) no está en el reporte: el
  owner estaba en la **hoja de Grupos**, y lo que se vio retirarse es el aviso de esa superficie.
- **B no era instalación limpia.** Cuenta ya creada. El escenario de install fresca —el del hermano
  `groups-join-intent-reconciler`— no es el que se corrió.
- **Esto no cierra al hermano.** `tickets/qa/groups-join-intent-reconciler.md` sigue en `qa/`: su REMAINS
  es que la solicitud le llegue **al owner** y que el invitado no reciba la notif espuria «se unió». El
  reporte de hoy dice que **A aprobó** y **no** dice por qué superficie supo de la solicitud ni si le
  llegó push. Aquí no se le anota nada.
- **Sin subida y sin flip.** No hubo TestFlight nuevo hoy. **A7/M5 sigue en HOLD**, igual que App Store y
  tag de release.

### Hallazgo nuevo de la MISMA corrida — va en ticket aparte, no aquí

Con B **todavía pendiente de aprobación**, el grupo «Probando» aparecía en su lista de Grupos y **al
tocarlo pudo entrar y ver el grupo**. Para el owner eso está mal. **No es este ticket** —aquí el defecto
era que el aviso no se retiraba DESPUÉS de aprobar, y ese aviso se retiró— así que se abre en
`tickets/backlog/groups-pending-member-can-open-group.md`, en este mismo PR. Sesión:
`docs/sessions/2026-08-28-device-qa-approval-banner.md`.
