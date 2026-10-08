/**
 * Tipos de Node que usa el banco de voz y que no declara `test/node-shim.d.ts` (ese fichero es de otros y no
 * se toca). Las declaraciones de módulo ambiente se FUSIONAN con las de allí: aquí solo van nombres nuevos.
 */
declare module "node:fs" {
  export function readdirSync(path: string | URL): string[];
  export function rmdirSync(path: string | URL): void;
  export function rmSync(path: string | URL, options?: { recursive?: boolean; force?: boolean }): void;
}
declare module "node:child_process" {
  export function spawnSync(
    file: string,
    args: string[],
    options?: { input?: Uint8Array | string; maxBuffer?: number; encoding?: "utf8" | "buffer"; timeout?: number },
  ): { status: number | null; stdout: Uint8Array & { toString(encoding?: "utf8" | "base64"): string }; stderr: { toString(): string }; error?: Error };
}
