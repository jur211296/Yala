/**
 * Sync API (Modo Nube) — el CONTRATO del envelope push/pull.
 *
 * Esta es la SEMILLA del contrato multi-cliente (iOS v1, y luego web/Android): la forma del
 * delta, del batch y de los códigos de error. Se documenta en README ("Sync API (Modo Nube)").
 *
 * Piezas de diseño que gobiernan estos tipos (MODO-NUBE-ARQUITECTURA §d):
 * - **`fields` es un PATCH PARCIAL de dominio limpio** (§d.1): solo las columnas tocadas; ausencia
 *   de una key = "no la toqué" (NUNCA "ponla a NULL"); un `null` explícito SÍ escribe NULL.
 * - **`field_hlcs` es el HLC por UNIDAD DE COHERENCIA** (§d.4bis): una unidad es (a) una columna
 *   disjunta (field-level puro, unit-key = nombre de columna) o (b) un GRUPO de coherencia cuyas
 *   columnas ganan/pierden ATÓMICAS (money/split/budget/tx_split). La membresía la resuelve el
 *   Worker desde `capability_manifest.json` (SSOT); el cliente emite el grupo ENTERO (invariante de
 *   emisión) y su `field_hlcs[unit]`.
 * - **`entity_type` = el NOMBRE de la tabla Postgres** (key del manifest: `tx_items`, `budgets`, …),
 *   snake_case. Es lo que `apply_delta.p_entity` consume; evita una capa de mapeo camel↔snake.
 */

/** Los 3 tipos de operación de un delta (§d.1). `identity_remap` se difiere a I8 (no soportado aquí). */
export type SyncOp = "upsert" | "tombstone";

/**
 * Delta de wire (lo que el cliente sube). `fields` es PLANO `{col: val}`; el Worker lo re-agrupa por
 * unidad (`{unit: {col: val}}`) contra el manifest ANTES de llamar al RPC — el RPC nunca ve el
 * mapeo columna→unidad ni hardcodea grupos.
 */
export interface SyncDelta {
  entity_type: string; // nombre de tabla Postgres (key del manifest)
  sync_id: string; // UUIDv4 (identidad estable de la fila)
  op: SyncOp;
  /** PATCH parcial de dominio limpio (§d.1). Ausente en `tombstone`. */
  fields?: Record<string, unknown>;
  /** Mapa unit-key → HLC 46-char (§d.4bis). Para `tombstone` puede ir vacío (usa `hlc`/row_hlc). */
  field_hlcs?: Record<string, string>;
  /** HLC de FILA (= MAX(field_hlcs)) — árbitro de tombstone/delete-vs-upsert (row-level, §d.4bis). */
  hlc: string;
  /** Idempotencia del upload (§d.1); el Worker lo ecoa para correlación. La dedup DB real es NO-OP por HLC. */
  client_mutation_id?: string;
  /** Versión de protocolo del cliente; gate de escritura por-COLUMNA (§d.2). */
  schema_version?: number;
}

/** Resultado por-delta que el Worker devuelve al cliente. */
export interface SyncDeltaResult {
  sync_id: string;
  client_mutation_id?: string;
  status: "applied" | "noop" | "rejected";
  /** Motivo cuando `rejected`/`noop` (p.ej. "coherence_group_partial", "schema_version_too_old"). */
  reason?: string;
  /** Outcome crudo del RPC (telemetría): {applied_units, resurrected, inserted, noop, …}. */
  outcome?: unknown;
}

/** POST /sync/push — request. */
export interface SyncPushRequest {
  deltas: SyncDelta[];
}
/** POST /sync/push — response. */
export interface SyncPushResponse {
  results: SyncDeltaResult[];
}

/** GET /sync/pull — un delta bajado (proyectado al capability-set del cliente). */
export interface PulledDelta {
  entity_type: string;
  sync_id: string;
  op: SyncOp;
  fields: Record<string, unknown>;
  field_hlcs: Record<string, string>;
  hlc: string;
  server_seq: number;
  schema_version: number;
}
/** GET /sync/pull — response. */
export interface SyncPullResponse {
  deltas: PulledDelta[];
  max_server_seq: number;
}

/** POST /prefs/push — request (LWW por key, sin field_hlcs; §e.6). */
export interface PrefsPushRequest {
  prefs: { key: string; value: string | null; hlc: string }[];
}
export interface PrefsPushResponse {
  results: { key: string; status: "applied" | "noop"; reason?: string }[];
}
/** GET /prefs/pull — response. */
export interface PrefsPullResponse {
  prefs: { key: string; value: string | null; hlc: string; server_seq: number }[];
  max_server_seq: number;
}

/** POST /attest/bind — request (bind keyId↔user_id; user_id SIEMPRE del JWT, §e.5). */
export interface AttestBindRequest {
  key_id?: string; // preferentemente tomado del attest-session; el body es fallback (staging)
  attestation_type?: string; // "app_attest" (default) | "play_integrity" | "webauthn"
  public_key?: string; // opcional (bytea base64) — no requerido para el bind lógico
}

/**
 * Códigos de error del subsistema de sync. Reutilizan el envelope OpenAI-compatible del gateway
 * (`src/errors.ts`) para no fragmentar el contrato de errores del cliente.
 */
export type SyncErrorType =
  | "yala_sync_bad_request" // JSON/forma inválida
  | "yala_sync_unknown_entity" // entity_type fuera del manifest
  | "yala_sync_coherence_group_partial" // delta emitió un grupo de coherencia incompleto (§d.4bis, 422)
  | "yala_sync_schema_too_old" // gate min_writable_version por-columna (§d.2)
  | "yala_sync_upstream"; // PostgREST/Postgres devolvió error
