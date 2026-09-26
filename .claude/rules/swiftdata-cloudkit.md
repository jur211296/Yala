---
description: Reglas inviolables de SwiftData, CloudKit y el sync de Grupos. Se cargan al trabajar con modelos, servicios o el canal de sincronización.
paths:
  - "Yala/Models/**"
  - "Yala/Services/**"
  - "Yala/Utils/SwiftDataConfiguration.swift"
  - "Cloudkit Schemas/**"
  - "YalaTests/CloudSync/**"
---
# SwiftData · CloudKit · Sync de Grupos

> ## ⚠️ Cómo leer este documento desde el 2026-08-06: el TRANSPORTE CloudKit de Grupos ya no existe
>
> **La Fase 3 del Modo Nube (commits 1 y 2) borró el transporte CloudKit de Grupos entero.** Este documento
> lo menciona mucho —`SplitSyncManager` sale **4 veces**, y era 18 antes de las podas— y **no se ha reescrito a propósito**: sus
> lecciones siguen valiendo aunque su código muriera, y varias se pagaron con incidentes de producción que
> nadie quiere volver a pagar. Lo que cambia es cómo se lee, y va aquí en vez de en 18 sitios porque el
> reparto exacto es por PÁRRAFO, no por bullet.
>
> **Símbolos que ya NO EXISTEN en `Yala/` — verificado con `grep` en este árbol:** `SplitSyncManager` ·
> `SplitZoneManager` · `CKRecordTranslator` · `CloudKitConstants` (`CKConstants`) · `CKShareEntryHandler` ·
> `PendingInviteStore` · `PendingLeaveShareTracker` · `SplitSyncStartGate` · `GroupsIdentityPurgeGate` ·
> `GroupsIdentityBootGuardLogic` · `GroupsICloudAvailabilityGateLogic` · `GroupsICloudUnavailableView` ·
> `SoftDeleteObserverLogic` · `CloudKitGroupMetaApplyLogic` · `GroupsIdentityPurgeIntent`. Todo párrafo que
> describa **su comportamiento** es **HISTÓRICO**: explica por qué las cosas son como son y qué se aprendió,
> no lo que hace el código de hoy. ⇒ **no lo uses como mapa, y no vayas a «verificar» nada en ellos.**
>
> **Lo que sigue VIVO y se lee tal cual:** el canal backend (`GroupsSyncClient`, `GroupsMembershipClient`,
> `GroupBackendMembershipService`, el drain y su ancla por-store del History) · el gate de frescura
> (`GroupChannelFreshnessGate` + `GroupChannelFreshness`) · el barredor `OrphanedBridgedTxSweeper` · los
> intents durables que quedan (`GroupsPendingBridgeIntent` / `GroupsPendingBridgeResume`) ·
> `GroupZoneCacheGate` · `GroupFreezeLogic` · `BootSaveGateLogic` · todo lo de SwiftData, `#Predicate`,
> el mirror CSV y el par `.cloud` + `mirrorOffArmed`, que nunca dependió del transporte.
>
> **Y la lección de método que el borrado deja, porque es la que se repite:** una regla que cita un símbolo
> es una afirmación verificable. Antes de obedecer un párrafo de aquí, comprueba que su código existe — un
> `grep` cuesta menos que el trabajo que te ahorra. El molde de marcado, cuando haya que marcar un párrafo
> suelto, es el bloque `[STALE, medido 2026-08-03 …]` que ya está más abajo: conserva el porqué y avisa de
> que el código se fue.

<!-- INDICE:inicio — generado por scripts/indexar_doc.py, no editar a mano -->

## Índice de reglas (74)

> Este fichero son **206 KB en 74 reglas largas**. No lo leas entero: localiza la regla
> aquí y lee **solo su tramo** con `sed -n '<linea>,<linea+N>p'`.
> Los números de línea se desplazan al editar — regenera con
> `python3 scripts/indexar_doc.py <fichero> --apply`.

| Línea | Regla | Peso |
|---|---|---|
| `L133` | CloudKit compat | 119 B |
| `L135` | Schema del container de GRUPOS — campo nuevo = deploy a Production en el MISMO PR | 1.1 KB |
| `L137` | `#Predicate` GENÉRICO-PROTOCOLO crashea (`DataUtilities.swift:85`) — usa concreto por tipo | 1.8 KB |
| `L139` | Acciones post-accept de un CKShare = intent PERSISTENTE reconciliable, nunca one-shot (bug Pia 2026-07-11) | 1.3 KB |
| `L141` | `context.hasChanges` y lo que llega al canal de sync NO son la misma señal, y confundirlas justifica guards por razones  | 2.1 KB |
| `L147` | Lazy M2M con CloudKit — CSV mirror | 1020 B |
| `L149` | CSV mirror — stale ≠ nil al regenerar un UUID de identidad (commit `899c1c25`) | 1.4 KB |
| `L151` | Sync de Grupos (CKSyncEngine) NO debe arrancar/`save()` sobre el `mainContext` compartido antes de que el primer import  | 403 B |
| `L153` | Lo que el gate de quiescencia DIFIERE solo se recupera solo si es un evento de CloudKit. Si es una INTENCIÓN, el diferid | 425 B |
| `L155` | El guard G6-3 es TAMBIÉN lo que impide avisos DUPLICADOS mientras los dos canales conviven (Fase 2, 2026-07-29). No lo d | 1.9 KB |
| `L157` | [STALE, medido 2026-08-03 — el código que describe ya NO EXISTE: `applyRemoteRecordIfAbsent` y `GroupPullRescueGate` dan | 555 B |
| `L159` | `DefaultHistoryToken` es POR-STORE, y un drain que ancla su high-water en el store equivocado queda ciego al suyo PARA S | 444 B |
| `L161` | Un borrado tiene DOS mitades y el camino remoto solo copió una: la fila del grupo se borra, el PUENTE personal se queda  | 398 B |
| `L163` | Un gate por ZONA calculado sobre filas VIVAS es la herramienta equivocada para un tombstone por FILA — y con un duplicad | 510 B |
| `L167` | El par que apaga el mirror NO se puede hacer atómico ni invertir: se enforcea en el CONSUMIDOR (C-1, commit `246a6939`). | 2.0 KB |
| `L169` | Un journal que no se deja leer NO es `notStarted`, y una lectura no escribe (2026-09-22). | 6.6 KB |
| `L231` | El push-all del cierre de sesión también pasa por el candado del motor, y «pendiente» incluye el History (2026-09-25). | 1.8 KB |
| `L247` | En el apply del pull, «no pude leer» NUNCA es «no hay nada» (2026-09-22). | 1.7 KB |
| `L264` | Y las refs colgadas tampoco (2026-09-23). | 2.3 KB |
| `L287` | Y el drain tampoco (2026-09-23). | 6.8 KB |
| `L350` | Y el Merkle tampoco, en ninguno de los dos canales (2026-09-22 personal · 2026-09-23 Grupos). | 1.8 KB |
| `L367` | Y los inventarios de la migración tampoco (2026-09-23). | 3.2 KB |
| `L398` | Un terminal de fallo DENTRO del cutover tiene que devolver el modo a `.icloud` como PRIMER efecto, o es peor que el limb | 1.3 KB |
| `L400` | `isMarkerExported()` es necesaria-no-suficiente y su espera necesita TOPE: no hay API de cuota de iCloud. | 1.9 KB |
| `L402` | La subida del snapshot de la IDA también tiene techo y salida, con dos relojes (2026-09-22). | 5.3 KB |
| `L453` | Y los otros tres pasos de la ida también: claim, identidad y `cutover(.pending)` (2026-09-22). | 6.6 KB |
| `L515` | Y el EFECTO del adopt también: techo, texto y salida (2026-09-23). | 5.2 KB |
| `L560` | El adopt solo sube lo que el backend no conoce si demuestra que el corpus es de ESA cuenta (2026-09-24). | 4.9 KB |
| `L606` | Y la IDA tampoco sube su corpus sobre el de otro dispositivo: el relevo prueba el linaje en la identidad (2026-09-24). | 4.7 KB |
| `L650` | Una fila que falta solo bloquea si aquí puede tener gemela (2026-09-24). | 4.7 KB |
| `L692` | Y el líder DESPLAZADO no sube ni una página más: la ida sube solo con el lease confirmado (2026-09-24). | 3.3 KB |
| `L723` | Y después del cutover el líder desplazado no sube, no sale: averigua quién cerró y se une (2026-09-24). | 3.5 KB |
| `L756` | Y el servidor ya no da ese relevo: después del cutover, quien llega entra en la cuenta (g16_04, 2026-09-24). | 2.1 KB |
| `L776` | Y lo que el líder desplazado exporta TARDE a iCloud no le cambia la identidad al relevo (2026-09-24). | 5.7 KB |
| `L830` | Y el borrado de una fila re-identificada sale también con la identidad que el backend conoce (2026-09-25). | 4.0 KB |
| `L868` | Y en el ADOPT tampoco: el marcador prueba el linaje, no las identidades (2026-09-25). | 4.4 KB |
| `L909` | Y el adopt que entra sin marcador deja el suyo: el relevo del marcador (2026-09-25). | 4.0 KB |
| `L946` | Y con el espejo adjunto, el adopt no juzga un store al que aún no ha llegado el corpus de iCloud (2026-09-25). | 4.0 KB |
| `L982` | Y lo que el espejo importa TARDE de filas que el backend ya conoce no sube: manda el backend (2026-09-25). | 4.9 KB |
| `L1027` | Y la espera del seguidor también: techo, aviso y «Cancelar» (2026-09-23). | 2.8 KB |
| `L1054` | Y la sesión que abrió el adopt se cierra cuando el adopt sale (2026-09-23). | 3.6 KB |
| `L1088` | La espera de `reverseUpload` también lleva techo, y mide el tiempo SIN AVANZAR, no el total (2026-09-16). | 5.1 KB |
| `L1090` | El claim de la reversa tampoco puede quedarse sin salida: todo `.rejected` vuelve al origen (2026-09-16). | 3.4 KB |
| `L1092` | Y una sesión que caduca ANTES de montar el espejo tampoco puede dejar la barra muda (2026-09-17). | 3.2 KB |
| `L1115` | Y las cuatro fases previas al montaje también tienen techo y salida, con efectos CERO (2026-09-21). | 15.2 KB |
| `L1254` | «Migrar a la nube» nunca adopta, y hacen falta las dos capas que lo impiden (2026-09-16). | 5.1 KB |
| `L1256` | `existing_stable` ya no llega al reintento del MISMO dispositivo sobre una cuenta vacía (2026-09-24). | 2.6 KB |
| `L1279` | El faro de iCloud-KV (`CloudBeacon`) solo se limpia con PRUEBA de que su cuenta no existe, y «el backend dice que no exi | 4.1 KB |
| `L1306` | Al ELIMINAR una función, lista lo que hacía ADEMÁS de lo que la sustituye — un guard no viaja solo con el camino que pro | 1.5 KB |
| `L1308` | Un dominio de preferencias por SESIÓN es la parte fácil; el INVENTARIO es la difícil (`2a773ed3` → `d04fe0b6`, retirado  | 2.7 KB |
| `L1315` | Antes de sincronizar una preferencia, pregunta DE QUIÉN es el hecho (2026-09-13). | 842 B |
| `L1317` | Una caché compartida se protege con un SELLO, no con una purga — y al retirar el sello, dilo donde estaba (widget, 2026- | 689 B |
| `L1319` | El dominio Grupos pertenece al Apple ID, no al humano: toda frontera de «otro usuario en este device» tiene que SELLARLO | 429 B |
| `L1321` | EXCEPCIÓN al punto anterior, y las tres trampas que trae (C-3, 2026-07-27, `612b21ee`) | 2.9 KB |
| `L1323` | `isCurrentUser` es un flag del canal CloudKit y en el BACKEND nace APAGADO para casi todo el mundo — toda resolución de  | 2.4 KB |
| `L1325` | Duplicar un canal duplica sus ESCRITURAS; sus OBSERVACIONES se quedan atrás, y eso no lo caza ningún test de un canal so | 2.5 KB |
| `L1327` | Una señal puede viajar en NEGATIVO — y entonces el `return` que no deja rastro es un bug de LECTURA, no de escritura (S4 | 372 B |
| `L1329` | Un gate de feature NO puede decidir SI se PARSEA la entrada: solo QUÉ hacer con ella. Y «byte-idéntico al camino viejo»  | 435 B |
| `L1331` | En una frontera de USUARIO el outbox de Grupos y su cursor tienen signos OPUESTOS: uno hay que matarlo y el otro hay que | 3.6 KB |
| `L1333` | El cursor del pull de Grupos (`GroupSyncCursor.groupCursorsJSON`) NO se resetea para «forzar una re-entrega» — es dañino | 1.5 KB |
| `L1335` | Un CONSENT no es una preferencia, y por eso el de Grupos SALIÓ del canal de prefs (C1, 2026-08-11). | 1.8 KB |
| `L1337` | `PreferenceSyncService.remove/set` propaga a la CUENTA, no al device — NUNCA limpiar un consent desde un camino con `.cl | 1.7 KB |
| `L1339` | CARGAR una preferencia no puede ESCRIBIRLA — y el eco de eso convertía al receptor en autor LWW de algo que no escribió  | 373 B |
| `L1341` | El resolvedor canónico de identidad NO es un reemplazo mecánico del flag: contesta otra pregunta en DOS ejes (2026-09-05 | 3.7 KB |
| `L1343` | `ubiquityIdentityToken` mide iCloud DRIVE, no CloudKit — y `.localNoMirror` adjunta el espejo igual, así que usarlo como | 2.0 KB |
| `L1345` | El testigo del mount MIENTE en los hosts de test, y por eso `attachesCloudKitMirror` necesita un seam en cualquier gate  | 2.6 KB |
| `L1347` | Una salida que borra lo local con el espejo montado borra ARCHIVOS antes del mount, nunca FILAS, y solo después de confi | 1.7 KB |
| `L1349` | `CKDatabase.modifyRecordZones` solo LANZA por un fallo de la operación entera: los fallos por ZONA llegan dentro del tup | 1.1 KB |
| `L1351` | Un campo Codable NUEVO y no opcional en el snapshot del App Group apaga TODOS los widgets, y el DTO está DUPLICADO en do | 2.1 KB |
| `L1353` | «ARCHIVOS, nunca FILAS» es una regla sobre el ESPEJO, y el store de Grupos tiene otro camino de salida: su DRAIN. Ahí lo | 2.7 KB |
| `L1355` | Un token que no llega NO es una sesión caducada: pregúntale al SDK si la conserva (2026-09-15). | 2.4 KB |
| `L1357` | El canal personal separa lo mismo desde el 2026-09-16, y cada sitio decide por su cuenta | 2.9 KB |
| `L1359` | La puerta para volver a entrar en la nube es UNA, y el aviso del cierre la nombra (2026-09-25). | 2.1 KB |
| `L1380` | Que `signOut()` volviera no dice que la sesión se fuera: pregúntale a su valor de retorno (2026-09-26). | 1.7 KB |

<!-- INDICE:fin -->

- SIEMPRE `@Relationship(inverse:)` en relaciones bidireccionales.
- Verificar `deleteRule` en cada relación.
- `@MainActor` en servicios que manipulan `ModelContext`.

- **CloudKit compat:** NUNCA `@Attribute(.unique)`, propiedades con default obligatorias, ni relaciones non-optional.

- **Schema del container de GRUPOS — campo nuevo = deploy a Production en el MISMO PR:** todo field key nuevo en records del container de grupos (`CKConstants`/`CKRecordTranslator`) exige desplegar el schema a Production (CloudKit Console) Y actualizar `Cloudkit Schemas/groups-production.ckdb` (snapshot-contrato del schema vivo del container `.groups`; su gemelo `groups_dev-production.ckdb` es del container `.groups.dev` que usa el scheme Yala Dev — desplegar en AMBOS) en el mismo PR — enforced por `CloudKitGroupsSchemaParityTests`. El sim corre grupos SIN CloudKit ⇒ el campo no se autocrea ni en Development; en Production el server RECHAZA todo save del record type y **CKSyncEngine descarta el record de su cola en silencio (NO reintenta rechazos definitivos)** → sync muerto bidireccional e invisible (incidente `isOpeningBalance` 27-jun→1-jul, 4 días). Redes de seguridad en runtime: `recoverUnsyncedRecordsIfNeeded` re-encola al arrancar los records con `ckSystemFieldsData == nil` (nunca hicieron round-trip) y `cloudkitGroupRecordSaveRejected` en TelemetryDeck es el canario (>0 = incidente de schema/permisos activo).

- **`#Predicate` GENÉRICO-PROTOCOLO crashea (`DataUtilities.swift:85`) — usa concreto por tipo:** NUNCA un fetch genérico `func f<T: SomeProto>(…) { FetchDescriptor<T>(predicate: #Predicate { $0.id == id }) }` donde `id` es un **requisito del protocolo** — `$0.id` resuelve al keypath del **witness del protocolo**, que SwiftData NO puede casar con el keypath concreto `\ConcreteType.id` del schema → `Fatal error: Couldn't find \X.<computed …> on X` al EJECUTAR el fetch (SIGTRAP, no atrapable). Síntoma: dos keypaths distintos para `id` en el mensaje. SIEMPRE `#Predicate<ConcreteType> { $0.id == id }` **concreto por tipo** (los concretos resuelven en CUALQUIER `ModelContext`; si necesitas DRY, un genérico que solo EJECUTE un `FetchDescriptor<T>` ya construido concretamente es seguro). Costó el crash de "generar enlace / forzar sync" en Grupos (`fetchByID<T: HasUUID>`/`deleteModel` → 5 helpers concretos `splitGroup/Expense/…(byID:in:)`, protocolo `HasUUID` ELIMINADO como footgun; commit `c74349fc`). El `ModelContext(container)` dedicado NO era la causa (los `#Predicate` concretos del mismo archivo nunca crashearon ahí). **Variante 2 (device, 2026-07-09, spike S6): `localizedStandardContains` sobre una propiedad OPCIONAL coalescada (`(x.note ?? "").localizedStandardContains(y)`) genera `TERNARY(...) CONTAINS[cdl]` que el SQL de SwiftData NO implementa → `NSInvalidArgumentException` en SQL generation, excepción ObjC que el `do/catch` de Swift NO atrapa (crash).** Compila limpio; solo revienta al EJECUTAR contra el store. Patrón seguro probado en device: igualdad exacta (`$0.note == x`, disjunción de variantes conocidas si hace falta). Si necesitas substring de verdad sobre opcional, testéalo en device ANTES de confiar en él (commit `4a270b4a`).

- **Acciones post-accept de un CKShare = intent PERSISTENTE reconciliable, nunca one-shot (bug Pia 2026-07-11):** toda acción tras `container.accept` que dependa de estado local sincronizado (p.ej. crear el `SplitMember` del invitado, que exige el `SplitGroup` de la zona) NUNCA debe ser un one-shot gateado por `if let` sobre estado que puede no haber llegado — la zona compartida tarda ≥60s en bajar (ventana export-only) y el skip silencioso deja al usuario "unido" sin member: el owner jamás recibe la solicitud y NADIE lo reintenta. Patrón vigente: `PendingJoinStore` (intent persistente, TTL 7d) + `GroupJoinReconciler` (3 triggers: acceptShare/boot/foreground, decisión pura en `GroupJoinReconcileLogic`) + `GroupJoinIntentTracker` (@Observable — la UI muestra la fase REAL; el "¡Todo listo!" del onboarding SOLO con member confirmado, jamás como fallback defensivo). Corolario de notifs: en el PRIMER import de una zona recién unida los members preexistentes clasifican como "nuevos" → `MemberChangeNotificationLogic` exige baseline (`SplitGroup.initialMemberImportStartedAt`, set en applyGroupMeta rama NUEVO, clear en `didFetchRecordZoneChanges`, ventana 15 min auto-sana) + autoexclusión por identidad (`memberID` del record vs `cachedRecordName`) — sin eso, el invitado recibía "Jür se unió al grupo" por el member del owner.

- **`context.hasChanges` y lo que llega al canal de sync NO son la misma señal, y confundirlas justifica guards por razones falsas (medido el 2026-09-08).** Asignar a un `@Model` un valor **idéntico** al que ya tenía deja `context.hasChanges == true`, pero el `drainOnce` del motor **no produce ni una fila de `SyncOutbox`**: el change-set que el History entrega al drain (`CloudSyncEngine.translateChange` → `typed.updatedAttributes`) no es el estado sucio del contexto. Medido con el motor real y su control positivo en `YalaTests/FXRepairQueueTests.swift` (`FXRepairQueueOutboxTests`): tras el insert 1 fila, tras la reescritura idéntica **1**, tras un cambio real **2**. ⇒ **una reescritura idéntica NO emite, NO expande el grupo de coherencia y NO sella un HLC nuevo**, así que no puede pisar por LWW la edición de otro dispositivo. El ticket `repair-queue-has-no-exit-for-partial-rate-rows` daba por hecho lo contrario y colgaba de ahí dos de sus tres daños; los dos eran falsos. **Lo que sí ahorra un guard de igualdad es el `save()`** —contexto sucio = escritura a disco— y que `hasChanges` deje de mentirle a quien lo consulte después, que no es poco pero es otra cosa. **Al escribir un guard de igualdad «para no emitir», mídelo antes**: `updatedAttributes` aparece cuatro veces en todo el repo y ninguna documenta este comportamiento, así que la intuición no tiene dónde apoyarse. Y la forma de medirlo NO es leer el estado final —re-escribir el mismo valor deja el store idéntico y el mutante no cae— sino **contar filas de outbox tras un `drainOnce`**, con el andamio de `CloudSyncEngineTests` (containers on-disk con los tres stores: el History es por-CONTAINER). **Y el History no le entrega al drain una actualización vacía: no le entrega
  NINGUNA** (medido el 2026-09-11 con el mutante M15 del paso 9, que le quita el `> 0` a
  `PersonalExportPendingCounter` y deja verde el test de la reescritura idéntica). ⇒ un filtro por
  `updatedAttributes.isEmpty` río abajo es cinturón sobre tirantes, y **ningún test puede matarlo**: no lo
  escribas creyendo que es él quien produce el cero, ni lo pongas como la explicación de un test verde.

- **Lazy M2M con CloudKit — CSV mirror:** cuando una `@Relationship` M2M `[Type]?` es crítica para correctness (cálculos, filtros, displays) y la app corre en cold start con sync activo, **duplica el filtro como CSV de UUIDs** en el mismo record. Patrón replicado en `Budget.subcategoryIDs/accountIDs/tagIDs` y `TransactionItem.tagIDs`. Helpers: `setFilters(...)`/`setTags(from:)` para dual-write; `resolvedXIDs(scheduleBackfill:)` para read CSV-first con M2M fallback y auto-cura async. La relación M2M queda solo para cascade `.nullify` automático. Razón: SwiftData/CloudKit puede entregar el record con relaciones lazy `nil` mientras espera que lleguen los Tag/Subcategory/Account records — el código pre-fix interpretaba `nil` como "sin filtros" → comportamiento catastrófico. Naming asimétrico aceptado: `Tag.id`, `Subcategory.shortcutID`, `Account.shortcutID`, `Budget.id`. Backfill eager en bootstrap **solo para Budget** (pocos records); TX usa lazy on hot path (miles de TX, eager sería caro).

- **CSV mirror — stale ≠ nil al regenerar un UUID de identidad (commit `899c1c25`):** `resolvedXIDs(scheduleBackfill:)` (y los `resolved*` de Budget) leen **CSV-first y SOLO caen a M2M si el CSV es `nil`**. Un CSV *stale-pero-presente* (apunta a un UUID que ya no existe — p.ej. tras regenerar un id de identidad) NO cae a M2M → `byIDLookup` no lo resuelve → display/filtro queda **huérfano permanente** (no auto-sana). ⇒ **regenerar cualquier UUID de identidad (`Tag.id`/`Account.shortcutID`/`Subcategory.shortcutID`) OBLIGA a reconstruir TODOS los mirrors que lo referencian con _nuke-on-nil_**: si la M2M forward viene `nil` (ventana lazy en paths sin quiescencia: force-sync/DEBUG), escribir `encode((m2m ?? []).map(\.id))` (= nukea el CSV → fuerza el fallback a M2M en la próxima lectura), NUNCA saltar (dejar el CSV stale orfanaría permanente). El colapso de estos UUIDs (CloudKit entrega el record sin el campo → default `UUID()` evaluado UNA vez y compartido) lo auto-cura `CategoryDeduplicationService.repairCollapsedIdentityUUIDs` (repetible, gateado por quiescencia, regenera solo colisionados vía `collidedUUIDItems`/`regenerateDuplicateUUIDs` + reconstruye mirrors); la migración one-shot **difiere** si el primer import de CloudKit no se asentó (`MigrationGateLogic.shouldDeferMigration`) para no regenerar sobre datos parciales y quedar bloqueada por su sentinel.

- **Sync de Grupos (CKSyncEngine) NO debe arrancar/`save()` sobre el `mainContext` compartido antes de que el primer import personal de CloudKit se asiente — crash-loop en restore de iCloud** — el caso entero (10 KB): [Sync de Grupos (CKSyncEngine) NO debe arrancar/`sa…](../../docs/aprendizajes-tecnicos.md#sync-de-grupos-cksyncengine-no-debe-arrancarsave-sobre-el-maincontext-compartido-antes)

- **Lo que el gate de quiescencia DIFIERE solo se recupera solo si es un evento de CloudKit. Si es una INTENCIÓN, el diferido tiene que ser DURABLE — y su par no se puede romper a mitad (fix 2026-07-30).** — el caso entero (15 KB): [Lo que el gate de quiescencia DIFIERE solo se recu…](../../docs/aprendizajes-tecnicos.md#lo-que-el-gate-de-quiescencia-difiere-solo-se-recupera-solo-si-es-un-evento-de-cloudkit-si-es)

- **El guard G6-3 es TAMBIÉN lo que impide avisos DUPLICADOS mientras los dos canales conviven (Fase 2, 2026-07-29). No lo debilites sin mirar esto.** Los re-cableos 2.1–2.3 **duplican** lógica a propósito: el canal backend gana su copia de notificaciones/freeze y el transporte CloudKit **conserva la suya** hasta que la Fase 3 la borre (estado estable declarado en el plan). Eso plantea la pregunta obvia —¿el usuario recibe dos avisos del mismo cambio?— y la respuesta es NO, por una razón de ORDEN que no está dicha en ningún commit: `backendZoneNames` se calcula en `SplitSyncManager.swift:1562` y descarta los records de grupos backend en **`:1610`** (y las deletions en `:1672`), mientras que `pendingBridgeChangeSet` —lo que alimenta `GroupNotificationService.processRemoteChanges`— no se rellena hasta **`:1723`**. ⇒ **un grupo del backend NUNCA entra en el changeset del transporte**, así que cada grupo notifica por exactamente un canal según el suyo. **Si alguien debilita ese guard, mueve el relleno del changeset por encima del descarte, o borra el lado del transporte en la Fase 3 sin comprobar que el del backend ya emite, aparecen avisos duplicados y NINGÚN test lo caza** (los tests de notificaciones ejercitan un canal a la vez). Al abrir la Fase 3, verificar este orden antes de borrar el emisor del transporte. **[CUMPLIDO Y CERRADO, 2026-08-06 — no hay nada que verificar aquí: la Fase 3 se abrió y el emisor del transporte YA SE BORRÓ.** Con `SplitSyncManager` fuera queda un solo canal, así que la duplicación que este bullet previene es hoy **inalcanzable por construcción** y sus tres coordenadas (`:1562`/`:1610`/`:1723`) apuntan a un fichero que no existe. Se conserva por la lección viva, que no era el orden sino su forma: **un guard puede estar impidiendo un daño del que nadie habla, y al retirar uno de dos canales hay que comprobar que el que se queda EMITE, no solo que el que se va calla.**]

- **[STALE, medido 2026-08-03 — el código que describe ya NO EXISTE: `applyRemoteRecordIfAbsent` y `GroupPullRescueGate` dan CERO ocurrencias en `Yala/` y en `YalaTests/`, borrados con el uploader en `5010db6a`. Se conserva por el corolario del History por-CONTAINER, que sí sigue vivo, y como registro de por qué el rescate existió.]** — el caso entero (3 KB): [[STALE, medido 2026-08-03 — el código que describe…](../../docs/aprendizajes-tecnicos.md#stale-medido-2026-08-03--el-cdigo-que-describe-ya-no-existe-applyremoterecordifabsent-y)

- **`DefaultHistoryToken` es POR-STORE, y un drain que ancla su high-water en el store equivocado queda ciego al suyo PARA SIEMPRE (bloqueante del épico, medido en producción 2026-07-31, dos iPhones, build 8, rollout 100 %).** — el caso entero (15 KB): [`DefaultHistoryToken` es POR-STORE, y un drain que…](../../docs/aprendizajes-tecnicos.md#defaulthistorytoken-es-por-store-y-un-drain-que-ancla-su-high-water-en-el-store-equivocado-q)

- **Un borrado tiene DOS mitades y el camino remoto solo copió una: la fila del grupo se borra, el PUENTE personal se queda (device, producción, 2026-08-02, build 9, dos iPhones).** — el caso entero (15 KB): [Un borrado tiene DOS mitades y el camino remoto so…](../../docs/aprendizajes-tecnicos.md#un-borrado-tiene-dos-mitades-y-el-camino-remoto-solo-copi-una-la-fila-del-grupo-se-borra-el)

- **Un gate por ZONA calculado sobre filas VIVAS es la herramienta equivocada para un tombstone por FILA — y con un duplicado deja de frenar justo cuando más falta hace (2026-08-02, mismo fichero y mismo día que la regla de arriba).** — el caso entero (48 KB): [Un gate por ZONA calculado sobre filas VIVAS es la…](../../docs/aprendizajes-tecnicos.md#un-gate-por-zona-calculado-sobre-filas-vivas-es-la-herramienta-equivocada-para-un-tombstone-por)

### Modo Nube · el par `.cloud` + `mirrorOffArmed`

- **El par que apaga el mirror NO se puede hacer atómico ni invertir: se enforcea en el CONSUMIDOR (C-1, commit `246a6939`).** `SwiftDataConfiguration.personalStoreDecision` monta el store personal mirror-OFF solo con el par COMPLETO (`storageMode == .cloud` **Y** `mirrorOffArmed`), y ese diseño es correcto: armar antes de que el `CloudMigrationMarker` exporte relanzaría con el mirror OFF y el marcador **jamás** llegaría a CloudKit (migración irrecuperable, SERIO-1). Tres salidas que parecen obvias y **están cerradas**: (1) **invertir el orden** deja la mitad `armado + .icloud`, y `CloudMigrationUIStateDeriver.derive` la lee como `needsRelaunch(.toCloud)` **sin mirar `storageMode`** ⇒ tras el relanzamiento el modo sigue `.icloud` ⇒ tarjeta «cierra y vuelve a abrir» **en bucle sin salida**; (2) **transaccionalidad**: `UserDefaults` no la tiene, dos `set` consecutivos nunca son atómicos; (3) **un tercer estado durable** («grant») convierte un estado sucio preexistente en uno *legal-looking*. ⇒ **El invariante real es operativo, no de escritura**: ningún estado durable puede tener `.cloud` + mirror-off SIN armar **en una fase journaleada ESTABLE**. Lo enforcea `MigrationRuntimeGate.canRun(phase:cloudWithMirrorOn:personalMountMismatch:)` (consumido por `CloudSyncRuntime.canRunDomain` a través de su variante `canRun(read:…)`, que con el journal ilegible no arranca — regla siguiente), con `StorageModePersistence.isCloudWithMirrorOn` como aserción y `writeCloudArmed` como escritor único del par. **Por qué importa y dónde muerde: `notStarted` ES fase estable** (device ADOPTADO, #30), así que un par a medio escribir —kill entre las dos keys del adopt (`runAdoptFlow`), o cierre de reversa a medias— dejaba pasar el gate con el mirror MONTADO ⇒ **motor de sync Y espejo de CloudKit escribiendo el mismo store**, sin ningún gate de fase que lo notara. En `.icloud` el predicado es `false` por construcción ⇒ inerte para el 99 % de usuarios de 2.x (pinneado en ambos valores del flag por `StorageModePersistenceTests`).

- **Un journal que no se deja leer NO es `notStarted`, y una lectura no escribe (2026-09-22).** Ticket
  `an-unreadable-migration-journal-reads-as-never-started`. Hasta ese día el `catch` del `fetch` de `MigrationState`
  devolvía `notStarted` en los DOS lectores (`MigrationPhaseStore`, `CloudMigrationController`), y `notStarted` es la fase
  estable más ancha: motor en marcha, BGTasks sin gate, remap emitido. El del controller además ponía a cero los seis
  motivos de la tarjeta —y `hasPendingReverseExit`, el freno de una vuelta nueva encima de una salida a medias—. Seis
  cosas que no se tocan sin romperlo:
  (1) **la lectura fallida es `JournaledPhaseRead.unreadable`, no un case de `MigrationPhase`**: ese enum se journalea con
  fixtures APPEND-ONLY y sus `switch` clasifican fases por las que la máquina PASA. Sin fila sigue siendo
  `.phase(.notStarted)`, que ahí sí es verdad;
  (2) **`MigrationPhaseStore.currentPhaseRead` devuelve la LECTURA**, y el nombre viejo (`currentPhase`) no existe a
  propósito: un getter de `MigrationPhase` al lado es la trampa puesta para el consumidor siguiente. Los siete deciden
  hacia el lado que no concede, cada uno con su variante `read:` pura — BGTasks con la disciplina TRANSITORIA
  (`BGTaskMigrationGate.decide(read:)`: el lector suspende y el escritor exige quiescencia, así que con quiescencia
  CORRE), motor parado (`MigrationRuntimeGate.canRun(read:)`), remap bloqueado, drenaje iKV sin drenar
  (`PrefsCutoverDrain.isLeaderPostRelaunchPhase(_ read:)`);
  (3) **la ventana de captura de identidad se APLAZA, no se decide** (`identityCaptureDerivationPending`): encenderla por
  las dudas contradice «no se enciende globalmente» y un prewarm la encendería en medio parque; dejarla apagada pierde la
  identidad de lo creado en la ventana, porque el flag vive en memoria y solo se deriva en `configure`. La primera lectura
  buena de `currentPhaseRead` hace la derivación, **y cada primer plano la provoca**
  (`deriveDeferredIdentityCaptureIfNeeded`, desde `AppBootstrapper.handleBecameActive`): en `.icloud` —casi toda la
  ventana— ni el motor ni el remap ni el drenaje llegan a leer la fase, y sin ese hook la lectura buena esperaba a un
  BGTask. El swap de persona suelta el pendiente;
  (4) **el controller tiene UN lector** (`readJournal()`) sobre una función pura (`MigrationJournalRead.read`) cuyo caso
  `.unreadable` no lleva valores: la rama ilegible solo marca `isJournalUnreadable` —rastro en la TRANSICIÓN, porque la
  pantalla lee cada segundo— y los seis motivos conservan el último valor leído. `readJournalDecisionInputs()` devuelve
  `nil` y `resumeIfNeeded`, `rekickIfParked` y `startRuntimeIfStable` no deciden nada, y `startMigration`/`startReverse`
  vuelven a leer antes de empezar (sus confirmaciones cuelgan de la RAÍZ de la pantalla y sobreviven al cambio de
  estado). **El re-kick de cada primer plano refresca** una pantalla que se quedó en `.journalUnreadable` y ya lee, **y
  arranca el motor si quedó `.idle` con la fase estable**: un arranque ilegible deja `CloudSyncRuntime` en `.idle`, que
  ni `handleBecameActive` re-evalúa ni el boot vuelve a mirar, así que un teléfono en la nube se quedaba sin sincronizar
  hasta relanzar, con «Todo sincronizado» en pantalla (lo cazaron dos lentes de la review). Solo `.idle`: `startShared`
  re-arranca todo lo que no sea `.running`, y un `.stoppedUntilRelaunch` no se toca;
  (5) **la pantalla tiene su estado, `CloudMigrationUIState.journalUnreadable`**: tarjeta honesta, ningún botón que mueva
  los datos y la sección de Grupos conservada (como `.failed`: puede durar). El relanzamiento de IDA sigue ganando porque
  no mira la fase (`needsForwardRelaunch`, un solo sitio para las dos derivaciones). `canCancelMigration` y
  `canCancelReverse` dan `false` mientras dure: `journaledPhase` es la última fase LEÍDA y sin ese término el `.onChange`
  no bajaría un diálogo abierto. **No cuenta como `isEngaged`** (`StorageRowGateLogic.isEngaged`, `switch` exhaustivo,
  el único sitio de ese término): con el `!= .idle` de antes abría la fila bajo el kill a quien nunca empezó y apagaba
  `abortIfCloudEntryClosed`. **El Welcome lo lee como «sin dato en este tick»** (`CloudWelcomeSignInFlow.phase` devuelve
  `nil` y la pantalla se queda como estaba): un `.error` ofrecía volver al chooser con el adopt quizá aparcado y un
  «Reintentar» que repetía el sign-in entero; el `claimBlocker` del runner sí gana;
  (6) **los cuatro `try?` de la pantalla, uno a uno**: la cola que no se cuenta ofrece firmar SIN cifra
  (`pendingUploadCount == nil`), el mapa que no se cuenta es `ReverseEligibility.mapUnreadable` (el born-cloud de este
  dispositivo sigue elegible: no necesita el mapa), «Ver qué migraría» no enseña ceros inventados
  (`MigrationDryRunPreview.unreadable`) y el marcador que no se cuenta se lee «no hay», que es el lado seguro por la regla
  de las dos capas de «Migrar». Lo fija `MigrationJournalUnreadableTests` (lógica pura con control positivo y el cuerpo
  entero de cada rama) y el XCUITest `StorageJournalUnreadableUITests` (seam `-uitest-migration-journal-unreadable`).
  **Y una fila que se lee pero no se ENTIENDE también es `.unreadable` (2026-09-25,
  `an-undecodable-migration-phase-reads-as-never-started`).** `readPhase()` y `readPendingEffects()` rellenan con
  `notStarted` y `[]` cuando un blob presente no decodifica —el único camino real es un DOWNGRADE desde un build con un
  case nuevo, que los fixtures APPEND-ONLY no pueden impedir—, y esos rellenos conceden. El testigo es UNO,
  `MigrationState.isJournalUndecodable` (fase, pendientes y pendientes del origen de la vuelta, más los dos raw cuyo
  relleno concede: `forwardClaimIntentRaw` → `.adoptIfExisting` y `reverseOriginRaw` → `.done`, con su `nil` legítimo
  fuera), y lo consultan los dos
  lectores y el runner. **El runner para y NO toca la fila**: hasta ese día la «normalización» M1 la reseteaba a
  `notStarted` sin pendientes en cada entrada, lo que borraba una migración en vuelo y hacía cosmético cualquier arreglo
  de los lectores (el primer `resume()` dejaba la fila en `notStarted` de verdad). El chequeo va en `runGuarded`, no en
  cada entrada: una entrada pública nueva lo hereda sin acordarse. La salida es actualizar Yala; el build que escribió la
  fila la retoma donde estaba. **Si añades un blob Codable al journal, entra en `isJournalUndecodable`.** Lo fijan
  `MigrationJournalUndecodableTests` y la §17 de `MigrationRunnerTests` (seis entradas × cinco campos, con control y un
  pendiente CONOCIDO sembrado: sin él la columna de la fase pasaba sola, porque el relleno `notStarted` ya cortaba).

- **El push-all del cierre de sesión también pasa por el candado del motor, y «pendiente» incluye el History (2026-09-25).**
  Ticket `sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate`. `syncCycle` no mira `canRunDomain()`; su único
  llamador de producción es el push-all del cierre en la nube, y con el journal ilegible, una fase transitoria o el espejo
  montado corría drain + push + pull que el motor no podía correr. Tres cosas que no se tocan sin reabrirlo:
  (1) **el candado se consulta antes de CADA ciclo** (`CloudMigrationController.pushAllForSignOut`), no solo al entrar;
  (2) **cerrado, sin drain y sin red**, y decide `CloudSignOutFlowLogic.pushAllVerdictWithoutEngine`: sigue al borrado —que
  es la salida del estado: se lleva sesión, sync-meta y la fila del journal— solo sin filas vivas **y** sin ediciones
  personales en el History que ningún drain capturó (`CloudSyncEngine.hasUncapturedPersonalChanges`, SOLO LECTURA: no crea
  el cursor). Mirar solo el outbox borraba en silencio lo editado con el motor parado, que en `.reverseFailedRollback`
  pueden ser días. Token roto o fetch que lanza es `nil` y bloquea;
  (3) **con pendientes bloquea con el motivo del candado** (`engineStoppedReason(read:)`, desde el 2026-09-25): su aviso
  nombra la salida real y no la conexión (`cloud-signout-with-the-engine-stopped-says-check-your-connection`). Y con el
  candado abierto, el paso 1 del cierre separa la subida que no llegó y la sesión caducada con el testigo del motor
  personal (`CloudSyncRuntime.stoppedByFailedUpload(for:)`, `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`). Grupos no entra: su canal corre su propio loop justo
  con el candado personal cerrado. Lo fija `CloudSyncRuntimeTests` (`signOutPushAll_*`, `uncapturedProbe_*`).

- **En el apply del pull, «no pude leer» NUNCA es «no hay nada» (2026-09-22).** La lectura LANZA y la página no
  se aplica. Ticket `apply-overwrites-a-pending-local-write-without-its-guards`. Todo lo que `applyPage` lee
  para no pisar datos lanza si el fetch falla, y el `catch` que ya existía hace rollback, devuelve `false` y el
  cursor no se mueve ⇒ `.transient` y reintento con el backoff del ciclo. Son: `buildPendingGuards` (un guard
  PARCIAL es peor que ninguno porque parece uno: deja que un remoto pise una escritura pendiente y el drain la
  lava bajo HLC fresco), `existingQuarantineSeqs` (vacío ⇒ cuarentenas duplicadas; se lee SOLO si la página trae
  algo sin cablear), la búsqueda de la fila (`find*`: «nil» haría un tombstone no-op con el cursor avanzado, o un
  born-remote DUPLICADO), `findSyncIdentity` y el reloj por unidad (`SyncUnitClockStore.upsertChecked`/
  `deleteChecked`: sin `.unique`, un `nil` inserta un SEGUNDO reloj que el reconciler de transferencias puede leer).
  Fuera de `applyPage`: `drainQuarantineOnce` no drena con el guard ilegible, y `deleteLiveRows` lanza ⇒
  `sweepZombies` hace rollback y devuelve `.transient` (antes «0 borradas» daba el barrido por hecho).
  **La trampa para el próximo llamador:** en `EntityApplyMap` conviven `find*` (lanza) y `fetch*` (`lenient`:
  convierte el fallo en `nil`). Quien DECIDE crear o borrar una fila usa `find*`; `fetch*` queda para leer una
  señal. El reloj por unidad del DRAIN dejó de ser tolerante el 2026-09-23 (regla «Y el drain tampoco», más abajo).
  Seams: `CloudSyncEngine._testThrowOnApplyRead` y `EntityApplyMap._testThrowOnFetchOf` (ESTÁTICO:
  resetéalo en `defer` y cuenta con que los tests corren con el paralelo apagado).

- **Y las refs colgadas tampoco (2026-09-23).** Ticket `dangling-ref-repair-is-lost-when-its-row-cannot-be-read`. El
  `SyncDanglingRef` es el ÚNICO sitio que guarda el UUID del destino de una ref singular (no tiene espejo CSV), así que
  toda lectura que decide sobre él es de las de arriba:
  - **Pase final**: `reresolveDangler` lee la fila y el destino con `find*`, y una lectura que lanza devuelve
    `DanglerOutcome.unreadable`, que CONSERVA el dangler. `.rowGone` es solo la ausencia leída de verdad; antes un
    fetch fallido se leía `.rowGone` y, con la base entera ilegible, se borraban todos los danglers de golpe. Un
    dangler ilegible no frena a los demás del pase: son independientes, y el pase se reintenta en cada ciclo. Deja
    rastro con `CloudSyncBreadcrumb.danglersUnreadable(count:)`, no con `applyPageFailed`: el pase guardó y el cursor
    no está atascado.
  - **Appliers**: `ColumnApplier.apply` es `throws`, y `resolveRef`, `clearDangler`/`registerDangler` y las lecturas
    M2M (`findTags`, `findAccounts`, `findSubcategories`) lanzan ⇒ se tira la página entera. No basta con «no pisar la
    ref»: el cursor avanzaría con el valor del wire sin aplicar ni apuntar. Los únicos llamadores de los appliers son
    `applyPage` y `drainQuarantineOnce`, los dos con rollback. **Un applier nuevo que lea algo usa una lectura que
    lanza**, y un llamador nuevo de los appliers tiene que envolverlos en un save con rollback.
  - La trampa que esto cierra, para no reabrirla: tragado el fetch del registro, la nota NUEVA no se escribía (fila sin
    ref y sin rastro del destino) o la VIEJA se quedaba viva, y al llegar su destino el pase final re-adjuntaba una
    relación que el wire ya había cambiado. Un `nil` tolerante ahí daría además un dangler DUPLICADO (no hay `.unique`).
  - **Intercambio aceptado**, el mismo de #216: una tabla que NUNCA se deja leer deja el pull en `.transient` (backoff,
    tope 300 s) en vez de avanzar degradado. Con los tags el CSV salvaba casi todo; ahora esa página espera.
  Lo fijan los casos con el seam y control positivo de `SyncApplyEngineTests` (entre ellos, las 18 ramas del pase y
  los 25 appliers que leen, uno a uno y con un scan de su zona: un `fetch*` tolerante compila limpio porque sigue vivo
  para `liveRowExists`), `CloudSyncWiredEntitiesTests` y `SyncQuarantineDrainTests`.

- **Y el drain tampoco (2026-09-23).** El reloj por unidad se LEE antes de escribir, el drain que falla deshace lo
  suyo, y quien decide algo leyendo el outbox pregunta si el drain terminó. Ticket
  `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read`. El drain, `enqueueSnapshotRows` y `emitIdentityRemap`
  leían el `SyncUnitClock` con `row`, que convierte el fallo en `nil`: el upsert insertaba un SEGUNDO reloj para el
  mismo `syncID` (sin `.unique`) y el tombstone dejaba el viejo vivo. Cinco cosas que no se tocan sin romperlo:
  - **Leer antes de escribir, no escribir y deshacer.** Los tres pasan por `SyncUnitClockStore.prepareWrites`, que lee
    el reloj de cada `syncID` del lote y LANZA antes de la primera inserción; `PreparedWrites.apply` ya no lee ni lanza,
    y una segunda escritura del mismo `syncID` ve la primera sin volver a leer. Así da igual si el llamador hace
    rollback: `enqueueSnapshotRows` no lo hace y su contexto puede llevar ediciones del usuario.
  - **No hay `upsert`/`delete` que traguen el error**: se retiraron. Quien decide insertar o borrar un reloj usa
    `upsertChecked`/`deleteChecked` o el lote; `row` y `unitHLC` quedan para LEER una señal (el reconciler).
  - **El rollback del drain cubre los pasos 6-7 y nada más** (save del outbox y del cursor): desde el barrido del paso 2,
    que guarda todo lo pendiente, lo único sucio en el contexto es del drain. En el `catch` general borraría ediciones
    del usuario sin guardar si fallara el propio barrido, y eso no tiene seam: lo fija un scan que empareja llaves en
    `DrainUnitClockUnreadableTests` (el `do` del rollback abre DESPUÉS del barrido y encierra los dos saves; ningún
    rollback dentro de `sweepAndBuildLookups`). **Si falla el save del OUTBOX se retiran también sus entradas del
    espejo**, que se escriben antes a propósito (Q3): sin eso, `rehydrateOutboxFromMirror` —diff incondicional en cada
    arranque— re-insertaba y subía unas filas deshechas. Si falla el del cursor, las filas ya están en disco y su espejo
    se queda: es la semántica de un kill entre 6 y 7.
  - **`drainOnce` devuelve si terminó, y es la pieza que más cuesta ver** (lo cazó la review, en MI fix): antes, un
    save del outbox fallido dejaba sus filas SUCIAS en el contexto, y un fetch del outbox las veía; con el rollback ya
    no están ni ahí. ⇒ quien lee el outbox tras un drain para decidir algo no puede seguir con `false`: el pull no
    aplica la página (el guard D-1 no vería la edición y la pisaría), el drenaje de cuarentena del arranque espera, y
    la verificación, la reconciliación del líder, el drenaje de la vuelta y la subida del snapshot salen como avería
    LOCAL (`.blocked(.localFailure)` o el `notWired` retomable del líder), igual que con el outbox ilegible. **Un
    llamador nuevo de `drainOnce` que lea el outbox después, lo comprueba**; el scan
    `drainCallersThatReadTheOutbox_checkThatItFinished` cuenta los que no lo hacen, cada uno con su porqué. `true` no
    cubre la traducción cortada por deriva del reloj: ticket
    `clock-drift-aborted-drain-lets-the-pull-overwrite-untranslated-edits`.
  - **El de Grupos también devuelve si terminó (2026-09-26), y ahí la traducción cortada SÍ es `false`**
    (`GroupsSyncClient.drainOnce`, ticket `groups-drain-failure-reads-as-nothing-pending`). Sus lectores no son el
    pull sino gestos que BORRAN —cierre, desasociar, «Empezar de cero»—, y lo que queda detrás del corte es justo lo
    que se perdería. No lo llaman a pelo: pasan por la captura de salida (`captureLocalWritesForExit`: rehidratar el
    espejo → drenar → barrer) y deciden con `CloudSignOutFlowLogic.groupsCaptureVerdict`, que con el outbox a 0 exige
    además la captura completa y el espejo sin entradas fuera del outbox. **Un gesto nuevo que borre el outbox o el
    espejo de Grupos pasa por ahí**, y el push-all re-captura tras cada ciclo que lo deja a 0: el drain del ciclo no
    viaja en su outcome. Con la traducción cortada tampoco se re-ancla el token (saltaría el corte).
  - **Y el drain de Grupos estampa con `HLCClock.sendLocal(eventTime: tx.timestamp)`, no con `send` (2026-09-26,
    ticket `groups-clock-rollback-wedges-the-drain-forever`).** Con `send`, un reloj lógico persistido más de 5 min por
    delante de la transacción (la hora del iPhone adelantada y devuelta) lanzaba la deriva en la MISMA transacción en
    cada vuelta: la fecha de la transacción no sube y el reloj lógico no baja. Nada de grupos subía y las tres salidas
    se bloqueaban con un «inténtalo en un rato» que esperando no se cumplía. Tres cosas que no se tocan sin reabrirlo:
    (1) **no vuelvas a `send` ni a `max(tx.timestamp, ahora)`**: el primero encalla; el segundo rompe el determinismo del
    que depende el dedup `(syncID, hlc, op)` de un re-drain (lo fija `drain_stampsWithTheTransactionTime_notWithNow`,
    con el `now` del cliente tres días por delante: en el régimen adelantado `max(l, pt)` da `l` y no distingue las dos
    variantes); (2) **el contador agotado avanza 1 ms** en vez de lanzar: con el reloj meses por delante los 65 536
    valores se gastan; (3) **`send` no cambia**: lo usan el canal personal, las prefs y el banco de vectores, y varios
    consumidores tratan su deriva como pasajera a propósito. **El precio, aceptado y con ticket**
    (`groups-clock-ahead-wins-every-conflict-until-real-time-catches-up`): hasta que la hora real alcance al reloj
    lógico, lo que ese teléfono escriba gana por LWW a lo que otros miembros escriban en esas filas —también un borrado
    suyo: el tombstone ajeno sale `noop`—, y el servidor no pone tope a un HLC futuro. Y el orden propio dura lo que
    viva `GroupSyncCursor.clockLatestHLC`: el cierre de sesión lo borra, el reloj vuelve a la hora real y una edición
    posterior de una fila que este teléfono selló adelantada sale `all_units_stale`. El gemelo personal
    (`CloudSyncEngine.appendRow`) sigue con `send`: `personal-clock-rollback-wedges-the-drain-forever`.
  - **Intercambio aceptado**, el de #216: cualquier drain que aborte —también por causas anteriores a este ticket, como
    un save del barrido que falla— deja ahora el pull en `.transient` en vez de aplicar. Y tras un fallo del save del
    cursor, un `applyPage` que corra antes del re-drain persiste un reloj mayor y el replay encola filas DUPLICADAS
    (HLC distintos): el backend las resuelve por LWW, cuesta tráfico, no datos.
  Rastro: `CloudSyncBreadcrumb.drainAborted(errorType:)`, en el `catch` general (toda vuelta abortada). Seams:
  `EntityApplyMap._testThrowOnFetchOf = ["SyncUnitClock"]`, `CloudSyncEngine._testThrowOnDrainOutboxSave` y
  `_testThrowOnDrainCursorSave`. Residual con ticket: los relojes duplicados que ya estén en disco no se funden
  (`unit-clocks-duplicated-before-the-fix-are-never-merged`).

- **Y el Merkle tampoco, en ninguno de los dos canales (2026-09-22 personal · 2026-09-23 Grupos).** Una tabla que no
  se deja leer NO se hashea como tabla vacía: `[]` entra al ensamblado como `sha256("")`, byte a byte el hash de una
  tabla sin filas. Con el servidor poblado eso salía `.diverged` —en Grupos, cursor a 0 y el grupo entero de vuelta; en
  el personal, canario y presupuesto de MISMATCH de la vuelta a iCloud—, y con el servidor vacío convergía en falso.
  Tickets `verify-reads-a-failed-local-fetch-as-an-empty-outbox` y `groups-merkle-reads-an-unreadable-table-as-an-empty-one`.
  - `SyncMerkle.computeLocalMerkle` y `GroupMerkleProjection.computeLocalMerkle` LANZAN; su único consumidor lo
    convierte en `.skipped(… localMerkleFetchFailed)`, y un skip nunca cuenta, ni remedia, ni es canario. En Grupos el
    guard [R4] de remoto-vacío exige `!localEmpty` y por eso NO lo paraba: no confíes en él para esto.
  - La fila que no canonicaliza sigue SALTÁNDOSE con rastro (`encodeRejected`): el resto de la tabla sí se leyó.
  - Los motivos de Grupos viven en `GroupMerkleSkipReason`, **no** en `MerkleSkipReason`: el `all` de éste es el
    canario de motivo desconocido de `VerifyProbeMapping` (canal personal). Un motivo nuevo de Grupos va allí.
  - Seams: `SyncMerkle._testThrowOnDanglingFetch`/`_testThrowOnLeafFetch` y `GroupMerkleProjection._testThrowOnLeafFetchOf`
    (un CONJUNTO de tablas: con un `Bool` el primer fetch corta y los otros cuatro `catch` son inalcanzables; y lanza
    un `CocoaError`, no el error propio, para que el test solo pase si el `catch` real lo convierte). ESTÁTICOS:
    resetéalos en `defer`. Rastro: `CloudSyncBreadcrumb.merkleLocalReadFailed(stage:)` y
    `GroupsSyncBreadcrumb.groupsMerkleLocalReadFailed(table:)`; ningún test los fija (el `Logger` no tiene sink).

- **Y los inventarios de la migración tampoco (2026-09-23).** Una tabla que no se deja leer NO es una tabla sin filas:
  los seis recorridos por las 16 entidades —snapshot de la ida, captura de identidad, los dos inventarios del adopt, el
  fetch de sus huérfanas y la muestra de la vuelta— saltaban la tabla bajo un `print` de `#if DEBUG` y seguían con el
  resto como si fuera el corpus entero. El snapshot la daba por subida (con la última tabla ilegible, `.completed`), el
  adopt apagaba su guard anti-fusión con un `uploadCount == 0` falso y se cerraba con `completed(uploaded: 0)`, y la
  muestra de la vuelta contaba menos pendientes: un avance falso para el techo o un `.drained` sin datos en iCloud.
  Ticket `an-incomplete-inventory-reads-as-the-whole-corpus`.
  - Todos LANZAN y cada llamador usa el desenlace de «avería local» que su camino ya tenía: el snapshot,
    `.blocked(.localFailure)` (techo corto); la identidad, el `throw` de `assignIdentity` (`driveIdentity` lo convierte
    en `.localFailure`); el adopt, `.transient` retomable; la vuelta, `ReverseUploadStatus.unreadable`, que **ni cierra
    ni cuenta como avance** (no mueve un reloj ya sellado ni el mínimo; si es la primera observación del intento, sella
    el reloj como cualquier otra; el techo sigue venciendo). **Un inventario nuevo sobre las 16 entidades, dentro del
    ejecutor, pasa por `MigrationWorkExecutor.fetchInventory`** (es `private`); fuera de él hace lo mismo a mano:
    saltar la tabla es el bug.
  - El backfill que corre ANTES de dos de esos inventarios (`SyncIdentityService.backfillIdentities`, ida y adopt)
    también LANZA desde este ticket: tragaba su error, y las filas que se quedaban sin identidad las saltaba el
    snapshot (`identityGap`) o el adopt las contaba como `needsIdentity` y no como huérfanas. Rastro:
    `migrationIdentityBackfillFailed(errorType:)`. Si lanza a mitad, lo ya escrito se queda sucio en el contexto sin
    `rollback` (a propósito: el contexto es compartido); la pasada siguiente lo reescribe igual.
  - La excepción que confirma la regla: en la muestra de la vuelta el fetch de TESTIGOS (`SyncIdentity`) sí se tolera
    —las filas van con testigo scratch y la muestra sigue leyendo el SQLite—. Lo que no se tolera es perder filas de
    negocio.
  - `collectLiveByEntityName` (canario de metadata huérfana) deja la tabla ilegible SIN key: con el `Set` vacío de
    antes toda su metadata contaba como huérfana. Y `rehydrateOutboxFromMirror` sigue saliendo sin re-insertar
    —re-insertar sin saber qué hay duplicaría—, pero ya deja `outboxFetchFailed(step: "rehydrate-mirror")`: un
    breadcrumb del dispositivo, no la métrica de flota, que en esa rama sigue sin emitirse.
  - Seams: `MigrationSnapshotUploader._testThrowOnInventoryFetchOf` (conjunto de clases) y
    `MigrationWorkExecutor._testInventoryFetchThrows` (closure `(paso, entidad)`: el adopt lee su inventario varias veces
    con el mismo paso —cuatro desde el relevo del marcador—, y con un conjunto las siguientes lecturas son inalcanzables). Los dos lanzan un `CocoaError` dentro del
    `do` real y son de INSTANCIA. Rastro: `CloudSyncBreadcrumb.migrationInventoryReadFailed(step:entity:)`.

- **Un terminal de fallo DENTRO del cutover tiene que devolver el modo a `.icloud` como PRIMER efecto, o es peor que el limbo que arregla.** `failedRollback` «pelado» deja `.cloud` persistido, y `MigrationRunner.resetAfterRollback` (el botón «Reintentar» de la UI) journalea `notStarted` — **fase estable** — y además hacía `setPendingEffects([])`, tirando el efecto que iba a reparar el modo. Resultado: motor + mirror sin gate. ⇒ el abort emite `[.persistICloudMode, .deleteCutoverCloudKitMarkers, .rollback]` **en ese orden** (`.persistICloudMode` es el ÚNICO que no puede lanzar — `UserDefaults` puro — así que la mitad peligrosa se deshace antes de que corra nada que falle; el borrado sí relanza a propósito y queda journaled-pendiente). Hasta el 2026-09-25 el segundo era `.deleteCloudKitMarker`, que borra TODOS; desde el relevo del marcador (regla «Y el adopt que entra sin marcador deja el suyo») el aborto deja los relevados y la reversa sigue borrándolos todos. Y `resetAfterRollback` **drena los pendientes ANTES de limpiar el journal**. Corolario para efectos nuevos de cierre: ordénalos por «qué pasa si el siguiente lanza», no por afinidad temática. El cuarteto de la reversa (§h.4) tiene el orden INVERSO y por eso conserva el mismo bug-class (residual documentado, ticket aparte).

- **`isMarkerExported()` es necesaria-no-suficiente y su espera necesita TOPE: no hay API de cuota de iCloud.** iOS no expone espacio disponible; la única señal real de «iCloud lleno» es el `CKError.quotaExceeded` **post-hoc**, y `iCloudSyncService.isRetriable` la clasifica como no-retriable pero el copy la degrada a «Sin conexión o iCloud no está disponible» (brecha E7-06, viva). ⇒ toda espera por un export del mirror lleva tope, y el tope va **por TIEMPO journaleado, no por intentos**: la cadencia del runner es boot + cada foreground + tap (`MigrationForegroundRekick`), no un timer, así que un contador castiga a quien abre la app muchas veces y premia a quien no la abre. `ICloudCutoverGateLogic` clasifica el atasco (`definitive` = CloudKit ya dictó que no entra → 900 s · `unknown` = aún no se sabe → 259 200 s) con **fail-open**: la ambigüedad nunca aborta una migración. El canario del atasco se emite en **cada** observación, no solo al agotar el presupuesto — así un fallo SISTÉMICO (p. ej. un record type sin desplegar a CloudKit Production) se ve en el dashboard mucho antes de que ningún device degrade. **Y `ICloudCutoverGateLogic` hospeda desde el 2026-09-21 un segundo clasificador que NO es fail-open** (`ReversePreMountBlocker.stallCause`, siempre `.definitive`): ahí lo que clasifica no es una ambigüedad sino un desenlace. Nació siendo «la palabra del servidor» y el 2026-09-22 dos de sus cinco motivos dejaron de serlo (`localFailure`, `unknownVerdict` — ver más abajo), así que el criterio se dice en positivo: **¿esperar lo arregla?** **Y desde el 2026-09-25 mira solo los marcadores del CUTOVER** (`!CloudMigrationMarker.isRelay`): uno RELEVADO por un adoptador que llegó por el espejo ya está exportado por definición y contestaría por el del líder. Se separan por el prefijo de `writerDeviceID`, no por el `deviceID` del teléfono, que cae a un UUID nuevo si `identifierForVendor` es nil.

- **La subida del snapshot de la IDA también tiene techo y salida, con dos relojes (2026-09-22).** Ticket
  `snapshot-upload-has-no-ceiling-and-no-way-out`, decisiones de Jürgen: 15 min ACUMULADOS bajo un motivo que esperar
  no arregla, 72 h sin confirmar una sola página con cualquier causa, texto por motivo en la tarjeta de fallo y
  «Cancelar la activación» con confirmación. Hasta ese día `uploadingSnapshot` cortaba sin evento ante cualquier
  fallo y la barra se quedaba al 55 % para siempre. Seis cosas que no se tocan sin romperlo:
  (1) **avanzar es `pageConfirmed`**, y reinicia LOS relojes en el mismo save que el cursor: una página confirmada
  prueba que la sesión, la cuenta y la lectura local funcionaron. Sin ese reinicio, un corpus grande que sube despacio
  agotaría el techo mientras avanza;
  (2) **el reloj por causa es `CauseStallClock`, compartido con el techo previo al montaje de la vuelta**: causa
  distinta empieza de cero, misma causa suma, observación sin causa PAUSA. No lo copies a una tercera etapa: llámalo.
  **Y desde el 2026-09-23 son TRES relojes, como en la vuelta** (ticket
  `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`, schema **12 → 13**:
  `snapshotStallDefinitiveAt` + `snapshotStallDefinitiveAccruedSeconds`). Los 15 min los decide el de «CUALQUIER motivo
  definitivo» (`CauseStallClock.observeAnyDefinitive`, el MISMO helper que usa la vuelta: una sola clave, suma entre
  motivos, la red lo pausa); el de causa ya solo elige el copy. Hasta ese día un fallo local al leer —salta ANTES del
  push— y el 409 del push se turnaban pasada a pasada, el de causa no pasaba de cero con el re-kick de 30 s y la salida
  se iba a las 72 h. Las dos consecuencias decididas en la vuelta valen igual aquí, fijadas con test: un hueco SIN
  observaciones entre dos motivos distintos cuenta (`snapshotDefinitiveClock_anUnobservedGapBetweenTwoCauses_counts`),
  y una fila v12 parada a mitad de la subida sale como mucho un plazo corto después
  (`snapshotDefinitiveClock_aRowFromBeforeV13_leavesOneShortCeilingLater`). El canario `cloudSnapshotUploadWaiting` NO
  cambia: su segundo segmento sigue siendo el tramo de causa, que es el que deja ver la alternancia en la flota;
  (3) **los motivos definitivos los tipa el uploader** (`SnapshotStepOutcome.blocked`): el 401 que no es de attest
  (`sessionExpired`), el 403 y el 409 de congelado (`accountUnavailable`) y un `fetch`/`save` local que lanza
  (`localFailure`). La DERIVA del HLC (`ClockDriftError`/`CanonicalTimeError`) va como `.transient`, a propósito: el
  reloj puede corregirse solo y el texto de «este dispositivo no pudo preparar tus datos» no sería verdad para ella.
  **La sesión caducada es definitiva en la ida y no en la vuelta**, pero SOLO con la sesión borrada por el SDK
  (`canRenewSession == false`, leído después del push): aquí la tarjeta no ofrece «Iniciar sesión», y con la sesión
  borrada la salida (fallo → «Reintentar» → «Migrar») es la que vuelve a pedirla. **Un 401 con la sesión todavía
  guardada va al LARGO**, y lo cazaron las tres lentes de la review: su caso principal es el reloj del teléfono
  atrasado, que el SDK cura solo al renovar; tratado como definitivo sacaba de la subida a los 15 min y el reintento
  reusaba el mismo JWT rechazado sin pedir nada. En `/sync/push` el `accountUnavailable` real es el 409
  `yala_account_reverting` (la ruta no emite 403 hoy);
  (4) **la salida es `failedRollback` con `[.rollback]`**, la misma de `verifying` al agotar sus reintentos. Antes del
  cutover el teléfono está intacto y `.rollback` no toca la red. Lo ya subido se queda en el backend (no hay RPC de
  abort de la ida) y el siguiente intento lo re-sube por LWW;
  (5) **el motivo lo elige el techo que VENCIÓ** (`MigrationRunner.snapshotExitReason`, con el predicado en
  `MigrationPolicy.snapshotCauseCeilingReached`): las 72 h salen con `stalled` aunque la pasada traiga un 403 recién
  visto. **Desde el 2026-09-23 el texto específico se mide contra el reloj de CAUSA y la salida contra el de lo
  definitivo**: con uno solo que agotó el plazo, los dos vencen en la misma observación y sale su texto; con motivos
  mezclados sale **`mixedCauses`**, un motivo propio (decisión de Jürgen del 23), y **no `stalled`**: el texto de
  `stalled` dice «lleva días sin avanzar», así que solo vale para las 72 h. Lo cazaron dos lentes: en la vuelta el
  genérico no afirma plazo y el molde no lo traía. **Si copias este reloj a otra etapa, mira qué dice su genérico.**
  El canario `cloudSnapshotUploadAborted` gana el valor `mixedCauses` y `stalled` sigue siendo solo el techo largo. `snapshotExitReasonRaw` sobrevive a `failedRollback` —lo lee `StorageFailureCopyLogic`— y solo lo limpian
  `resetAfterRollback`, que es la salida de esa fase (la normalización de un journal ilegible que también lo limpiaba se
  retiró el 2026-09-25: esa fila ya no se toca);
  (6) **los seis `snapshotStall*` solo existen dentro de la fase**: `handle` los limpia al ENTRAR y al SALIR
  (`clearSnapshotStallCeiling()`), así que la vuelta desde `verifying` por mismatch no hereda el reloj.
  «Cancelar» va a `notStarted` sin efectos, que es el mismo estado al que ya llega «Reintentar»: deja la sesión de la
  nube puesta. Los otros tres pasos de la ida con el mismo agujero (22 %, 35 % y 80 %) se cerraron el mismo día: regla
  siguiente.

- **Y los otros tres pasos de la ida también: claim, identidad y `cutover(.pending)` (2026-09-22).** Los del 22, 35 y
  80 %. Ticket `forward-migration-steps-have-no-ceiling-and-no-exit`, decisiones de Jürgen: 15 min / 72 h por
  paso, «Cancelar la activación» con la misma confirmación, texto por motivo, y cerrar la trampa del claim sin respuesta.
  Hasta ese día los tres cortaban sin evento y la barra se quedaba quieta para siempre. Siete cosas que no se tocan sin
  romperlo:
  (1) **aquí avanzar es CAMBIAR DE PASO**, y el único sitio que lo sabe es `handle`: borra los cuatro `forwardStepStall*`
  en cada cambio de `ForwardStepPhase` (`clearForwardStepStallCeiling()`). No hay campo de paso que lo compare después, a
  propósito: esa limpieza es la única que impide que la identidad herede el sello del claim y salga con cero segundos de
  parada real, y un segundo cinturón haría superviviente a su mutante;
  (2) **el reloj por causa es `CauseStallClock`, el mismo de la subida y de la vuelta**, y el motivo que se journalea
  (`forwardStepExitReasonRaw`, aparte del de la subida) lo elige el techo que VENCIÓ (`forwardStepExitReason`, con el
  predicado en `MigrationPolicy.forwardStepCauseCeilingReached`);
  (3) **definitivos, y quién los produce**: la sesión BORRADA por el SDK en el claim o el cutover (`canRenewSession`
  leído DESPUÉS de la llamada: en el claim lo pregunta el runner con `executor.canRenewSession()`, en el cutover el
  ejecutor), el 403 del claim (`accountUnavailable`), el `rejected` del cutover (`refused`), su `other_leader`
  (`otherDevice`: otro dispositivo tomó el relevo del lease y desde `.pending` no se vuelve a liderar) y la base local en
  la identidad (`localFailure`: el `save()`, o desde 2026-09-23 el backfill o un inventario de la captura que no se deja
  leer). La red y el 401 con la sesión guardada van al LARGO. `confirmCutoverServer` dejó de ser un
  `Bool` (`CutoverServerOutcome`): su `false` único metía los cinco casos en el mismo saco;
  (4) **en el claim, techo y «Cancelar» con las DOS intenciones, pero la salida del ADOPT deja marca** (desde
  2026-09-23, ticket `adopt-claim-stays-parked-with-no-ceiling`; hasta ese día solo con «Migrar», porque la salida del
  adopt era un callejón: la pantalla solo ofrecía «Migrar», que la puerta de identidad para con esa cuenta, y el texto
  decía «tus datos siguen en este dispositivo» en un teléfono recién instalado). La marca es
  `MigrationState.adoptClaimExitRaw` (schema 11), escrita en el MISMO save de la salida —techo o cancelación— cuando
  `AdoptClaimScope.isAdoptClaim` (claim + intención `adoptIfExisting`, que incluye la fila sin intención). **Sobrevive a
  `failedRollback`, a «Reintentar» y a `notStarted` a propósito** —es lo que hace que la tarjeta de `.idle` ofrezca
  «Activar la nube en este dispositivo» sin marcador (`offersAdoptReentry`)— y la borra `handle` al ENTRAR en
  `claimingMigration` (otro intento empezó y manda su desenlace) y al llegar a `icloudActive`. **Va atada a UNA cuenta**,
  `adoptClaimAccountHash`, que `handle` apunta al ENTRAR en el claim (no en el self-hold: la sesión puede estar ya
  borrada): la tarjeta de adopt no pasa por la puerta de «Migrar», así que con otra sesión no se ofrece, y tras firmar
  otra cuenta en el chooser `continueToClaim` para sin claim (`AdoptClaimScope.blocksReentry`). Sin atarla, la sesión de
  Grupos de otra cuenta adoptaba esa y le subía lo local (lo cazó la lente de consumidores). La intención se lee ANTES
  del `handle`, porque el cierre del intento la borra en ese mismo save. El texto de la tarjeta de fallo
  (`StorageFailureCopyLogic`, el adopt primero), el cuerpo del diálogo (`isAdoptClaim`) y el aviso del 22 %
  (`AdoptClaimScope.notice`) son del adopt. **El aviso lee lo que vio el último claim** (`lastClaimDefinitiveCause`, en
  memoria), no el reloj de causa: el reloj PAUSA sin borrar la causa, y un aviso leído de él seguía diciendo «tu sesión ya
  no es válida» con la sesión recuperada y la red caída. Tampoco `lastClaimBlocker`, cuyo `.sessionExpired` incluye el
  401 con la sesión guardada. El
  alcance de «Cancelar» vive en `ForwardCancelScope.offersCancel(_:)`, que consultan el controller (el botón) y el runner
  (`journalMigrationCancel`, el ÚNICO sitio que journalea una cancelación). El seguidor (`waitingForLeader`) entró el
  2026-09-23: regla «Y la espera del seguidor también», más abajo;
  (5) **el «sí» de Cancelar vale para la PASADA**: se honra en la próxima fase que lo ofrece y se retira en la primera que
  no (verificación, cutover confirmado). Con el botón al 22 %, retirarlo al salir de la subida —como hacía #212— perdía un
  «sí» dado con el claim en vuelo y la pasada seguía hasta el cutover. El controller, además, cancela donde la pasada se
  aparca si esa fase lo ofrece: un «sí» dado sobre la subida puede acabar cancelando al 80 %, y es lo que se pidió;
  (6) **la marca del claim sin respuesta** (`CloudClaimActionStore.recordMigrationClaimAttempt`): un claim de «Migrar» que
  llega al servidor y pierde la respuesta deja la cuenta `complete` sin el sello `.proceedMigration`, y con techo o
  «Cancelar» al 22 % el reintento se paraba en la puerta con un «ya tiene datos» falso. La escribe `performClaim` ANTES
  del POST y solo con `marksMigrationAttempt` (el runner lo pasa con la intención journaleada; el seguidor y el adopt no
  marcan); la borra la respuesta de cualquier claim de esa cuenta. La puerta la recibe APARTE del sello
  (`hasUnansweredMigrationClaim`) porque la trata distinto: **no se salta la red de «Empezar desde cero»**, que el sello
  sí se salta (su residual escrito); fundirlas con un `||` en el controller le quitaría esa diferencia. Deja pasar un poco
  más que el sello —un `claiming_in_progress` perdido seguido del abandono de otro dispositivo acaba en un relevo—, de la
  misma clase que ya tiene cualquier «Migrar»;
  (7) **salida a `failedRollback` con `[.rollback]`, «Cancelar» a `notStarted` sin efectos**, desde los tres; desde
  `cutover(.serverConfirmed)` los dos eventos son `.invalid`. En `.pending` una respuesta perdida puede dejar `migrated_at`
  estampado: el cliente no lo lee y el reintento del mismo líder converge (claim `created`, `cutover` idempotente), y la
  precondición del canal iCloud sigue yendo antes que el techo en cada pasada. `MigrationState` schema 9 → 10. Residual
  con ticket: la identidad
  cuyo `save()` falla deja sucio el contexto compartido, así que su salida no llega a disco — la misma clase que
  `a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved`, que la recoge.

- **Y el EFECTO del adopt también: techo, texto y salida (2026-09-23).** Ticket `adopt-effect-retries-forever-with-no-ceiling`,
  decisiones de Jürgen: 15 min acumulados con la base local que no se deja leer, 72 h con cualquier causa, la tarjeta de
  progreso con «Cancelar» mientras espera, y dos textos propios. Es el par `(notStarted, [.adoptBackendAccount])` que deja un
  claim que ya contestó `existing_stable` cuando el reconcile de huérfanas no termina; hasta ese día el runner lo reintentaba
  para siempre, Almacenamiento lo pintaba `.idle` y el motor no arrancaba. Seis cosas que no se tocan sin romperlo:
  (1) **la espera NO pasa por `handle`**: una transición que repusiera el pendiente lo ejecutaría otra vez dentro del mismo
  `handle`. La observación (`MigrationRunner.observeAdoptEffectFailure`, desde el `catch` de `drainPendingEffects`) sella
  `adoptEffectStall*` con su propio save y lanza `Stop.effectFailed`; solo la salida es un evento (`.adoptEffectStalled`,
  `.invalid` bajo presupuesto en la máquina);
  (2) **quién reinicia el reloj**: toda transición de `handle` (el claim que vuelve a emitir el efecto, la cancelación, la
  salida, un «Migrar» que reemplaza el pendiente) y el save que retira el efecto cuando el adopt termina. «Retomar», el
  re-kick de 30 s, el auto-resume del Welcome y relanzar NO lo reinician: pasan por `resume`, no por un claim;
  (3) **el corto es el reloj de «cualquier motivo definitivo»** (`CauseStallClock.observeAnyDefinitive`): la base local
  (`MigrationExecutorError.adoptLocalFailure`) y, desde el 2026-09-24, el linaje sin probar (`adoptLineageUnproven`, regla
  de abajo); la salida la nombra la causa de la observación que lo vence. La red y la quiescencia lo PAUSAN. El ejecutor separa
  `.localFailure` de `.transient` en `runAdoptOrphanReconcile` —inventario, backfill, fetch de huérfanas, encolado salvo la
  deriva del reloj, outbox— y lee el inventario una vez ANTES de la red, para que una avería local no pague la enumeración
  entera en cada reintento (el plan preliminar del guard anti-fusión se vuelve a leer después de enumerar). La sesión borrada y el 403 de la enumeración siguen en el largo (la enumeración los aplana a `nil`);
  (4) **sin techo ni «Cancelar» con `.cloud` ya persistido** (`MigrationWorkExecuting.hasPersistedCloudMode`, término de
  `AdoptEffectScope.isPending`): un kill entre `writeCloudArmed` y el save que retira el pendiente relanza así, y salir a
  `failedRollback` dejaría `.cloud` en un terminal de fallo —la regla del cutover de arriba—. Se reintenta como antes;
  (5) **la salida es la del claim del adopt** (`failedRollback` con `[.rollback]`) y **la marca es la suya**:
  `AdoptClaimExit` gana `effectLocalFailure` y `effectStalled`, que eligen texto y hacen que «Reintentar» lleve a «Activar
  la nube en este dispositivo», atada a la cuenta que apuntó el claim. Ningún texto afirma que la nube no cambió —el
  reconcile pudo subir algo antes de fallar— ni que «tus datos siguen en este dispositivo», falso en un teléfono recién
  instalado: dicen «lo que tienes en este dispositivo sigue aquí» (`cancelAdoptEffectBody` es el cuerpo del diálogo). Lo elige el techo
  que VENCIÓ: el corto solo vence en una pasada con el motivo;
  (6) **la pantalla lo pinta como progreso** (`CloudMigrationUIStateDeriver`, `adoptEffectJournaled` del snapshot del
  journal): `.migrating` con la fase `notStarted` y `adoptEffectFraction`. Con eso cuenta como `isEngaged`, apaga la
  comprobación del cambio de Apple ID del arranque (su guard es `uiState == .idle`) y el «Retomar» del Welcome deja de
  re-reclamar: ahora reanuda, que es lo que no reinicia el reloj. Conserva la sección de Grupos (puede durar 72 h, y es la
  única puerta para soltar esa cuenta), y el «sí» de «Cancelar» se mira ANTES de cada intento: mirándolo solo al fallar,
  un intento que salía bien adoptaba a quien acababa de cancelar. Residuales con ticket: un `save()` local que falla deja
  el contexto sucio y el sello tampoco llega a disco (`a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved`, la
  misma clase); y un import que no se asienta nunca no llega a observarse. La sesión que abrió el adopt se cierra al salir
  desde el 2026-09-23: regla «Y la sesión que abrió el adopt», más abajo. **La bienvenida lee la misma marca y cancela por el mismo camino** desde
  `welcome-adopt-effect-failure-has-no-reason-and-no-cancel`: el texto de cada salida y el cuerpo del diálogo salen de
  `StorageFailureCopyLogic.adoptExitMessage` / `cancelMigrationBody`, que comparten las dos pantallas, así que un motivo
  nuevo se añade ahí y aparece en las dos. **Y `notStarted` no prueba que una cancelación aterrizara**: es también el
  efecto pendiente ANTES de cancelar y el adopt que terminó bien. La huella es `notStarted` + sin `.adoptBackendAccount`
  pendiente + marca `.cancelled` (`WelcomeAdoptCancel.afterCancel`), y se mira en cada vuelta del poll, porque con la
  pre-espera del import vencida el «sí» lo ejecuta una pasada posterior. Mientras tanto el `uiState` es `.idle`, que el
  Welcome pinta como `.adopting(0)`, y su «Retomar» con `.idle` volvería a reclamar la cuenta: con la cancelación pedida
  reanuda.

- **El adopt solo sube lo que el backend no conoce si demuestra que el corpus es de ESA cuenta (2026-09-24).** Ticket
  `adopt-uploads-a-foreign-corpus-without-a-lineage-check`. El diff del reconcile sabe «el backend no conoce esta fila», y eso
  es igual de cierto para la huérfana de la ventana del cutover que para el corpus entero de otro iCloud: un seguidor de otro
  Apple ID, o cualquier teléfono que llegue al adopt con datos ajenos, los subía como huérfanos. Cuatro cosas que no se
  tocan sin reabrirlo:
  (1) **dos pruebas, y basta una**: el `CloudMigrationMarker` con el `accountHash` de la sesión (`adoptLineageProven`),
  que el líder escribe en SU CloudKit en el cutover —o, desde el 2026-09-25, un adoptador que entró con cobertura total
  (el relevo, regla «Y el adopt que entra sin marcador deja el suyo»)—, **o una fila VIVA de la cuenta en el inventario del plan**, en su tabla
  y fuera de `ExchangeRate` (`lineageSharedLiveRows`, la prueba de la ida). La segunda existe desde el 2026-09-24 (ticket
  `adopt-after-the-cutover-needs-a-marker-the-leader-never-exported`): desde g16_04 quien llega tras el cutover del
  SERVIDOR adopta, y el líder estampa `migrated_at` ANTES de exportar el marcador; dormido en `cutover(.markerWritten)`, o
  tras agotar el tope y borrarlo, dejaba fuera para siempre al 2.º teléfono del mismo iCloud. Ninguna tabla personal tiene
  identidades fijas entre teléfonos (se acuñan por dispositivo, también las de sistema), así que un corpus de otro iCloud
  no comparte ninguna: **un test que modele el corpus ajeno con una fila compartida no representa un teléfono real**. La
  excepción medida es un store que YA mezcló la vuelta a iCloud (filas de la cuenta + la zona de otro iCloud): esa cuenta
  sigue con `reverse_frozen_at` tras `reverse_complete` y el gateway rechaza su push con 409, así que la mezcla no llega.
  **Y la fila compartida sola no basta: en cada tabla con algo que subir tienen que estar ya TODAS las filas vivas de la
  cuenta** (`adoptSharedRowsProof`, `.accountRowsMissing`). El marcador se exporta después de las identidades que el líder
  asignó, así que traerlo implicaba traerlas (el relevado, después de TODAS las filas vivas del backend, que el adoptador
  tenía con su identidad); sin él, la exportación del líder puede estar parada, la cuenta (`shortcutID`)
  se comparte, sus movimientos siguen aquí sin `syncID` y el backfill los subiría DUPLICADOS con otra identidad. **Desde
  `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait` (2026-09-24) «todas» es «ninguna que falte con
  gemela aquí»**: regla «Una fila que falta solo bloquea si aquí puede tener gemela», más abajo. Los tipos
  de cambio tampoco piden cobertura (los siembra cualquier teléfono). El
  marcador se mira primero (su tabla ilegible para con `.localFailure`). **El faro NO vale** (lo escribe también el alta
  born-cloud, sin corpus en CloudKit), ni «hay algún marcador» (uno de otra cuenta, de una migración anterior de este
  iCloud, lo daría por bueno);
  (2) **solo se exige con algo que subir** (huérfanas o filas sin identidad), **fuera de `ExchangeRate`**
  (`adoptLineageExemptTables`). El 2.º dispositivo de una cuenta NACIDA en la nube entra por este mismo adopt
  (`BornCloudSignUpFlow.continueAsReturningUser`) y nunca puede tener marcador; y nunca llega con el store vacío, porque
  el arranque siembra tipos de cambio sin identidad ANTES del Welcome (`AppBootstrapper.loadExchangeRates`). Un test con
  el inventario vacío no representa un teléfono real: lo cazó la review. Se decide sobre el plan preliminar Y sobre el
  definitivo, que es el que sube;
  (3) **va ANTES de toda mutación y del guard de backend vacío**: ese guard SIGUE el adopt y cambia el modo, y con un corpus
  ajeno eso lo deja dentro de la cuenta, listo para subir en la primera edición. La tabla del marcador se lee por
  `fetchInventory` (paso `adopt-lineage`): ilegible es `.localFailure`, nunca «probado»;
  (4) **esperar no lo arregla**: `.lineageUnproven` → `adoptLineageUnproven` → causa definitiva del techo CORTO, con salida y
  texto propios (`effectLineageUnproven`). La espera legítima —lo que aún se importa— la para ANTES la quiescencia.
  Esa salida deja la marca SIN cuenta (`adoptClaimAccountHash = nil`): atada, `blocksReentry` impedía entrar con la cuenta
  buena, que es justo el arreglo cuando la persona eligió otra en el chooser.
  **No cubre el relevo de un líder callado**: el `created` del takeover de `claim_account` va a la subida del LÍDER, no al
  adopt, y ahí no hay marcador (el líder nunca llegó al cutover). Lo cubre la regla siguiente.
  Los tests del reconcile que suben algo necesitan el marcador del líder (`seedLeaderMarker` en `MigrationWorkExecutorTests`)
  o una fila compartida con su backend; los que prueban el bloqueo, un backend sin filas del inventario
  (`seedWindowCorpus(...).foreignBackend`).

- **Y la IDA tampoco sube su corpus sobre el de otro dispositivo: el relevo prueba el linaje en la identidad (2026-09-24).**
  Ticket `migration-takeover-uploads-without-a-lineage-check`. `claim_account` da `created` a un dispositivo que reclama con
  `migration` cuando el líder lleva más de 60 min sin latir (el relevo), y el cliente no lo distinguía de un alta: subía su
  corpus encima de lo que el otro alcanzó a subir, fuera o no el mismo. Cinco cosas que no se tocan sin reabrirlo:
  (1) **la pista es del servidor** (g16_03): todo `created` lleva `has_personal_writes` (fila en `sync_seq_counters`), que
  `performClaim` guarda y `handle` journalea en `MigrationState.forwardLineageUnverified` (schema 16) en el MISMO save que
  ENTRA en la identidad. **En `handle` y no en `driveClaim`**: el seguidor que recibe el relevo entra por `pollLeaderInternal`,
  que es otro claim, y es justo el caso del ticket. `false` no comprueba —el alta normal no paga nada—; `true` y la AUSENCIA
  comprueban, y `nil` en el journal también (una fila de antes de la v16): falla cerrado. Va en los cinco `created` porque la
  respuesta perdida de un relevo se reintenta por la rama del mismo líder;
  (2) **la prueba es una identidad compartida** (`MigrationWorkExecutor.checkForwardLineage`): alguna fila VIVA del backend
  está en el inventario local, en su tabla. `exchange_rates` no cuenta ni para pedir ni para dar prueba
  (`adoptLineageExemptTables`). No es el marcador (el líder callado no llegó al cutover) ni el faro (lo escribe el propio
  claim del relevo). El relevo legítimo la tiene al instante porque la subida va por tablas en orden UTF-8 y `accounts` va
  primero, con una identidad (`Account.shortcutID`) que nace con la fila y viaja por CloudKit sin esperar al líder.
  **Y la compartida sola no basta, como en el adopt** (2026-09-24, ticket
  `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived`): en cada tabla con algo que subir tienen
  que estar ya TODAS las filas vivas del backend (`adoptSharedRowsProof`, la misma función; si no,
  `ForwardLineageOutcome.accountRowsMissing`). Medido: el servidor solo deduplica por `(user_id, sync_id)`, los testigos
  `SyncIdentity` del rebind son locales de cada teléfono (store de metadatos, `cloudKitDatabase: .none`: el relevo nunca
  tiene los del líder) y el
  `verify` baja las copias del líder ANTES del Merkle, que así CUADRA con el libro doble. Sin la cobertura, un relevo cuyas
  identidades sintéticas (movimientos, categorías, borradores, favoritos, comercios) no llegaron las acuñaba de nuevo y
  duplicaba lo que el líder había subido; el test que daba `proven` a ese caso fijaba el bug como contrato;
  (3) **el Merkle tiene que dar la enumeración por completa ANTES de cualquier veredicto** (`verifyEnumerationComplete`):
  para «no hay nada» y «no comparte nada», y desde el 2026-09-24 también para «llegó todo» —hasta ese día una compartida
  probaba sin él—, porque la página que faltó es justo la que escondería las filas que no están. Una enumeración incompleta
  es `transient`, nunca `unproven` ni `proven`;
  (4) **va en `driveIdentity` ANTES de `assignIdentity()`**, tras la quiescencia de la pasada, y probada se journalea `false`
  para no enumerar otra vez. `accountRowsMissing` tiene su bloqueador y su texto (`ForwardStepBlocker.leaderRowsNotArrived`,
  `storage.failed.stepLeaderRowsNotArrived`, la misma pantalla `.lineageExit` de la bienvenida, que lleva el motivo): el de
  `unproven` dice «no coinciden» y pide revisar la cuenta, falso en el mismo iCloud. Un borrado hecho durante la espera
  lo dejaba sin salida hasta el 2026-09-24: regla siguiente.
  `unproven` es causa DEFINITIVA del techo corto del paso (`ForwardStepBlocker.lineageUnproven`,
  15 min) con texto propio (`storage.failed.stepLineageUnproven`, `StorageFailureCopyLogic.forwardLineageMessage`), el mismo
  en Almacenamiento y en la bienvenida (`CloudWelcomeSignInPhase.lineageExit`, con la flecha y «Reintentar»). La red y la
  enumeración incompleta van al largo;
  (5) **reintentar ES la recuperación, y por eso el sello `.proceedMigration` se queda**: el relevo bloqueado sigue siendo
  líder, así que toda entrada suya recibe `created` y vuelve a comprobar; el legítimo bloqueado en falso (un import lento,
  un `shortcutID` que cada dispositivo reparó por su cuenta) pasa cuando sus datos llegan. Se probó retirar el sello y la
  review lo tumbó: no cortaba el bucle —el adopt que recomienda la puerta de «Migrar» lo reabre— y dejaba al legítimo sin
  salida. Residual aceptado: el relevo bloqueado se queda el lease hasta que caduca (no hay RPC para soltarlo). El líder
  desplazado que volvía y seguía subiendo se cerró en la regla siguiente.

- **Una fila que falta solo bloquea si aquí puede tener gemela (2026-09-24).** Ticket
  `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`. La cobertura de las dos reglas anteriores pedía
  TODAS las filas vivas de la cuenta, y una que este teléfono borró durante la espera —o fundió un deduplicador— no llega
  nunca: el único que la tombstonea en el backend es el motor del líder, callado. Relevo y adopt esperaban para siempre.
  El duplicado de #241 necesita que la MISMA fila esté aquí con otra identidad, así que `adoptSharedRowsProof` (la función
  de las dos) pregunta por las **candidatas**: las filas de esa tabla sin identidad del backend, que son lo único que sube.
  Siete cosas que no se tocan sin reabrirlo (las cazaron DOS rondas de review; la primera versión fallaba abierta):
  (1) **falla cerrado**: tras casar, una fila que falta sigue bloqueando mientras quede UNA candidata sospechosa. Solo
  dejan de serlo la que consta creada aquí DESPUÉS de la última escritura del backend (`provenNew`) y la semilla cuya
  clave de FUSIÓN es la de alguna fila sin explicar (`LineageTwinKey.fusion`: si sube duplicada, el deduplicador del
  arranque la funde con esa). «La clave de linaje no casa» NO prueba nada;
  (2) **«creada aquí después» se lee del historial de SwiftData** (`lineageRowsBornHere`): un insert en una transacción
  SIN el autor del espejo (`PrivateSignOutExportGateLogic.mirrorAuthorPrefix`, que firma lo que BAJÓ) posterior a la
  última escritura del backend (componente físico del HLC más alto de la enumeración) más 10 min por relojes desfasados.
  Solo se lee desde ese corte. Un HLC ilegible deja la última escritura en `nil` y NADA consta como nuevo. **Se apoya en
  que el espejo firme TODAS sus importaciones con ese prefijo**: lo mismo que el cierre de la sesión privada, y sin medir
  en device todavía (primer punto del device-QA de `session-exits-one-verb-per-session`). Si alguna no lo lleva, esto falla
  abierto. Residual aceptado: un desfase de relojes de más de 10 min (B adelantado o A atrasado);
  (3) **casar exige una clave ÚNICA**: una vez entre TODAS las vivas de la tabla en el backend y una vez entre las
  candidatas; y una fila del backend SIN clave legible apaga el casado de su tabla entera. Casa ⇒ la candidata TOMA la
  identidad del backend y se guarda antes de devolver `proven` (`resolveLineageCoverage`; si el guardado falla deshace SOLO
  lo suyo, sin `rollback`: el contexto es compartido). Importaciones, recurrentes y el `createdAt` que la migración ligera
  rellenó con `Date.now` en cada teléfono repiten el milisegundo, y casar dentro de un grupo cruzaría identidades;
  (4) **la clave de linaje (`LineageTwinKey`) usa lo que no se edita**: movimientos, borradores y favoritos por
  `created_at` en ms; comercios por `merchant_canonical`; categorías SEMILLA por la clave del deduplicador
  (`icon|color|isIncome`, la de `CategoryDeduplicationService.identityKey`). **Las categorías del usuario no tienen clave**:
  con el nombre, «borro Gym y renombro Sport a Gym» casaba la fila de Sport con la identidad de Gym. **Si cambias la clave
  de un deduplicador, cambia la de linaje o la de fusión**: un test las compara;
  (5) **identidad propia** (cuentas, subcategorías, presupuestos, etiquetas, avisos, cashflow, preferencias de puente): no
  casan —su UUID lo referencian los espejos CSV— y siguen la regla (1). Fusión: subcategorías semilla por icono (el
  criterio del deduplicador de categorías) y avisos de sistema por `typeRaw` (los `custom` no). Una fila que BAJÓ de
  iCloud sin estar en el backend puede ser la del líder re-identificada aquí (`repairCollapsedIdentityUUIDs`): bloquea;
  (6) **la única mutación nueva de `checkForwardLineage` es la re-identificación**, y en el adopt va antes del backfill,
  que ya no acuña identidad a las casadas (`identityAssigned` las descuenta). Leer candidatas o historial que falle es
  `.localFailure`, nunca «probado». El camino feliz (nada falta) no lee nada;
  (7) **lo que NO cierra, con ticket**: la fila borrada VUELVE (sigue viva en el backend y el `verify`/pull la baja, como
  antes de #241: `row-deleted-during-the-relief-wait-comes-back-after-the-relief`); el adopt SIN marcador contra una
  cuenta en la que otro teléfono escribe a diario no llega nunca a «creada después» (el corte es global a propósito).
  Desde el 2026-09-25 eso solo pasa si el primer adoptador no tenía cobertura total: si la tenía, releva el marcador y los
  siguientes entran por él (regla «Y el adopt que entra sin marcador deja el suyo»). Y sigue esperando, con el techo de 15 min
  y su texto, el teléfono que conserva una fila del líder sin su identidad que no casa: el caso que #241 protege.

- **Y el líder DESPLAZADO no sube ni una página más: la ida sube solo con el lease confirmado (2026-09-24).** Ticket
  `displaced-migration-leader-keeps-uploading-after-a-takeover`. El linaje protege a quien TOMA el relevo; el teléfono que lo
  pierde no vuelve a pasar por la identidad, y seguía subiendo desde su cursor encima de lo del nuevo líder hasta que el
  `cutover` le decía `other_leader`. Cuatro cosas que no se tocan sin reabrirlo:
  (1) **la puerta va delante de CADA página y de cada verificación** (`MigrationWorkExecuting.confirmMigrationLease`, en
  `driveUpload` y `driveVerify`), no de cada pasada: una pasada suspendida más de 60 min se reanuda a mitad. Solo `.held`
  sube; `.lost` sale; `.unconfirmed` (red, 5xx, `no_profile`, `bad_action`, 401 con la sesión guardada) y `.sessionExpired`
  (sesión borrada) esperan con el trato de la red y de la sesión de cada fase. La verificación entra porque empuja el
  outbox y trae el corpus de la cuenta;
  (2) **una confirmación vale 60 s contados desde que se PREGUNTÓ, con `ContinuousClock`**: el servidor estampa el lease
  después de recibir la pregunta, y el reloj monotónico sigue contando con el teléfono en reposo —cuando caduca el lease—
  y no se mueve si cambian la hora. **Sin throttle de intentos**, a diferencia de `sendLeaseHeartbeatIfDue` (que arma el
  suyo también con un rechazo): cada pregunta sin `ok` deja la siguiente sin confirmar, y nada se cachea, porque el mismo
  teléfono puede volver a liderar tras «Reintentar». El requisito del protocolo no tiene default: un `.held` heredado sería
  una puerta que falla abierta;
  (3) **`not_in_progress` también es «perdido»**: `migration_progress` mira «¿hay migración en curso?» ANTES que «¿quién
  lidera?», así que es lo que recibe el desplazado cuando el nuevo líder ya terminó. En la subida no llega por otro camino;
  (4) **sale EN EL ACTO** (`MigrationEvent.migrationLeaseLost`, solo desde `uploadingSnapshot` y `verifying`, a
  `failedRollback` con `[.rollback]`) y journalea `forwardStepExitReasonRaw = otherDevice`: texto `stepOtherDevice` en
  Almacenamiento. Sin techo porque ninguna espera devuelve el lease; el `cutover(.pending)` conserva su techo de 15 min
  para el mismo `other_leader`. La subida ya no llama a `sendLeaseHeartbeatIfDue`: la puerta la sustituye y lee la respuesta.
  **Y el lease cambió de significado, a propósito**: antes solo latía una página CONFIRMADA, así que un líder conectado cuyo
  push fallaba (5xx, un rechazo transitorio) dejaba caducar el lease y otro tomaba el relevo — justo el escenario de este
  bug. Ahora late cada pasada que PREGUNTA (≤ 1/min), también en la verificación: el lease dice «el líder está vivo», no «el
  líder avanza». Un líder sin red sigue sin latir y pierde el lease a los 60 min, como antes; el que se atasca conectado lo
  conserva hasta su propio techo, y el seguidor espera con el suyo. Además la confirmación caduca a MEDIA página: los trozos
  del push (50 filas) y el pull de la verificación se cortan si la confirmación tiene más de 30 min
  (`MigrationWorkExecutor.leaseInFlightBudget`), el caso de la app congelada entre dos trozos. Residual con ticket: la
  bienvenida pinta esta salida como error de red (`welcome-shows-a-takeover-exit-as-a-connection-error`). El líder que
  pierde el lease DESPUÉS del cutover va en la regla siguiente.

- **Y después del cutover el líder desplazado no sube, no sale: averigua quién cerró y se une (2026-09-24).** Ticket
  `leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile`. El lease puede caducar esperando el marcador
  o el relanzamiento (ahí no late nadie), y `claim_account` daba el relevo sin mirar `migrated_at` (medido en producción;
  lo cierra g16_04, en la regla siguiente). El reconcile
  de `done` empujaba el residual encima de la migración del otro y reintentaba el efecto —con su `complete`
  `other_leader`— en cada arranque, con Almacenamiento
  diciendo «nube activa». Cinco cosas que no se tocan sin reabrirlo:
  (1) **aquí no hay salida a iCloud**: el marcador ya se exportó y el corpus del líder está verificado en la cuenta. La
  salida de la regla anterior (`failedRollback`) contradiría «el cutover jamás hace rollback». Por eso la máquina no
  cambia: todo vive en el efecto (`MigrationWorkExecutor.resolvePostCutoverLease`);
  (2) **la puerta va delante del drain y del push**, y el push lleva el mismo `continueWhile` de 30 min que la subida. Un
  push que entrega menos resultados que filas (un trozo cortado) lanza `sweepTransient` ANTES del `complete`: el Worker
  contesta un resultado por delta (`gateway/src/sync/routes.ts`), así que menos es un barrido a medias;
  (3) **`not_in_progress` del latido es AMBIGUO aquí**, a diferencia de la subida: también lo recibe el líder cuyo propio
  `complete` llegó y perdió la respuesta. Lo desempata `complete`, que el RPC contesta `ok` al líder aunque la migración
  ya esté cerrada (guard de líder primero). Tratarlo como «perdido» dejaba sin cerrar a un líder legítimo;
  (4) **con `other_leader` en el `complete`, un claim de migración decide**, y va DIRECTO a `accountClient.claim`, no por
  `performClaim`, que estamparía el sello de ese claim (`claiming_in_progress` dejaba al runtime sin arrancar):
  `created` = el otro dejó caducar el lease y este vuelve a liderar (se confirma con otro latido antes de subir);
  `claiming_in_progress` = el otro sigue vivo → espera sin subir, sin canario (el re-kick de 30 s lo repetiría);
  `existing_stable` = la migración ya no está en curso (la cerró el otro, o la cuenta volvió a iCloud) → el efecto
  termina con el sello `.routeReturningUser` y el residual viaja por el sync normal de una cuenta cerrada (si la cuenta
  está VOLVIENDO a iCloud, el push recibe el 409 de cuenta revirtiendo, como cualquier otro dispositivo). Ese claim sí
  escribe una cosa: con `existing_stable` estampa `personal_adopted_at` (g16_02), que es verdad —este teléfono entra en
  la cuenta— y solo pesa en la rama g16_01, cerrada para una cuenta con contador. La espera dura lo que la migración del
  otro: termina, o deja de latir y a los 60 min este teléfono recupera el relevo. **El runtime NO se para mientras tanto**
  (medido el 2026-09-25): `CloudSyncRuntime.canRunDomain` no mira los efectos pendientes y el sello sigue en
  `.proceedMigration` hasta el cierre, así que el arranque lo pone en marcha con el reconcile pendiente (ticket
  `cloud-engine-can-start-with-a-reverse-abort-pending`). Que `complete` de quien NO lidera conteste `other_leader` y no
  `not_in_progress` está medido en el cuerpo vivo (md5 `14fc5e2c…`: las acciones de ida miran el líder antes que nada);
  (5) **sin texto nuevo, a propósito**: no hay nada que la persona pueda decidir y «Nube activa» es verdad en cuanto se une.
  Canario `cloudPostCutoverLeaseLost` (`joined` | `retaken`).

- **Y el servidor ya no da ese relevo: después del cutover, quien llega entra en la cuenta (g16_04, 2026-09-24).** Ticket
  `claim-grants-a-takeover-after-the-leader-passed-the-cutover`; decisión de Jürgen: B adopta, no espera ni releva. Con
  `migrated_at` puesto y el lease del líder vencido, `claim_account` contesta `existing_stable` —con y sin `migration`;
  con ella estampa `personal_adopted_at`— y **no cambia de líder**. Tres cosas que no se tocan sin reabrirlo:
  (1) **el líder apuntado ES el del cutover**: `migrated_at` solo lo estampa el `cutover` del líder, y con la migración en
  curso el único otro que cambia de líder es `reverse_claim`, que la cierra. Por eso quien hizo el cutover ya no pierde el
  lease ante otra ida: al volver, su latido da `.held` y cierra con su `complete`. Las ramas `created`/`claiming_in_progress`
  del paso (4) de la regla anterior quedan para un servidor sin g16_04, y se conservan porque el cliente no sabe cuál le
  contesta;
  (2) **el cliente no cambia**: `existing_stable` ya lleva al adopt por las tres puertas (poll del seguidor, `driveClaim`
  con `adoptIfExisting`, alta del Welcome) y ninguna lee `profile.migration_in_progress`. La cuenta queda con la migración
  del líder abierta hasta que vuelva, y eso no bloquea nada: el Worker no mira `migration_in_progress` en el push. Un
  adoptador sube solo sus huérfanas (`runAdoptOrphanReconcile`), nunca el corpus entero. Con algo que subir, el adopt no
  necesita el marcador que el líder puede no haber exportado aún: le basta una fila de la cuenta (regla del adopt, punto 1).
  Residual con ticket: una huérfana del adoptador puede ganar a la edición que el líder ausente aún no subió
  (`adopt-orphan-with-a-fresh-hlc-beats-the-absent-leaders-edit`);
  (3) **lease vigente, latido nulo y antes del cutover, sin cambio**: con el lease vivo el líder cierra enseguida
  (`claiming_in_progress`); un latido nulo nunca vence; y sin `migrated_at` el relevo legítimo sigue. El banco (27
  escenarios, 13 mutantes) está en `qa/cloud/g16_04_claim_no_takeover_after_the_cutover.sql`.

- **Y lo que el líder desplazado exporta TARDE a iCloud no le cambia la identidad al relevo (2026-09-24).** Ticket
  `displaced-leader-late-identity-export-can-rekey-the-relief-corpus`. El líder acuña sus identidades en `assignIdentity` y
  se queda sin red antes de exportarlas; el relevo acuña las suyas y las sube; el líder vuelve y su espejo las exporta. El
  `syncID` va en el schema personal (espejado) y el espejo del relevo sigue vivo hasta el remonte del cutover, así que si
  CloudKit le da la razón al líder —**sin medir: pide dos teléfonos**— la misma fila cambia de identidad por debajo, y eso
  duplica por dos caminos MEDIDOS: el snapshot pagina por `afterSyncID` y la vuelve a subir, y el pull de la verificación
  crea un born-remote con la copia del backend. Seis cosas que no se tocan sin reabrirlo:
  (1) **gana la identidad del relevo**, la que el backend ya tiene; el líder desplazado no sube más (su puerta del lease).
  **Al entrar en la cuenta NO lo re-identificaba el linaje del adopt**, como decía esta regla hasta el 2026-09-25: con el
  marcador la guarda se salta el casado. Lo cubre la regla «Y en el ADOPT tampoco», más abajo. La restauración es
  `MigrationWorkExecutor.restoreRelayIdentities`;
  (2) **el testigo es el `SyncIdentity` con las coordenadas del record** que `assignIdentity` captura con el espejo vivo: el
  record es el mismo en los dos teléfonos y no cambia. Se restaura solo la fila cuya identidad NO tiene testigo aquí y
  cuyo record casa con UN testigo huérfano (su `syncID` no lo lleva ninguna fila viva) de su tipo, y ese testigo con ella
  sola. Todo camino LOCAL que cambia un `syncID` ya puesto escribe su testigo —rebind, curación de colisiones, linaje—, y
  los que no lo escriben solo lo ponen donde era `nil` o en una fila nueva (con record nuevo), así que «sin testigo y con
  el record de un huérfano» señala al espejo. **Si añades un camino local que cambie un `syncID` ya puesto sin escribir el
  testigo, esto lo deshará**;
  (3) **falla cerrado**: sin coordenadas, con dos candidatas o dos huérfanos para un record, o con la identidad del
  testigo viva en otra fila, no se toca. Una fila que el líder pudo re-identificar existía en CloudKit antes que la
  identidad del relevo, así que su testigo tiene coordenadas; el caso sin ellas es residual. Solo los seis tipos de
  identidad ACUÑADA (`mintedIdentityTypes`): los otros diez nacen con la fila, y su reparación local
  (`repairCollapsedIdentityUUIDs`) es otra regla;
  (4) **dónde, y siempre sin `await` entre la restauración y lo que lee identidades** (el import se fusiona desde la cola
  principal y no cabe en un tramo síncrono): antes de cada página (`uploadSnapshot`), antes del pre-check de la
  verificación de la ida, **antes del drain F-1 de cada página del pull** (`pullAndApplyOnce(beforeDrain:)`, lo único que
  cubre un import que aterriza durante la espera del pull), antes del árbol local del Merkle
  (`verifyIntegrity(beforeLocalTree:)`, tras la espera del remoto: sin él, una divergencia falsa gastaba un reintento de
  MISMATCH), antes del drain del cutover y al empezar el reconcile de
  `done`, ya con el espejo apagado y delante de TODAS sus salidas (las que se unen dejan el drain al runtime). **Delante
  también de la pregunta del lease, y con cualquier respuesta** (2026-09-25, ticket descartado
  `displaced-leader-after-the-cutover-restores-its-own-identity-over-the-relays`): aquí solo llega quien pasó SU cutover, al
  cutover solo se entra con la verificación en `.match` y la hoja del Merkle lleva el `sync_id`, así que la identidad que se
  devuelve el backend la tiene, también en quien se une a la migración de otro. Y el runtime puede estar corriendo ya
  (`canRunDomain` no mira los pendientes): detrás de la red de la pregunta, su pull creaba un born-remote y la fila ya no se
  restauraba. Moverla detrás del lease se probó y se retiró por eso. La vuelta a
  iCloud no la hace (`underMigrationLease == false`): allí el espejo baja lo que la nube congeló, y es otra pregunta;
  (5) **una lectura que falla es avería local, también la de los metadatos de CloudKit**: `CKIdentityCapture` con algún
  `failed` (el SQLite no abre, faltan las tablas del espejo) no es «esta fila no tiene record», que es lo que leía la
  primera versión —y dejaba sin restaurar justo la fila que había que restaurar—. `.blocked(.localFailure)` en la subida
  y en la verificación (también cuando falla la del pull, que solo sabe devolver `.transient`:
  `relayIdentityPinUnreadable` lo separa; la verificación de la ida lo cuenta después como la red, que es la decisión de
  siempre de `driveVerify`), y en el cutover no se drena. **La excepción es el reconcile de `done`**
  (`toleratingUnreadableRecords`): corre remontado sin espejo, que las tablas sigan legibles ahí no está medido, y
  lanzar dejaría el efecto pendiente y el motor parado para siempre; deja rastro y sigue. Si falla el guardado deshace
  SOLO lo suyo;
  (6) **cambia solo el `syncID`**: el drain lo salta (la identidad no es columna) y el espejo, si sigue vivo, lo exporta.
  Canario `cloudRelayIdentityRestored` (tipo y cuántas): distinto de cero mide en la flota lo que el ticket no pudo. Coste
  aceptado: cada llamada lee los testigos y las seis tablas (la subida ya lee su tabla entera por página); los records
  solo se buscan con un testigo huérfano y una fila sin testigo a la vez.
  Residual con ticket: la vuelta a iCloud que re-importa la identidad del líder desde la nube congelada
  (`reverse-mount-can-reimport-a-late-leader-identity`). La fila re-identificada y BORRADA antes de restaurarse se cerró el
  2026-09-25 (regla siguiente), y la misma ventana en el adopt también (regla «Y en el ADOPT tampoco»).

- **Y el borrado de una fila re-identificada sale también con la identidad que el backend conoce (2026-09-25).** Ticket
  `relay-row-rekeyed-then-deleted-tombstones-the-leader-identity`. La restauración de la regla anterior solo alcanza a las
  filas VIVAS; si el usuario borra una fila re-identificada antes de la siguiente, el drain emitía el tombstone con
  `tombstone[\.syncID]` —la identidad del líder, que el backend no conoce— y el movimiento reaparecía en los otros
  teléfonos (y el Merkle de la verificación no cuadraba). Seis cosas que no se tocan sin reabrirlo:
  (1) **el vínculo es la fila por su `Z_PK` (con el identificador del store), no el record de CloudKit**: el cambio de
  identidad del espejo es un update del MISMO objeto y Core Data no reutiliza `Z_PK` en un store. El record del objeto
  borrado solo se lee hasta que el espejo exporta el borrado (segundos con red; del cutover al relanzamiento pueden ser
  horas), así que no sirve de testigo. El registro es `RelayIdentityLedger` (JSON en Application Support), sembrado por
  `assignIdentity` con los seis tipos acuñados. **Se fusiona, nunca se recorta** durante la migración: la entrada de una
  fila ya borrada es la que hace falta, y una pasada repetida tras un kill no puede tirarla;
  (2) **es un fichero y no un modelo porque lo leen DOS motores**: el executor tiene su propio `CloudSyncEngine`
  (`CloudMigrationController.makeExecutor`) y el runtime otro, y el registro tiene que sobrevivir al relanzamiento del
  cutover. Los dos leen `relayIdentityLedgerURL`, que en producción es `RelayIdentityLedger.defaultURL`; los tests lo
  apuntan a su directorio (el helper `makeExecutor` de `MigrationWorkExecutorTests` lo hace para motor y executor);
  (3) **salen LAS DOS identidades, no una traducción**: desde un teléfono no se sabe cuál conoce el backend —en el relevo es
  la del registro; en el líder desplazado, al que el espejo le trae la del relevo, es la preservada—, y `apply_delta`
  guarda como borrada una identidad que no conoce (medido en producción el 2026-09-25: inserta la fila con
  `deleted = true`), así que la que sobra no hace daño. La del registro se añade solo con las condiciones de la
  restauración (`CloudSyncEngine.relayTombstoneIdentity`): la preservada NO tiene testigo, la del registro sí, de su tipo
  y con las tres coordenadas, y ninguna fila viva la lleva. Si añades un camino local que cambie un `syncID` ya puesto SIN
  escribir el testigo, esto también lo leerá como obra del espejo;
  (4) **un testigo o una fila que no se dejan leer abortan la vuelta ENTERA del drain** (`RelayTombstoneReadFailure`,
  `drainOnce` devuelve `false`), no solo su transacción: con `true`, el guard D-1 del pull y el `complete` del reconcile
  daban por completo un outbox al que le faltaba el borrado (lo cazó la review). Un registro ilegible, o que no se puede
  escribir al sembrar, deja rastro (`relayIdentityLedgerUnavailable`) y sale solo la preservada, como antes: parar la
  migración por esta red (un disco lleno) sería peor que el daño que cubre;
  (5) **se retira por MARCA, no por fase**: el cierre del reconcile de `done` (`stampMigrationFinished`) la pone y el primer
  drain completo DESPUÉS borra el registro. Con la fase a secas el runtime podía retirarlo antes de que el reconcile
  restaurara (arranca con el reconcile pendiente). **Si esa restauración toleró unos metadatos de CloudKit ilegibles, no
  se marca**: pudo quedar una fila viva con la identidad del líder y el registro es lo único que traduciría su borrado.
  La vuelta atrás antes del cutover (`.rollback`) lo borra; sembrar quita una marca vieja;
  (6) canario `cloudRelayTombstoneTranslated` (el tipo).
  Residuales con ticket: un teléfono que se actualice a este build DESPUÉS de su `assignIdentity` no tiene registro y sigue
  como antes (`relay-identity-ledger-missing-after-an-update-mid-migration`). Que la restauración de #243 en el líder
  desplazado tras el cutover duplicara se descartó el 2026-09-25: esa identidad está en el backend (punto (4) de la regla
  anterior).

- **Y en el ADOPT tampoco: el marcador prueba el linaje, no las identidades (2026-09-25).**
  Ticket `adopt-window-late-leader-identity-export-can-duplicate-after-the-remount`. Un teléfono que adopta
  recibe por su espejo lo que exporta TARDE un líder desplazado (qué gana CloudKit sigue sin medir; se diseña para el peor
  caso, como en #243). Dos ventanas, medidas con tests que fallaban sin el arreglo:
  - **antes del reconcile de huérfanas**, la grande: del remonte del relevo al adopt pueden pasar días, y a partir de ahí
    CloudKit se queda con la identidad del líder (el relevo ya no espeja y no la devuelve). Con el marcador,
    `adoptLineageGate` salía en `adoptLineageProven` sin casar nada: la fila re-identificada subía como huérfana y el
    duplicado quedaba EN EL BACKEND. Le pasa también al líder desplazado cuando entra en la cuenta;
  - **del reconcile al remonte**, la del ticket: el runtime arrancaba, drenaba la edición bajo la identidad nueva (fila
    aparte en el backend) y el pull creaba un born-remote con la copia del backend.
  Seis cosas que no se tocan sin reabrirlo:
  (1) **con el marcador, las filas sin identidad del backend casan por clave de linaje ÚNICA con las que faltan**
  (`rebindRekeyedRows`, sobre el plan PRELIMINAR, antes del backfill; `lineageKeyRebinds`, la misma función del paso 1 de
  `adoptSharedRowsProof`). **Las que no traen identidad también**: la primera versión las dejaba fuera y la review lo
  tumbó, porque en un reintento el backfill anterior ya se la había dado y el mismo teléfono casaba o no según hubiera
  fallado el push. El canario cuenta solo las que traían otra identidad. En el plan definitivo no se casa;
  (2) **lo que no casa NO bloquea, a propósito**: el líder desplazado trae también filas que creó sin red, que no están en
  el backend y tienen que subir, y con el marcador faltan casi siempre filas (lo que el relevo escribe tras su remonte no
  llega por CloudKit). Bloquear dejaba fuera para siempre a todo teléfono que adopte. Sube como antes: las categorías del
  usuario no tienen clave, los movimientos cuyo `createdAt` rellenó cada teléfono tampoco casan, los tipos de cambio no
  piden linaje (`adoptLineageExemptTables`) y una gemela BORRADA en el backend no casa (el casado mira solo las vivas),
  así que el movimiento borrado vuelve. Residual con ticket
  (`adopt-rekeyed-rows-without-a-unique-lineage-key-still-duplicate`);
  (3) **el adopt siembra `RelayIdentityLedger` con sus identidades DEFINITIVAS** (`pinAdoptedIdentities`, tras la guarda
  definitiva y antes del primer `await` que la sigue, en todas las salidas que terminan el adopt, también sin huérfanas),
  captura las coordenadas de sus testigos (el drain las pide para traducir un borrado, #244) y deja la **marca del adopt**
  (`RelayIdentityLedger.markAdoptPin`). Sembrar quita esa marca: la siembra de una ida no la hereda;
  (4) **el runtime restaura al arrancar tras el remonte, antes de su primer drain y de su primer pull**
  (`CloudSyncEngine.restoreAdoptedRelayIdentitiesIfPinned`, en `CloudSyncRuntime.start`), y marca el registro para que ese
  drain lo retire. **Por `Z_PK`, no por coordenadas** (`restoreRelayIdentitiesFromLedger`): tras el remonte no hay espejo y
  la lectura de sus metadatos no está medida. Mismas condiciones que el tombstone de #244 menos las coordenadas: la
  identidad de ahora sin testigo, la del registro con testigo de su tipo, ninguna fila viva que la lleve y una sola fila que
  la reclame. Sin la marca no hace nada: la ida la sigue retirando el reconcile de `done`. Si falla, la marca se queda y
  el motor arranca igual (el registro sigue traduciendo borrados);
  (5) **en un reintento del adopt, la misma restauración al empezar el reconcile, solo hacia identidades que el backend
  conoce (vivas o borradas) o que ya esperan en el outbox** (`onlyTo`). Las del outbox cuentan porque la huérfana que la
  pasada anterior encoló y no llegó a subir aún no está en el backend: sin ella la fila subía con las dos (lo cazó la
  review). Un outbox ilegible es `.localFailure` con rastro (`adopt-reconcile-restore`). Por eso el adopt NO llama a `restoreRelayIdentities`: en el líder desplazado el
  testigo huérfano con coordenadas es SU identidad, que el backend no ha visto, y la restauración de la ida se la pondría;
  (6) canario `cloudRelayIdentityRestored`, el mismo de #243: mide lo mismo, que CloudKit le dio la razón al líder.

- **Y el adopt que entra sin marcador deja el suyo: el relevo del marcador (2026-09-25).** Ticket
  `markerless-adopt-stays-blocked-while-another-device-writes-to-the-account`. **Medido**: el líder no apaga su espejo sin
  exportar su marcador (paso 4), así que «otro teléfono escribe a diario y yo no tengo marcador» no sale de un líder que
  terminó: sale de una cuenta cuyo líder nunca lo exportó (murió o abortó tras el cutover del servidor) y en la que el que
  escribe es un ADOPTADOR. Los adoptadores no escribían marcador, y todo teléfono posterior —también el líder abortado,
  que vuelve «por adopt»— se quedaba fuera para siempre: sus filas que faltan crecen cada día y nunca viajan por iCloud.
  Flota: producción con 0 perfiles ese día, y el bloqueo solo dejaba `os_log`. Seis cosas que no se tocan sin reabrirlo:
  (1) **releva solo con COBERTURA TOTAL** (`adoptCoverageComplete`): toda fila viva del backend, en TODAS las tablas y
  fuera de `exchange_rates`, está aquí con su identidad, y hay al menos una. Más estricta que la prueba del adopt, que
  tolera filas que faltan sin gemela posible: el marcador lo va a creer otro teléfono sin mirar nada. Con eso vale lo
  mismo que el del líder: quien lo importa trae antes todo lo que el backend tenía (el espejo exporta en orden, lo mismo
  que asume el marcador del líder), y lo que se escribe en la nube después no pasa por iCloud, así que no tiene gemela.
  Sin marcador de ESTA cuenta (uno de otra no cuenta) y solo tras un reconcile `.completed`, en UN sitio
  (`relayAdoptMarkerIfCovered`, detrás de `uploadAdoptOrphans`);
  (2) **se distingue por el prefijo `relay:` de `writerDeviceID`** (`CloudMigrationMarker.isRelay`), sin campo nuevo (el
  schema de CloudKit pediría deploy a Production). No por el `deviceID`: `identifierForVendor` puede ser nil y entonces
  cambia en cada arranque;
  (3) **el líder no lo cuenta**: `isMarkerExported` y el aborto del paso 4 (`.deleteCutoverCloudKitMarkers`, efecto
  append-only) miran solo los del cutover. Si el aborto lo borrara, el borrado se exportaría y dejaría fuera a todos otra
  vez; y el líder abortado que lo conserva entra por adopt, que es lo que la cuenta necesita. **La reversa sí los borra
  todos** (`.deleteCloudKitMarker`): ahí la nube deja de mandar. `MigrationRunner.markerSeqCut` también los salta (corte 0:
  el adoptador no sabe el del líder);
  (4) **el adopt espera a verlo exportado antes de armar el apagado del espejo** (`relayMarkerAwaitingExport`, en
  `runAdoptFlow` antes y después del reconcile, con `adoptRetry(reason: "relayMarkerExport")`: el runner lo trata como la
  red). Es el paso 4 del líder para el relevo: con el par armado, el relanzamiento monta sin espejo y el marcador se queda
  en local. **Tope: 10 min desde `migratedAtStamp`** (`relayMarkerExportBudget`); vencido, o con el reloj atrasado por
  debajo del sello, entra igual: la espera es un añadido y no puede dejar fuera de la nube a quien releva. Un fallo al
  leerlo tampoco espera. El reintento de la espera sale antes del reconcile (no enumera el backend cada 30 s);
  (5) **canarios**: `cloudAdoptMarkerRelayed` (`exported` | `unconfirmed`, al terminar la espera, no al escribirlo) y
  `cloudAdoptLineageBlocked` (`noSharedRows|rowsMissing` × `active|quiet|unknown`, una vez por proceso;
  `active` = el backend se escribió en las últimas 24 h). `rowsMissing|active` sostenido es este ticket sin arreglar;
  (6) **lo que NO cierra**: el primer adoptador sin cobertura total (borró o fundió una fila de la cuenta) no releva, y los
  siguientes siguen fuera mientras alguien escriba (ticket `markerless-adopt-without-full-coverage-never-relays-the-marker`).
  Y el relevo le lleva a estas cuentas los residuales del camino del marcador: la fila sin clave única de un adoptador
  concurrente sube duplicada (`adopt-rekeyed-rows-without-a-unique-lineage-key-still-duplicate`), donde antes se bloqueaba.
  Ninguna lente encontró un duplicado propio del relevo que no exista ya con el marcador del líder.

- **Y con el espejo adjunto, el adopt no juzga un store al que aún no ha llegado el corpus de iCloud (2026-09-25).** Ticket
  `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`. **Medido**: el adopt corre con el espejo
  ADJUNTO en el resume del arranque, en el «Ya tengo una cuenta» de un Welcome que se mató a mitad (el fichero del store ya
  existe y no hay neutro) y en Ajustes (que casi siempre llega con categorías del onboarding: ahí decide la guarda). Nada
  fuerza el relanzamiento, el espejo sigue importando, y el drain traduce los imports como cualquier escritura. Con el store
  sin nada que pida linaje, la guarda devolvía `nil`, el adopt armaba la nube y el corpus que bajaba después subía entero en
  el primer drain. Cinco cosas que no se tocan sin reabrirlo:
  (1) **el paso 0-bis del reconcile** (`awaitICloudCorpusIfNotLocal`, antes de la red del backend): con el espejo adjunto y
  ninguna fila local fuera de las tablas exentas (`adoptInventoryHasLineageRows`), le pregunta a CloudKit sin el espejo
  (`ICloudPersonalCorpusProbe.adoptRelevantRecords`). `found` → `.awaitingICloudCorpus` → `adoptRetry` (techo LARGO);
  `none`/`noAccount` → sigue; `failed` → `.transient`: **sin respuesta no se entra**;
  (2) **tras un `found`, la primera tanda no basta**: espera a `adoptImportSettled` (primer import del proceso terminado y
  quieto) aunque ya haya filas, y solo entonces decide la guarda. Sin eso, una fila de la cuenta apagaba el paso 0-bis y el
  resto del corpus quedaba por encima del ancla del paso 3 (lo cazó la review). El `found` vive en memoria: un kill a mitad
  deja que la pasada siguiente juzgue lo que haya llegado, el import-lag de siempre;
  (3) **los tipos que busca son los que la guarda contaría** (`CD_` + `CloudSyncEngine.personalEntityNames` menos
  `adoptExemptEntityNames`), y `AdoptICloudCorpusCheckWiringTests` ata esa exención a `adoptLineageExemptTables` entidad a
  entidad. Baja solo metadatos (`desiredKeys: []`) y para en el primero: los tipos de cambio de ESTE teléfono ya están en esa
  zona (el espejo los exporta) y por eso no cuentan;
  (4) **los seams nacen apagados** (`adoptMirrorAttached` `{ false }`, la sonda `.failed("unwired")`, `adoptImportSettled`
  `{ true }`): el testigo del mount MIENTE en el host de test. Producción los inyecta en `CloudMigrationController.makeExecutor`
  con `attachesCloudKitMirror` —no `isICloudAvailable`, que mide Drive— y el mismo test lo fija;
  (5) **falla cerrado, con precio**: una sonda que no contesta, o un espejo que nunca baja lo que la zona tiene, dejan a esta
  población esperando hasta el techo de 72 h (`effectStalled`) donde antes entraba al momento. El canario
  `cloudAdoptICloudCorpusChecked` (`found|none|noAccount|failed:<motivo>`) lo hace visible; `failed:` sostenido en la flota es
  la sonda rota en producción. Y el 2.º teléfono de una cuenta nacida en la nube cuyo iCloud tiene un corpus VIEJO de Yala ya
  no entra por ganarle la carrera al import: sale por linaje, como siempre que el import llegaba antes.
  **Anclar la línea base sin transacción personal NO era el arreglo**: un teléfono real siempre tiene una (los tipos de cambio
  del arranque) y lo importado después del paso 3 queda por encima de cualquier ancla. Tampoco `hasCompletedFirstImport` solo
  (no se enciende con un iCloud sin nada que importar) ni la gracia de `BootSaveGateLogic` (falla abierta con un import lento).
  **Sin medir en device**: CloudKit no existe en el simulador. En `Yala Dev` con `.localNoMirror` la sonda mira el contenedor
  `.dev` y el espejo `.automatic` puede usar otro (solo desarrollo). Residuales con ticket: lo que llega al espejo DESPUÉS de la
  respuesta —otro teléfono del mismo Apple ID que escribe, o una cuenta de iCloud que se inicia tras un `noAccount`— sube igual
  (`adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check`). Lo que un import tardío trae de filas que el backend
  ya conoce se cerró el mismo día: regla siguiente.

- **Y lo que el espejo importa TARDE de filas que el backend ya conoce no sube: manda el backend (2026-09-25).** Ticket
  `adopt-window-late-imports-overwrite-newer-cloud-edits`. Tras el paso 3 del adopt (`fastForwardHistoryBaseline`) el espejo
  sigue adjunto hasta el remonte, y lo que importa ahí lo lee el primer drain tras relanzar —el síncrono de
  `CloudSyncRuntime.start`, detrás de `restoreAdoptedRelayIdentitiesIfPinned`—, y sube ANTES del primer pull. De una fila que el backend ya tiene, eso es la versión vieja de iCloud, y
  traducida subía con un HLC fresco que ganaba por LWW a la edición más nueva de la nube. Se eligió no traducirla —el pull
  trae la del backend— en vez de acuñarle el HLC que tenía: ese HLC no viaja por CloudKit y no hay de dónde leerlo. Cinco
  cosas que no se tocan sin reabrirlo:
  (1) **qué conoce el backend lo dice la enumeración del reconcile** (vivas y borradas, `enumeration.known`), guardada junto
  al registro del adopt (`RelayIdentityLedger.writeAdoptBackendKnown`, fichero `….backend-known`) por `pinAdoptedIdentities`,
  detrás de la marca del adopt. Vive y muere con el registro: la siembra de una ida la quita, la vuelta atrás la borra, la
  salida por backend vacío (`abortedEmptyBackend`) quita la de una pasada anterior, y la retira el primer drain completo
  después de que la restauración del arranque marque el registro. Si esa restauración lanza, no hay marca y la lista sigue
  hasta un arranque que termine: inerte, porque sin espejo no hay imports. **La retirada decide por la MARCA, no por el
  fichero del registro** (`retireRelayIdentityLedgerIfFinished`): un adopt sin filas acuñadas con testigo no escribe el
  registro, y con el guard de antes la lista se quedaba para siempre;
  (2) **altas, cambios y borrados**, no solo altas: un cambio o un borrado que el espejo trae de una fila conocida también
  subía con HLC fresco. **El borrado se mira con sus DOS identidades**: re-identificada por el espejo, la preservada es la
  del líder y la del registro (`relayTombstoneIdentity`) es la que el backend conoce; mirando solo la primera, el tombstone
  traducido salía (lo cazaron dos lentes de la review). Por eso esa función ya no emite su rastro ni su canario: los deja
  `translateChange` cuando el borrado sale de verdad. El borrado que no sale deja que el pull devuelva la fila (la
  resurrección benigna del residual (b) del reconcile) o la borre si el backend ya lo hizo. Si el cursor del pull ya hubiera pasado esa fila, la cura el Merkle
  (reset y re-pull en `runMerkleVerification`), inferido y sin test;
  (3) **las altas se filtran sin mirar el autor; cambios y borrados, solo con el del espejo**
  (`PrivateSignOutExportGateLogic.mirrorAuthorPrefix`). Dentro de la ventana ningún camino local da a una fila NUEVA una
  identidad que el backend ya tiene —el barrido acuña UUIDs frescos, el alta que baja del pull la firma el motor, y el
  REBIND de `backfillIdentities`, que sí reusa la identidad de un testigo, corre en el reconcile, antes del paso 3—, así que
  el alta no depende de una firma sin medir en device; lo que se edita o borra en este teléfono en la ventana sí sale, con
  cualquier otro autor. **Si añades un camino que inserte una fila con una identidad del backend después del paso 3, este
  filtro se la come**;
  (4) **lo que el backend NO conoce sigue subiendo**: es `adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check`.
  Y lo que el backend aprendió después de la enumeración (otro teléfono que sube en la ventana) no está en la lista: sube
  como antes. Tampoco cierra una edición de este teléfono en la ventana sobre una fila que el espejo pisa DESPUÉS: el drain
  construye el cambio desde la fila viva y sube, en las columnas que el usuario tocó, el valor que dejó el espejo (ticket
  `adopt-window-user-edit-uploads-the-value-the-mirror-wrote-over-it`);
  (5) **una lista ilegible es «como antes»**, con rastro (`relayIdentityLedgerUnavailable(step: "drain-backend-known")`):
  parar el motor por esta red sería peor, la regla del registro. Canario `cloudAdoptLateImportSkipped` (tipo, cuántos),
  contado solo en las transacciones que el drain consume: distinto de cero mide lo que el ticket solo pudo inferir, **salvo
  en un drain que re-anclara el token** (`historyTokenRecovered`): esa recuperación relee un margen anterior al paso 3 y sus
  imports también se saltan y se cuentan.
  **Cambió un contrato de `adopt-window-late-leader-identity-export-can-duplicate-after-the-remount`**: sus tests afirmaban
  que la edición que el espejo trae junto con la re-identificación sube tras restaurar; ahora no sube y manda el backend,
  y sigue sin duplicarse. Lo fijan los `adoptLateImport_*` de `MigrationWorkExecutorTests` (con control sin la lista) y
  `start_afterAnAdopt_restoresTheRekeyedIdentityBeforeTheFirstDrain`, que sigue cazando el orden: restaurada después del
  drain, la edición saldría con la identidad del líder.

- **Y la espera del seguidor también: techo, aviso y «Cancelar» (2026-09-23).** Ticket
  `adopt-follower-waits-for-the-leader-with-no-ceiling`, decisiones de Jürgen: el techo del 22 % y la salida del adopt.
  `waitingForLeader` —el adopt cuyo claim contestó `claiming_in_progress`— solo apuntaba `lastClaimBlocker` con la
  sesión borrada o un 403 y devolvía sin evento: «esperando a otro dispositivo» para siempre. Cuatro cosas que no se tocan
  sin romperlo:
  (1) **es el cuarto `ForwardStepPhase`** (raw `waitingForLeader`, valor nuevo de `cloudForwardStepWaiting` y
  `cloudForwardStepAborted`) y usa los mismos campos `forwardStepStall*`, sin schema nuevo. `pollLeaderInternal` clasifica
  como `driveClaim` (sesión borrada por el SDK y 403 al corto; red y 401 con la sesión guardada al largo);
  (2) **aquí el avance es que el servidor vuelva a contestar `claiming_in_progress`**: prueba que el líder latió en la
  última hora (la rama no refresca el lease; desde `displaced-migration-leader-keeps-uploading-after-a-takeover` el latido
  sale con la puerta de la subida y de la verificación del líder, avance o no: ver la regla del líder desplazado). `noteLeaderAlive`
  BORRA los dos relojes en su propio save, porque la fase no cambia, y **no los re-sella**: los sella la primera
  observación que no avanza, como en los otros tres. La primera versión sellaba al entrar y en cada respuesta, y la review
  lo tumbó: el seguidor es justo quien cierra Yala mientras espera, y al volver días después sin red el primer poll lo
  sacaba con «lleva días sin avanzar» aunque su líder hubiera terminado. Al seguidor no lo acotan los techos del líder
  sino el lease: a los 60 min sin latido el claim contesta `created` y el seguidor pasa a liderar. Residual: una fila con
  `migration_in_progress` y el latido `NULL` no caduca nunca (lo avisa el SQL de `claim_account`); ahí la salida es
  «Dejar de esperar»;
  (3) **`AdoptClaimScope.isAdoptClaim` y `ForwardCancelScope` lo incluyen**: misma marca `adoptClaimExitRaw`, mismo aviso
  (`adoptClaimNotice`) y mismos textos de la tarjeta de fallo. **El botón y su diálogo son propios** («Dejar de esperar»,
  `canStopWaitingForLeader`; texto de Jürgen del 2026-09-23): «Cancelar la activación» bajo «otro de tus dispositivos está
  activando la nube» se leía como parar el otro teléfono, que no se entera. Con eso deja de perderse el «sí» dado con el
  claim del adopt en vuelo cuando contesta `claiming_in_progress`: la pasada lo honra en la espera en vez de retirarlo;
  (4) **el «sí» se mira ANTES de volver a reclamar, tras un `claiming_in_progress` y antes de traducir un `created`**: el
  poll no pasa por `drive()` en los dos primeros, y en el tercero el relevo escribía el faro y cancelaba ya en la
  identidad, sin marca. Si el líder terminó, lo para además la comprobación previa al efecto del adopt.

- **Y la sesión que abrió el adopt se cierra cuando el adopt sale (2026-09-23).** Ticket
  `adopt-exit-keeps-the-session-it-opened`, decisión A de Jürgen: techo, «Cancelar» y «Dejar de esperar» cierran la sesión que
  firmó el propio intento, como hace «Migrar» (`closeSessionIfOpened`, que sigue siendo el único `signOut` del controller).
  Sin eso `GroupsAssociationRegistrar` la registraba como cuenta de grupos en el arranque siguiente. Seis cosas que no se
  tocan sin romperlo:
  (1) **el testigo es DURABLE** (`AdoptSessionOwnership`, key `cloudSync.adoptSessionAccountHash`, sin schema): el techo del
  efecto son 72 h y casi siempre vence en el `resume` de un arranque posterior, así que el molde en memoria de
  `migrationAttempt` solo cubría el caso raro. Guarda el hash del faro de la cuenta, y solo cierra si la sesión viva es ESA;
  **y describe una SESIÓN**: `CloudAuthService` la borra en cada sign-in y sign-out (una sesión de Grupos firmada después
  con la misma cuenta la heredaba);
  (2) **se apunta ANTES de conducir y se retira si la llamada no llegó al claim** (`stoppedBeforeTheClaim`). Después, un
  kill en la primera pasada —que dentro de un solo `submit` hace el claim y hasta el efecto— dejaba el adopt sin marca;
  sin retirarla, un `authenticating` normalizado se leía como salida y la bienvenida perdía la sesión de su «Retomar». Con
  la marca puesta, «salió» es `failedRollback` o `notStarted` sin el efecto, y eso cubre también las salidas del líder de
  un adopt que contestó `created`, que no dejan `adoptClaimExitRaw`;
  (3) **«la abrió el intento» es literal**: en Ajustes, el camino que firma; en la bienvenida, la pantalla que firmó
  (`sessionOpenedHere`). La sesión de Grupos (`.useLiveSession`) y la que trae la puerta de Grupos al cover
  (`adoptCompleteAccountFromGroups`) no se cierran nunca. Un intento que no abrió la suya conserva la marca solo si ya
  describe la sesión viva (`markToRecord`: un «Retomar» tras relanzar), y «Migrar» la borra;
  (4) **se mira por NIVEL** (`closeSessionOfExitedAdopt`) tras `resume`, `pollLeader` y `cancelMigration` y al empezar
  `resumeIfNeeded`, que es el arranque y el re-kick. El adopt que llega a la nube la olvida sin cerrar, y sin sesión
  legible no se decide (un llavero aún protegido no es «otra sesión»);
  (5) **el registrador de Grupos no asocia la sesión de un adopt** (`ownsLiveSession`, dentro de
  `syncFromLiveSessionIfNeeded`): `signOut` espera antes de borrar la sesión y en el arranque el registrador podía llegar
  antes, y un arranque a MITAD del adopt la asociaba. La bienvenida sin sesión vuelve a firmar en su «Retomar».
  (6) **la parada ANTES del claim cierra la sesión solo en Ajustes** (2026-09-24, ticket
  `settings-adopt-stalled-before-the-claim-keeps-the-session`): si `submit(.signInSucceeded)` vence la quiescencia, la rama
  adopt de `continueToClaim` cierra la que abrió el intento y avisa, como «Migrar». El predicado es el MISMO que retira la
  marca (`withdrawAdoptSessionOwnershipIfNotStarted` devuelve si paró): dos definiciones de «no llegó al claim» divergirían.
  La bienvenida no pasa por `continueToClaim` y conserva la sesión para su «Retomar»; no le añadas el cierre. El aviso nombra
  iCloud solo con el import aún sin asentar (`settingsAdoptStoppedBeforeTheClaim`) y no habla de la sesión, porque sale
  también cuando el intento reusó la de Grupos y no cerró nada. Lo fijan `AdoptSessionOwnershipTests` (tabla, tienda y cableado con los
  cuerpos enteros) y `GroupsAssociationRegistrarTests.noRegistraLaSesionDeUnAdopt`.

- **La espera de `reverseUpload` también lleva techo, y mide el tiempo SIN AVANZAR, no el total (2026-09-16).** Ticket `reverse-upload-has-no-ceiling-and-no-exit`, decisiones de Jürgen: 15 min si CloudKit ya dijo que no entra, 72 h si no se sabe (desde el 2026-09-23 son 15 min ACUMULADOS bajo motivos definitivos y 72 h sin avanzar con cualquiera, punto 2), y «Cancelar y seguir en la nube» disponible durante toda la espera. Las dos salidas **de esta espera** vuelven al ORIGEN (`done`/`notStarted`) en modo nube con `[.rearmMirrorOff, .reverseRollback]` en ese orden —**las dos de las fases previas al montaje salen SIN efectos y con el `reverse_abort` fuera del journal**, regla propia más abajo, así que `ReverseExitPending` y el aviso de pantalla que usa su predicado no las ven—: lo local, que no puede lanzar, antes que el `reverse_abort` de red. Cinco cosas que no se tocan sin romperlo: (1) **el muestreo cuenta TODAS las filas vivas** (`MigrationWorkExecutor.collectReverseUploadPairs`), con testigo scratch las que no tienen `SyncIdentity`: lo creado en el teléfono por una cuenta nacida en la nube no tiene testigo (solo lo crean `backfillIdentities` y el pull de filas nuevas), y emparejar solo con testigo daba cero pares y una vuelta «drenada» al instante sin nada en iCloud; (2) **el reloj es el del último avance** (`reverseUploadProgressAt`) y avanzar es bajar de la cifra más baja vista (`reverseUploadLowestPending`); lo escrito durante la espera sube la cifra y borrar la baja, así que un borrado cuenta como avance (sesgo hacia esperar, a propósito); el tiempo con Yala cerrada también cuenta —el espejo no sube— y tras 72 h la salida llega en la primera observación al abrir (D16, aceptado). **Desde el 2026-09-23 son TRES relojes, el molde de las fases previas al montaje** (ticket `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`, schema 14 → 15, cinco campos `reverseUploadCause*`/`reverseUploadDefinitive*` y `clearReverseUploadCeiling()` para los siete `reverseUpload*`): el de avance gobierna las 72 h con CUALQUIER motivo; el de «cualquier motivo definitivo» (`CauseStallClock.observeAnyDefinitive`) acumula desde el último avance lo que la espera lleva bajo `icloudFull` o `icloudUnusable`, sean el mismo o se turnen, y gobierna los 15 min; el de causa solo elige el TEXTO (`MigrationRunner.reverseUploadExitReason`: el específico si UN motivo agotó solo el plazo, si no `stalled`, cuyo texto no afirma días ni motivo). `icloudOff` y `unknown` **pausan** los dos acumulados —son la «red» de esta espera—, y **un avance los reinicia**. Hasta ese día el corto se medía contra el de avance: tres horas sin cuenta y el `notAuthenticated` que CloudKit suelta justo al entrar sacaban de la vuelta en esa misma pasada, sin un reintento. Queda una salvedad de la familia entera, con ticket (`stall-clock-charges-a-closed-app-gap-to-a-one-off-cause`): un tramo abierto sigue contando con la app cerrada, y aquí la señal de CloudKit vive en memoria, así que la primera pasada tras relanzar lo cierra con esas horas. El canario pasa a `stalled|<tramo de avance>|<tramo de causa>|<motivo>`, con `-` sin motivo definitivo; (3) **se vuelve a la fase origen, no a `reverseFailedRollback`**: ahí el motor no arranca hasta un toque y el techo salta con la persona ausente; y como esa fase queda con `.reverseRollback` pendiente si no hay red, `submit(.reverseActivated)` DRENA esa salida antes de empezar otra vuelta —`handle` reemplaza los pendientes, y borrar el abort dejaba la vuelta nueva al 30 % contra la nube congelada—. **Solo esa** (`ReverseExitPending`): un `.runLeaderReconcileFromFrozenCloudKit` en `done` o un `.adoptBackendAccount` en `notStarted` se reemplazan como siempre, porque el reconcile de un líder al que otro dispositivo le quitó la lease lanza mientras el otro lidera (desde el 2026-09-24 espera sin subir y se une o vuelve a liderar cuando el otro cierra o suelta: regla del líder desplazado después del cutover) y drenarlo bloquearía esta vuelta mientras tanto; el aviso de la pantalla usa el mismo predicado; (4) **solo la palabra VIGENTE de CloudKit acorta**: `lastExportError` no se limpia con un éxito, así que `ReverseUploadBlockerLogic` exige que `iCloudSyncService.lastExportErrorAt` sea posterior a `lastSuccessfulExportDate`; (5) **sin token de iCloud la causa es `unknown`** y el aviso es condicional: el token mide Drive. Es MÁS permisiva que la ida, no igual —allí `noAccountWithFootprint` sí acorta sin error de CloudKit—. La excepción al «post-montaje HOLD, nunca rollback» de la máquina es solo esta espera: un `fatalError` post-montaje sigue holdeando. Residuales con ticket: `reverse-cancel-pushes-what-the-mirror-imported-during-the-wait`, `cloud-engine-can-start-with-a-reverse-abort-pending`, `reverse-upload-sample-reads-unreadable-rows-as-drained`, `reverse-exit-on-a-reverted-account-rejects-the-retry`, `reverse-abort-rejected-leaves-a-frozen-cloud-saying-up-to-date`, `reverse-exit-leaves-a-partial-copy-in-icloud`, `reverse-upload-ceiling-trusts-a-clock-set-back-during-the-wait` (el re-sellado de un sello futuro también cree un reloj atrasado ahora) y `reverse-upload-sample-walks-every-row-twice-on-the-main-thread`.

- **El claim de la reversa tampoco puede quedarse sin salida: todo `.rejected` vuelve al origen (2026-09-16).** Ticket `reverse-claim-rejection-has-no-way-out-in-the-client`. `reverseClaimLeader` es TRANSITORIA: con ella journaleada el motor de la nube no arranca (`CloudSyncRuntime.canRunDomain`; el bucle que ya corría no re-mira la fase, así que el daño es de entre arranques) y los BGTasks se difieren, así que una fase que no sale deja el teléfono sin sincronizar tras relanzar, no solo una barra al 15 %. Cuatro cosas que no se tocan sin romperlo: (1) **la salida va SIN efectos de la máquina** (`reverseClaimRejected(returnTo:)`, gemela de `reverseOtherLeader`, `reversePreMountStalled` y `reversePreMountCancelled`): los rechazos de `reverse_claim` salen del RPC antes de cualquier UPDATE (medido en el cuerpo vivo de producción, md5 `14fc5e2c…`), y un `.reverseRollback` sin red se quedaría pendiente en la fase estable con el motor parado; (2) **pero SÍ repone los pendientes del origen** que `reverseActivated` reemplazó (`MigrationState.reverseOriginPendingEffectsData`, decidido por `ReverseOriginPendingEffects.restoresOnReturn`: toda vuelta al origen antes de que el servidor conceda la reserva, también declinar o un kill en la confirmación). Lo cazaron dos lentes de review por separado: el `.runLeaderReconcileFromFrozenCloudKit` de un líder es lo ÚNICO que manda `complete`, y sin reponerlo `migration_in_progress` se quedaba puesto en el backend para siempre —antes lo curaba el takeover de la reversa a los 60 min—, con otro dispositivo esperando al líder sin fin. Si el pendiente repuesto lanza, la salida ya está journaleada y se anota igual; (3) **un motivo desconocido es PERMANENTE** (`ReverseAbortReason.forClaimRejection`): solo `migration_in_progress` es pasajero, y leer lo desconocido como «reintenta» es el 15 % eterno con otro nombre; `.transient` y `.sessionExpired` sí siguen retomables **hasta el techo largo de la etapa, 72 h** (regla propia más abajo); (4) **la alerta compara `MigrationRunner.lastReverseClaimExit` antes y después de llamar al runner** (`CloudMigrationController.announceReverseClaimExit`, en `startReverse` y en `resume`), porque la nota journaleada (`reverseAbortReasonRaw`, el mismo campo de la espera) no distingue un rechazo de ahora de uno anterior; sale con el toque, con «Retomar» y con un re-kick, y solo se ve con la pantalla de Almacenamiento delante. Nota y alerta salen de `L10n.Storage.ReverseAbort.note(for:)`, en pasado a propósito: la nota dura días. Residuales con ticket: una respuesta perdida de un claim fresco en una cuenta ya revertida deja la reserva de este dispositivo puesta y el reintento en `not_complete` (`reverse-exit-on-a-reverted-account-rejects-the-retry`, que también recoge un `not_complete` que tapa la vuelta en curso de otro dispositivo), la sesión caducada en las fases previas al montaje se cerró el 2026-09-17 (`reverse-before-mount-stays-stuck-with-an-expired-session`, regla propia más abajo), el toque se pierde en silencio si hay un resume en vuelo (`reverse-tap-is-lost-while-a-resume-is-running`), y un pendiente repuesto que falla (líder desplazado mientras el otro lidera; desde el 2026-09-24 ya no para siempre) deja el motor sin arrancar esa sesión si hubo un arranque con la vuelta a medias (`reverse-claim-exit-with-a-restored-failing-effect-keeps-the-engine-off`): se aceptó porque lo repuesto es lo que el teléfono ya tenía antes del toque.

- **Y una sesión que caduca ANTES de montar el espejo tampoco puede dejar la barra muda (2026-09-17).** Ticket
  `reverse-before-mount-stays-stuck-with-an-expired-session`. Las cuatro fases previas al montaje —`reverseClaimLeader`,
  `reverseDrainAll`, `reverseVerify`, `reverseFreezeBackend`— leían la sesión caducada como un corte retomable sin
  evento, y ninguna es estable: con ellas journaleadas el motor de la nube no corre y el aviso de «vuelve a entrar» de
  Ajustes (`syncNeedsSignIn`) **no puede salir**, porque ese exige el runtime en `.stoppedUntilSignIn` y lo que se pinta
  es la tarjeta de progreso. Cinco cosas que no se tocan sin romperlo: (1) **lo que separa «caducada» de «sin red» es
  `canRenewSession`, y hay que ponerlo en los dos pasos que piden el token a mano** (`performReverseClaim`,
  `freezeBackendForReverse`); en el drain y el verify ya lo hacen `SyncPushClient`/`SyncPullClient` desde el 2026-09-16,
  y repetirlo ahí sería el pre-filtro tapando al criterio. `/account/migration` no exige App Attest, así que su 401 es
  siempre el JWT: no hay segundo 401 que separar, a diferencia de `/sync/*`. (2) **`reverseVerify` no gasta `verifyNetworkRetries` ni degrada** —hasta el 2026-09-21 cortaba SIN evento; desde el techo de la etapa emite `reversePreMountStalled`, que bajo presupuesto holdea en la misma fase y sin efectos—:
  con el trato de red gastaba `verifyNetworkRetries` y al tope degradaba a `reverseFailedRollback` **con
  `.reverseRollback` pendiente**, un efecto que con la sesión caducada lanza en cada resume — la fase de fallo se
  quedaba con su abort sin ejecutar. (3) **El hecho vive en memoria** (`MigrationRunner.lastReverseSessionExpiry`, molde
  de `lastReverseUploadSample`), y lo repone el resume del arranque y el re-kick de 30 s de la pantalla, que para las
  cuatro fases deciden `.resume`. Journalearlo obligaría a borrarlo en cada paso con éxito: un testigo que sobrevive a
  lo que describe. (4) **Un escritor y UN borrador**: `noteReverseSessionExpiry` pone, `drive()` borra al empezar cada
  pasada. Repartir el borrado por cada outcome que avanza o corta por red deja líneas que se cumplen solas —desde un
  claim aceptado toda continuación pasa por otro escritor—, así que quitarlas no cambia nada observable y **ningún test
  puede cazarlas**: fue un mutante superviviente. (5) **El canario va por `canaryOnce` con la fase en la clave**: el
  re-kick choca con el mismo hecho cada medio minuto. La IDA **no cambia** —`driveVerify` agrupa el caso nuevo con la
  red, que es su trato de siempre— y eso es una decisión con test (`forwardVerify_sessionExpired_spendsNetworkRetry`) y
  residual propio (`forward-verify-reads-an-expired-session-as-network`); `.accountUnavailable` (403) sigue leyéndose como red **en la verificación de la IDA, en el claim y en el congelado** —la subida del snapshot lo tipa desde el 2026-09-22— (`/account/migration` no devuelve 403 y `CloudAccountClient` manda a `.transient` todo lo que no sea 200/401); **en el drenaje y el verify de la VUELTA sale TIPADO desde el 2026-09-21** (`.blocked(.accountUnavailable)`), porque es lo que elige el techo corto de la etapa. Sigue sin ofrecer «Iniciar sesión»: no es una sesión que renovar.

- **Y las cuatro fases previas al montaje también tienen techo y salida, con efectos CERO (2026-09-21).** Ticket
  `reverse-before-mount-has-no-way-to-abandon-the-return`. Hasta ese día `reverseClaimLeader`, `reverseDrainAll`,
  `reverseVerify` y `reverseFreezeBackend` podían quedarse paradas para siempre, y ninguna es estable: el teléfono deja
  de sincronizar, no solo se queda la barra al 15/30/50/62 %. Nueve cosas que no se tocan sin romperlo:
  (1) **Son TRES relojes: el de fase y el de lo definitivo deciden la salida, y el de causa el copy** (`MigrationState`, SIETE campos aditivos,
  schema **6 → 8 → 12**: `reversePreMountProgressAt` + `reversePreMountPhaseRaw` para el de FASE;
  `reversePreMountCauseRaw` + `reversePreMountCauseAt` + `reversePreMountCauseAccruedSeconds` para el de CAUSA, que
  entró el 2026-09-22 con `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`; y
  `reversePreMountDefinitiveAt` + `reversePreMountDefinitiveAccruedSeconds` para el de «CUALQUIER motivo definitivo»,
  que entró el 2026-09-23 con `alternating-definitive-causes-never-reach-the-short-ceiling`; una fila vieja los lee
  `nil` y el presupuesto le empieza a contar desde que este build la mira). El de FASE mide el tiempo desde el último
  CAMBIO DE FASE —aquí no hay cifra que baje, así que avanzar es pasar de fase— y gobierna el techo LARGO. El de lo
  DEFINITIVO mide el tiempo ACUMULADO bajo motivos que esperar no arregla, **sean el mismo o se turnen**, y gobierna el
  CORTO. **Se sale con el primero de los dos que venza.** El de CAUSA ya no decide la salida: decide el COPY (1-bis).
  **Hasta el 2026-09-23 el corto se medía contra el de CAUSA**, y dos motivos turnándose —un 403 y un store que falla a
  ratos, alcanzable en el drenaje desde `verify-reads-a-failed-local-fetch-as-an-empty-outbox`— lo reiniciaban en cada
  observación: con el re-kick de 30 s no pasaba nunca de cero y la salida se iba al largo, 72 h. El de lo definitivo es
  `CauseStallClock` con una sola clave para todo lo definitivo, así que **conserva el criterio del de causa por la
  pausa**: la red no trae motivo, las horas de red no las acumula nadie, y un `localFailure` aislado tras ellas empieza
  en cero. Lo que SÍ suma entre motivos es el tiempo bajo otro motivo definitivo, y es a propósito — **incluido un hueco
  SIN observaciones** entre dos motivos distintos (un 403, la app cerrada, un fallo local al volver): es la regla que el
  de causa ya aplicaba a un solo motivo, y está fijada con test
  (`reversePreMountDefinitiveClock_anUnobservedGapBetweenTwoCauses_counts`). La máquina no mira el de causa: todo lo
  que acumula un motivo lo acumula también el de lo definitivo —salvo una fila v11 parada a mitad de fase, que trae el
  de causa lleno y el nuevo vacío y sale como mucho un plazo corto después—, así que como término de salida sobraba. **El mismo agujero en la subida del snapshot se cerró el mismo día con el
  mismo reloj** (`snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`; regla de la subida,
  punto 2), y los dos llaman a `CauseStallClock.observeAnyDefinitive`; la espera de subida de la vuelta, también, desde `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`. En la ida sin cifra se midió y no es alcanzable
  de forma sostenida.
  Cuatro cosas del reloj de causa, y las cuatro son la decisión: **(a)** la clave es el `rawValue` del blocker y no su
  `abortReason` —`accountUnavailable` y `refused` comparten copy, y fundirlos sumaría dos causas como si fueran una; hoy
  eso decide el copy y el canario, no la salida—;
  **(b)** una observación SIN motivo lo **PAUSA**, no lo borra: la pantalla de Almacenamiento re-kickea cada 30 s, así
  que con una racha consecutiva bastaba un timeout de red cada quince minutos para que los 900 s no llegaran nunca y
  el desenlace pasara de 15 min a 72 h (lo cazaron dos lentes de review); un hueco no prueba que el motivo se fuera,
  solo que no se pudo preguntar, así que no cuenta ni a favor ni en contra (ojo: habla de un hueco en el que se
  OBSERVÓ red; uno sin ninguna observación deja el tramo abierto y sí cuenta); **(c)** un cambio de CAUSA sí tira lo
  acumulado del motivo anterior; **(d)** un sello del tramo abierto en el FUTURO se re-ancla conservando lo acumulado.
  Los siete campos se limpian SIEMPRE juntos, con `MigrationState.clearReversePreMountCeiling()`, en cinco sitios: una
  vuelta nueva los limpia en el cruce a `reverseClaimLeader` —o la primera observación daría un `stalled` de días—,
  los tres cierres de intento y el reset tras rollback (la normalización de un journal ilegible se retiró el 2026-09-25).
  **Y el cambio de fase
  los limpia en `handle`, no solo la observación al ver otra fase**: `reverseVerify` vuelve a `reverseDrainAll` por
  mismatch, y sin esa limpieza la segunda visita al drenaje heredaba el sello de la primera y el techo saltaba con
  cero segundos de parada real (lo cazó una review).
  (1-bis) **El motivo que se journalea al salir lo elige el techo que VENCIÓ, no la última observación**
  (`MigrationRunner.reversePreMountExitReason`, y el predicado del techo corto vive en UN solo sitio,
  `MigrationPolicy.reversePreMountCauseCeilingReached`, porque lo consultan la máquina y el runner). Con dos relojes,
  la vuelta puede salir por el de FASE en una pasada que casualmente traiga un motivo recién visto: journalear ese
  blocker le diría «tu cuenta en la nube no lo permitió», con el correo de soporte, a quien llevaba tres días sin red.
  Si el 403 es real no se pierde nada — la persona reintenta y a los 15 min sale con el motivo bueno. **Desde el
  2026-09-23 el texto específico se mide contra el reloj de CAUSA y la salida contra el de lo definitivo**: si el corto
  venció con motivos mezclados, ninguno de los textos específicos es verdad entero y sale `preMountStalled`; si un
  motivo solo agotó el plazo, los dos relojes vencen en la misma observación y sale su texto. Límite aceptado: la clave
  del de causa es el `rawValue`, así que `accountUnavailable` y `refused` turnándose salen con el genérico aunque los dos
  digan lo mismo — no miente, y cambiar la clave le cambiaría el significado al tramo del canario.
  (2) **Solo acorta lo que no se arregla esperando** (`ReversePreMountBlocker`: el 403 `accountUnavailable` del drenaje
  y del verify, el `other_leader` y el `rejected` del congelado; desde el 2026-09-22 también `localFailure` —un `fetch`
  de SwiftData que lanzó— y `unknownVerdict` —un veredicto con un motivo que este build no
  sabe leer—, ticket `reverse-verify-network-bucket-hides-a-definitive-server-no`): 900 s. **`localFailure` nació
  acotado a la verificación y ese mismo día dejó de estarlo**: `verify-reads-a-failed-local-fetch-as-an-empty-outbox`
  lo añadió al **DRENAJE** (`reverseDrainOnce`, cuando el `fetch` del outbox lanza) y a las dos lecturas que
  `verify()` hace antes de preguntarle nada al Merkle. ⇒ **la fase `drain` pasó de tener UN motivo definitivo a
  tener DOS**, y con la regla «causa distinta ⇒ el reloj corto empieza de cero» eso las hace mutuamente
  cancelatorias: una cuenta suspendida **y** un store que falla a ratos alternan `accountUnavailable`/`localFailure`
  en cada observación, el reloj corto se re-sellaba siempre y los 900 s no vencían nunca — la salida se iba al reloj de
  FASE, 72 h. `reverseVerify` ya tenía tres motivos y por tanto ya era alcanzable ahí. **Cerrado el 2026-09-23** con el
  reloj de lo definitivo (punto 1): `alternating-definitive-causes-never-reach-the-short-ceiling`. **Hasta ese día la regla
  decía «solo la palabra del SERVIDOR» y dejó de ser cierta**: los dos nuevos no son una respuesta de nadie. Los dos
  salen con `preMountStalled` y NO con `preMountRefused`, porque ese copy acusa a la cuenta en la nube y da el correo
  de soporte — y ahí no habló ninguna cuenta; lo cazaron dos lentes de la review. El canario de la espera renombró su
  prefijo de `server_` a `stop_` por lo mismo, así que la serie `cloudReversePreMountWaiting` cambia de valores con ese
  build. **Y esos 900 s son del reloj de lo DEFINITIVO desde el 2026-09-23** (del de CAUSA entre el 22 y el 23) —parada
  ACUMULADA bajo motivos definitivos, no parada de la fase—, que es lo que cerró
  `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`: hasta ese día un `localFailure` aislado tras
  horas de espera por red se cobraba las horas y sacaba en el acto, sin un reintento. La red y la sesión caducada van al largo, 259 200 s —
  esa segunda mitad es la que cubre «una cuenta a la que ya no se puede entrar». Es lo CONTRARIO del fail-open de
  `ReverseUploadBlockerLogic` —allí la ambigüedad no era una respuesta— y por eso los dos clasificadores conviven en el
  mismo fichero. Los tres motivos **llegaban colapsados en `.transient`** hasta este ticket: sin separarlos no hay techo
  corto posible, y esa es la razón de que el congelado fuera la única de las cuatro sin ninguna salida.
  (3) **La salida va SIN un solo efecto de máquina**, y las dos mitades son decisiones: sin `.rearmMirrorOff` porque
  pre-montaje el espejo nunca se re-encendió, y sin `.reverseRollback` porque ese efecto LANZA con el token ausente, con
  la sesión caducada y con cualquier `.transient` —el 403 incluido—, y un efecto que lanza no se consume:
  `MigrationBootDecision.decide` devuelve `.resume` mientras haya pendientes ⇒ relanzaría en cada arranque. Ese es el
  criterio 3 del ticket.
  (4) **El `reverse_abort` lo intenta el RUNNER, una vez, best-effort y DESPUÉS de journalear la salida.** Si el proceso
  muere en medio, «en el origen con la reserva puesta» se cura solo y «en una fase pre-montaje sin reserva» no. Cuesta
  poco: el re-claim del MISMO dispositivo es idempotente-ok y no mira la edad del lease
  (`gateway/test/account.goldens.test.ts`, golden 14); para los demás dispositivos, 60 min. **Y se intenta también
  cuando el paso que journalea LANZA** (`leaveReversePreMount`): la salida se salva antes de drenar los pendientes que
  `handle` repone, así que un reconcile que falla siempre dejaba el aviso al servidor sin intentar NUNCA — no es un
  efecto journaleado y la fase ya no vuelve a pasar por ahí.
  (5) **Salir de `reverseClaimLeader` repone los pendientes del origen** (`ReverseOriginPendingEffects.restoresOnReturn`
  decide por FASE, no por evento), así que «la salida no deja efectos» es cierto de la MÁQUINA, no del journal. **Y el
  brazo que los DESCARTA exige salir de la fase** (`next != .reverseClaimLeader`): el techo le dio a esa fase su primer
  self-hold, y sin ese término un claim sin cobertura tiraba el `.runLeaderReconcileFromFrozenCloudKit` del líder —lo
  único que manda `complete`— y el rechazo posterior reponía una lista vacía.
  (6) **El botón es UNO para las cinco fases que lo ofrecen** (`MigrationRunner.cancelReverse`, `canCancelReverse`), y
  el cuerpo de su confirmación se elige con un predicado POSITIVO (`isBeforeReverseMount`): «¿no es la espera de la
  subida?» falla abierto y le daría «no hay que relanzar» a una fase post-montaje. **Y firmar para continuar RETIRA un
  «Cancelar» apuntado** (`signInToResumeReverse`): hasta este ticket los dos botones no podían coexistir, y con el
  nuevo en esas cuatro fases un «sí» que la pre-espera no dejó pasar abandonaba, en silencio y sin nota, la vuelta que
  la persona acababa de rescatar.
  (7) **El copy no reusa los textos del claim**: `preMountRefused` y `preMountOtherDevice` existen porque los del claim
  dicen «no pudimos EMPEZAR» y aquí la reserva ya existía. El mismo argumento vale para los dos; aplicarlo a uno solo
  fue un hallazgo de review.
  (8) **El canario va por observación** (`cloudReversePreMountWaiting`, `canaryOnce`) además del de la salida
  (`cloudReversePreMountAborted`): sin él, un 403 sistémico en toda la flota sería invisible 15 min o 72 h, que es
  justo lo que tarda en dejar de serlo por sí solo. Su detalle es `<fase>|<tramo de fase>|<tramo de causa>|<causa>`
  desde el 2026-09-22, con `-` en el tramo de causa cuando la observación no trae motivo: **publicar un solo reloj
  dejaba ciega la mitad del mecanismo** en las dos direcciones —solo el de fase leería «tres horas de avería local»
  por un fallo de doce segundos; solo el de causa dejaría un teléfono con dos motivos alternándose 72 h publicando
  `lt_15m` y, con el dedupe por proceso, la flota vería UN evento diciendo que no pasa nada—. La serie cambió de
  valores dos días seguidos (21 y 22 de septiembre). **El 23 NO cambió**, aunque el corto pasó a medirse contra el
  reloj de lo definitivo: el tercer segmento sigue siendo el tramo de CAUSA, que es el que deja reconocer la alternancia
  en la flota (fase creciendo, causa siempre en `lt_15m`), y cambiarle el significado por tercera vez rompería la serie.
  (9) **La red PURA del verify entró al techo el 2026-09-21, y la salida AVISA en el momento** (ticket
  `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`: los dos residuales que este dejó, los dos
  decididos por Jürgen). Eran las dos mitades que faltaban. `reverseVerify` + red era la única de las OCHO
  combinaciones fase × causa fuera del techo —gastaba `verifyNetworkRetries` y al octavo degradaba a
  `reverseFailedRollback` con `.reverseRollback` pendiente: salida tenía, pero la peor de las dos—, y el techo
  escribía `reverseAbortReasonRaw` sin dejar nada en memoria, así que la barra desaparecía muda y la nota que
  quedaba no se distinguía de la de un intento de días atrás. Tres cosas nuevas que no se tocan sin romperlo:
  **(a)** `driveReverseVerify` manda `.networkTimeout` a `observeReversePreMountStall(blocker: nil)` ⇒ techo LARGO,
  como la red del drenaje y la del congelado. En la VUELTA el único contador S9 vivo pasa a ser el del mismatch, y
  por eso `reverseVerifyOutcome(.networkTimeout)` **dejó de ser un par legal** desde `reverseVerify` (`.invalid`):
  dejar la rama viva sin emisor es código muerto que afirma lo contrario del ticket. **La IDA no cambia**
  —`driveVerify` es otra función y sigue agrupando red, sesión y `blocked`—, y eso es una decisión con test en las
  dos capas (`forwardVerify_networkTimeout_…` en el runner y en la máquina).
  **(b)** El testigo `MigrationRunner.lastReversePreMountExit` (`ReversePreMountExit`, molde de `ReverseClaimExit` y
  de `ForwardClaimRefusal`), que escribe `reportReversePreMountExit` y **solo al DEJAR la etapa**: bajo presupuesto
  no hay salida, así que el re-kick de 30 s no repite alerta mientras la vuelta sigue esperando. La `sequence` es lo
  que distingue una salida de ahora de la nota journaleada, igual que en el claim.
  **(c)** `CloudMigrationController.announceReversePreMountExit`, en `startReverse` y en `resume` —el toque,
  «Retomar» y el re-kick—, con la foto ANTES de llamar al runner. **Pasa el motivo por
  `ReverseUploadWaitingCopyLogic.abortNote`**, y ese término es la única diferencia con el helper del claim: aquí la
  salida puede ser la que pidió la persona («Cancelar y seguir en la nube» vive también en estas cuatro fases) y
  `L10n.Storage.ReverseAbort.note(for:)` agrupa `cancelled` con `stalled` ⇒ sin el filtro, cancelar a propósito
  sacaba una alerta de error. El testigo se queda FACTUAL y quién lo enseña lo decide un solo sitio.

- **«Migrar a la nube» nunca adopta, y hacen falta las dos capas que lo impiden (2026-09-16).** Ticket `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`. Adoptar no es «no subir»: `runAdoptOrphanReconcile` sube a la cuenta toda fila local que el backend no conoce, así que con la cuenta de otra persona es una FUSIÓN que llega a todos sus dispositivos. **Capa 1, la comprobación** (`StorageMigrationIdentityGateLogic`, cableada en `CloudMigrationController.continueToClaim` y adelantada al toque con sesión viva en `preflightMigrationIdentity`): corre con el runner en `authenticating`, que no es durable, y si para vuelve por `.signInFailed` sin claim. **Sola no basta**: `/account/exists` da `groups_only` a la cuenta que volvió a iCloud y el claim le contesta `existing_stable`. **Capa 2, la intención** (`ForwardClaimIntent.migrateOnly`): con ella `driveClaim` devuelve `existing_stable` y `claiming_in_progress` a `notStarted` (`claimRefusedExistingAccount`, sin efectos: esas ramas de `claim_account` no escriben). Tampoco se sigue a otro líder (Jürgen, 2026-09-16): seguirle acaba en un adopt y relevarle sube lo local encima de lo suyo, y con otro iCloud eso mezcla dos corpus. Seis cosas que no se tocan sin romperlo: (1) **la intención que decide es la JOURNALEADA** (`MigrationState.forwardClaimIntentRaw`, en el save de `authenticating → claimingMigration`), no la de memoria: un claim aparcado por la red se retoma tras relanzar con un runner nuevo, y la review midió que esa ventana no es «una petición»; (2) **la cuenta `complete` que reclamó ESTE dispositivo sigue** (sello `.proceedMigration` de `CloudClaimActionStore`): la cuenta que crea un intento ya es `complete`, y sin la excepción «Reintentar» tras un rollback quedaba bloqueado para siempre, aunque el servidor le da `created` al mismo líder. Y el `complete` del líder cambia ese sello por `.routeReturningUser` (`.runLeaderReconcileFromFrozenCloudKit`): sin eso, una migración TERMINADA seguía abriendo la comprobación; (3) **el sello del claim devuelto se deshace antes de journalear la vuelta** (`MigrationWorkExecutor.discardLastClaimStamp`, que repone el anterior), o el Welcome leería `.routeReturningUser` de una cuenta que nadie adoptó; (4) **la sesión que abrió el intento se cierra ANTES de `submit(.signInFailed)`**, que espera quiescencia hasta 120 s: una sesión viva en un iPhone con sesión privada la registra como cuenta de grupos el arranque siguiente (`GroupsAssociationRegistrar`, salvo en un teléfono sellado), sea completa o no; y un `submit(.signInSucceeded)` que no llega al claim también es una parada, con aviso y cierre; (5) **toda entrada que lleve al claim de la ida fija la intención antes** (`setForwardClaimIntent`): el adopt del Welcome, la tarjeta del marcador y el panel DEBUG ponen `.adoptIfExisting`, porque ahí una cuenta con datos es lo esperado, y una entrada nueva sin ella heredaría la del intento anterior (ninguna de las tres lee el sello de «Empezar desde cero»: ver residuales); (6) **en un teléfono que empezó desde cero, `nil` no deja seguir con una sesión que no abrió el intento** (`deviceSealedForFreshStart`, ticket `fresh-start-keeps-a-groups-session-that-migrate-promotes`): «Empezar desde cero» RETIRA la sesión desde el 2026-09-17 (`CloudSessionRetirement`), pero el retiro es asíncrono y una REINSTALACIÓN no deja sello, así que la sesión viva todavía puede ser la de la persona anterior. Solo retira un `.proceed` —promover y crear cuenta nueva— y va DESPUÉS de la excepción de «Reintentar». `preflightMigrationIdentity` pasa `false`, `continueToClaim` el `openedSession` de verdad, y el sello se lee de `UserDefaults.standard`, como lo leen la asociación y el bridge. **Y el `nil` necesita que nadie fabrique un `true`**: con el sello, `GroupsAccountAssociation.associate` solo apunta una sesión abierta por el propio sign-in (`sessionOpenedByThisSignIn`), porque el cinturón de `GroupsSignInView` reusa la sesión viva cuando una unión por invitación vuelve pidiendo sesión con la sesión aún guardada (hoy, un 401 del gateway; hasta el 2026-09-17 también el token que no se renovaba sin red), y apuntarla le daba a la puerta el `true` de la persona anterior (lo cazaron las dos lentes de la review). `clear()` tampoco toca el iCloud-KV con el sello: es la salida a la que manda el aviso. Lo fijan `StorageMigrationIdentityGateLogicTests`, `MigrationRunnerTests` §10c y los cuerpos enteros de `MigrationIdentityGateWiringTests`. Residuales con ticket: el seguidor de un líder con otro corpus (`adopt-uploads-a-foreign-corpus-without-a-lineage-check`), el segundo dispositivo del mismo iCloud antes de la marca (`settings-migrate-blocks-a-second-device-before-its-marker`), los residuales que deja el retiro de la sesión anterior (`previous-person-cloud-session-survives-fresh-start-and-reinstall`, cerrado el 2026-09-17: el sello `.proceedMigration` de un intento previo y el Apple ID del teléfono al volver a firmar), los pendientes que tira `userActivated` (`migration-activation-drops-pending-effects-it-never-restores`) y la sesión del intento tras un relanzamiento (`migrate-attempt-session-survives-a-relaunch-mid-attempt`).

- **`existing_stable` ya no llega al reintento del MISMO dispositivo sobre una cuenta vacía (2026-09-24).** Ticket
  `claim-promotion-lost-response-blocks-the-retry`, migración `qa/cloud/g16_01_…`. Un claim sin `migration` del mismo
  `device_id` que creó o promocionó una cuenta `complete`, sin migración ni vuelta en curso y **sin fila en
  `sync_seq_counters`**, contesta `created`: es el reintento tras una respuesta perdida, y antes «Activar Yala completo»
  bloqueaba con «ya tienes finanzas personales» y el alta del Welcome adoptaba una cuenta vacía. Tres cosas que no se
  tocan sin romperlo: (1) **el contador es la señal y no las 16 tablas**: lo estampa `stamp_server_seq` en las 17 del
  canal personal (preferencias incluidas) y sobrevive a los borrados; una tabla personal nueva sin ese trigger rompería
  el cursor del pull ANTES que esto; (2) **el RPC es SECURITY INVOKER y lee el contador por RLS** (`seq_select`): una
  policy que se lo escondiera haría fallar la rama ABIERTA —una cuenta con datos leída como vacía—; la sonda de la
  migración lo ejerce con el rol `authenticated` y el golden g3_02 por el wire; (3) **otro dispositivo sigue recibiendo
  `existing_stable` aunque la cuenta esté vacía**: su alta puede estar en curso, sin nada escrito todavía; (4) **y si
  otro dispositivo ya ENTRÓ, el reintento tampoco repite** (`qa/cloud/g16_02_…`, ticket
  `claim-replay-can-seed-beside-a-phone-that-adopted-silently`): el adopt no sube nada hasta que el usuario crea algo, así
  que el contador no lo ve; lo ve `profiles.personal_adopted_at`, que estampa el claim **con `migration`** de un
  dispositivo que no es el líder al recibir `existing_stable`. Solo con `migration`, porque es el claim con el que se
  ENTRA —toda entrada acaba en `performClaim`, «Soy nuevo → nube» incluida—; un claim sin ella que choca y se queda fuera
  («Activar Yala completo» desde otro teléfono) no sella, o bloquearía a los dos sobre una cuenta vacía. Si algún día un
  camino nuevo entra en la cuenta personal SIN pasar por el claim del adopt, o el cliente empieza a mandar `migration`
  en un claim que no entra, este sello deja de decir la verdad. Cliente sin
  cambios: `.seeded` ya lleva al commit en los dos llamadores, y el `device_id` es `identifierForVendor` (con él `nil`
  sale un UUID por llamada y el reintento vuelve a bloquear, el lado seguro). Residual aceptado: un kill DESPUÉS de que el
  motor suba algo —preferencias o lo puenteado— sigue bloqueando: nadie ha medido que re-ejecutar el commit local (persistir [P] otra vez) sea idempotente, y bloquear no escribe nada.

- **El faro de iCloud-KV (`CloudBeacon`) solo se limpia con PRUEBA de que su cuenta no existe, y «el backend dice que no existe» NO es esa prueba (paso 6 del rediseño de sesiones, 2026-09-10).** El faro vive en el iCloud-KV del Apple ID: limpiarlo es irreversible y viaja a todos sus dispositivos. `BeaconOrphanLogic` acepta dos pruebas y ninguna más: (1) el hash del faro es el de la identidad que acaba de firmar; (2) faro de Apple y sesión de Apple — Sign in with Apple solo firma con el Apple ID del teléfono, que es el mismo cuyo KV guarda el faro (el KV es por bundle: Yala y Yala Dev NO lo comparten, medido en los dos `.entitlements`). **La (2) es la que cubre el fresh start**: el hash es del uuid de Supabase y, al borrarse `auth.users`, volver a firmar da OTRO uuid, así que la (1) sola no dispara nunca. **Google con otro hash no es prueba** (puede ser otra cuenta de Google de la misma persona, y la del faro seguir viva): «simplificar» a «limpia ante cualquier `exists == false`» le quita el encaminamiento a una cuenta que existe. La limpieza vive en el motor de [I] (`CloudIdentityDiscovery`) para que la haga toda puerta, con tres condiciones de cableado y un test cada una en `CloudIdentityDiscoveryTests`: el método de sesión lo pasa el caller que acaba de firmar cuando lo sabe (el Welcome; Grupos cae al Keychain) y nunca con un `?? "apple"`; el `userID` se relee DESPUÉS del `await`; y el faro no puede haber cambiado mientras se preguntaba. **Residuales, escritos para que nadie los dé por cerrados:** si el faro nuevo de otro dispositivo aún no ha llegado a éste, se puede borrar igual (el iCloud-KV no tiene compare-and-delete); y el bundle `.dev` habla con DOS backends —Debug-Dev con staging, Release-Dev con producción—, así que en un móvil de desarrollo que alterne builds la prueba (2) puede limpiar el faro de una cuenta del otro entorno. El rastro de producción (`CloudBeacon orphan CLEARED proof=…`) solo se escribe si el faro de verdad se apagó.

### Preferencias y fronteras de cuenta

> **La sesión de visita (M1) YA NO EXISTE — retirada el 2026-09-13, PR-B del paso 12.** Con ella se
> fueron `SecondarySessionStore`, `SessionDefaults`, `SessionPreferenceKeys`, el store
> `YalaModel-Secondary`, el percent del gateway y los flags de onboarding de los que colgaba la shell
> (`OnboardingMode`, `UsageFocus`). **Ninguno de esos símbolos existe ya en `Yala/` — verificado con
> `git grep` en este árbol**, así que todo párrafo de abajo que describa «la visita», «la invitada» o
> «la sesión secundaria» habla de un mecanismo MUERTO: explica por qué las cosas son como son, no lo
> que hace el código de hoy. El modelo vivo tiene **dos nombres**: *sesión privada* (dispositivo +
> iCloud privado, su eje es `PrivateSessionMark`) y *sesión en la nube* (cuenta Google/Apple, completa
> o solo grupos). Prestar el móvil dejó de ser un caso propio: el dueño cierra sesión, la otra persona
> entra con su cuenta, y luego el dueño restaura. **Dos identidades sobre un store del Apple ID siguen
> existiendo**: quien entra por un grupo en ese móvil (celda F) tiene debajo el iCloud-KV del dueño.
> `OwnerKeyValueStore` perdió su guard el 2026-09-13 por la premisa «ya solo hay una sesión por teléfono» y
> lo recuperó al día siguiente (`OwnerKeyValueGate`). Antes de retirar un guard de frontera de cuenta,
> recórrelo celda por celda contra la matriz del ADR.
>
> **Estas reglas se reescribieron en vez de borrarse, y esa decisión es de Jürgen** (2026-09-09): lo
> que merezca sobrevivir a un símbolo se queda en `.claude/rules/`. Las cuatro que hablaban de la
> visita —y se localizan por su primera frase: «Al ELIMINAR una función…», «Un dominio de preferencias
> por SESIÓN…», «Un CONSENT no es una preferencia…» y «`PreferenceSyncService.remove/set` propaga a la
> CUENTA…»— se pagaron con incidentes, y ninguna de sus lecciones dependía de que hubiera dos humanos
> en un teléfono: dependían de la FORMA del error, que se repite en cualquier frontera de cuenta. El
> barrido añadió además dos reglas nuevas, que no vienen de ahí.

- **Al ELIMINAR una función, lista lo que hacía ADEMÁS de lo que la sustituye — un guard no viaja solo con el camino que protegía (C2, 2026-08-12, `3a960fd9`).** Una función del onboarding se borró a propósito: escribía un trío de preferencias sin sesión y sin consent, y su sustituta hacía lo mismo al final de la cadena y con identidad en mano ⇒ el cambio parecía estrictamente mejor. **Lo que el borrado se llevó sin que nadie lo listara fue su guard de frontera de cuenta**, que no estaba en ninguna descripción de lo que esa función «hacía»: era una precondición, no una escritura. Y la sustituta no lo tenía **por una razón que el propio borrado invalidó**: su docblock declaraba que no hacía falta porque «su único call-site es inalcanzable con una sesión ajena viva» — cierto hasta que el mismo commit le añadió un segundo call-site. ⇒ **al mover un camino de una función a otra, la pregunta no es «¿el sustituto escribe lo mismo?» sino «¿las precondiciones del destino siguen siendo ciertas con el call-site nuevo?»** — y esa respuesta suele estar en un docblock escrito cuando el call-site era uno. Lo cazó la MUTACIÓN de un source-scan de cableado, no un test de comportamiento: con el guard quitado, todo lo observable en el harness era idéntico, porque la condición que el guard miraba es `false` en cualquier test normal. Corolario de método: **un docblock que justifica la AUSENCIA de un guard citando cuántos call-sites hay es una afirmación con fecha de caducidad — cuéntalos otra vez antes de creértelo.**

- **Un dominio de preferencias por SESIÓN es la parte fácil; el INVENTARIO es la difícil (`2a773ed3` → `d04fe0b6`, retirado el 2026-09-13 con su caso de uso).** Existió una puerta que resolvía a qué `UserDefaults` iba cada preferencia y un inventario que decidía qué key era de la persona y cuál del dispositivo (99 keys + 3 familias dinámicas · 10 excepciones). Las cinco lecciones que deja **no dependen de que haya dos sesiones**: valen para cualquier allowlist, cualquier escáner y cualquier cambio de dominio.
  1. **El contrato de una puerta de dominio tiene tres cláusulas y las tres tienen mutante.** Instancia **cacheada** por suite (dos `UserDefaults(suiteName:)` son objetos distintos y `addObserver(object:)` filtra por identidad ⇒ construirlo inline deja al lector sin recargar, **en silencio, toda la sesión**); nombre resuelto **por llamada** y jamás capturado (el estado que decide el dominio puede cambiar con el proceso vivo); lectores **congelados** al arranque a propósito (uno reactivo produce el brick de la pantalla inicial sobre un store vacío). Si alguien viene a «optimizar» cacheando la resolución, eso ES el mutante de la cláusula 2.
  2. **Una excepción de entorno cubre TODAS las operaciones —resolver, sembrar, destruir— y bajo `isRunningTests` Y `isUITesting`.** Los seams de XCUITest se plantan en el dominio VOLÁTIL, pero un `suiteName` PERSISTE y los anclajes del ciclo de vida están apagados ahí ⇒ nace un cajón que nadie destruye. El precedente exacto es `groupsDomainSealedForFreshStart`.
  3. **Destruir un dominio compuesto va ANTES de borrar el dato que compone su nombre, y con ese dato por parámetro explícito.** Al revés queda un dominio huérfano permanente, con datos de otra persona dentro. Y resolver «lo que devuelva la puerta» en ese punto para borrarlo arrasaría el `UserDefaults` **entero**. La retirada de M1 (`SecondarySessionRetirement`) conserva ese orden por esto mismo.
  4. **Un ESCÁNER SOLO PROTEGE LO QUE ESTÁ DECLARADO, y ahí es donde el propio fix se hizo daño.** Al mover un contador al cajón sin su par —la fecha con la que se compara—, el servicio quedó comparando la fecha de una persona contra el contador de otra: el lector desalineado en su forma exacta, creado por el commit que existe para evitarlo, y **el escáner no lo vio** porque la otra mitad del par no estaba en el inventario. ⇒ **al añadir una key, la pregunta no es solo «¿de quién es?» sino «¿con qué se COMPARA?»**; los pares se declaran juntos o no están cubiertos.
  5. **Escritor y lectores de una key viajan en el MISMO commit.** El plan estimaba «tres» lectores desalineados; medidos eran **40**. Un escritor movido con su lector atrás deja la app incoherente, que es **peor** que el bug original.

- **Antes de sincronizar una preferencia, pregunta DE QUIÉN es el hecho (2026-09-13).** Hasta el barrido, «por dónde entró esta persona» viajaba por el iCloud-KV del Apple ID con merge **never-downgrade por rank**, y eso tenía un daño que costó caro: el valor de OTRO dispositivo ganaba sobre el de éste y le recortaba la shell al dueño, sin vuelta atrás por el canal — había que repararlo a mano en el relevo de humano, escribiendo `""` al KV para que el merge lo ignorase sin pisarle el modo a los demás dispositivos. El eje que decide la shell hoy (`PrivateSessionMark`) es un hecho del DISPOSITIVO y **por definición no viaja**, con lo que el relevo se cierra en un solo sitio. ⇒ si una key describe el teléfono y no a la persona, no va al canal de preferencias; y si ya está ahí, sácala antes de construir encima.

- **Una caché compartida se protege con un SELLO, no con una purga — y al retirar el sello, dilo donde estaba (widget, 2026-08-14 · retirado 2026-09-13).** El snapshot del App Group llevaba el `sub` de la sesión que lo escribió, y el lector descartaba el que no casara. Lo que lo hacía correcto no era la limpieza sino el sello: esa caché sobrevive a casi todo, así que la única defensa que no dependía de que un borrado llegara a correr era que el dato dijera de quién era. Se fue con la sesión de visita —el único caso de dos identidades sobre esa caché— y la lección queda escrita en `WidgetDataService.loadSnapshot`: si vuelve a haber dos, la defensa es el sello.

- **El dominio Grupos pertenece al Apple ID, no al humano: toda frontera de «otro usuario en este device» tiene que SELLARLO, y borrar sus filas OBLIGA a resetear los tokens del engine (fix handover 2026-07-27)** — el caso entero (3 KB): [El dominio Grupos pertenece al Apple ID, no al hum…](../../docs/aprendizajes-tecnicos.md#el-dominio-grupos-pertenece-al-apple-id-no-al-humano-toda-frontera-de-otro-usuario-en-este-d)

- **EXCEPCIÓN al punto anterior, y las tres trampas que trae (C-3, 2026-07-27, `612b21ee`):** «el dominio Grupos pertenece al Apple ID» deja de ser cierto para el canal BACKEND — ahí la identidad es el `sub` de la cuenta Yala, así que un cambio de Apple ID del OS es un NO-EVENTO para esas filas y borrarlas es pérdida PERMANENTE. `clearAllLocalGroupData` pasa por `GroupsIdentityPurgeGate` (`Yala/App/Logic/`), que retiene `isBackendGroup || movedToBackendAt != nil` mientras `CloudAuthService.hasSession` (sin sesión borra como antes). **(1) `clearState(name:)` NO resetea nada por sí solo** — solo borra el fichero `<name>.json`; los engines siguen VIVOS con su `stateSerialization` en memoria y el delegate la re-escribe en el siguiente `.stateUpdate`, así que sin `recreateEnginesAfterIdentityChange()` (molde de `enableAutoSync` pero con `state: nil` y SIN transferir los pendientes, que son del Apple ID que se fue) «resetear los tokens» es no-determinista y a veces no ocurre nunca. Corolario: ese descarte se lleva el marcador de migración, que vivía SOLO en `engine.state` ⇒ hay que re-armar `markerEnqueuedFlag = false` en las filas de owner migrado o los members no congelan JAMÁS. **(2) Decidir por FILA cuando el borrado es por ZONA destruye lo que se acaba de retener**: existen `SplitGroup` distintos con el mismo `cloudKitZoneID` (`SplitGroupDeduplicationService`) y el flip de canal marca solo uno; como los hijos cuelgan de `groupZoneID`, procesar el duplicado sin marcar vacía el grupo conservado. Agrupar por zona ANTES de decidir. Relacionado: borrar hijos por `CKConstants.zoneName(for: group.id)` en vez de por `group.cloudKitZoneID` deja HUÉRFANOS en todo grupo born-backend (el pull inserta `SplitGroup()` con id nuevo y le pisa la zona). **(3) Retener la fila obliga a revocar CUATRO credenciales, no una**: el `backendReInviteToken`, su re-hidratación desde el GroupMeta (`CKRecordTranslator.update` lo devuelve en el siguiente fetch, y el reset de tokens GARANTIZA ese fetch ⇒ hace falta la marca LOCAL-only `SplitGroup.rejoinRevokedAt`), el `cloudKitUserRecordID` del `SplitMember` con `isCurrentUser` (que `legacyMemberKeyForRejoin` usa para pedir el rebind server-side) y el `legacyMemberKey` del `PendingJoinStore` (UserDefaults, TTL 7d, fuera del store). Con una sola viva, el humano nuevo entra COMO el anterior con permiso de editar y borrar. **Corolario de alcance:** retener vuelve alcanzables los sitios que escriben a CKSyncEngine (`enqueueSave`, `enqueueDeletion`, los 2 recoveries, `reconcileMarkers`) y `GroupService.refreshCurrentUserFlags` — este último apagaba `isCurrentUser` en el grupo retenido, dejándolo sin «quién soy». Los guards de escritura usan `isBackendGroup || isMigratedFrozen` (primitiva de `GroupFreezeLogic`), NO `movedToBackendAt != nil` crudo: su mitigación #9 (owner tras reinstall) perdería su último camino de subida.

- **`isCurrentUser` es un flag del canal CloudKit y en el BACKEND nace APAGADO para casi todo el mundo — toda resolución de identidad del canal nuevo necesita un fallback por `sub` (2.6, Fase 2):** solo hay UN escritor que lo enciende en el canal backend, `GroupBackendMembershipService.createGroup` sobre el member del CREADOR; `GroupsSyncClient.applyMember` NUNCA lo setea (lo dicen `GroupJoinReconciler.swift:115` y `:156`) ⇒ **quien se UNE a un grupo, y CUALQUIERA en un 2º device o tras un reinstall, recibe su propio `SplitMember` por el PULL sin el flag**. Y `GroupService.refreshCurrentUserFlags` tampoco lo arreglaba: su guard C-3 saltaba los grupos del canal backend ENTEROS —correcto mientras la única señal era el record-name, que ahí siempre da `false`—, así que su rama por `sub` era inalcanzable en la práctica. Se cae en cascada y sin ruido: `GroupDetailViewModel.currentUserMember` lee SOLO ese flag ⇒ sin banda de balance, sin FAB, sin editar/liquidar, `mySharesByExpense` vacío. **El re-cableo tiene tres partes y las tres importan:** (a) el salto C-3 pasa a ser condicional (`!backendCanResolve`) para que el member backend llegue a la rama por `sub`; (b) los sitios que juzgan por record-name (`cloudKitMatch`, el backfill legacy, la inferencia de `isGroupOwner`) se apagan en zonas del canal backend **y** cuando el record-name no resolvió — sin ese par, dejar la función viva sin iCloud APAGA `isCurrentUser` en todos los grupos CloudKit del device; (c) los resolvedores de la UI y del write-side (`GroupExpenseService.selectCurrentUserMemberID`, `GroupJoinReconciler.currentUserMemberExists`, `GroupSettingsView.hasOutstandingBalance`) llevan el fallback por `userID`/`memberKey == sub` **después** del flag y **antes** del record-name: primero el flag para no divergir de `GroupNotificationService.currentMemberID(inZone:)` (que resuelve solo por él), y el `sub` antes que iCloud porque en el canal nuevo es la identidad autoritativa. Con `groupsBackendEnabled` OFF el `currentUserID` es nil en todos los callsites ⇒ byte-idéntico. **Trampa de forma:** `GroupSettingsView` probaba el record-name PRIMERO y devolvía nil sin caer al fallback — en un grupo backend eso da siempre nil (`cloudKitUserRecordID` vacío por diseño, pero el recordName de iCloud SÍ existe) y el usuario aparecía sin deuda al archivar o salir. Un `if let` sobre una identidad que puede no casar NUNCA debe cortocircuitar la cadena de fallbacks.

- **Duplicar un canal duplica sus ESCRITURAS; sus OBSERVACIONES se quedan atrás, y eso no lo caza ningún test de un canal solo (banner de aprobación, device 2026-07-31):** el canal backend heredó el apply, las notificaciones y el freeze de `SplitSyncManager`, pero NO las dos cosas que su post-fetch hace además de escribir: llamar al reconciliador desde su post-fetch y mirar el member para mover la fase del join intent (`processPendingRemoteChanges`, la rama `phase == .pendingApproval`). Consecuencia medida con dos iPhones contra producción: el owner aprobaba (`approve_member - Ok`, cursor del pull avanzando), el `SplitMember` propio quedaba `active` en el store —el banner de DENTRO del grupo desaparecía, porque lo pinta el status local— y el banner de tab `groups.invite.waitingApproval.banner` se quedaba puesto **para siempre**. **Y el reconciliador no era la red que parecía**: `reconcileBackendEntry` dispara `.correctAndClear` en cuanto el member existe localmente **aunque esté `pendingApproval`**, y eso LIMPIA el intent ⇒ cuando llega la aprobación los tres triggers vivos salen por su `guard !entries.isEmpty`. Un intent que se limpia con el trabajo a medias deja de ser una red: aquí el estado «pendiente» todavía tenía una transición pendiente por delante. El gemelo silencioso era el RECHAZO, que dejaba el banner igual de pegado. **Fix vigente**: `GroupInviteOnboardingLogic.shouldRepublishPhase` (pura — zona trackeada + fase EN VUELO; nunca desde `.idle`, que resucitaría un banner que nadie muestra, ni desde `.active`/`.failed`, que tienen salida propia) consumida por `GroupsSyncClient.publishTrackedJoinPhaseIfNeeded`, **POST-SAVE** —dentro del `saveWithAuthor` publicaría la fase de un member que el `rollback()` revierte— y **antes** de notificaciones/freeze/bridge, porque a partir de esa línea el member ya está en disco y cualquier hueco deja el banner puesto sobre una aprobación aplicada. Lo que se publica es el status del member **PROPIO leído del store y resuelto por `sub`**, JAMÁS el `status` del delta: en el mismo pull baja la aprobación de un compañero, y `isCurrentUser` está apagado por diseño (regla de arriba). ⇒ **al portar lógica de un canal al otro, lista lo que el viejo OBSERVA además de lo que escribe** (fases de UI, reconciliadores, trackers `@Observable`): las escrituras las echa en falta el compilador o una fila que no aparece; una observación que falta no rompe nada — solo deja una pantalla mintiendo, y con `ENFORCE`/canales asimétricos la suite entera puede estar verde.

- **Una señal puede viajar en NEGATIVO — y entonces el `return` que no deja rastro es un bug de LECTURA, no de escritura (S4, `c6581184`, 2026-08-04).** — el caso entero (5 KB): [Una señal puede viajar en NEGATIVO — y entonces el…](../../docs/aprendizajes-tecnicos.md#una-seal-puede-viajar-en-negativo--y-entonces-el-return-que-no-deja-rastro-es-un-bug-de-lec)

- **Un gate de feature NO puede decidir SI se PARSEA la entrada: solo QUÉ hacer con ella. Y «byte-idéntico al camino viejo» es una afirmación que hay que MEDIR, no declarar (invite backend mudo, device 2026-07-31).** — el caso entero (3 KB): [Un gate de feature NO puede decidir SI se PARSEA l…](../../docs/aprendizajes-tecnicos.md#un-gate-de-feature-no-puede-decidir-si-se-parsea-la-entrada-solo-qu-hacer-con-ella-y-byte-i)

- **En una frontera de USUARIO el outbox de Grupos y su cursor tienen signos OPUESTOS: uno hay que matarlo y el otro hay que conservarlo (2.7, Fase 2):** los dos viven en `syncMetaSchema` —el store que `DataWipeService.wipeAllUserData` NO toca— así que un «empiezo de cero» del Welcome (`wipeLocalGroupsDomain`, los 2 call-sites de `ContentView`) los deja vivos a ambos. Pero **no se purgan juntos**: (a) las filas de `GroupSyncOutbox` son escrituras PENDIENTES de la sesión que las firmó ⇒ **se SUBEN antes de borrar nada, y si no suben el gesto se para** (desde el 2026-09-26, ticket `fresh-start-wipe-kills-unsent-group-writes-silently`: `CloudSessionSignOut.drainGroupsBeforeFreshStart` en los tres callers y `DataWipeService.requireNoUnsentGroupWrites` como cinturón del escritor; lo que el borrado mata son las dead-letter). **Hasta ese día esta regla decía «hay que borrarlas»** porque «se subirían firmadas como suyas»: van firmadas por su dueño a sus grupos, que es a donde iban, y quien empieza de cero puede ser esa misma persona — tirarlas perdía en silencio sus gastos sin cobertura. No lo «arregles» de vuelta; (b) `GroupSyncCursor` es la **BARRERA** que impide que el corpus del anterior BAJE a este device con ese mismo JWT (el bug de `31dded30`) ⇒ borrarlo REABRE la fuga. El par coherente es **outbox vacío (subido) + cursor vivo**. **Desde el 2026-09-17 ese camino SÍ cierra la sesión (`CloudSessionRetirement`, armado dentro de `wipeLocalGroupsDomain` y consumido por `AppBootstrapper`), y MEDIDO: no invierte el signo del cursor** — está indexado por `groupID`, así que los grupos de la persona nueva son otros IDs y bajan enteros; si comparten grupo, el re-join ya lo resetea (`cursorResetGroupIDs`); y el retiro es un `Task` que un kill puede dejar para el arranque siguiente, así que el cursor sigue siendo la barrera mientras tanto. Lo que cambia es el PORQUÉ del outbox, no el par. ⇒ **NO reusar `CloudSessionSignOut.purgeGroupsSyncState` en este camino**: borra AMBOS, y su propio docblock acota su uso al camino solo-grupos «tras el teardown (generación cortada)» — precondición que el Welcome sigue sin cumplir aunque desde el 2026-09-17 sí RETIRE la sesión: retirar no es cortar la generación del canal —no hay teardown, el retiro es un `Task` que puede no llegar, y el arm lo repara en el arranque SIGUIENTE—. **Ojo con esta línea:** hasta ese día la precondición se leía «ahí no se cierra la sesión», así que quien la midiera hoy la encontraría cumplida, repuntaría el default a `purgeGroupsSyncState` y reabriría `31dded30`. **Y la mitad que se olvida:** borrar las filas sin purgar el espejo del App Group es COSMÉTICO — `GroupsSyncClient.rehydrateOutboxFromMirror` las re-inserta en el próximo boot, y su filtro por `userID` tampoco basta aquí: desde el 2026-09-17 este camino retira la sesión, pero el retiro es asíncrono y hasta que termine la identidad de las entries del anterior sigue casando ⇒ el borrado de filas va con `GroupsOutboxMirror()?.purgeAll()` en el seam `resetSyncState`. Pinneado en los DOS sentidos por `HandoverGroupsDomainTests` (outbox 0 **y** cursor 1, con su contenido intacto) + `HandoverGroupsWiringTests` (el espejo se purga; la función de sign-out no se llama — la aserción busca `purgeGroupsSyncState(` CON paréntesis, porque el fichero nombra esa función en el comentario que explica por qué no la usa). **Aviso de plan:** el §2.7 de [[MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS]] prescribía «repuntar el default a `purgeGroupsSyncState`» — cerraba (a) y abría (b). Un plan puede estar equivocado; esta regla gana.

- **El cursor del pull de Grupos (`GroupSyncCursor.groupCursorsJSON`) NO se resetea para «forzar una re-entrega» — es dañino por tres vías independientes (C-3, 2026-07-27):** (a) en la ventana de migración a medias (paso 1 hecho, paso 3 pendiente) el server solo tiene meta+members —el contenido sube en el paso 4— así que re-entrega una CÁSCARA, y `applyGroupMeta` la re-crea born-remote con `isBackendGroup = true` ⇒ `handleFetchedRecordZoneChanges` descarta desde entonces TODO record CloudKit de esa zona y el grupo deja de casar el predicado de `fetchCandidates` ⇒ migración muerta y datos que HOY volverían al re-firmar, perdidos; (b) el reset lo PISA la propia página en vuelo: `applyPulledPage` mergea los `page.cursors` autoritativos del server DESPUÉS de leer el mapa, y el server los manda aunque no haya deltas; (c) en «empiezo de cero» ese cursor superviviente es la BARRERA que impide que el corpus del usuario anterior baje al device del nuevo (el bug de `31dded30`) — purgarlo ahí lo reabre en el canal backend. El JWT vive en Keychain propio y sobrevivía al relevo; desde el 2026-09-17 se retira (`CloudSessionRetirement`), pero el retiro es asíncrono y puede fallar, y el cursor es lo único que queda entonces. El par coherente es **filas retenidas + cursor vivo**; lo que perdía datos era «filas borradas + cursor vivo». Si de verdad hace falta re-pedir un grupo, el molde correcto es el reset por re-join (`cursorResetGroupIDs` DENTRO del apply, después del merge), no un reset externo.

- **Un CONSENT no es una preferencia, y por eso el de Grupos SALIÓ del canal de prefs (C1, 2026-08-11).** La regla de abajo describe cómo no destruir un consent que viaja por `PrefSyncKey`; la lección de C1 es anterior a eso: **el destino de una pref lo decide el `behavior` del INSTANTE en que se escribe**, y `groupsConsentAcceptedAt`/`groupsConsentTextVersion` se escribían casi siempre con `storageMode == .icloud` —el default del parque— mientras Grupos va al 100 % **sin exigir Modo Nube** ⇒ acababan en el iCloud KV del Apple ID y **jamás llegaban a Yala**. No era un bug de un camino: era la rama normal. Como responsables del tratamiento no podíamos demostrar el consentimiento (RGPD Art. 7.1) de casi nadie. ⇒ el registro vive ahora en `groups_consents` (Supabase), **append-only POR EL GRANT** (`select, insert`, sin `update` y sin `delete`), y la copia local es un **snapshot SELLADO con el `userID` dentro** (`GroupsConsentState`), no dos keys sincronizadas. Tres corolarios que se generalizan: (1) **el grant es mejor invariante que el docblock** — con `delete` revocado, el incidente `bdbc46d1` (un `.int(0)` sin tombstone pisando por LWW el epoch de una cuenta viva) deja de ser posible por construcción, y los cinco `clear()` del cierre dejan de ser un campo de minas; (2) **un hecho de la CUENTA se lee con su propio request, no por el canal de prefs** — el molde completo ya existía en `AccountEntitlementService`/`AccountEntitlementStore`; (3) **la seguridad de una caché de sesión viene del SELLO, no de una purga**: lo que hace inofensiva la caché de otra cuenta es que su `userID` no case, corra o no corra ninguna limpieza. Al añadir una key nueva a `PrefSyncKey`, la pregunta previa es **de quién es el hecho**: si es de la cuenta y no del device, no va ahí.

- **`PreferenceSyncService.remove/set` propaga a la CUENTA, no al device — NUNCA limpiar un consent desde un camino con `.cloud` VIVO (commit `bdbc46d1`):** el service ramifica por `behavior`, que es **computed y se resuelve en CADA llamada** (`CloudSyncFlags.storageMode`): `.icloud` → local + iKV; `.cloud` → `enqueuePref(.int(0))` al outbox de prefs, que **SUBE al backend**. Para la familia `intPresence` un `0` **ES** "no aceptado" (`isAccepted` es `> 0`) y el wire de prefs **no tiene tombstone**, así que ese `0` pisa por LWW el epoch de aceptación en `user_preferences`: borra el **registro GDPR de una cuenta que sigue VIVA** y lo propaga a sus otros devices. Un sign-out es "hasta luego", no una retirada de consentimiento — el precedente del repo es append-only (`cloudConsentAcceptedAt` no lo borra NINGÚN camino). ⇒ el olvido del consent en un cierre va **donde el modo persistido ya es `.icloud`**: hoy el boot-hook `performSignOutWipeIfArmed`, DESPUÉS de `StorageModePersistence.write(.icloud)` (rama sin backend) y ANTES de `resetPrefs()` (que podría barrer la key que gatea el clear, dejándolo mudo en silencio). Pinneado en AMBAS direcciones: `SignOutNotificationWiringTests.inSessionConsentClears_neverOnCloudModePaths` resuelve la función contenedora y **nombra al culpable** si alguien cuela el clear en un camino `.cloud`, y `modeAtClear` en `SignOutWipeHookTests` captura el modo **DENTRO** de la closure — leerlo tras el return no prueba nada del instante del clear (un mutante que mueva el `write(.icloud)` por debajo quedaría verde). **Corolario general:** todo `set`/`remove` de prefs en un camino de cierre o de frontera de cuenta debe preguntarse en qué rama de `behavior` caerá **en ese instante**, no en cuál cae "normalmente".

- **CARGAR una preferencia no puede ESCRIBIRLA — y el eco de eso convertía al receptor en autor LWW de algo que no escribió (`05c44cf4`, 2026-08-05).** — el caso entero (4 KB): [CARGAR una preferencia no puede ESCRIBIRLA — y el …](../../docs/aprendizajes-tecnicos.md#cargar-una-preferencia-no-puede-escribirla--y-el-eco-de-eso-converta-al-receptor-en-autor-lww)

- **El resolvedor canónico de identidad NO es un reemplazo mecánico del flag: contesta otra pregunta en DOS ejes (2026-09-05, PR #64).** Alinear los catorce consumidores estrechos de `isCurrentUser` con `GroupExpenseService.resolveCurrentUserMember` (la regla de `isCurrentUser`, más arriba, aplicada al resto) introdujo **cuatro cambios de comportamiento que nadie pidió**, y los cuatro salen de las mismas dos diferencias: el resolvedor **(a) colapsa a UNA fila por zona** (`min(by: joinedAt)`) donde el `#Predicate` devolvía TODAS las marcadas, y **(b) no filtra por estado** — puede devolver un member `pendingApproval`, `left` o `removed`. ⇒ **antes de sustituir, pregunta cuál de las dos formas necesita el consumidor.** Los cuatro casos, porque cada uno enseña una forma distinta de equivocarse: **(1) Un consumidor que solo distingue «existe / está activo» convierte (b) en daño.** El gate de `ScheduledPaymentDraftService` pausa al no-activo escribiendo `payment.isActive = false`, persistente y sin re-encendido: resolver la identidad le APAGABA el pago recurrente a quien espera aprobación — el usuario que el arreglo venía a atender. Un `pendingApproval` es el mismo «todavía no se sabe» que su `.retryLater` ya cubría, no el «removido/salido» que su propio comentario dice querer pausar. **(2) Una pregunta POR FILA no se contesta con la canónica, y aquí el precio es un borrado.** El guard removed-self de `AppBootstrapper` pregunta «¿existe una fila mía expulsada?»; el resolvedor contesta «¿la canónica lo está?». Con dos filas del mismo humano divergen en las dos direcciones, y la mala dispara `performRemovedSelfCleanup` —que borra el `SplitGroup`, cascadea gastos/shares/liquidaciones y **emite tombstones al backend**— sobre un grupo al que el usuario acaba de re-unirse (un re-join estrena `member_key` ⇒ la fila vieja `removed` sobrevive junto a la nueva `active`). Quedó SIN alinear a propósito, con el motivo escrito en la línea. **(3) Colapsar donde había que unir deja al gemelo huérfano PARA SIEMPRE.** `updateCurrentUserDisplayName` renombraba solo la canónica; como su filtro de trabajo es `displayName != nuevo`, reentraba en cada arranque sin converger nunca. Para eso existe la variante **plural** `resolveAllCurrentUserMembers` (mismos tres criterios en OR en vez de en cascada) — úsala cuando la pregunta sea «¿cuáles son mis filas?». **(4) `resolver-y-filtrar` ≠ `buscar-la-que-cumple-ambas`.** `first { isCurrentUser && isActive }` escanea hasta encontrar una que cumpla las dos; resolver y luego filtrar por `isActive` devuelve la canónica y la descarta, dando «no hay nadie» cuando sí lo hay. Con dos filas mías y la más antigua inactiva, eso reabría el formulario EN BLANCO — el síntoma exacto que el arreglo quitaba. La forma correcta es `resolveCurrentUserMember(from: members.filter(\.isActive))`. **Y un detalle del helper por zona:** su fetch va `sortBy: joinedAt` porque ante empate exacto `min(by:)` devuelve el primero DEL ARRAY, y los demás consumidores canónicos resuelven sobre el array ya ordenado de `GroupService.fetchMembers` — sin ordenar, dos filas empatadas al milisegundo bastan para que el formulario marque un pagador y el bridge resuelva otro. **Corolario de verificación, y es el que más costó:** un **source-scan de cableado** (¿este fichero llama al resolvedor?) prueba que el cambio se APLICÓ, no lo que HACE. Ninguno de los cuatro fallos de arriba se ve en un grep; los cuatro los cazó una review adversarial por lentes y los pinnea ahora `YalaTests/GroupJoinerConsumerBehaviourTests` con su control en la dirección contraria (al pendiente no se le pausa **y** al expulsado sí). Un escáner es una red contra la regresión del cableado, nunca la red del comportamiento.

- **`ubiquityIdentityToken` mide iCloud DRIVE, no CloudKit — y `.localNoMirror` adjunta el espejo igual, así que usarlo como gate de «¿me va a caer algo de iCloud encima?» falla ABIERTO (2026-09-10).** `SwiftDataConfiguration.isICloudAvailable()` es `FileManager.default.ubiquityIdentityToken != nil`, y es el predicado correcto para **la tabla de mounts** —para eso existe—. Lo que NO es, es una respuesta a «¿este Apple ID tiene datos en CloudKit que van a bajar a este dispositivo?»: con **iCloud Drive apagado y la sesión de iCloud viva**, el token es `nil` mientras CloudKit funciona perfectamente, y el mount que sale de ahí (`.localNoMirror`) **adjunta el mirror igual** porque no pasa `cloudKitDatabase:` y cae en `.automatic` (medido en la auditoría R1(c); está escrito en `PersonalStoreDecision.attachesCloudKitMirror`). ⇒ un gate escrito con ese token deja pasar exactamente a la población que pretende proteger. Costó el defecto más grave del paso 4 del rediseño de sesiones: la puerta de «Primera vez → privado» le decía a esa gente «no pude comprobar tu iCloud», la dejaba seguir, y el histórico le bajaba encima igual — **el bug que el ticket arreglaba, reintroducido por el predicado elegido para arreglarlo.** Las dos preguntas y sus dos testigos: «¿este arranque ESPEJA?» → `SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror`; «¿hay cuenta a la que preguntar?» → **el error de la propia llamada a CloudKit** (`CKError.notAuthenticated` / `.managedAccountRestricted`), que es la única fuente que no puede discrepar del canal que importa. **Corolario que costó una segunda vuelta:** `attachesCloudKitMirror` tampoco vale como pre-filtro en cualquier sitio — devuelve `false` para `.neutralNoMirror`, que es el mount de TODA instalación fresca, así que en la puerta del Welcome apagaba la validación en el 100 % de su población. Sirve donde la pregunta es sobre el espejo que YA está puesto (el aviso del espejo tardío), no donde el espejo llega en el arranque siguiente.

- **El testigo del mount MIENTE en los hosts de test, y por eso `attachesCloudKitMirror` necesita un seam en cualquier gate que lo consulte (2026-09-11).** `SwiftDataConfiguration.personalConfiguration` sale por su rama `YalaModel-UITest` —`cloudKitDatabase: .none`, o sea que ese store NO espeja— **antes** de llamar a `capturePersonalStoreMountedDecisionOnce`, así que `personalStoreMountedDecision` se queda en el default de su DECLARACIÓN, que es `.iCloudMirror`. El eje ancho da `true` en toda corrida de XCUITest, y el estrecho también. La consecuencia ya estaba escrita para el otro lado (`UITestEphemeralDefaults.applySecondarySession`: «`capturePersonalStoreMountedDecisionOnce` tampoco corre»); lo que faltaba era el corolario para quien LEE el testigo. Costó el hallazgo más caro de la mitad 2 del paso 5: la puerta de «Vengo por un grupo» volvía SIEMPRE al neutro bajo test, `.proceed` era inalcanzable, un XCUITest de control se caía, y **cada corrida armaba un boot-wipe real** cuya key (`cloudSync.signOutWipeArmed`) sobrevive a `-uitest-reset` y a `DataWipeService` — así que el siguiente arranque MANUAL del simulador, donde el ejecutor sí corre, borraba el store. ⇒ **un gate nuevo que lea el mount declara su seam, con el default en la VERDAD del host de test (`false`) y no en una inversión**, y el hook solo lo enciende quien quiera recorrer la otra rama. **Y «hosts de test» es literal: el de UNIT también miente, por la misma razón y sin `-uitest` de por medio** (medido el 2026-09-11 en la puerta del invitado, `GroupInviteNeutralGateLogic`). Bajo `YalaTests` nadie monta el store de producción, así que `personalStoreMountedDecision` se queda igualmente en `.iCloudMirror` y **el eje ancho vale `true` en toda celda** — el gate nuevo disparaba en las 12 celdas de dos suites que no tenían nada que ver con él (`GroupInviteSheetAlwaysShownTests`, `GroupJoinReconcilerTests`), y sus rojos NO señalaban al gate: decían que la hoja del invitado no se presentaba. El seam de `isUITesting` no las cubre, porque `isRunningTests` es otra cosa. ⇒ **el provider del mount se INYECTA en el `makeEnv` de toda suite que ejercite un camino que lo lea**, con `false`, que es la verdad de un dispositivo sin espejo; exentar el host de unit dentro del seam sería peor —cegaría a los tests que sí quieren medir la rama del espejo—. Y una trampa aparte, medida el mismo día: **una purga del arm en `applyUITestHooksEarly` NO sirve** — el ejecutor corre en `PersonalContainerHost.makeContainer()`, que se construye antes, y bajo `-uitest` está apagado de todos modos; la única red real es no armar.

- **Una salida que borra lo local con el espejo montado borra ARCHIVOS antes del mount, nunca FILAS, y solo después de confirmar el export contra el historial (paso 9 del rediseño de sesiones, 2026-09-11).** Borrar filas con `NSPersistentCloudKitContainer` montado deja los deletes en la History y el espejo los exporta: vaciaría el iCloud de la persona en todos sus dispositivos. Por eso los cierres de la sesión privada (C, D) y de la solo-grupos (F) usan el mismo boot-wipe que la nube (`armSignOutWipe` → `SwiftDataConfiguration.performSignOutWipeIfArmed`) y relanzan: el swap sin relanzar no admite mounts con espejo. iOS no expone «export pendiente», así que el testigo es propio: cambios LOCALES del store personal en el historial de SwiftData —sin el autor `NSCloudKitMirroringDelegate…`, que es lo que BAJÓ— posteriores al `startDate` del último evento de export con éxito (`iCloudSyncService.confirmedExportStart`, monótono, invalidado por cambio de cuenta, de reloj y `.notAuthenticated`). Tres cosas que parecen simplificables y no lo son: **(1)** el ancla es el INICIO del export y no su fin, porque un cambio guardado mientras un export corría puede no haber viajado en él; **(2)** sin ancla no hay número honesto, así que el contador devuelve «desconocido» si hay escrituras locales y el aviso lo dice con esas palabras en vez de inventar una cifra; **(3)** el último recuento va PEGADO al arm, sin ningún `await` entre medias, porque cualquier suspensión deja entrar un save que el borrado se llevaría sin haberlo contado. Lo que el simulador no puede probar —que el espejo firme sus importaciones con ese prefijo y que emita el evento de export tras un save— es el primer punto del device-QA de `session-exits-one-verb-per-session`.

- **`CKDatabase.modifyRecordZones` solo LANZA por un fallo de la operación entera: los fallos por ZONA llegan dentro del tuple, en silencio (2026-09-10).** La firma async devuelve `(saveResults:, deleteResults:)`, dos diccionarios de `Result`, y descartarlos con `_ = try await …` convierte un `zoneBusy`, un `quotaExceeded` o una red que se cae a medio batch en un **éxito reportado**. En el borrado del corpus personal eso era: se retiraba el arm, nadie reintentaba, y en el camino que además vacía el store local la persona se quedaba **sin sus datos locales Y con el corpus viejo entero en iCloud** — la peor combinación posible. Es la misma familia que el `recordZoneChanges` de al lado, que devuelve `modificationResultsByID: [CKRecord.ID: Result<…>]` y sí hay que desempaquetar. ⇒ **toda API de CloudKit que devuelva `Result` por elemento se recorre; `try` no cubre lo parcial.** Y al clasificar el fallo, `String(describing: type(of: error))` colapsa todo a `"CKError"`: usa `error.code.rawValue`, que no lleva PII y es lo único que distingue una cuota agotada de una red caída en el canario.

- **Un campo Codable NUEVO y no opcional en el snapshot del App Group apaga TODOS los widgets, y el DTO está DUPLICADO en dos targets (2026-09-09).** `WidgetDataSnapshot` viaja de la app al widget por `UserDefaults(suiteName:)` + `JSONEncoder`, y se lee con `JSONDecoder().decode(WidgetDataSnapshot.self, …)` — **struct entera y sin versionado**. Una clave nueva que falte en el payload ya escrito lanza `keyNotFound`, `loadSnapshot()` devuelve nil y **todos** los widgets de la pantalla de inicio se quedan en cero hasta que el usuario abra la app; en un widget eso pueden ser horas. Y no es un fallo del campo: si la clave cuelga de `thisMonthSummary` —que tampoco es opcional— **revienta el snapshot entero**. ⇒ **todo campo nuevo va `Bool?`/`T?` y se lee con `?? valor`**, con el precedente del propio fichero (`periodBalance`, `sessionSeal`, `WidgetScheduledPayment.isVariableAmount`, los tres con «Optional for backwards compatibility with old cache format»). **Y hay que declararlo en los DOS lados**: `Yala/Services/WidgetDataCache.swift` (escribe) y `YalaWidgets/Services/WidgetDataService.swift` (lee) son structs distintas que decodifican el mismo payload; ponerlo opcional solo en el lector deja al otro roto — que es como se descubrió. **Lo cazó un test que existía para otra cosa**: un caso escrito para el sello de identidad de sesión, que decodifica un JSON con «la forma exacta que hay hoy en los discos». Ese sello se retiró el 2026-09-13 con la sesión de visita y el caso **se mudó** en vez de irse con él — hoy vive en `WidgetSnapshotLegacyDecodeTests`. Al añadir un campo, extiéndelo ahí — el caso original llevaba `"transactions":[]`, así que no ejercitaba `WidgetTransaction`. **Aviso de cobertura, medido:** ese test resuelve a la struct de la APP, porque el target `YalaTests` sincroniza `YalaTests` y compila `Yala`, **no `YalaWidgets`** (`project.pbxproj`, `fileSystemSynchronizedGroups`). La copia del lector no la cubre ningún test de decodificación: lo único que impide quitarle el `?` es un source-scan, y por eso ese scan tiene que nombrar cada campo.

- **«ARCHIVOS, nunca FILAS» es una regla sobre el ESPEJO, y el store de Grupos tiene otro camino de salida: su DRAIN. Ahí lo que blinda un borrado local es el AUTOR del `save()` (2026-09-11).** La regla de arriba prescribe borrar archivos antes del mount porque con `NSPersistentCloudKitContainer` montado los deletes de filas quedan en la History y el espejo los exporta. El store de Grupos monta `cloudKitDatabase: .none` —no hay espejo— y su único camino de export es el drain, que traduce el SwiftData History a filas de `GroupSyncOutbox`. ⇒ para él la forma correcta no es el boot-wipe (que además exigiría relanzar, y el desasociar de Ajustes es in-session) sino **firmar la transacción con `GroupsSyncClient.outboxSaveAuthor`**: `performDrain` descarta por autor ANTES de traducir, así que esos deletes dejan de ser traducibles mire el drain el History desde donde lo mire. Vive DENTRO de `DataWipeService.deleteLocalGroupsRows`, que por eso hace SIEMPRE el `save()` y ofrece `alsoDeleting` para lo que el llamador quiera meter en la misma transacción: con el autor restaurado antes de un save ajeno la firma no serviría de nada, y un tercer camino que borre estas filas tiene que nacer firmado sin acordarse. **Lo que NO vale es apoyarse en que el canal esté cortado**: cortar el canal protege ESTE proceso, no el siguiente — el History sobrevive al relanzamiento, y hasta este ticket lo único que cerraba el agujero era un efecto colateral del orden dentro de `syncCycleOnce` (el drain corre antes del pull ⇒ `backendGroupZoneIDs` vacío ⇒ no emite), que se reabría con que ese primer drain lanzara. **Y tres cosas que se probaron y NO ayudan, medidas** (ticket `detach-history-replay-can-tombstone-groups-on-next-launch`): (1) conservar el ancla del drain en vez de borrar el cursor **no protege esos deletes** —son posteriores al ancla, así que `fetchHistory($0.token > token)` los devuelve igual— y clava `lastDrainedTxAt`, uno de los cuatro suelos del corte de purga del History, sin canal que lo avance; (2) el re-barrido completo del History **con las filas ya borradas no emite nada**, porque el `case` de insert/update no resuelve ninguna fila viva por `PersistentIdentifier` — el daño de re-emitir upserts con HLC nuevos es del par «cursor borrado + filas VIVAS», y lo que lo impide es que el borrado sea UNA transacción; (3) por eso el par de una frontera de CUENTA sigue siendo «filas borradas + cursor borrado, atómico», sin excepción a la regla del reset del cursor. Pinneado por `YalaTests/CloudSync/GroupsDetachHistoryReplayTests` (5 casos, tres mutantes verificados: quitar la firma deja 2 en rojo, quitar el borrado del cursor o el del outbox deja 1 cada uno).

- **Un token que no llega NO es una sesión caducada: pregúntale al SDK si la conserva (2026-09-15).** `CloudAuthService.accessToken()` devuelve `nil` por CUALQUIER fallo, y el canal de Grupos leía ese `nil` —y el refresh forzado que vuelve sin token tras un 401— como `.sessionExpired`: sin red y con el token caducado, el loop moría hasta volver a primer plano o relanzar, y el cierre de sesión decía «Tu sesión caducó». El SDK ya separa los dos casos: solo BORRA la sesión guardada ante `session_not_found`, `session_expired`, `refresh_token_not_found` y `refresh_token_already_used`, y la borra antes de lanzar; la red caída, un 5xx o cualquier otro rechazo la dejan donde estaba. ⇒ con `canRenewSession == true` es `.transient` (backoff: el loop propio reintenta solo, hasta cada 5 min, y al volver a primer plano ya no se re-arranca —no ha muerto— pero **sí se DESPIERTA** desde el 2026-09-16: `startIfEligible` le corta el sueño para que cicle ya, o esos cambios esperaban el backoff entero con la red ya recuperada; en `.cloud` Grupos cicla dentro del runtime personal, ver la regla siguiente); con `false`, `.sessionExpired`. En Grupos deciden dos sitios: el canal de sync, en `GroupsSyncClient.sdkRemovedTheSession`, y desde el 2026-09-17 las acciones (salir, unirse, crear, aprobar…), en `GroupsMembershipClient.call`, que lanza `.transient(status: -1)` SIN su reintento corto: el SDK ya reintenta la renovación dos veces, y repetirla triplicaba la espera (ticket `groups-actions-read-an-offline-token-refresh-as-a-session-expiry`). La premisa del SDK la fija `SupabaseSessionRenewalContractTests`, que conviene volver a correr al actualizar supabase-swift. **Dos trampas:** (1) el testigo es `canRenewSession` y NO `hasSession`, que lleva el seam `-uitest-fake-cloud-session` y dice «hay sesión» sin ninguna guardada; (2) un test que para el loop con un 401 sin refresh tiene que inyectar `canRenewSession: { false }` — si lee el singleton y el simulador guarda una sesión, el refresh nulo es pasajero y el test CUELGA en vez de fallar. El cliente de las acciones tiene la misma trampa sin loop: con su default, un test de token nulo depende del Keychain del simulador y FALLA, así que inyecta el testigo. **Y el testigo se lee DESPUÉS de pedir el token**, en los dos clientes: el SDK borra la sesión antes de lanzar, y leído antes contaría como guardada la que la renovación acaba de invalidar.

- **El canal personal separa lo mismo desde el 2026-09-16, y cada sitio decide por su cuenta** (ticket `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`): `SyncPushClient`, `SyncPullClient`, `PrefsSyncClient`, `BornCloudSignUpService` y —desde el 2026-09-22— `SyncMerkleClient` leen `canRenewSession` DESPUÉS de pedir el token (el SDK borra la sesión antes de lanzar). Si cambias el criterio, cámbialo en los CINCO, en `sdkRemovedTheSession` y en `GroupsMembershipClient.call`. **El Merkle llegó el último, y no por descuido**: mientras su desenlace se aplanaba en «red» daba igual acertar, y desde que su 401 enciende el aviso de «vuelve a entrar» de la vuelta a iCloud acertar es lo único que importa (`reverse-verify-network-bucket-hides-a-definitive-server-no`). Con él llegó también su rama de `yala_attest_required`, por lo mismo. En `.cloud` el runtime entra en backoff en vez de `stopUntilSignIn`, y Grupos cicla en la primera vuelta en que el push personal pasa. **Ojo al reproducirlo:** `performCycle` pide el token de App Attest antes de subir, y ese token vive 15 min en memoria; sin red y con él caducado, el ciclo sale pasajero en la puerta y nunca llega al token nulo del push, con el arreglo y sin él. El bug solo salía con el JWT caducado y el attest aún en caché, o con el servidor de sesiones caído y la red bien. **Tres cosas que no se tocan sin romperlo:** (1) en los tres clientes `canRenewSession` tiene default `{ false }` —el trato de antes, para no tocar las decenas de construcciones de la suite— y producción pasa el de su proveedor de sesión; lo exige `AttestWiringTests.personalChannelConstructions_passTheSessionRenewalWitness`, que fija la etiqueta Y la definición de `canRenew`; (2) el canario `cloudSyncBlockedByExpiredSession` ya no sale con el token nulo y la sesión guardada ni con el 401 del attest (sí con la sesión borrada o con otro 401), así que la serie cambió de definición con ese build; (3) **la migración YA NO colapsa `.sessionExpired` y `.transient` en la vuelta a iCloud** — lo hacía hasta el 2026-09-17, y esta frase decía «ahí la separación no cambia el recorrido», que dejó de ser cierto ese día: `reverseDrainOnce` y `verify` los separan, y `performReverseClaim` y `freezeBackendForReverse` preguntan por su cuenta a `canRenewSession` (regla siguiente). Lo que SÍ sigue colapsando es la IDA (`driveVerify`, que desde el 2026-09-21 agrupa **tres**: `networkTimeout`, `sessionExpired` y `blocked`) y `sweepZombies`. **El snapshot dejó de colapsar el 2026-09-22** (`snapshot-upload-has-no-ceiling-and-no-way-out`): separa la sesión BORRADA por el SDK (definitiva) del 401 con la sesión guardada (pasajero), con este mismo testigo leído después del push. **Aceptado a sabiendas, como en Grupos:** una sesión que el servidor rechaza sin que el SDK la borre (`user_banned`) se lee pasajera, y «Activar Yala completo» ofrece un «Reintentar» que no puede funcionar.

- **La puerta para volver a entrar en la nube es UNA, y el aviso del cierre la nombra (2026-09-25).** Ticket
  `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`. El cierre en la nube que bloquea por sesión caducada
  enseña `.cloudSessionExpired` («abre Dónde viven tus datos y toca Iniciar sesión»), y esa puerta es la tarjeta de
  sincronización (`SyncSignInBannerLogic`, `CloudMigrationController.signInToResumeSync`). Cuatro cosas que no se tocan sin
  reabrirlo:
  (1) **la tarjeta cuenta las DOS colas** (personal y `GroupSyncOutbox` vivas) y sale con el motor en `.stoppedUntilSignIn`
  **o en `.idleSignedOut` sin sesión** — el segundo es el caso principal: tras relanzar con la sesión borrada por el SDK el
  motor arranca así (`start()`), y la primera versión lo dejaba sin puerta (tres lentes de la review). Si añades un texto
  que mande a esa puerta, comprueba en qué estados del motor sale;
  (2) **con la sesión guardada, la puerta prueba con un ciclo antes de firmar**: `accessToken()` devuelve el JWT que el
  servidor acaba de rechazar, y el atajo «hay token ⇒ despierta» era un botón que no entraba;
  (3) **la firma se ata al dueño del motor** (`CloudSyncRuntime.ownerUserID`) y, sin dueño en memoria, al sello del claim
  —el gate de `start()`—; con otra cuenta la sesión se cierra por `closeSessionIfOpened` (el único `signOut` del controller)
  y no se reanuda. El proveedor sale del faro cuando su hash es el del dueño: `storedProvider()` lo reescribe cualquier
  firma. **El ciclo del motor aplica la misma guarda** (`sessionBelongsToAnotherAccount`, paso 1.5 de `performCycle`) y
  `handleBecameActive` no reanuda con otra cuenta; **las entradas directas de Grupos NO** (ticket
  `groups-outbox-rows-without-a-live-session-have-no-exit`);
  (4) **el cierre para el motor al bloquear** (`CloudSyncRuntime.stopUntilSignIn`, solo desde `.running`): la cadencia
  puede tardar un minuto en chocar con el mismo 401. Las celdas privadas siguen con `.sessionExpired` y su texto sin sitio
  (`private-signout-groups-session-expiry-does-not-say-where-to-sign-in`).

- **Que `signOut()` volviera no dice que la sesión se fuera: pregúntale a su valor de retorno (2026-09-26).** Ticket
  `detach-does-not-verify-the-cloud-session-actually-closed`. Medido en supabase-swift 2.50.0
  (`SupabaseSignOutContractTests`): `signOut(scope: .local)` borra la sesión ANTES de la red, así que sin red LANZA con la
  sesión ya fuera; el borrado del llavero traga su error, así que con el llavero negándose NO lanza y la sesión sigue; y un
  refresco del token en vuelo la repone al terminar. Cuatro cosas que no se tocan sin reabrirlo:
  (1) **el testigo es el retorno de `CloudAuthService.signOut()`** (`@discardableResult -> Bool`), que relee el llavero con
  `sessionIsGone`: viva si el SDK la ve, si el llavero no se deja leer o si guarda algo que decodifica como sesión. Ni
  `currentSession` a secas (convierte un fallo de LECTURA en `nil`: fallaría abierto justo cuando el borrado tampoco entró)
  ni `hasSession` (lleva el seam `-uitest-fake-cloud-session`: bloquearía todo XCUITest que lo use);
  (2) **un camino que no relanza y escribe algo irreversible detrás lo comprueba antes de su punto de no retorno**. Hoy solo
  el desasociar: se para en `.blocked(.sessionNotClosed)` sin escribir nada del dominio Grupos. Los cierres de sesión lo
  descartan, y el boot-wipe no purga el llavero de la sesión: ticket `sign-out-exits-do-not-verify-the-cloud-session-closed`;
  (3) **el perfil capturado y el proveedor se borran SOLO con la sesión ida**: borrados antes, el registrador de Grupos del
  arranque reescribía la asociación sin nombre, también en el iCloud-KV;
  (4) **un refresco que aterriza DESPUÉS de la lectura no lo ve nadie** (`detach-postcondition-misses-a-token-refresh-that-lands-after-it`).
