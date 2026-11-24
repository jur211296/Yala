import { WorkerEntrypoint } from "cloudflare:workers";
import type { Env } from "../env";
import { enqueueConnectorDraft, listQueuedForConnector, type EnqueueOutcome, type QueuedDraftView } from "./store";

/**
 * La ÚNICA puerta del conector (`mcp/`) al gateway: una clase RPC que el conector alcanza por un service binding
 * (`[[services]] … entrypoint = "ConnectorDrafts"` en `mcp/wrangler.toml`). No es una ruta HTTP: desde internet no se
 * llega aquí. El conector pasa el `sub` de la sesión de Supabase que ya verificó en `/mcp`; el gateway no vuelve a
 * verificarlo porque no hay token que verificar —el binding es la credencial— y por eso no hay nada más expuesto que
 * encolar en la Bandeja y leer lo que la cola tiene de esa cuenta.
 */
export class ConnectorDrafts extends WorkerEntrypoint<Env> {
  /** `options` (referencia, forzar, candidatos) desde el 2026-11-24; sin él, como antes. */
  async enqueue(userId: string, payload: unknown, options?: unknown): Promise<EnqueueOutcome> {
    return enqueueConnectorDraft(this.env, userId, payload, Date.now(), options);
  }

  /** Lo que espera en la cola a que la app lo recoja (`ver_bandeja`). `null` si el `userId` no es válido. */
  async pending(userId: string): Promise<QueuedDraftView[] | null> {
    return listQueuedForConnector(this.env, userId);
  }
}
