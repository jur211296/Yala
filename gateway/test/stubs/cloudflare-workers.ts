/**
 * `cloudflare:workers` solo existe dentro del runtime de Workers. El gateway lo importa para la clase RPC del conector
 * (`src/connector/entrypoint.ts`); en Node basta una clase vacía que guarde `env`. Lo usa solo `vitest.config.ts`
 * (alias). Copia del de `mcp/test/stubs/`.
 */
export class WorkerEntrypoint<Env = unknown> {
  constructor(
    readonly ctx: unknown,
    readonly env: Env,
  ) {}
}
