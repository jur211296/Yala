---
id: rescue-discarded-groups-pull
status: discarded
priority: high
area: groups
created: 2026-07-27
updated: 2026-08-26
source: YalaWiki/Backlog/modo-nube/qa_rescate-pull-grupos-descartados.md
---


# Rescatar los gastos que el pull de grupos descarta

Ticket derivado de la sesión de C-3/C-4 (Modo Nube, bugs del encendido). El owner lo sacó a ticket propio el 2026-07-27 tras una revisión adversarial que mostró que es una **feature**, no un fix.

Contexto en el vault: [[MODO-NUBE-DECISIONES-ESCENARIOS]] §9 fila C-4 · [[MODO-NUBE-AUDITORIA-ESCENARIOS]] §4 fila 10.

## Contexto

`SplitSyncManager.handleFetchedRecordZoneChanges` descarta TODO record de CloudKit cuya zona esté en `backendZoneNames` (grupos con `isBackendGroup == true`). Ese guard es G6-3 (C2) y existe por una razón legítima: tras migrar, la verdad vive en el backend y un miembro rezagado escribiría records STALE que pisarían las ediciones backend post-migración.

El problema (C-4 residual, no cerrado en el commit de C-3/C-4): **el descarte no distingue el eco stale legítimo (record ya conocido localmente) del record NUNCA VISTO, que es dato real perdido.** El token de CKSyncEngine avanza igual, así que ese record no se re-entrega jamás. Firma: `groupsCkPullSkippedBackendGroup(site:"applyRemote")`, indistinguible del caso legítimo.

Dos ventanas que esto cierra y que el gate de quiescencia del commit anterior (`GroupFetchQuiescenceGate`) NO cierra:

1. **El invitado que sube su gasto DESPUÉS del flip.** Su ventana no depende del reloj del owner: un gasto registrado sin red hace días sube mañana.
2. **El camino de resume:** si el paso 5 del uploader falla, el grupo queda `isBackendGroup == true && movedToBackendAt == nil` durante días, con CloudKit congelado y cada escritura de los invitados descartándose.

El propio `GroupFetchQuiescenceGate` lo dice en su cabecera: *«no cierra la carrera hacia el futuro… eso lo cierra el RESCATE de pull, que vive en SU PROPIO TICKET»*.

## Hallazgos de la revisión adversarial previa

Ya incorporados al diseño de abajo — no re-descubrir.

| # | Sev | Hallazgo | Dónde se resuelve |
|---|-----|----------|-------------------|
| B1 | BLOQUEANTE | `isKnownLocally` NO significa «el backend no lo tiene». En un device que NO migró, `isBackendGroup` se enciende en el pull backend (`GroupsSyncClient.applyGroupMeta:1717` born-remote y `:1737` adopción C3) ANTES de que ese pull haya entregado las filas. En esa ventana CloudKit entrega los records PRE-migración y adoptarlos los empujaría con HLC fresco, PISANDO en el servidor las ediciones post-migración de todo el grupo | Incremento 2 + gate `backendPullSettled` |
| B2 | BLOQUEANTE | Resurrección en masa. Tras un reset de tokens (`clearState`, que solo borra el fichero) el siguiente cold start hace re-entrega COMPLETA; toda fila borrada en el backend después de migrar vuelve como «nunca vista» → se adopta → se empuja → `apply_group_delta` la reinstaura para todo el grupo. Un testigo en memoria del proceso equivocado NO sirve | Incremento 3 (`replayingFullCorpus`, derivado de `loadState == nil` en el proceso que hace la re-entrega) |
| B3 | BLOQUEANTE | El pre-fetch de IDs existentes (`handleFetchedRecordZoneChanges:1734-1748`) es best-effort — su catch deja los sets VACÍOS y sigue. Con el rescate cableado a ese Set, ese mismo catch convertiría TODO el batch en «nunca visto» | Incremento 4 (`prefetchFailed` + el rescate NO se decide por el Set) |
| B4 | BLOQUEANTE | `applyRemoteRecord:2380` UPDATEA si la fila existe (`applyExpense:2434`, `applyShare:2477`, `applySettlement:2492`). El invariante «el rescate solo inserta» tiene que estar enforced en el SITIO DE LA MUTACIÓN, no en un Set | Incremento 4 (`applyRemoteRecordIfAbsent` re-chequea con `splitExpense(byID:in:)`:2603 etc.) |
| I1 | IMPORTANTE | Dos SSOT distintas: lo adoptable se decide con `CKConstants.RecordType` (namespace CloudKit) y lo emisible con `GroupEntityEmissionMap.emittableGroupEntityNames` (nombres de clase `@Model`). Si divergen se adopta dinero que el drain descarta en silencio | Incremento 5 (test de paridad) |
| I2 | IMPORTANTE | Las MODIFICACIONES no las cubre un rescate insert-only | **DECIDIDO 2026-07-27 (owner): insert-only, residual documentado.** Ver §Residuales |
| I3 | IMPORTANTE | El History es POR CONTAINER. `CloudSyncEngine.deleteHistorySafeCut:2319` calcula el corte mirando solo el outbox PERSONAL ⇒ puede borrar la transacción de la fila rescatada antes de que el drain de Grupos la consuma | Incremento 6 |
| I4 | IMPORTANTE | El rescate no debe reabrir el agujero que el guard cerró (G6-3 C2) | Invariantes de §Diseño; deletions NO se rescatan nunca |
| M1 | MENOR | El pre-fetch adicional debe ser condicional a `!backendZoneNames.isEmpty` para no meter una query por zona en el camino caliente del pull con el flag apagado | Incremento 4: el rescate NO añade pre-fetch de batch — usa lookup puntual por id, solo en el camino frío |

---

## Analisis tecnico

### Estado real del código (líneas verificadas 2026-07-27)

Las líneas del ticket original venían de una revisión anterior; las vigentes son:

| Referencia del ticket | Línea real hoy |
|---|---|
| guard de modificaciones | `SplitSyncManager.swift:1771-1776` |
| guard de deletions | `SplitSyncManager.swift:1830-1835` |
| pre-fetch best-effort | `SplitSyncManager.swift:1729-1748` |
| paso 3 del uploader (`isBackendGroup = true`) | `GroupMigrationUploader.swift:307-316` |
| paso 6 (`movedToBackendAt`) | `GroupMigrationUploader.swift:334-343` |
| helpers concretos por id | `SplitSyncManager.swift:2600-2614` |

Los otros 3 call-sites del breadcrumb (`:1471` zoneDeletion, `:2148` conflict, `:2244` zoneNotFound) NO cambian de comportamiento — solo ganan el `reason:`.

### Diseño

**Regla:** en una zona backend, un record de tipo rescatable que NO existe localmente y cuyo gate está abierto se **INSERTA** (jamás se actualiza) y se deja que el drain del canal backend lo capture por History → outbox → push. Todo lo demás se descarta como hoy, pero con un `reason` que lo nombra.

**Invariantes (los que no se pueden romper):**

1. **El rescate JAMÁS actualiza.** Enforced en la mutación (`applyRemoteRecordIfAbsent` re-chequea por id con los helpers concretos), no en un Set precalculado. Esto preserva G6-3 C2 tal cual: las ediciones backend post-migración no se pisan nunca.
2. **El rescate JAMÁS aplica deletions.** Una deletion de una zona backend es exactamente lo que el guard debe descartar — la verdad de las bajas vive en el backend. El bloque `:1830-1835` queda intacto.
3. **El rescate JAMÁS toca `GroupMeta` ni `SplitMember`.** `GroupMeta` porque el grupo existe por definición (es lo que pone la zona en `backendZoneNames`) y adoptarlo sería meta stale; `SplitMember` porque es PULL-ONLY (`emittableGroupEntityNames` lo excluye) ⇒ adoptarlo sería dinero fantasma que el drain descarta en silencio. Rescatables: `SplitExpense`, `SplitShare`, `SplitSettlement`.
4. **Con `groupsBackendEnabled == false` el comportamiento es byte-idéntico al de hoy.** Nadie pone `isBackendGroup = true` con el flag apagado, y el gate corta por bandera antes de cualquier fetch extra.

**El gate (`GroupPullRescueGate`, decisión PURA — idioma del repo: `SplitSyncStartGate`, `GroupFetchQuiescenceGate`, `MigrationGateLogic`):**

```
Signal
  flagOn                        CloudSyncFlags.groupsBackendEnabled
  replayingFullCorpus           algún engine arrancó SIN state en esta sesión (B2)
  prefetchFailed                el pre-fetch del batch lanzó (B3)
  backendPullCompletedSession   GroupsSyncClient completó ≥1 pull ENTERO en esta sesión (B1)
  groupHasBackendCursor         el group_id está en GroupSyncCursor.groupCursorsJSON (B1)
  isRescuableType               recordType ∈ {SplitExpense, SplitShare, SplitSettlement}
  existsLocally                 lookup puntual por id con el helper concreto (B4)

decide → .rescue | .discard         (.rescue solo si TODO se cumple)
skipReason → slug estable para el breadcrumb, precedencia fija:
  flagOff → replay → prefetchFailed → noBackendPull → noCursor → notRescuable → staleEcho
```

**Por qué `backendPullCompletedSession && groupHasBackendCursor` cierra B1:** el cursor por grupo (`{group_id: server_seq}`) solo existe una vez que el server reportó ese grupo, y `pullUntilExhausted` solo devuelve `.completed` cuando una página trae 0 deltas — es decir, cuando el corpus backend de ese grupo está aplicado hasta su `server_seq`. Con las dos condiciones, «ausente localmente» significa de verdad «ni CloudKit ni el backend lo tenían», que es la única lectura bajo la que adoptar-y-empujar es correcto.

**Por qué la bandera de re-entrega es de SESIÓN y no de ciclo:** durante la re-entrega completa la avalancha llega repartida en muchos ciclos de fetch a lo largo de la sesión. Suspender el rescate solo hasta el primer ciclo cerrado lo dejaría abierto justo cuando llega el grueso. Suspenderlo toda la sesión es la dirección segura, y la siguiente sesión ya arranca con token.

### Archivos involucrados

| Archivo | Cambio | Impacto |
|---------|--------|---------|
| `Yala/App/Logic/GroupPullRescueGate.swift` | **Crear** — decisión pura + `skipReason` | Alto |
| `Yala/Services/Groups/SplitSyncManager.swift` | Modificar — bandera `replayingFullCorpus`, `prefetchFailed`, `applyRemoteRecordIfAbsent`, cableado del gate en `:1771-1776`, cache por zona | Alto |
| `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift` | Modificar — `backendPullSettled(groupID:context:)` (expone `lastPullCycleCompleted` + presencia del gid en el cursor) | Medio |
| `Yala/Services/CloudSync/CloudSyncEngine.swift` | Modificar — `deleteHistorySafeCut` incluye el suelo del canal de Grupos | Medio |
| `Yala/Services/CloudSync/Groups/GroupsSyncBreadcrumb.swift` | Modificar — `groupsCkPullRescued(entity:)` nuevo + `reason:` en `groupsCkPullSkippedBackendGroup` | Bajo |
| `Yala/Services/Metrics/MetricsService.swift` | Modificar — canario `.groupCkPullRescued` | Bajo |
| `qa/coverage-index.json` | Modificar — áreas `groups-backend-g6-migration` y `groups-cross-device-sync` | Bajo |

### Modelo de datos

**Ninguno.** Sin campos nuevos en `SplitGroup` ni en ningún `@Model`, y por tanto **sin deploy de schema a CloudKit Production** (la decisión insert-only es justo lo que evita `backendFreezeAt`). El gate se alimenta de estado ya existente: `GroupSyncCursor.groupCursorsJSON`, el `state` de CKSyncEngine y contadores en memoria del delegate.

### Dependencias

- `GroupsSyncClient` (pull backend, cursor por grupo) ← nueva lectura desde `SplitSyncManager`. Ambos `@MainActor`, sin frontera nueva.
- `GroupEntityEmissionMap.emittableGroupEntityNames` ← atado por test de paridad (I1).
- `CloudSyncEngine.purgeHistoryOnce` (hoy bajo doble flag) ← el fix del corte lo endurece antes de que se encienda.
- `GroupFetchQuiescenceGate` **no cambia**: cierra la ventana pasada, este ticket cierra la futura. Son complementarios.

---

## Plan de implementacion

### Incrementos (orden de ejecucion)

1. **Gate puro + telemetría que distingue** — la decisión aislada, sin cablear.
   - Archivos: `Yala/App/Logic/GroupPullRescueGate.swift` (nuevo), `GroupsSyncBreadcrumb.swift`, `MetricsService.swift`, y el `reason:` (con default) en los 5 call-sites del breadcrumb.
   - Tests: `YalaTests/CloudSync/GroupPullRescueGateTests.swift` — matriz completa de `decide`, precedencia de `skipReason`, y que cualquier señal en falso da `.discard`.
   - Sin cambio de comportamiento: nadie llama al gate todavía.

2. **Señal del pull backend por grupo** — cierra B1.
   - Archivos: `GroupsSyncClient.swift` (`backendPullSettled(groupID:context:) -> Bool`, `internal` para tests).
   - Tests: ampliar `YalaTests/CloudSync/GroupsSyncClientTests.swift` — `false` sin pull completado; `false` con pull completado pero gid ausente del cursor; `true` con ambos; `false` tras un ciclo `.transient` posterior.

3. **Testigo de re-entrega completa** — cierra B2.
   - Archivos: `SplitSyncManager.swift` — `replayingFullCorpus` se enciende en `startEngines` cuando `loadState` devuelve `nil` para cualquiera de los dos engines, en `recreateEnginesAfterIdentityChange` (construye con `state: nil` explícito) y en las ramas `.purged` / `.encryptedDataReset` de `handleFetchedDatabaseChanges:1484-1497`. Nunca se apaga dentro de la sesión.
   - Tests: `SplitSyncManagerTests` — arranque fresh enciende la bandera; arranque con state persistido no; el cambio de identidad la enciende.

4. **`applyRemoteRecordIfAbsent` + cableado del rescate** — el corazón (B3 + B4).
   - Archivos: `SplitSyncManager.swift`. El `continue` incondicional de `:1771-1776` pasa a consultar el gate (parte de sesión computada una vez por batch; parte por zona cacheada al molde de `adminCache`/`baselineCache`). El `catch` del pre-fetch `:1744` enciende `prefetchFailed` del batch. `applyRemoteRecordIfAbsent` hace switch por `recordType`, lookup con el helper concreto, e inserta vía `CKRecordTranslator` solo si falta. Deletions intactas.
   - Tests: `YalaTests/CloudSync/GroupPullRescueTests.swift` — los 7 casos, **todos rojos antes del fix**: (a) gasto nunca visto en zona backend con gate abierto → insertado; (b) eco stale → la fila local NO cambia ni un campo; (c) `replayingFullCorpus` → descartado; (d) `prefetchFailed` → descartado; (e) sin cursor backend del grupo → descartado; (f) `GroupMeta`/`SplitMember` → descartados aun con gate abierto; (g) deletion en zona backend → nunca aplicada.

5. **Paridad de las dos SSOT + wiring** — cierra I1.
   - Archivos: `YalaTests/CloudSync/GroupPullRescueParityTests.swift` (nuevo) — los 3 tipos rescatables tienen entity name en `emittableGroupEntityNames`; `GroupMeta` NO es rescatable **y** su `RecordType` ("GroupMeta") no coincide con su nombre de clase ("SplitGroup") — el test nombra esa asimetría para que nadie la cruce; `SplitMember` no es rescatable. Wiring source-scan al molde de `GroupFetchGateWiringTests` (qué campo del manager alimenta cada entrada del gate).

6. **Suelo del corte de History con el canal de Grupos** — cierra I3.
   - Archivos: `CloudSyncEngine.swift` — `deleteHistorySafeCut` pasa a devolver el `min` de: `drainedBoundary`, `createdAt` del `SyncOutbox` sin-2xx más viejo, `GroupSyncCursor.lastDrainedTxAt`, y `createdAt` del `GroupSyncOutbox` vivo más viejo. Además, tras un batch con rescates, el `deferredBridgeTask` ya existente (`:1894-1900`) dispara un `drainOnce` oportunista — aceleración, no garantía; la garantía es el corte.
   - Tests: ampliar los del corte — el corte nunca adelanta al canal de Grupos; una fila de `GroupSyncOutbox` viva lo retiene; sin canal de Grupos el resultado es idéntico al de hoy (no-regresión).

7. **Cierre** — `qa/coverage-index.json` (`groups-backend-g6-migration` + `groups-cross-device-sync`: `coverage` y `lastVerified`), `bash qa/validate-coverage.sh`, y el gotcha durable en `.claude/rules/swiftdata-cloudkit.md` (el invariante insert-only + su residual).

### Riesgos

| Riesgo | Mitigación |
|---|---|
| Reabrir G6-3 C2 (pisar ediciones backend post-migración) | Invariante 1 enforced en la mutación + test (b) que verifica que el eco stale no cambia ni un campo |
| Resurrección en masa tras reset de tokens | Incremento 3 + test (c). La bandera es de SESIÓN, se enciende en los 4 caminos que dejan el engine sin token |
| Adoptar dinero que el drain descarta en silencio | Incremento 5 (paridad) — el fallo sería mudo sin el test |
| Coste en el camino caliente del pull | El gate corta por `flagOn` antes de nada; el lookup por id solo corre en zonas backend con el gate abierto. Sin pre-fetch de batch adicional (M1) |
| Fila rescatada perdida por la purga de History | Incremento 6. Hoy `purgeHistoryOnce` vive bajo doble flag ⇒ el fix llega antes que el encendido |
| Doble escritura contra el backend si otro device escribió la misma fila entre el pull completado y el batch CloudKit | Converge por LWW por unidad de coherencia (`apply_group_delta`) — no hay pérdida de fila. Residual documentado |

### Residuales (conscientes, no atajos)

- **Modificaciones pre-freeze no bajadas** (decisión owner 2026-07-27): una edición que un miembro hizo antes del freeze y que este device no había bajado llega como eco de algo conocido y se descarta para siempre. Cubrirla exigiría un umbral temporal (`backendFreezeAt` nuevo, viajando por CloudKit ⇒ deploy de schema a Production en los dos containers) y comparar el reloj del servidor CloudKit contra el del owner. Se acepta a cambio de mantener el invariante «el rescate jamás pisa» verificable de un vistazo.
- **Sesión con re-entrega completa:** en esa sesión no se rescata nada. Un gasto de invitado rezagado que caiga justo ahí se pierde. Es la dirección segura frente a la resurrección en masa.
- **Ventana entre el paso 3 del uploader y el primer pull que reporte el grupo:** sin cursor del gid el gate está cerrado. Se auto-sana en el siguiente ciclo (cadencia 60s).

### Estimacion

- Incrementos: **7**
- Complejidad: **alta** — sync/race + migración + dinero; entra en el criterio de review adversarial de CLAUDE.md.
- Todo bajo `CloudSyncFlags.groupsBackendEnabled` (hoy `false` compilado; para probar en runtime, el override de tests — **no** encender el compilado).
- `/gate` antes de commitear.


---

## Implementación

**2026-07-28 · commit `d00a7078`** (branch `2.0.5`). Los 7 incrementos del plan, completos. Gate verde: build ×2 schemes, 45 tests nuevos en 5 suites, XCUITest de `edge-cases-logic` (2 tests), audit limpio, índice de QA OK.

### Qué cambia para el usuario

Un gasto que un compañero de grupo registró sin conexión y sube días después de que el grupo se haya mudado a la nube ya no desaparece. Antes ese gasto llegaba por iCloud, se descartaba junto con los ecos inocentes, y no volvía nunca: iCloud lo daba por entregado. Ahora se adopta y se sube a la nube. Lo mismo con el grupo que se queda a medias porque la subida falló y pasa días con iCloud congelado.

Nada de esto es visible todavía: vive detrás del interruptor del canal de Grupos, apagado en producción.

### Archivos

| Archivo | Qué cambió |
|---|---|
| `Yala/App/Logic/GroupPullRescueGate.swift` (nuevo) | Decisión pura: 7 puertas con precedencia fija, `skipReason` para el diagnóstico, y el mapa `RecordType` → clase `@Model` que hace visible la asimetría de los dos namespaces |
| `Yala/Services/Groups/SplitSyncManager.swift` | El guard de modificaciones consulta el gate en vez de descartar a ciegas; nacen `applyRemoteRecordIfAbsent` (insert-only, re-chequeo por id) y `recordExistsLocally`; testigos `replayingFullCorpus` (sesión) y `prefetchFailed` (batch); drain en caliente tras un batch con rescates |
| `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift` | `backendPullSignal(groupID:context:)` — lectura PURA del estado del canal (no crea la fila de cursor) |
| `Yala/Services/CloudSync/CloudSyncEngine.swift` | `deleteHistorySafeCut` incluye el suelo del canal de Grupos |
| `Yala/Services/CloudSync/Groups/GroupsSyncBreadcrumb.swift` | `reason:` en el breadcrumb de descarte + `groupsCkPullRescued(entity:)` |
| `Yala/Services/Metrics/MetricsService.swift` | Canario `groupCkPullRescued` (serie propia, NO un `*Failed`: rescatar es lo correcto) |
| `.claude/rules/swiftdata-cloudkit.md` | Regla durable: los 4 invariantes, los 4 gates y el corolario del History por-container |
| `qa/coverage-index.json` | 4 áreas actualizadas: `groups-backend-g6-migration`, `groups-cross-device-sync`, `cloud-sync-capture`, `groups-backend-g2-sync-channel` |

### Decisiones técnicas y su porqué

**El seam del canal devuelve DOS señales, no un booleano compuesto.** El plan preveía `backendPullSettled(groupID:) -> Bool`. Al cablearlo se vio que un único booleano borra la diferencia entre «el pull todavía no ha terminado» y «este grupo aún no aparece en el cursor», que son dos diagnósticos distintos y accionables en Console.app. `backendPullSignal` devuelve `(completed:, hasCursor:)` y el gate los evalúa con precedencia propia (`noBackendPull` vs `noCursor`).

**El candado del «solo inserta» vive en la mutación, no en un Set.** `applyRemoteRecord` UPDATEA si la fila existe, y el Set del pre-fetch del batch es best-effort (su `catch` lo deja vacío). Decidir el rescate con ese Set habría bastado para pisar una edición backend post-migración — el agujero exacto que G6-3 (C2) cerró. `applyRemoteRecordIfAbsent` vuelve a preguntar por id, contra el store, en el instante de escribir, y la rama de update sencillamente no existe.

**`replayingFullCorpus` es de SESIÓN, no de ciclo.** La re-entrega completa tras un reset de tokens llega repartida en muchos ciclos de fetch a lo largo de la sesión; suspender solo hasta el primer ciclo cerrado dejaría el rescate abierto justo cuando llega el grueso. Se enciende en los 5 caminos que dejan el engine sin token y nunca se apaga dentro de la sesión.

**No se añadió pre-fetch de batch.** El plan lo contemplaba condicional a `!backendZoneNames.isEmpty`; con el re-chequeo por id resultó innecesario. Un lookup puntual por record, solo en zonas backend con el gate abierto (camino frío), en vez de N queries por zona en el camino caliente del pull.

**Residual ratificado por el owner:** insert-only. Las modificaciones pre-freeze que este device no bajó se descartan. Cubrirlas exigiría `backendFreezeAt` viajando por CloudKit (⇒ deploy de schema a Production en los dos containers) y comparar el reloj del servidor contra el del owner.

### Verificación por mutación (4 mutantes, 4 cazados)

| Mutante | Lo cazó |
|---|---|
| Gate `replayingFullCorpus` eliminado de `decide` | 5 tests de `GroupPullRescueGateTests` |
| El rescate actualiza en vez de solo insertar | `neverUpdatesAnExistingRow` + `theRescueNeverUpdates` |
| El corte del History vuelve a ignorar el canal de Grupos | 3 tests de `GroupPullRescueChannelTests` |
| El gate colado en el bucle de deletions | `theDeletionLoopNeverConsultsTheGate` |

**Un fallo real cazado en los propios tests durante esa verificación:** `theDeletionLoopNeverConsultsTheGate` anclaba su rango al primer `for deletion in fetched.deletions` del archivo, que es el de `handleFetchedDatabaseChanges` — habría pasado en VERDE con el invariante 2 roto. Corregido anclando después del bucle de modificaciones.

### Qué falta (QA)

No es verificable en simulador con el flag apagado. El guion de device tiene que cubrir, con el canal encendido en un build DEV:

1. **La ventana del invitado.** Owner migra el grupo; invitado en modo avión registra un gasto; invitado recupera red después del flip → el gasto tiene que aparecer en la nube para todos. Breadcrumb esperado: `ckPullRescued entity=SplitExpense`.
2. **El eco stale no pisa.** Owner migra; edita el importe de un gasto YA en la nube; un miembro rezagado sube por iCloud la versión vieja → el importe de la nube NO cambia. Breadcrumb esperado: `ckPullSkippedBackendGroup … reason=staleEcho`.
3. **Sin resurrección tras reinstalar.** Borrar un gasto en la nube después de migrar; reinstalar la app (tokens frescos) → el gasto NO vuelve. Breadcrumb esperado: `reason=replay` durante toda esa sesión.
4. **Canario en cero** en el dashboard de Analytics Engine salvo en el escenario 1.

### Fuera de alcance, detectado de paso

`ProUpsellServiceOneShotTests` (2 tests) falla bajo el scheme `Yala Dev` desde antes de este trabajo — verificado con `git stash` contra HEAD limpio. El host de tests arranca como usuario Pro y esos tests asumen lo contrario. Efecto colateral: hoy NINGÚN scheme corre la suite de unit entera en verde (con `Yala` fallan las dos suites que exigen `DEV_BUILD`). Chip creado: `task_6bbda818`.

migrated from YalaWiki Backlog/modo-nube/qa_rescate-pull-grupos-descartados.md @ 1934e8ad
