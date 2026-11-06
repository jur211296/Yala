import { WorkerEntrypoint } from "cloudflare:workers";
import type { Env } from "../env";
import { enqueueConnectorDraft, type EnqueueOutcome } from "./store";

/**
 * La ÚNICA puerta del conector (`mcp/`) al gateway: una clase RPC que el conector alcanza por un service binding
 * (`[[services]] … entrypoint = "ConnectorDrafts"` en `mcp/wrangler.toml`). No es una ruta HTTP: desde internet no se
 * llega aquí. El conector pasa el `sub` de la sesión de Supabase que ya verificó en `/mcp`; el gateway no vuelve a
 * verificarlo porque no hay token que verificar —el binding es la credencial— y por eso no hay nada más expuesto que
 * encolar en la Bandeja.
 */
export class ConnectorDrafts extends WorkerEntrypoint<Env> {
  async enqueue(userId: string, payload: unknown): Promise<EnqueueOutcome> {
    return enqueueConnectorDraft(this.env, userId, payload);
  }
}
