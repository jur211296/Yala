import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { readRepoFile } from "./swift";

/**
 * La nota final que la app arma con `merchant` y `note` de la foto: compila el `VisionNoteCleaner.swift` REAL de la
 * app con `swiftc` (una vez por versión del fichero, cacheado en `bench/.cache/`) y le pasa los pares. Así el banco
 * mide la limpieza que corre en el iPhone, sin réplica en TypeScript que pueda divergir.
 *
 * Contrato con el Swift: `VisionNoteCleaner.note(merchant:note:)`. Si cambia esa firma, cambia `MAIN`.
 */
const SOURCE = "Yala/App/Logic/VisionNoteCleaner.swift";
const CACHE = new URL("../.cache/", import.meta.url);

const MAIN = `
import Foundation
let input = FileHandle.standardInput.readDataToEndOfFile()
let pairs = (try JSONSerialization.jsonObject(with: input)) as? [[Any]] ?? []
let notes = pairs.map { pair -> String in
    VisionNoteCleaner.note(merchant: pair.first as? String, note: pair.count > 1 ? pair[1] as? String : nil)
}
let out = try JSONSerialization.data(withJSONObject: notes)
FileHandle.standardOutput.write(out)
`;

let binary: string | null = null;

function build(): string {
  if (binary) return binary;
  const src = readRepoFile(SOURCE);
  const hash = createHash("sha1").update(src).update(MAIN).digest("hex").slice(0, 12);
  mkdirSync(CACHE, { recursive: true });
  const bin = new URL(`note-cleaner-${hash}`, CACHE).pathname;
  if (!existsSync(bin)) {
    // Código de nivel superior: swiftc solo lo admite en un fichero que se llame `main.swift`.
    const dir = new URL(`note-cleaner-src-${hash}/`, CACHE);
    mkdirSync(dir, { recursive: true });
    const main = new URL("main.swift", dir).pathname;
    const lib = new URL("VisionNoteCleaner.swift", dir).pathname;
    writeFileSync(main, MAIN);
    writeFileSync(lib, src);
    execFileSync("swiftc", ["-O", lib, main, "-o", bin], { stdio: "inherit" });
  }
  binary = bin;
  return bin;
}

/** Las notas finales de la app para cada par `[merchant, note]`. */
export function cleanNotes(pairs: [string | null, string | null][]): string[] {
  if (pairs.length === 0) return [];
  const out = execFileSync(build(), [], { input: JSON.stringify(pairs) });
  return JSON.parse(String(out)) as string[];
}

/** La nota de antes de la limpieza: `VisionDraftFactory.buildNote` hasta el 2026-10-10 (comercio + " - " + nota). */
export function rawNote(merchant: string | null, note: string | null): string {
  return [merchant, note].filter((p): p is string => !!p).join(" - ");
}
