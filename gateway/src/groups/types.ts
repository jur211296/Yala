/**
 * Sync API de GRUPOS (G2) — el CONTRATO del envelope push/pull/merkle del canal Grupos->backend.
 *
 * Reusa la forma del delta personal (`sync/types.ts`) + `group_id`: el canal de grupos es una CLASE
 * NUEVA que convive con el personal sin tocarlo. El eje de secuencia es POR GRUPO, la PK es
 * (group_id, sync_id) / (group_id, member_key), la RLS es por MEMBERSHIP.
 */
import type { SyncDelta, SyncDeltaResult, PulledDelta } from "../sync/types";

/**
 * Delta de wire de grupos (lo que el cliente sube). = `SyncDelta` + `group_id`. Para `split_groups`
 * el `sync_id` es null (el group_id es la identidad; el gateway manda p_sync_id=null al RPC).
 */
export interface GroupSyncDelta extends Omit<SyncDelta, "sync_id"> {
  group_id: string;
  sync_id?: string | null;
}

/** POST /groups/push — request. */
export interface GroupPushRequest {
  deltas: GroupSyncDelta[];
}
/** POST /groups/push — response (mismo shape por-delta que el personal). */
export interface GroupPushResponse {
  results: SyncDeltaResult[];
}

/** GET /groups/pull — un delta bajado del canal de grupos. = `PulledDelta` + `group_id`. */
export interface PulledGroupDelta extends PulledDelta {
  group_id: string;
}
/** GET /groups/pull — response. `cursors`/`memberships` son POR GRUPO. */
export interface GroupPullResponse {
  deltas: PulledGroupDelta[];
  /** {group_id: max_server_seq_visto} — el cliente lo persiste y lo reenvía como `cursors`. */
  cursors: Record<string, number>;
  /** group_ids de los que el caller es member (active/pendingApproval) — descubre grupos nuevos Y perdidos. */
  memberships: string[];
}

/** GET /groups/merkle?group_id=<gid> — response (dos canales, acotado a UN grupo). */
export interface GroupMerkleResponse {
  canon_version: string;
  group_id: string;
  root: string;
  entities: Record<string, { count: number; hash: string }>;
  channel2_root: string;
}
