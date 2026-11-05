/**
 * Tipos mínimos de Node para los tests y el banco, que leen ficheros del repo (wrangler.toml, fuentes
 * Swift, casos) y lanzan `sips`. El tsconfig carga solo `@cloudflare/workers-types` —el código del
 * Worker no debe ver APIs de Node—, así que `node:fs` e `import.meta.url` no tenían tipos y
 * `npm run typecheck` salía rojo en `2.1` (medido el 2026-10-07). Vitest y vite-node corren en Node.
 */
declare module "node:fs" {
  export function readFileSync(path: string | URL, encoding: "utf8"): string;
  export function readFileSync(path: string | URL): { toString(encoding: "base64"): string };
  export function writeFileSync(path: string | URL, data: string): void;
  export function appendFileSync(path: string | URL, data: string): void;
  export function mkdirSync(path: string | URL, options?: { recursive?: boolean }): void;
  export function existsSync(path: string | URL): boolean;
}
declare module "node:url" {
  export function fileURLToPath(url: string | URL): string;
}
// SQLite de Node (22.13+ sin flag): el D1 de verdad en memoria de `mail.fakeD1.ts`.
declare module "node:sqlite" {
  interface StatementSync {
    get(...params: unknown[]): unknown;
    all(...params: unknown[]): unknown[];
    run(...params: unknown[]): { changes: number | bigint; lastInsertRowid: number | bigint };
  }
  export class DatabaseSync {
    constructor(path: string);
    exec(sql: string): void;
    prepare(sql: string): StatementSync;
  }
}
declare module "node:os" {
  export function homedir(): string;
}
declare module "node:child_process" {
  export function execFileSync(file: string, args: string[], options?: { stdio?: "ignore" | "inherit"; input?: string }): unknown;
}
declare module "node:crypto" {
  interface Hash {
    update(data: string): Hash;
    digest(encoding: "hex"): string;
  }
  export function createHash(algorithm: "sha1" | "sha256"): Hash;
}
declare const process: { argv: string[]; env: Record<string, string | undefined>; exit(code?: number): never };
declare const Buffer: { from(data: unknown): { toString(encoding: "base64"): string } };

interface ImportMeta {
  readonly url: string;
}
