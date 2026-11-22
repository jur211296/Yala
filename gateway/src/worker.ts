/**
 * Punto de entrada del Worker (wrangler `main`). Reexporta la app de `index.ts` tal cual y añade la entrada interna de
 * Yala web, que solo se alcanza por un *service binding* desde otro Worker de la cuenta (no tiene ruta pública).
 *
 * Va en un fichero aparte porque `cloudflare:workers` no existe en Node: los tests importan `index.ts` y siguen igual.
 */
import { WorkerEntrypoint } from "cloudflare:workers";
import type { Env } from "./env";
import { readGroupsForWeb, type WebGroupsResult } from "./web/groupsReader";
import {
  addWebExpense,
  addWebSettlement,
  createWebInvite,
  type WebExpenseInput,
  type WebInviteResult,
  type WebSettlementInput,
  type WebWriteResult,
} from "./web/groupsWriter";

export { default } from "./index";
export { RateLimiter } from "./rate_limiter";
export { ConnectorDrafts } from "./connector/entrypoint";

/** Lectura de Grupos para Yala web (lote 3). Ver `src/web/groupsReader.ts`. */
export class WebGroupsReader extends WorkerEntrypoint<Env> {
  async snapshot(token: string, only?: string): Promise<WebGroupsResult> {
    return readGroupsForWeb(this.env, typeof token === "string" ? token : "", typeof only === "string" && only ? only : undefined);
  }
}

/**
 * Escritura de Grupos para Yala web (lote 3, opción A): tres operaciones cerradas. Ver `src/web/groupsWriter.ts`.
 * El aviso push a los demás miembros corre después de responder (`waitUntil`).
 */
export class WebGroupsWriter extends WorkerEntrypoint<Env> {
  private defer = (p: Promise<unknown>) => this.ctx.waitUntil(p);

  async addExpense(token: string, input: WebExpenseInput): Promise<WebWriteResult> {
    return addWebExpense(this.env, typeof token === "string" ? token : "", input, this.defer);
  }

  async addSettlement(token: string, input: WebSettlementInput): Promise<WebWriteResult> {
    return addWebSettlement(this.env, typeof token === "string" ? token : "", input, this.defer);
  }

  async createInvite(token: string, groupId: string): Promise<WebInviteResult> {
    return createWebInvite(this.env, typeof token === "string" ? token : "", typeof groupId === "string" ? groupId : "");
  }
}
