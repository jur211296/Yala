// Tipos mínimos de Node para tests y scripts (el Worker no los ve: tsconfig.json solo incluye src/).
declare const process: { argv: string[]; env: Record<string, string | undefined>; exit(code?: number): never; stdout: { write(s: string): void } };
declare module "node:fs" {
  export function readFileSync(path: string | URL, enc: "utf8"): string;
  export function writeFileSync(path: string | URL, data: string): void;
  export function existsSync(path: string | URL): boolean;
}
declare module "node:os" {
  export function homedir(): string;
}
declare module "node:sqlite" {
  export class DatabaseSync {
    constructor(path: string);
    exec(sql: string): void;
    prepare(sql: string): {
      run(...params: unknown[]): unknown;
      get(...params: unknown[]): Record<string, unknown> | undefined;
      all(...params: unknown[]): Record<string, unknown>[];
    };
  }
}
interface ImportMeta {
  url: string;
}
