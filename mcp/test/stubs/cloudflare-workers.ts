/**
 * `cloudflare:workers` solo existe dentro del runtime de Workers. La librería OAuth lo importa para reconocer
 * handlers que sean clases `WorkerEntrypoint`; este Worker usa objetos con `fetch`, así que en Node basta una clase
 * vacía. Lo usa solo `vitest.config.ts` (alias). Lo que depende del runtime de verdad lo cubre el e2e.
 */
export class WorkerEntrypoint<Env = unknown> {
  constructor(
    readonly ctx: unknown,
    readonly env: Env,
  ) {}
}
