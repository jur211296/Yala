import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { TASK_SCHEMAS } from "../../src/ai/routes";
import { photoReadBody } from "../lib/appRequests";
import { gradePhoto, type PhotoCase } from "../lib/grading";
import type { BenchTask } from "./types";

const BENCH = new URL("../", import.meta.url);
const CASES = new URL("cases/", BENCH);
const CACHE = new URL(".cache/", BENCH);

/**
 * La foto como la manda la app: JPEG calidad 0.8. `edge` = lado mayor en px (0 = resolución original).
 * Con `sips` de macOS, el mismo motor de imagen que el iPhone.
 */
export function jpegBase64(file: string, edge: number): string {
  mkdirSync(CACHE, { recursive: true });
  const src = new URL(`photo/${file}`, CASES).pathname;
  const out = new URL(`${file.split("/").pop()!.replace(/\.[^.]+$/, "")}-${edge}.jpg`, CACHE).pathname;
  if (!existsSync(out)) {
    // Nunca se amplía: si la imagen ya cabe en `edge`, se manda a su tamaño (como haría la app).
    const dims = String(execFileSync("sips", ["-g", "pixelWidth", "-g", "pixelHeight", src])).match(/\d+/g)?.slice(-2).map(Number) ?? [0, 0];
    const args = edge > 0 && Math.max(...dims) > edge ? ["-Z", String(edge)] : [];
    execFileSync("sips", [...args, "-s", "format", "jpeg", "-s", "formatOptions", "80", src, "--out", out], { stdio: "ignore" });
  }
  return readFileSync(out).toString("base64");
}

export const photoTask: BenchTask<PhotoCase> = {
  name: "photo.read",
  image: true,
  baseParams: { responseFormat: "json_object", jsonSchema: TASK_SCHEMAS["photo.read"] },
  body: (c, v) => photoReadBody(jpegBase64(c.file, v.edge ?? 0), c.today, c.currencyContext),
  grade: (content, c) => gradePhoto(content, c),
};
