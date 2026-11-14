/**
 * Punto de entrada del Worker (wrangler `main`). Reexporta la app de `index.ts` tal cual y añade la entrada interna de
 * Yala web, que solo se alcanza por un *service binding* desde otro Worker de la cuenta (no tiene ruta pública).
 *
 * Va en un fichero aparte porque `cloudflare:workers` no existe en Node: los tests importan `index.ts` y siguen igual.
 */
import { WorkerEntrypoint } from "cloudflare:workers";
import type { Env } from "./env";
import { readGroupsForWeb, type WebGroupsResult } from "./web/groupsReader";

export { default } from "./index";
export { RateLimiter } from "./rate_limiter";

/** Lectura de Grupos para Yala web (lote 3). Ver `src/web/groupsReader.ts`. */
export class WebGroupsReader extends WorkerEntrypoint<Env> {
  async snapshot(token: string, only?: string): Promise<WebGroupsResult> {
    return readGroupsForWeb(this.env, typeof token === "string" ? token : "", typeof only === "string" && only ? only : undefined);
  }
}
