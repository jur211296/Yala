//
//  TelemetryService.swift
//  Yala
//
//  Privacy-first analytics via TelemetryDeck.
//  No tracking IDs, no PII — only aggregate event signals.
//

import Foundation
import TelemetryDeck

// MARK: - Analytics Event

enum AnalyticsEvent: String {
    case appLaunched = "App · Abierta"
    case transactionSaved = "Uso · Transacción guardada"
    case draftApproved = "Uso · Borrador aprobado"
    case draftRejected = "Uso · Borrador rechazado"
    case budgetSaved = "Planificación · Presupuesto guardado"
    case budgetFiltersAppearEmpty = "Diagnóstico · Filtros de presupuesto vacíos"  // params: budgetID, periodType, hadM2MNotEmpty
    case appEntityShortcutIDsRegenerated = "Diagnóstico · IDs de atajos regenerados"  // params: accounts, subcategories, tags, budgets, txs, drafts, favorites, scheduled, waitedForSync, waitDuration_bucket, sawRace
    case tagDeleted = "Uso · Etiqueta eliminada"  // params: duration_bucket, txCount, draftCount, favoriteCount, scheduledCount, budgetCount
    case tagCatalogRebuilt = "Diagnóstico · Catálogo de etiquetas reconstruido"  // params: tagCount
    case scheduledPaymentSaved = "Planificación · Pago programado guardado"
    case accountCreated = "Uso · Cuenta creada"
    case exportCompleted = "Uso · Exportación completada"
    case aiInsightsGenerated = "Análisis · Insight IA generado"
    case onboardingCompleted = "Activación · Onboarding completado"  // params: mode, expensesOnly, usedSeedCategories
    case onboardingStarted = "Activación · Onboarding iniciado"  // params: mode (initial|fullActivation), prefilled (true|false)
    case onboardingStepViewed = "Activación · Paso de onboarding"  // params: step, stepIndex, totalSteps, mode
    case onboardingPurposePicked = "Activación · Propósito elegido"  // params: purpose (expensesOnly|dayToDay|fullControl)
    case onboardingAccountsPicked = "Activación · Cuentas elegidas"  // params: accounts (single|multiple)
    case onboardingAccountTypePicked = "Activación · Tipo de cuenta elegido"  // params: type (checking|savings|creditCard|cash)
    case onboardingCurrencyPicked = "Activación · Moneda elegida"  // params: currency (rawValue)
    case onboardingCategoriesPicked = "Activación · Categorías elegidas"  // params: loadSeed (true|false)
    case onboardingBackTapped = "Activación · Onboarding atrás"  // params: fromStep, mode
    case onboardingCancelled = "Activación · Onboarding abandonado"  // params: atStep, mode
    case welcomeChooserBranchSelected = "Activación · Camino elegido"  // A4 — params: branch (new|restore|invite)
    case welcomeCloudSignInOutcome = "Activación · Sign-in nube"  // H4 — params: outcome (found|notFound|blocked|error|leaderWait)
    case purchaseAttempted = "Pro · Compra intentada"
    case featureGateHit = "Pro · Tope de función Free"
    case reviewPromptShown = "App · Pidió reseña"
    case proUpsellShown = "Pro · Oferta mostrada"
    case proUpsellTapped = "Pro · Oferta tocada"
    case proUpsellDismissed = "Pro · Oferta descartada"
    case paywallViewed = "Pro · Vio el paywall"
    case trialStarted = "Pro · Prueba iniciada"
    case purchaseCompleted = "Pro · Compra exitosa"
    case trialExpiring = "Pro · Prueba por expirar"
    case proTourStarted = "Pro · Tour iniciado"
    case proTourPhaseCompleted = "Pro · Tour fase completada"
    case proTourCompleted = "Pro · Tour completado"
    case proTourSkipped = "Pro · Tour saltado"
    case chatSheetOpened = "Chat IA · Abierto"
    case chatSheetDismissed = "Chat IA · Cerrado"
    case chatQuestionAsked = "Chat IA · Pregunta enviada"
    case chatSuggestionTapped = "Chat IA · Sugerencia tocada"
    case chatErrorOccurred = "Chat IA · Error"
    case chatDailyLimitReached = "Chat IA · Límite diario alcanzado"
    case chatSuggestionsLLMSucceeded = "Diagnóstico · Sugerencias chat OK"
    case chatSuggestionsLLMFailed = "Diagnóstico · Sugerencias chat fallaron"
    case chatVoiceInputUsed = "Chat IA · Entrada por voz"
    case chatTopicsSheetOpened = "Chat IA · Temas abiertos"
    case chatPersistedSessionRehydrated = "Chat IA · Sesión retomada"
    // Yala AI Onboarding (4-step tutorial first-use post-consent)
    case yalaAIOnboardingShown = "Chat IA · Tutorial mostrado"  // params: launcher (panel|records|stats)
    case yalaAIOnboardingCompleted = "Chat IA · Tutorial completado"  // tap CTA Step 4 "Empezar a chatear"
    case yalaAIOnboardingSkipped = "Chat IA · Tutorial saltado"  // tap "Saltar" topRight (steps 1-3)
    case yalaAIOnboardingDismissed = "Chat IA · Tutorial cerrado"  // tap "X" topLeft — flag NO se setea
    case yalaAIOnboardingTonePicked = "Chat IA · Tono elegido"  // params: tone (normal|considerate|sarcastic), focus (balanced|saver|cautious)
    // Groups Onboarding (3-step informativo, primer tap del tab Grupos)
    case groupsOnboardingShown = "Grupos · Tutorial mostrado"  // params: launcher (groupsTab)
    case groupsOnboardingStepViewed = "Grupos · Paso de tutorial"  // params: step (1|2|3)
    case groupsOnboardingCompleted = "Grupos · Tutorial completado"  // tap CTA Step 3 "Ir a Grupos"
    // Chat → Registrar transacciones
    case chatIntentClassified = "Chat IA · Intención clasificada"  // params: intent, used_force_intent
    case chatDraftProposed = "Chat IA · Borrador propuesto"  // params: count
    case chatDraftSaved = "Chat IA · Gasto guardado"
    case chatDraftDismissed = "Chat IA · Borrador descartado"  // tap explícito en botón Descartar
    case chatDraftEditedExternally = "Chat IA · Borrador editado"
    case chatAmbiguousRepregunta = "Chat IA · Repregunta"

    // Intent lifecycle (Siri / Atajos / Lock Screen / Control Center)
    case intentInvoked = "Atajos · Atajo ejecutado"
    case intentSuccess = "Atajos · Atajo exitoso"
    case intentFailed = "Atajos · Atajo fallido"
    case applePayPayloadMaterialized = "Atajos · Apple Pay materializado"  // params: count — la app creó N borradores desde la cola de App Group del intent de Apple Pay (nuevo flujo sin SwiftData en el intent)
    case applePayPayloadDropped = "Atajos · Apple Pay descartado"  // params: count — N pagos encolados se descartaron por monto no parseable/cero (canario de payloads corruptos)
    case siriPayloadMaterialized = "Atajos · Siri materializado"  // params: count — la app creó N borradores desde la cola de App Group del intent de Siri (nuevo flujo sin SwiftData en el intent)
    case siriPayloadDropped = "Atajos · Siri descartado"  // params: count — N dictados encolados se descartaron por no tener ninguna transacción parseable

    // Group lifecycle
    case groupCreated = "Grupos · Grupo creado"
    case groupArchived = "Grupos · Grupo archivado"
    case groupDeleted = "Grupos · Grupo eliminado"
    case groupSoftDeleted = "Grupos · Grupo eliminado para todos"
    case groupExpenseAdded = "Grupos · Gasto agregado"
    case draftConvertedToGroupExpense = "Grupos · Gasto desde bandeja"  // params: source (draft sourceType), bridgeReady
    case groupTwoPersonSplitChosen = "Grupos · Split rápido elegido"  // params: choice (iPaidEqual|iPaidOwedFull|theyPaidEqual|theyPaidOwedFull|moreOptions)
    case openingBalanceCreated = "Grupos · Saldo inicial creado"
    case openingBalanceRemoved = "Grupos · Saldo inicial eliminado"
    case groupSettlementCreated = "Grupos · Liquidación creada"
    case groupSettlementConfirmed = "Grupos · Liquidación confirmada"
    case groupSettlementRejected = "Grupos · Liquidación rechazada"
    case groupInviteSent = "Grupos · Invitación enviada"
    case groupInviteAccepted = "Grupos · Invitación aceptada"

    // Bridge opt-out (F8) — disparados solo desde UI handlers (no didSet de AppPreferences)
    case bridgeGlobalToggled = "Grupos · Bridge global cambiado"
    case bridgeOverrideSet = "Grupos · Bridge override"
    case bridgeActivationCompleted = "Grupos · Bridge activado"
    case bridgeDeactivationCompleted = "Grupos · Bridge desactivado"
    case bridgeVirtualLentTxFailed = "Diagnóstico · TX préstamo virtual falló"  // params: role — TX2 virtual del préstamo no se pudo crear (saldo degradado)

    // Nudges
    case nudgeShown = "App · Sugerencia mostrada"
    case nudgeTapped = "App · Sugerencia tocada"
    case nudgeDismissed = "App · Sugerencia descartada"
    case nudgeAutoDismissed = "App · Sugerencia auto-descartada"

    // Conversion
    case fullModeActivationStarted = "Activación · Modo completo iniciado"
    case fullModeActivationCompleted = "Activación · Modo completo completado"
    case groupInviteOnboardingCompleted = "Activación · Onboarding de invitación completado"

    // Panel Hero IA
    case panelHeroAIGenerated = "Análisis · Hero IA generado"
    case panelHeroAICacheHit = "Diagnóstico · Hero IA caché"
    case panelHeroCTAImpression = "Análisis · Hero IA impresión"
    case panelHeroCTATap = "Análisis · Hero IA tocado"

    // CloudKit observability
    case cloudkitExportFailed = "Diagnóstico · Sync export falló"
    case cloudkitExportSucceeded = "Diagnóstico · Sync export OK"
    case cloudkitStalledDetected = "Diagnóstico · Sync estancado"
    case cloudkitIndicatorTapped = "Diagnóstico · Indicador sync tocado"
    case cloudkitDuplicateDetected = "Diagnóstico · Duplicado detectado"
    case cloudkitTransferOrphanRepaired = "Diagnóstico · Transferencia huérfana reparada"
    case cloudkitTransferCollisionDetected = "Diagnóstico · Colisión de transferencia"
    case cloudkitBudgetCSVMirrorRebuilt = "Diagnóstico · Espejo de presupuesto reconstruido"  // params: count
    case cloudkitGroupSyncGateHardCap = "Diagnóstico · Gate de grupos llegó al tope"  // params: isSyncing — el sync de grupos arrancó por tope sin import personal asentado
    case cloudkitGroupSyncPromotedToAuto = "Diagnóstico · Sync de grupos promovido a auto"  // params: importSettled (false = promovido por hard cap sin import asentado) — los engines pasaron de export-only a automaticallySync
    case cloudkitGroupSyncNoImportPromote = "Diagnóstico · Sync de grupos promovido sin import personal"  // sin params — store personal VACÍO (ningún .import apareció en la ventana de gracia) promovido a auto-sync; antes quedaba export-only para siempre (bug del usuario "solo grupos")
    case cloudkitGroupZoneRecovered = "Diagnóstico · Zona de grupo recuperada"  // params: count — zonas owner sin GroupMeta subido re-encoladas al arrancar
    case cloudkitGroupRecordsRecovered = "Diagnóstico · Records de grupo recuperados"  // params: count — records con ckSystemFieldsData nil (nunca subieron, p.ej. rechazados por schema) re-encolados al arrancar
    case cloudkitGroupRecordSaveRejected = "Diagnóstico · Save de grupo rechazado"  // params: code, recordType — CANARIO: >0 en prod = incidente de schema/permisos en el container de grupos (el server descarta el record; la recovery lo re-encola al próximo launch)
    case cloudkitGroupEnqueueDroppedNoEngine = "Diagnóstico · Enqueue de grupo dropeado sin engine"  // params: op (save|delete) — CANARIO: markPendingChange/Deletion con engine nil = drop definitivo e invisible (pre-initialize / post-signOut); antes era un no-op SILENCIOSO
    case iCloudRestoreOutcome = "Diagnóstico · Resultado de restore"  // params: phase (completed|partial), destination (groupsOnly|directToApp|onboarding)
    case cloudSyncIdentityGapObserved = "Diagnóstico · Gap de identidad de sync"  // params: entityType — CANARIO (Modo Nube I3): un delete cuyo tombstone NO trae syncID preservado → el outbox no pudo emitir el tombstone; >0 = revisar la captura de identidad (barrido/born-cloud)
    case cloudSyncCoherenceGroupPartial = "Diagnóstico · Grupo de coherencia parcial"  // params: entity, group — CANARIO (Modo Nube I8c, §d.4bis): el emisor produjo un grupo de coherencia (money/split/budget/tx_split) INCOMPLETO tras la expansión (bug del emisor; no debe ocurrir por construcción). >0 = revisar EntityEmissionMap/DeltaEmitter
    case cloudSignInProviderMismatch = "Diagnóstico · Proveedor de sign-in distinto"  // CANARIO (Modo Nube §f.1 variante B, guard R9 SUB-FIRST H4): sign-in sin cuenta (exists=false) con faro cloud-activado, provider DISTINTO y sub que no coincide con el del faro → aviso "usa el otro método" ANTES del claim (jamás 2ª cuenta divergente); >0 = priorizar identity-linking (A30) — incluye el falso-positivo aceptado de una invitada SIN cuenta en device ajeno con provider distinto. Call-site real: WelcomeCloudSignInView (rama .accountMissing, ProviderMismatchLogic.decide → .mismatch); AccountClaimDecision.showProviderMismatch sigue declarado para born-cloud futuro
    case cloudSyncBlockedByAttestUnavailable = "Diagnóstico · Sync bloqueado por attest"  // params: platform — CANARIO (Modo Nube I7, §f.5/E2E-S10): la 2ª señal (App Attest/Play Integrity/WebAuthn) es TERMINAL → el device no puede sincronizar de forma segura; >0 = devices sin backup. Superficie declarada; la DISPARA el consumidor I7c cuando AttestSyncGate.classify → .terminal
    case cloudSyncBlockedByExpiredSession = "Diagnóstico · Sync bloqueado por sesión expirada"  // params: pending — BREADCRUMB (Modo Nube I7, §f.3/S11): sesión no renovable con deltas en el outbox → estado accionable "inicia sesión para subirlos". Superficie declarada; la DISPARA el consumidor I7c/I8 cuando SessionExpiryPolicy → .blockedNeedsSignIn
    case cloudSyncOutboxMirrorRehydrated = "Diagnóstico · Outbox re-hidratado del espejo"  // params: count — CANARIO (Modo Nube I8d/A1, §d.5): >0 en boot = una lightweight migration recreó la tabla SyncOutbox y `count` filas se re-hidrataron del espejo App Group (evento hoy invisible). La DISPARA CloudSyncEngine.rehydrateOutboxFromMirror
    case cloudSyncOutboxMirrorDivergence = "Diagnóstico · Divergencia del espejo del outbox"  // params: delta — CANARIO (Modo Nube I8d/A1, §d.5): delta = |espejo del userID| − |store SyncOutbox| en cada arranque; >0 persistente SIN migración = crash entre purga y remove no reconciliado, o vaciado parcial (el modo de fallo que ni el Merkle ve). La DISPARA CloudSyncEngine.rehydrateOutboxFromMirror
    case cloudCutoverLeaderOrphanReconciled = "Diagnóstico · Cutover: writes huérfanos rescatados"  // params: count — CANARIO (Modo Nube I10 w8, §g.4 SERIO 1 v3): la capa de RED del líder rescató writes de la ventana localModeSet→mirrorOff que la capa primaria no había subido. >0 = la ventana existió en la práctica (esperado raro). Sin PII (solo el conteo)
    case cloudAdoptOrphanReconciled = "Diagnóstico · Adopt: filas huérfanas rescatadas"  // params: count — CANARIO (Modo Nube DIFERIDOS #30, mecanismo v1 DARK): el device que adopta (.icloud→.cloud) subió filas de la ventana de cutover cuya identidad no existía en el backend (espejo del par del líder). >0 = la ventana multi-device existió en la práctica (esperado raro). La DISPARA MigrationWorkExecutor.runAdoptOrphanReconcile. Sin PII (solo el conteo)
    case cloudConsentAccepted = "Diagnóstico · Consent nube aceptado"  // params: path (migration|adopt) — MÉTRICA (Modo Nube I14, §2.8/§j.4): el usuario aceptó el consentimiento informado de privacidad y activó la nube (por migración o por adopt de una cuenta existente). Sin PII (solo la ruta)
    case cloudSyncMutationRejected = "Diagnóstico · Mutación de sync rechazada"  // params: reason — CANARIO (Modo Nube I8e, §d.5): el backend RECHAZÓ un delta (status rejected). El delta queda en dead-letter (SyncOutbox.rejectedReason), NO se pierde. >0 = write-site sin auditar / grupo de coherencia parcial (bug de emisión, debe ser 0). La DISPARA SyncPushClient.applyResults. Sin PII (solo el motivo)
    case cloudAccountUnavailable = "Diagnóstico · Cuenta no disponible"  // BREADCRUMB (Modo Nube I8e, §d.5): el backend respondió 403 (autenticado pero prohibido) → cuenta suspendida/deshabilitada, distinto del 401 (sesión expirada). >0 = revisar estado de la cuenta. La DISPARA SyncPushClient.push. Sin PII
    case cloudAccountReverting = "Diagnóstico · Cuenta en reversa"  // BREADCRUMB (freeze §h.1): el backend respondió 409 yala_account_reverting → la cuenta está en/tras una reversa a iCloud (reverse_frozen_at estampado; el backend ya no es fuente de verdad). El device deja de pushear (stop hasta relanzar, mismo trato que 403) y sus deltas quedan en el outbox para su propia reversa/adopción (I14). La DISPARA SyncPushClient.push. Sin PII
    case cloudSyncClockReceiveRejected = "Diagnóstico · HLC remoto rechazado por el reloj"  // params: reason — CANARIO (Modo Nube I8f-1, F-5): `HLCClock.receive` RECHAZÓ un HLC remoto (drift >5min futuro / counter overflow) al aplicar deltas del pull → el reloj local NO se envenena pero pierde causalidad con ese emisor bajo skew extremo (residual documentado; el server lo vigila con cloudSyncSuspectClockWin). La DISPARA CloudSyncEngine.receiveRemoteClock. Sin PII (solo el motivo)
    case cloudSecondaryMountMismatchBlocked = "Diagnóstico · Secundaria bloqueada por mount-mismatch"  // CANARIO (M1, D3 del /review-plan): canRunDomain bloqueó el runtime porque el descriptor de sesión secundaria está activo pero el proceso montó el store del DUEÑO (ventana de entrada pre-relaunch). Esperado a lo sumo UNA ventana corta por entrada; >0 SOSTENIDO en un mismo device = la ventana se está pisando (usuario operando sin relanzar) — sin el guard eso pushearía la History del dueño a la cuenta entrante. Dedupeado por proceso. La DISPARA CloudSyncRuntime.canRunDomain. Sin PII
    case cloudSyncMerkleDivergence = "Diagnóstico · Divergencia Merkle de sync"  // params: entity — CANARIO (Modo Nube I8f-3, §d.7 Canal 1): el entityHash local de una tabla ≠ el del backend CON quiescencia local (outbox vivo vacío + pull completado, guard A-3) → infidelidad del apply/canon vs la verdad server-side. >0 = incidente de fidelidad del sync (remediación v1: re-pull completo, wiring I9). La DISPARA CloudSyncEngine.verifyIntegrity. Sin PII (solo el nombre de tabla o "root")
    case groupMerkleDivergence = "Diagnóstico · Divergencia Merkle de grupos"  // params: groupCount — CANARIO (Grupos→backend B1, §d.7 Canal 1): UNA señal por corrida — N grupos cuyo árbol Merkle LOCAL ≠ el del backend CON quiescencia del grupo (outbox vivo del grupo vacío + dead-letters 0 + pull completado + canon c1) → infidelidad del apply/canon del canal de Grupos. Excluye el corpus-vacío-remoto (remoción de membership por RLS, breadcrumb merkleEmptyRemote). >0 = incidente de fidelidad. Remediación: reset del cursor de cada grupo divergente + re-pull, UNA vez por sesión. La DISPARA GroupsSyncClient.runGroupMerkleVerification. Sin PII (solo el COUNT de grupos, jamás group_ids)
    case groupPushRejected = "Diagnóstico · Push de grupo rechazado"  // params: reason — CANARIO (Grupos→backend G4, §12): el backend RECHAZÓ un delta de grupo (dead-letter en GroupSyncOutbox.rejectedReason, NO se pierde). yala_not_authorized es transitorio-DE-ESTADO (se re-drivea al aprobar el member); el resto (malformed_delta, coherence_*, yala_bad_request…) es permanente. >0 sostenido = write-site de grupo sin auditar / permisos. La DISPARA GroupsSyncClient.applyResults. Sin PII (solo el slug)

    // Routing observability (F9 — privacy-first: only intent IDs, no payloads)
    case routingIntentSuperseded = "Diagnóstico · Routing supersedido"  // a queued intent was dropped by an incoming one
    case routingIntentDeferred = "Diagnóstico · Routing diferido"  // an incoming intent was persisted to DeferredIntentBuffer
    case routingReadinessBlocked = "Diagnóstico · Routing bloqueado"  // a drain was blocked because a modal was visible
    case routingDrainHoldSustained = "Diagnóstico · Routing hold sostenido"  // params: blocker, consumer — CANARIO (D4, gate Clase D): un intent de .mainTab/.panel lleva >45s retenido Y sigue en cola → flag publicado pegado (shellModalBlocker/isMainTabModalVisible/hasActivePresentation stale). >0 sostenido = presentaciones congeladas en producción. La DISPARA RouterHoldCanary. Sin PII
    case routingWelcomeChainSuperseded = "Diagnóstico · Routing welcome supersedido"  // welcome chain dismissed to let a superseding intent drain (B4-04)
    case inviteReEmittedFromStore = "Diagnóstico · Invitación re-emitida"  // a persisted group invite was re-emitted after the transient intent was dropped
    case invitePendingExpired = "Diagnóstico · Invitación pendiente expirada"  // a persisted group invite was purged by TTL (24h) before presenting
    case groupJoinIntentPersisted = "Diagnóstico · Join intent persistido"  // acceptShare OK → intent guardado en PendingJoinStore; el member se reconcilia cuando la zona materialice
    case groupJoinIntentReconciled = "Diagnóstico · Join intent reconciliado"  // params: trigger (acceptShare|remoteInsert|boot|foreground), status (pendingApproval|active) — el SplitMember del current user quedó asegurado y encolado
    case groupJoinIntentDeferred = "Diagnóstico · Join intent diferido"  // params: reason (waitForGroup|enginesNotReady|importNotQuiescent) — el reconcile no pudo correr aún; reintenta en el próximo trigger (antes esto era un skip SILENCIOSO en acceptShare)
    case groupJoinIntentExpired = "Diagnóstico · Join intent expirado"  // CANARIO: una entry de PendingJoinStore venció su TTL (7d) sin lograr member — el invitado quedó fuera del grupo pese a aceptar; >0 = revisar la materialización de zonas compartidas
    case groupJoinFailed = "Diagnóstico · Join de grupo falló"  // params: reason (slug estable sin PII del ErrorKind + código yala_* si permanente) — CANARIO (Grupos→backend G4, C6): el join backend por token falló de forma PERMANENTE (invalidInvite/notAuthorized/permanentRejected/generic) → el intent se limpió y el invitado no entra. JAMÁS en transient (el reconciler reintenta). La DISPARA GroupBackendInviteEntryHandler. Sin PII (solo el slug)
    case groupLegacyRebindFailed = "Diagnóstico · Rebind legacy de grupo falló"  // CANARIO (Grupos→backend G4/G6, C6): se ENVIÓ un legacyMemberKey al join y el resultado vino rebound==false → el rebind no matcheó una fila migrada de CloudKit (relevante para G6). Hoy nil en el flujo de token normal — el canario queda cableado. La DISPARA GroupBackendInviteEntryHandler. Sin PII
    case groupsIdentityBootMismatch = "Diagnóstico · Identidad de grupos no coincide al arrancar"  // CANARIO (GAP 1): el boot-guard detectó groups_currentUserRecordName ≠ userRecordID actual y corrió la limpieza de account-switch. >0 sostenido = falso positivo del guard (revisar) o churn real de Apple ID en devices compartidos
    case relaunchNetExhausted = "Diagnóstico · Red de relaunch agotada"  // params: net (signout|secondaryEntry) — CANARIO (fix carrera 2026-07-14): la red del cover terminal agotó su ciclo de reintentos sin confirmar presentación (onAppear del contenido real). >0 = algo tapa el anchor del root con el wipe/entrada armados; el blocker de la matriz contiene el router y el exit-on-background es la red final. La DISPARAN los nets de ContentView. Sin PII
    case accountDeletionCompleted = "Diagnóstico · Cuenta eliminada"  // params: step (cloud|groupsOnly) — el borrado GDPR (G5-D1b) completó el server-side + cierre local armado. La DISPARA AccountDeletionService. Sin PII
    case accountDeletionFailed = "Diagnóstico · Borrado de cuenta falló"  // params: step (groups|delete|localClose) — CANARIO (G5-D1b): un paso del borrado falló; NADA local se armó, la sesión sigue viva, el usuario reintenta. >0 sostenido = revisar el RPC/gateway del step. La DISPARA AccountDeletionService. Sin PII
    case groupMigrationCompleted = "Diagnóstico · Migración de grupo completada"  // params: count — Grupos→backend G6-3: el owner migró `count` grupos vivos de CloudKit al backend (marcador estampado, congelado para los members). La DISPARA GroupMigrationUploader. Sin PII
    case groupMigrationFailed = "Diagnóstico · Migración de grupo falló"  // params: step (migrate|invite|freeze|seed|push|marker) — CANARIO (G6-3): un paso de la migración falló; el grupo NO quedó marcado, reintenta en el próximo boot (todos los pasos idempotentes). >0 sostenido = revisar el RPC/gateway del step. La DISPARA GroupMigrationUploader. Sin PII
    case siwaExchangeFailed = "Diagnóstico · Canje SIWA falló"  // params: reason (no-code|no-jwt|exchange|keychain) — CANARIO (B1, 5.1.1(v)): el canje del authorization_code post-sign-in no dejó refresh token custodiado → si ese usuario borra la cuenta, el revoke se saltará (skippedNoToken). Best-effort: el sign-in NO falló. >0 sostenido = revisar /account/siwa/exchange o el secret SIWA_AUTH_KEY. La DISPARA SIWAExchangeSeam/SIWAExchangeCapture. Sin PII (jamás code/token)
    case siwaRevokeFailed = "Diagnóstico · Revocación SIWA falló"  // params: reason (no-jwt|revoke) — CANARIO (B1, 5.1.1(v)): el revoke del refresh token de Apple falló en el borrado de cuenta (el borrado NO se bloquea — contrato best-effort; el par queda para el retry). >0 sostenido = revisar /account/siwa/revoke o el secret. La DISPARA SIWATokenRevocation. Sin PII
    case groupPushTokenRegisterFailed = "Diagnóstico · Registro de push token de grupo falló"  // CANARIO (Grupos→backend G8-2): el registro del device token APNs contra /push/register fue RECHAZADO por el server (4xx ≠ 401) → este device no recibirá silent push de grupos hasta el próximo boot que reintente. NO se dispara en offline transitorio ni 401 (sesión). >0 sostenido = revisar el endpoint/credenciales de push. La DISPARA PushTokenRegistrar. Sin PII

    // MARK: Telemetría 2.0 — eventos nuevos
    // Activación (primeras veces) · sesión · fin de suscripción
    case appResumed = "App · Reactivada"                          // warm start (foreground), complementa appLaunched (cold)
    case firstTransaction = "Activación · Primera transacción"    // params: origen
    case firstBudget = "Activación · Primer presupuesto"          // params: periodo
    case firstScheduledPayment = "Activación · Primer pago programado" // params: recurrencia
    case subscriptionEnded = "Pro · Suscripción terminada"        // Pro→Free; params: era_trial

    // P1 — CRUD · planificación · grupos · chat
    case transactionDeleted = "Uso · Transacción eliminada"           // params: type
    case transactionDuplicated = "Uso · Transacción duplicada"        // params: type
    case bulkEditApplied = "Uso · Edición masiva"                     // params: campos, cantidad_bucket
    case searchPerformed = "Uso · Búsqueda"                           // params: con_resultados
    case dataImported = "Uso · Importación"                           // params: formato, cantidad_bucket
    case budgetAlertTriggered = "Planificación · Alerta de presupuesto" // params: umbral (100 = superado)
    case budgetDeleted = "Planificación · Presupuesto eliminado"
    case scheduledPaymentDeleted = "Planificación · Pago eliminado"
    case groupLeft = "Grupos · Salió del grupo"                       // params: con_deuda
    case groupBalancesViewed = "Grupos · Balances vistos"
    case chatDraftRetried = "Chat IA · Reintento"

    // P2 — configuración + consumo
    case themeChanged = "Ajustes · Tema cambiado"                     // params: tema
    case currencyChanged = "Ajustes · Moneda principal"               // params: moneda
    case notificationsPermission = "Notificaciones · Permiso"         // params: resultado
    case notificationTapped = "Notificaciones · Tap"                  // params: tipo
    case widgetConfigured = "Atajos · Widget configurado"             // params: tipo
    case reportViewed = "Análisis · Reporte visto"
    case statsTabViewed = "Estadísticas · Tab visto"                  // params: tab
    case recordsDuplicateModeActivated = "Registros · Identificar duplicados"  // params: byAmount, byNote, bySubcategory, byDate
}

enum DuplicateDetectionContext: String {
    case bootCleanup = "boot-cleanup"
    case runtimeFetch = "runtime-fetch"
    case syncApply = "sync-apply"
    case uniquingFallback = "uniquing-fallback"
}

enum TransferReconcileContext: String {
    case bootReconcile = "boot.transferReconcile"
    case bootCollision = "boot.transferCollision"
}

// MARK: - Telemetry Service

@MainActor
enum TelemetryService {

    private static var isConfigured = false
    private static var trackedOnceKeys: Set<String> = []

    // MARK: - Configuration

    static func configure() {
        guard let appID = APIKeyService.telemetryDeckAppID else {
            #if DEBUG
            print("TelemetryService: No App ID configured — analytics disabled")
            #endif
            return
        }
        TelemetryDeck.initialize(config: .init(appID: appID))
        isConfigured = true
        #if DEBUG
        print("TelemetryService: Initialized")
        #endif
    }

    // MARK: - Tracking

    static func track(_ event: AnalyticsEvent, parameters: [String: String] = [:]) {
        guard isConfigured else { return }
        var params = parameters
        params["isProUser"] = String(FeatureGateService.shared.isProUser)
        TelemetryDeck.signal(event.rawValue, parameters: params)
        #if DEBUG
        if event.rawValue.hasPrefix("cloudkit") {
            print("TelemetryService: [CloudKit] \(event.rawValue) params=\(params)")
        }
        #endif
    }

    /// Builds common parameters for upsell/conversion tracking.
    static func upsellParameters(source: String) -> [String: String] {
        var params: [String: String] = ["source": source]
        if let firstLaunch = UserDefaults.standard.object(forKey: "reviewFirstLaunchDate") as? Date {
            let days = Calendar.current.dateComponents([.day], from: firstLaunch, to: .now).day ?? 0
            params["daysSinceInstall"] = String(days)
        }
        params["sessionNumber"] = String(UserDefaults.standard.integer(forKey: "pro.upsell.sessionCount"))
        return params
    }

    /// Tracks an event only once per session (deduplicates by composite key).
    static func trackOnce(_ event: AnalyticsEvent, key: String, parameters: [String: String] = [:]) {
        let compositeKey = "\(event.rawValue):\(key)"
        guard !trackedOnceKeys.contains(compositeKey) else { return }
        trackedOnceKeys.insert(compositeKey)
        track(event, parameters: parameters)
    }

    /// Reports a CloudKit-driven duplicate observation. The composite key includes
    /// `keySuffix` (typically a zoneID or count) so each distinct duplicate fires once
    /// instead of collapsing every dup in a session into a single event. The suffix
    /// is local-only — it never reaches the backend.
    static func cloudkitDuplicateDetected(
        model: String,
        count: Int,
        context: DuplicateDetectionContext,
        keySuffix: String
    ) {
        trackOnce(
            .cloudkitDuplicateDetected,
            key: "\(model):\(context.rawValue):\(keySuffix)",
            parameters: [
                "model": model,
                "count": String(count),
                "context": context.rawValue
            ]
        )
    }

    // MARK: - Routing observability (F9)

    /// Fires when `RouterEntryGate` drops queued intents because an incoming one
    /// supersedes them (e.g. `.navigate(.inbox)` supersedes `.showInboxAlert`).
    /// Privacy-first: only intent IDs, no payloads.
    static func routingIntentSuperseded(droppedID: String, by incomingID: String) {
        track(.routingIntentSuperseded, parameters: [
            "dropped": droppedID,
            "by": incomingID
        ])
    }

    /// Fires when an intent is deferred to the DeferredIntentBuffer because
    /// the app cannot present right now (pre-bootstrap, locked, mid-onboarding).
    static func routingIntentDeferred(intentID: String, reason: String) {
        track(.routingIntentDeferred, parameters: [
            "intent": intentID,
            "reason": reason
        ])
    }

    /// CANARIO M1 (D3): el guard de mount-mismatch de `CloudSyncRuntime.canRunDomain` bloqueó un
    /// arranque del runtime en la ventana de entrada de la sesión secundaria (molde
    /// `routingReadinessBlocked` — producción sin PII, fuera de `#if DEBUG`).
    static func cloudSecondaryMountMismatchBlocked() {
        track(.cloudSecondaryMountMismatchBlocked)
    }

    /// Fires when the .contentView consumer is unable to drain because a
    /// modal is blocking. Surfaces unexpected gates in production.
    static func routingReadinessBlocked(blocker: String) {
        track(.routingReadinessBlocked, parameters: [
            "blocker": blocker
        ])
    }

    /// CANARIO D4: un intent de .mainTab/.panel retenido por el gate Clase D
    /// superó el umbral sostenido Y sigue en cola — flag publicado pegado.
    static func routingDrainHoldSustained(blocker: String, consumer: String) {
        track(.routingDrainHoldSustained, parameters: [
            "blocker": blocker,
            "consumer": consumer
        ])
    }

    /// Fires when ContentView dismisses the welcome chain so a pending
    /// welcome-superseding intent (group invite/reconnect) can drain past the
    /// readiness gate. Confirms the B4-04 deadlock fix triggers in production.
    /// Privacy-first: only the intent ID, no payloads.
    static func routingWelcomeChainSuperseded(intentID: String) {
        track(.routingWelcomeChainSuperseded, parameters: [
            "intent": intentID
        ])
    }

    /// Fires when a persisted group invite is re-emitted from `PendingInviteStore`
    /// (cold launch or foreground) after the transient intent was dropped by
    /// `resetTransients`. Confirms the fix rescues invites in production.
    /// Privacy-first: no payload.
    static func inviteReEmittedFromStore() {
        track(.inviteReEmittedFromStore)
    }

    /// Fires when a persisted group invite is purged by TTL (24h) without ever
    /// being presented. Privacy-first: no payload.
    static func invitePendingExpired() {
        track(.invitePendingExpired)
    }

    /// Reports orphan / malformed / pairing repair from `TransferPairReconcileService`.
    /// Privacy-first: no pairIDs ni TX identifiers, solo counts.
    static func cloudkitTransferOrphanRepaired(orphansCleared: Int, pairedCount: Int) {
        track(.cloudkitTransferOrphanRepaired, parameters: [
            "orphansCleared": String(orphansCleared),
            "pairedCount": String(pairedCount),
            "context": TransferReconcileContext.bootReconcile.rawValue
        ])
    }

    /// CANARIO Modo Nube (I3): un delete llegó al `CloudSyncEngine` con un tombstone SIN `syncID`
    /// preservado (`.preserveValueOnDeletion` vacío = identidad nunca acuñada antes del borrado) →
    /// el outbox no pudo emitir el tombstone. >0 en producción = revisar la captura de identidad.
    /// Privacy-first: solo el tipo de entidad, sin IDs ni PII.
    static func cloudSyncIdentityGapObserved(entityType: String) {
        track(.cloudSyncIdentityGapObserved, parameters: [
            "entityType": entityType
        ])
    }

    /// CANARIO Modo Nube (I8c, §d.4bis): el `DeltaEmitter` produjo un grupo de coherencia
    /// (money/split/budget/tx_split) INCOMPLETO tras la expansión del invariante de emisión. No debe
    /// ocurrir por construcción (la expansión es total) → red defensiva. >0 = bug en
    /// `EntityEmissionMap`/`DeltaEmitter`. Privacy-first: solo tabla + grupo, sin IDs ni PII.
    static func cloudSyncCoherenceGroupPartial(entity: String, group: String) {
        track(.cloudSyncCoherenceGroupPartial, parameters: [
            "entity": entity,
            "group": group
        ])
    }

    /// CANARIO Modo Nube (I7, §f.1 variante B): un born-cloud cuyo faro KV dice "cloud activado" firmó
    /// con un proveedor cuyo `sub` NO tiene cuenta → se evitó una 2ª cuenta divergente con un aviso.
    /// >0 = priorizar identity-linking (riesgo A30). La dispara el consumidor I7c cuando
    /// `AccountClaimDecision.decide` devuelve `.showProviderMismatch`. Privacy-first: sin IDs ni PII.
    static func cloudSignInProviderMismatch() {
        track(.cloudSignInProviderMismatch)
    }

    /// CANARIO Modo Nube (I7, §f.5/E2E-S10): la 2ª señal (App Attest iOS / Play Integrity Android /
    /// WebAuthn web) es TERMINAL → este device no puede sincronizar de forma segura (nunca respalda).
    /// La dispara el consumidor I7c cuando `AttestSyncGate.classify` devuelve `.terminal`.
    /// Privacy-first: solo la plataforma, sin IDs ni PII.
    static func cloudSyncBlockedByAttestUnavailable(platform: String) {
        track(.cloudSyncBlockedByAttestUnavailable, parameters: [
            "platform": platform
        ])
    }

    /// BREADCRUMB Modo Nube (I7, §f.3/S11): la sesión de Supabase no puede renovar y hay deltas en el
    /// outbox → estado accionable "inicia sesión para subir tus N cambios" (los datos están a salvo
    /// localmente). La dispara el consumidor I7c/I8 cuando `SessionExpiryPolicy.decide` devuelve
    /// `.blockedNeedsSignIn`. Privacy-first: solo el conteo, sin IDs ni PII.
    static func cloudSyncBlockedByExpiredSession(pending: Int) {
        track(.cloudSyncBlockedByExpiredSession, parameters: [
            "pending": String(pending)
        ])
    }

    /// CANARIO Modo Nube (I8d/A1, §d.5): una lightweight migration recreó la tabla `SyncOutbox` y
    /// `count` filas se re-hidrataron del espejo App Group. >0 = evento hoy invisible (pérdida de deltas
    /// financieros evitada). La dispara `CloudSyncEngine.rehydrateOutboxFromMirror` cuando `count > 0`.
    /// Privacy-first: solo el conteo, sin IDs ni PII.
    static func cloudSyncOutboxMirrorRehydrated(count: Int) {
        track(.cloudSyncOutboxMirrorRehydrated, parameters: [
            "count": String(count)
        ])
    }

    /// CANARIO Modo Nube (I8d/A1, §d.5): `delta = |espejo del userID| − |store SyncOutbox|` medido en
    /// cada arranque. >0 persistente SIN migración = crash entre purga y remove no reconciliado (archivo
    /// espejo huérfano), o vaciado parcial — el modo de fallo que ni el Merkle ve. La dispara
    /// `CloudSyncEngine.rehydrateOutboxFromMirror` cuando `delta != 0`. Privacy-first: solo el delta.
    static func cloudSyncOutboxMirrorDivergence(delta: Int) {
        track(.cloudSyncOutboxMirrorDivergence, parameters: [
            "delta": String(delta)
        ])
    }

    /// CANARIO Modo Nube (I8e, §d.5): el backend RECHAZÓ un delta (`SyncDeltaResult.status == rejected`).
    /// El delta NO se pierde — queda en dead-letter (`SyncOutbox.rejectedReason`) para el panel DEBUG (I12).
    /// >0 = un write-site sin auditar o un grupo de coherencia parcial (bug de emisión, debe ser 0 tras
    /// I8b/I8c). La dispara `SyncPushClient.applyResults`. Privacy-first: solo el motivo, sin IDs ni PII.
    static func cloudSyncMutationRejected(reason: String) {
        track(.cloudSyncMutationRejected, parameters: [
            "reason": reason
        ])
    }

    /// CANARIO Modo Nube (I10 w8, §g.4 SERIO 1 v3): la capa de RED del líder rescató writes huérfanos de
    /// la ventana de cutover que la capa primaria no había subido. >0 = la ventana existió en la práctica
    /// (esperado raro). Sin PII (solo el conteo).
    static func cloudCutoverLeaderOrphanReconciled(count: Int) {
        track(.cloudCutoverLeaderOrphanReconciled, parameters: [
            "count": String(count)
        ])
    }

    /// CANARIO Modo Nube (DIFERIDOS #30, mecanismo v1 DARK): el device que adopta subió filas huérfanas de
    /// la ventana de cutover cuya identidad no existía en el backend (espejo del par del líder). >0 = la
    /// ventana multi-device existió en la práctica (esperado raro). Sin PII (solo el conteo).
    static func cloudAdoptOrphanReconciled(count: Int) {
        track(.cloudAdoptOrphanReconciled, parameters: [
            "count": String(count)
        ])
    }

    /// MÉTRICA Modo Nube (I14, §2.8/§j.4): el usuario aceptó el consentimiento informado y activó la nube.
    /// `path` = `migration` (usuario iCloud migrando) | `adopt` (returning-user sobre cuenta poblada, #30).
    /// Privacy-first: solo la ruta, sin IDs ni PII.
    static func cloudConsentAccepted(path: String) {
        track(.cloudConsentAccepted, parameters: [
            "path": path
        ])
    }

    /// BREADCRUMB Modo Nube (I8e, §d.5): el backend respondió 403 (autenticado pero prohibido) → la cuenta
    /// está suspendida/deshabilitada. Distinto del 401 (sesión expirada → `cloudSyncBlockedByExpiredSession`).
    /// La dispara `SyncPushClient.push`. Privacy-first: sin IDs ni PII.
    static func cloudAccountUnavailable() {
        track(.cloudAccountUnavailable)
    }

    /// MÉTRICA Modo Nube (G5-D1b): el borrado GDPR de la cuenta completó server-side + cierre local armado.
    /// `step` = `cloud` | `groupsOnly`. La dispara `AccountDeletionService`. Sin PII.
    static func accountDeletionCompleted(step: String) {
        track(.accountDeletionCompleted, parameters: [
            "step": step
        ])
    }

    /// CANARIO Modo Nube (G5-D1b): un paso del borrado de cuenta falló. `step` = `groups` (forget_user) |
    /// `delete` (/account/delete) | `localClose` (quiescencia del cierre solo-grupos). NADA local se armó, la
    /// sesión sigue viva, el usuario reintenta. La dispara `AccountDeletionService`. Sin PII.
    static func accountDeletionFailed(step: String) {
        track(.accountDeletionFailed, parameters: [
            "step": step
        ])
    }

    /// CANARIO B1 (5.1.1(v)): el canje del authorization_code de SIWA no dejó refresh token custodiado.
    /// `reason` = `no-code` | `no-jwt` | `exchange` | `keychain`. Best-effort (el sign-in NO falló). La
    /// disparan `SIWAExchangeSeam`/`SIWAExchangeCapture`. Sin PII (jamás el code/token).
    static func siwaExchangeFailed(reason: String) {
        track(.siwaExchangeFailed, parameters: [
            "reason": reason
        ])
    }

    /// CANARIO B1 (5.1.1(v)): el revoke del refresh token de Apple falló al borrar la cuenta. `reason` =
    /// `no-jwt` | `revoke`. El borrado NO se bloquea (contrato best-effort); el par queda para el retry.
    /// La dispara `SIWATokenRevocation`. Sin PII.
    static func siwaRevokeFailed(reason: String) {
        track(.siwaRevokeFailed, parameters: [
            "reason": reason
        ])
    }

    /// BREADCRUMB Modo Nube (freeze §h.1): el backend respondió 409 `yala_account_reverting` → la cuenta
    /// está en/tras una reversa a iCloud (backend congelado, ya no es fuente de verdad). El device deja
    /// de pushear (stop hasta relanzar). La dispara `SyncPushClient.push`. Privacy-first: sin IDs ni PII.
    static func cloudAccountReverting() {
        track(.cloudAccountReverting)
    }

    /// CANARIO Modo Nube (I8f-1, F-5): `HLCClock.receive` RECHAZÓ un HLC remoto (drift >5min en el
    /// futuro / counter overflow) al integrar deltas del pull. El reloj local conserva su `latest`
    /// (no se envenena) y el apply continúa; bajo skew extremo se pierde causalidad con ese emisor —
    /// residual documentado vigilado server-side. La dispara `CloudSyncEngine.receiveRemoteClock`.
    /// Privacy-first: solo el motivo del rechazo, sin IDs ni PII.
    static func cloudSyncClockReceiveRejected(reason: String) {
        track(.cloudSyncClockReceiveRejected, parameters: [
            "reason": reason
        ])
    }

    /// CANARIO Modo Nube (I8f-3, §d.7 Canal 1): el entityHash Merkle LOCAL de una tabla difiere del
    /// del backend CON quiescencia local (guard A-3: outbox vivo vacío + último pull `.completed`) →
    /// el apply/canon divergió de la verdad server-side (infidelidad del sync). Remediación v1 =
    /// re-pull completo de la tabla (wiring I9). La dispara `CloudSyncEngine.verifyIntegrity`.
    /// Privacy-first: solo el nombre de tabla (o "root"), jamás hashes ni datos.
    static func cloudSyncMerkleDivergence(entity: String) {
        track(.cloudSyncMerkleDivergence, parameters: [
            "entity": entity
        ])
    }

    /// CANARIO Grupos→backend (B1, §d.7 Canal 1): UNA señal por corrida de verificación — `groupCount`
    /// grupos cuyo árbol Merkle LOCAL difiere del backend CON quiescencia del grupo. Excluye el corpus-vacío-
    /// remoto (remoción de membership por RLS). Remediación v1 = reset del cursor de cada grupo divergente +
    /// re-pull, una vez por sesión. La dispara `GroupsSyncClient.runGroupMerkleVerification`. Privacy-first:
    /// SOLO el count de grupos, jamás group_ids ni hashes.
    static func groupMerkleDivergence(groupCount: Int) {
        track(.groupMerkleDivergence, parameters: [
            "groupCount": String(groupCount)
        ])
    }

    /// Reports a `transferPairID` shared by 3+ TXs (collision). NO auto-repair se aplica
    /// porque la heurística podría borrar data válida. Solo telemetry.
    static func cloudkitTransferCollisionDetected(count: Int) {
        track(.cloudkitTransferCollisionDetected, parameters: [
            "model": "TransactionItem",
            "count": String(count),
            "context": TransferReconcileContext.bootCollision.rawValue
        ])
    }
}
