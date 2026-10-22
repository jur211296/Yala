---
id: groups-settlement-reminder
status: done
priority: medium
area: groups
created: 2026-07-01
updated: 2026-09-23
source: YalaWiki/Backlog/groups-recordatorio-liquidacion.md
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - solo sale con una deuda de 21 dias sin moverse, no se fabrica hoy; SettlementReminderLogicTests
---


# Recordatorio amable de liquidación pendiente

## Problema

Cuando alguien queda debiendo dinero en un grupo, Yala nunca vuelve a
recordarlo — la deuda simplemente queda visible en el balance del grupo hasta
que alguien la liquida manualmente. No hay ningún nudge tipo "Juan te debe
S/50 hace 3 semanas". El usuario tiene que entrar al grupo y fijarse por su
cuenta, o depender de acordarse. Esto es distinto de las notificaciones
existentes (nuevo gasto, liquidación, miembro nuevo), que son reactivas a un
evento — este nudge es proactivo, basado en tiempo transcurrido **sin**
evento.

## Solución

Un chequeo periódico (boot-time o similar a como `BudgetAlertService` chequea
presupuestos) que, para cada deuda activa entre dos miembros de un grupo, si
lleva más de N semanas sin cambios (sin nuevo gasto que la modifique, sin
liquidación parcial, sin notificación previa reciente), dispare un
recordatorio amable a quien le deben (o a ambos, a decidir) con la voz de
marca de Yala (revisar BRAND-VOICE.md antes de escribir el copy final — nada
de tono cobrador/agresivo).

## ⚠️ Riesgo de schema CloudKit (leer antes de implementar)

**El problema de diseño central de este ticket, antes de tocar CloudKit:**
`GroupBalanceService.calculateBalances`/`calculateDebts`
(`Yala/Services/Groups/GroupBalanceService.swift:51-119`, `124-138`) son
**funciones puras sin estado** — reciben `[SplitExpense]`+`[SplitShare]`+
`[SplitMember]`+`[SplitSettlement]` como parámetros y recalculan el `[Debt]`
resultante desde cero en cada llamada. No existe ningún campo, en ningún
modelo, que registre "desde cuándo existe esta deuda específica" ni "cuándo
fue la última vez que se avisó de ella". Confirmado leyendo el archivo
completo: ni `Debt` ni `MemberBalance` (definidos en ese mismo archivo,
líneas 12-19 y la struct `Debt` referenciada) tienen un campo de timestamp —
son el resultado de un cálculo, no una entidad persistida.

Esto es distinto de `GroupNotificationService`
(`Yala/Services/Groups/GroupNotificationService.swift`), que es **puramente
reactivo**: solo dispara cuando `SplitSyncManager` le entrega un
`RemoteChangeSet` tras un cambio remoto (comentario de cabecera, líneas 5-7:
"Disparado por SplitSyncManager cuando llegan cambios remotos"). No tiene
ningún timer propio ni escaneo periódico — su rate-limit de 5 minutos
(`rateLimitInterval: TimeInterval = 300`, línea 47) sirve para no espamear
tras una ráfaga de cambios, no para decidir "cuánto tiempo lleva esto sin
resolverse". **Este feature necesita un mecanismo de disparo nuevo** (chequeo
por tiempo transcurrido, análogo a `BudgetAlertService.checkBudgetsAndNotify`,
`Yala/Services/BudgetAlertService.swift:30-81`, que se invoca periódicamente
—verificar dónde se llama hoy, probablemente boot-time o background refresh—
y no reactivo a un evento).

**Por lo tanto se necesita persistir estado nuevo, y la pregunta de diseño
es: ¿dónde vive?** Tres opciones, con sus implicaciones de schema:

1. **Campo nuevo en `SplitMember`** — ej. algo como un CSV de
   `"otroMemberID:timestamp"` (pares explícitos, mismo patrón de
   `SplitConfigCodec.encodeValues`/`decodeValues`,
   `Yala/App/Logic/SplitConfigCodec.swift:41-64`, que ya resuelve el problema
   de "pares clave-valor sin depender de orden, sin dos CSV paralelos"
   porque un miembro puede tener deudas pendientes con varios otros
   miembros simultáneamente, no solo una). Ventaja: no crea un modelo nuevo,
   reduce el número de record types en un schema ya delicado. Desventaja:
   `SplitMember` no es naturalmente "la deuda A→B", es "un miembro" — el
   campo describiría relaciones N-a-N desde una entidad que no es esa
   relación, lo cual es un poco forzado, y cada actualización de este campo
   dispara un `enqueueSave` de `SplitMember` completo
   (`SplitSyncManager.enqueueSave(modelID:group:)`, ver `enqueueSave` en
   `SplitSyncManager.swift:815-822`) por cada cambio de timestamp, aunque
   nada más del miembro haya cambiado — ruido de sync innecesario para un
   dato que cambia con cada nudge (ej. semanal).

2. **Modelo nuevo ligero, ej. `DebtReminderState`** — un record por par
   `(fromMemberID, toMemberID, currencyCode)` con
   `lastNotifiedAt: Date`. Sigue el patrón arquitectónico de los modelos de
   Grupos existentes (vínculo por ID plano `groupZoneID`+memberIDs, **sin**
   `@Relationship`, igual que `SplitShare`/`SplitSettlement`) y se sincroniza
   vía CKSyncEngine con su propio record type. Ventaja: separación de
   responsabilidad clara, cambios de timestamp no contaminan el save de
   `SplitMember`. Desventaja: **es exactamente el tipo de cambio que este
   proyecto trata con máxima cautela** — un record type nuevo en el schema
   de Grupos significa: nuevo entry en `CKConstants.RecordType`
   (`Yala/Services/Groups/CloudKitConstants.swift:20-26`), nuevo enum de
   campos, nuevas 3 funciones en `CKRecordTranslator`, nuevo caso en el
   switch de `applyExpense`/`applyMember`/etc. de `SplitSyncManager`
   (buscar el switch en `handleFetchedRecordZoneChanges`,
   `SplitSyncManager.swift:1037` en adelante, que despacha por
   `record.recordType`), y sobre todo: **añadir al `groupsSchema`**
   (`Yala/Utils/SwiftDataConfiguration.swift:107-115`), lo cual es una
   migración SwiftData del store `YalaGroups` — el mismo store que protagonizó
   la saga de crashes de restore de iCloud documentada extensamente en
   CLAUDE.md (ver entradas 2026-06-20 a 2026-06-22, "Sync de Grupos
   (CKSyncEngine) NO debe arrancar/`save()` sobre el `mainContext` compartido
   antes de que el primer import personal de CloudKit se asiente"). Un
   modelo nuevo no es, por sí mismo, la causa de esos crashes — pero cada
   pieza nueva en ese store es una superficie más para que un problema de
   timing similar reaparezca, y el equipo ya gastó varias semanas
   depurándolos.

3. **Estado solo local (`UserDefaults`), sin sync** — ej. una key
   `GroupDebtReminders.lastNotified.<fromID>.<toID>.<currency>` en
   `UserDefaults`, siguiendo el patrón que ya usa
   `GroupNotificationService.persistTimestamp(for:)`/`loadTimestamp(for:)`
   (líneas 50-59) para el rate-limit de notificaciones — es prácticamente el
   mismo problema (throttle por timestamp), y esa función ya resuelve un caso
   análogo sin tocar CloudKit en absoluto. Ventaja: **cero riesgo de schema**
   — no toca el container CloudKit de Grupos en absoluto. Desventaja: el
   estado no viaja entre dispositivos del mismo usuario ni informa a otros
   miembros — si Juan tiene el iPhone y el iPad, cada uno podría re-notificar
   independientemente (mitigable con un rate-limit generoso, ej. no más de 1
   recordatorio cada 7 días por deuda, calculado igual en ambos dispositivos
   porque el chequeo es determinístico sobre el mismo dato sincronizado —
   solo el "ya avisé" es local, no el cálculo de si corresponde avisar).

**Recomendación de este ticket: empezar con la opción 3 (UserDefaults local,
sin sync)** para la primera versión. Es la única de las tres que no toca el
schema CloudKit de Grupos en absoluto, y el proyecto tiene precedente directo
y probado (`GroupNotificationService.persistTimestamp`/`loadTimestamp`) para
resolver "no re-notificar antes de tiempo" sin persistencia sincronizada. Si
tras usarlo en producción se decide que el recordatorio debe verse
consistente entre dispositivos del mismo usuario, o que otros miembros deben
saber que ya se envió un recordatorio, migrar a la opción 2 en una iteración
posterior — con todo el cuidado de schema que eso implica (ver checklist
abajo), nunca como parte de la V1.

**Si en algún momento se opta por la opción 1 o 2 (persistencia sincronizada),
el checklist de deploy es:**
1. Modelo/campo nuevo con default explícito (CloudKit no admite propiedades
   sin default).
2. Entry nuevo en `CKConstants.RecordType` (si es modelo nuevo) o
   `CKConstants.XField` (si es campo en modelo existente).
3. Las 3 funciones de traducción en `CKRecordTranslator` (`applyXFields`,
   `x(from:)`, `update(_:from:)`), todas con lectura default-safe
   (`record[F.campo] as? Tipo ?? default`) para tolerar records viejos.
4. Si es modelo nuevo: añadirlo a `groupsSchema`
   (`SwiftDataConfiguration.swift:107-115`) — esto es una migración
   SwiftData del store `YalaGroups`; verificar que sea lightweight
   (propiedad opcional o con default, sin `@Attribute(.unique)`, sin
   relaciones non-optional — las 3 reglas inviolables de CloudKit compat de
   CLAUDE.md) y probar el upgrade-over-install antes de shippear.
5. Caso nuevo en el switch de clasificación de
   `handleFetchedRecordZoneChanges` en `SplitSyncManager.swift` (si es record
   type nuevo).
6. Deploy en CloudKit Dashboard — revisar el diff antes de confirmar
   (append-only, sin margen de error de tipo).
7. **Considerar explícitamente el mismo problema de timing de la saga de
   crashes**: cualquier `save()` nuevo sobre el store de Grupos que ocurra en
   boot temprano (un chequeo de recordatorio "corre al arrancar la app" es
   exactamente el tipo de disparo que causó los crashes anteriores) debe
   gatearse por quiescencia del import personal, igual que el resto del
   sync de Grupos (`SplitSyncStartGate`, mencionado extensamente en
   CLAUDE.md 2026-06-20 a 2026-06-22). Un chequeo de recordatorios que se
   dispara en boot y termina escribiendo un timestamp en el store de Grupos
   ANTES de que el import personal asiente es, literalmente, la misma clase
   de bug que costó varias semanas resolver.

## Plan técnico

### Modelo/campos nuevos propuestos

**V1 (recomendada):** ninguno en CloudKit. Solo `UserDefaults` local, key con
formato `GroupDebtReminders.lastNotified.<fromMemberID>.<toMemberID>.<currencyCode>`
→ `Double` (timestamp), mismo patrón de
`GroupNotificationService.persistTimestamp`/`loadTimestamp`
(`GroupNotificationService.swift:50-59`).

**V2 (si se necesita sync — no implementar sin re-evaluar el riesgo arriba):**
modelo `DebtReminderState` en `groupsSchema`, campos `groupZoneID: String`,
`fromMemberID: String`, `toMemberID: String`, `currencyCode: String`,
`lastNotifiedAt: Date`, vínculo por IDs planos (sin `@Relationship`, igual
que `SplitShare`/`SplitSettlement`).

### Servicios/vistas existentes a reutilizar

- `GroupBalanceService.calculateDebts` (`GroupBalanceService.swift:124-138`)
  — ya calcula el `[Debt]` consolidado por par de miembros y moneda; el
  chequeo periódico lo invoca igual que ya lo hacen las vistas de detalle de
  grupo, sin modificarlo.
- **Falta un campo de "desde cuándo" que hoy no existe en `Debt` ni se puede
  derivar limpiamente** — un `Debt` es el resultado neto de posiblemente
  varios `SplitExpense`/`SplitShare`/`SplitSettlement` a lo largo del tiempo,
  no una entidad con una sola fecha de origen. La aproximación más simple
  para V1: usar la fecha del `SplitExpense` **más antiguo sin liquidar**
  que contribuye a esa deuda (requiere recorrer `activeExpenses`/`shares`
  igual que hace `rawDebts` internamente, líneas 141-182, pero sin
  consolidar — necesitaría exponerse una variante que retenga la fecha, o
  un helper nuevo). Esto es trabajo de diseño pure-logic, no de schema, y
  debe resolverse antes de escribir el chequeo periódico.
- Patrón de disparo periódico: `BudgetAlertService.checkBudgetsAndNotify`
  (`BudgetAlertService.swift:30-81`) — mismo tipo de "chequeo global +
  guard de toggle" (`budgetAlertsEnabled` en `UserDefaults`, línea 32);
  buscar dónde se invoca hoy (`AppBootstrapper` o un background refresh) para
  cablear el chequeo de deudas en el mismo punto o uno análogo, respetando el
  gate de quiescencia de import mencionado en la sección de riesgo si el
  chequeo toca el store de Grupos en boot.
- `NotificationService.shared.sendNotification(title:body:deepLink:)` — canal
  ya usado por `GroupNotificationService.buildNotification` (línea 117-128
  aprox., `Task { await NotificationService.shared.sendNotification(...) }`)
  y por `BudgetAlertService.sendNotification` (líneas 190-215) — mismo canal,
  reusar directamente, con `deepLink: "groups/\(groupID.uuidString)"` igual
  que ya hace `GroupNotificationService` (línea 118).
- Toggle global nuevo en Ajustes de notificaciones (patrón de
  `budgetAlertsEnabled` — un usuario debe poder apagar este nudge
  específicamente, no asumir que todo el mundo lo quiere).

### Qué falta construir

1. Helper pure-logic que, dado el conjunto de expenses/shares/settlements de
   un grupo, determine para cada `Debt` activo la fecha más antigua de
   origen (o el criterio que se decida — alternativa más simple: la fecha
   del `SplitExpense` más reciente **entre** los dos miembros involucrados,
   como proxy de "última actividad relacionada con ellos", en vez de
   "primera vez que existió la deuda exacta" — decidir con el owner, afecta
   directamente qué tan preciso es el copy "hace 3 semanas").
2. Servicio nuevo (o extensión de `GroupBalanceService`, evaluar si pure vs.
   `@MainActor` con contexto — probablemente necesita `ModelContext` para
   leer `UserDefaults` de rate-limit y despachar la notificación, así que
   sigue el patrón `@MainActor final class` de `GroupNotificationService`/
   `BudgetAlertService`, no un enum stateless como `GroupBalanceService`).
3. Chequeo N semanas configurable (empezar con un valor fijo razonable,
   ej. 2-3 semanas, antes de exponerlo como preferencia de usuario).
4. Rate-limit por deuda vía `UserDefaults` (V1) — no re-notificar la misma
   deuda antes de, ej., 7 días desde el último recordatorio, incluso si el
   chequeo corre a diario.
5. Cablear el disparo periódico (boot-time con gate de quiescencia si toca
   Grupos, o background refresh — decidir el punto de entrada exacto
   revisando `AppBootstrapper` primero).
6. Copy con voz de marca (revisar BRAND-VOICE.md) — nunca tono cobrador. Ej.
   evitar "Juan te debe" en tono de reclamo; preferir algo como "¿Ya
   arreglaron lo del viaje con Juan? Lleva unas semanas pendiente" — el
   ticket no fija el copy final, solo el tono a evitar.
7. Toggle en Ajustes de notificaciones para apagar este nudge específico.
8. Tests pure-logic para el cálculo de "fecha de origen de la deuda" y para
   el rate-limit.
9. `qa/coverage-index.json` actualizado con el área nueva.

## Acceptance Criteria

- [ ] Una deuda entre dos miembros que lleva más de N semanas sin cambios
      dispara exactamente un recordatorio (no uno por cada `SplitExpense`
      que contribuye a ella).
- [ ] Liquidar la deuda (aunque sea parcialmente) o crear un nuevo gasto
      entre esos dos miembros resetea el contador — no se debe notificar de
      una deuda que ya tuvo actividad reciente.
- [ ] El mismo recordatorio no se re-envía antes del rate-limit configurado
      (ej. 7 días), incluso si el chequeo corre a diario.
- [ ] El usuario puede apagar este nudge sin apagar el resto de
      notificaciones de Grupos.
- [ ] El chequeo periódico no dispara ningún `save()` sobre el store de
      Grupos antes de que el import personal asiente (si aplica — ver
      sección de riesgo).
- [ ] Copy revisado contra BRAND-VOICE.md — tono amable, nunca cobrador.
- [ ] Tests pure-logic para el cálculo de antigüedad de deuda y el
      rate-limit, sin necesidad de `ModelContext` si es posible (mismo
      espíritu que `GroupBalanceService`, que es stateless y testeable sin
      contexto).

## Decisión Jürgen (2026-09-06)

**Al deudor, en tono suave.** Elegida entre: al deudor, a los dos, solo al acreedor, o un banner dentro
del grupo sin push. Motivo, tal como se le puso delante y ratificó: es quien puede resolverlo y el acreedor ya lo sabe; una sola lógica de
destinatario. Copy tipo «te recordamos que le debes X a Ana», revisado contra `BRAND-VOICE.md`:
amable, nunca cobrador. El banner dentro del grupo puede acompañar, pero el pedido es un nudge que
llega sin abrir la app.

## Notas

- **Decisión de diseño abierta más importante:** si el recordatorio se
  envía solo a quien le deben (el acreedor, "recuérdale a Juan") o también
  al deudor (Juan mismo, "te recordamos que le debes a X") — o ambos. Cada
  opción tiene una implicación distinta sobre `GroupNotificationRecipientLogic`
  (mencionado en `GroupNotificationService.swift` como el helper pure-logic
  que decide destinatarios de notificaciones existentes — revisar si aplica
  aquí o si este nudge necesita su propia lógica de destinatario, dado que
  es fundamentalmente distinto: no reacciona a "algo que pasó", sino a "algo
  que no pasó").
- **Alternativa considerada:** en vez de un chequeo periódico que dispara
  notificaciones push, un banner persistente dentro del detalle del grupo
  ("Esta deuda lleva 3 semanas pendiente") sin notificación push. Más simple
  de implementar (no requiere ningún disparo por tiempo, solo un cálculo
  al renderizar la vista) y sin ningún riesgo de boot-time. Se descarta como
  V1 principal porque el pedido original es explícitamente un "nudge" (algo
  que llega sin que el usuario abra la app), pero vale la pena considerarlo
  como complemento de bajo riesgo, o incluso como V0 antes de construir el
  disparo periódico — un banner in-app no tiene NINGUNO de los riesgos de
  timing/boot descritos en este ticket, y podría validar si el feature vale
  la pena antes de invertir en la parte más delicada (el disparo
  proactivo).
- Este ticket es el complemento natural, en espíritu, del feature de
  "pagos planificados de grupo" (commit `b98f31cd`) — ambos son formas de
  que Yala recuerde algo relacionado con el grupo sin que el usuario tenga
  que acordarse. Pero técnicamente son muy distintos: aquel vive del lado
  personal (`ScheduledPayment.groupZoneID`, el vínculo de recurrencia "vive
  SOLO del lado personal", según CLAUDE.md 2026-07-01) y no toca el schema
  de Grupos en absoluto; este, si se implementa con persistencia
  sincronizada (opción 2), sí lo haría. No asumir que el mismo approach de
  bajo riesgo aplica aquí sin pensarlo.

migrated from YalaWiki Backlog/groups-recordatorio-liquidacion.md @ 1934e8ad

---

## Implementado (2026-09-07)

**Qué hace ahora la app.** Si le debes dinero a alguien en un grupo y esa cuenta lleva tres
semanas sin moverse, Yala te manda un aviso amable —a ti, que eres quien puede resolverlo— sin
que tengas que abrir la app: «👋 Te recordamos que le debes S/ 50 a Ana. Cuando puedas, ponte al
día». Si le debes a varias personas del mismo grupo llega **un solo aviso**, no uno por persona.
No se repite antes de una semana, y cualquier gasto o pago nuevo entre vosotros dos reinicia el
contador. Se enciende en Ajustes → Notificaciones → «Recordatorios de deudas», y nace apagado.

**Piezas nuevas**
- `Yala/App/Logic/SettlementReminderLogic.swift` — decisión pura: a quién, cuándo, cada cuánto.
- `Yala/Services/Groups/GroupSettlementReminderService.swift` — los gates, el cálculo y el envío.
- `Yala/Services/Groups/SettlementReminderTracker.swift` — el «ya avisé», por deuda.
- `AppPreferences.groupSettlementRemindersEnabled` (synced, default `false`) + su tarjeta en
  Ajustes, y 4 strings nuevos en los 16 `.lproj`.

**V1 según el ticket: opción 3.** Cero cambios de schema CloudKit. El estado del rate-limit vive
solo en `UserDefaults`, con el precedente de `GroupNotificationService.persistTimestamp`.

### Las cuatro decisiones que no estaban en el ticket

1. **Deudas DIRECTAS siempre, aunque el grupo tenga `simplifyDebts` encendido.** La primera
   versión lo respetaba «para que el aviso diga lo mismo que la pantalla»; la review lo tumbó con
   un caso numérico. Bajo simplificación la arista «yo → X» es un enrutado calculado sobre saldos
   de terceros: podía afirmar «lleva semanas quieta» sobre dinero de anoche, con un importe 7×
   mayor que el real, y el rate-limit se rompía porque su clave (`Debt.id`) cambiaba cuando dos
   personas que no eres tú se pagaban algo. Precio aceptado y escrito en el código: en un grupo
   con simplificación el importe del aviso puede no coincidir con la fila de la pantalla.
2. **El reloj se mide por PAR de personas, no por grupo.** En un piso compartido siempre hay
   gastos; medir por grupo dejaría el nudge mudo justo donde más falta hace.
3. **Se exige `belongsToBackendChannel` además de `isFresh`.** El gate de frescura concede
   `.fresh` incondicional a una zona sin canal — correcto para el editor, y lo contrario de lo
   que hace falta aquí: sobre un snapshot congelado «lleva tres semanas sin moverse» es cierto
   por construcción. Sin ese filtro, además, un solo grupo legacy en el store hacía salir la
   espera en el primer poll y el feature quedaba mudo en el arranque.
4. **Solo se avisa a un miembro `isActive` de un grupo no congelado.** `resolveCurrentUserMember`
   no filtra por estado (regla de `.claude/rules/swiftdata-cloudkit.md`, caso 4): sin eso, un push
   pidiendo liquidar podía llegar a quien ya salió del grupo o a quien no puede escribir en él.

### Verificado

- Build ×2 (`Yala` y `Yala Dev`) en verde, sin warnings nuevos.
- 36 tests en 5 suites, incluidos los 20 propios. **Verificados por mutación**: contar deudas en
  vez de acreedores, y quitar el clamp de fechas futuras, ponen rojos exactamente sus tests.
- `qa/coverage-index.json`: área `groups-settlement-reminders`, `manual` (la entrega depende del
  reloj real y del permiso de notificaciones; nada de eso es determinista en XCUITest).

### Pendiente

- **Device-QA**: los cuatro gates end-to-end, el deep link y el texto renderizado.
- Dos tickets abiertos de camino: `groups-settlement-reminder-stale-clock` (el reloj no ve
  ediciones ni pagos retro-fechados; necesita campo nuevo) y
  `groups-settlement-reminder-discoverability` (**decisión de Jürgen**: el toggle nace apagado,
  no entra en el primer y depende de un segundo interruptor invisible).

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Solo sale con una deuda de un grupo que lleve 21 días sin moverse, y el reloj usa la fecha de creación del gasto: no se fabrica hoy. Lo cubre `SettlementReminderLogicTests`.
