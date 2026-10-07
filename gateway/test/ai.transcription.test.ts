/**
 * Transcripción gestionada (sesión 2): el gateway rehace el multipart de la app para el modelo de la fila.
 * `gpt-transcribe` quiere `languages[]` (y rechaza la petición entera si llega también `language`) y los términos del
 * usuario como `keywords[]`, uno por campo (developers.openai.com/api/docs/guides/speech-to-text, 2026-10-07).
 */
import { describe, expect, it, vi } from "vitest";
import { buildTranscriptionForm, keywordsFrom, languageFrom, sanitizeKeyword, sendTranscription } from "../src/ai/providers/transcription";
import type { TranscriptionRoute } from "../src/ai/routes";

const BOUNDARY = "----yala-unit-tr";
function appMultipart(fields: Record<string, string>): Uint8Array {
  const enc = new TextEncoder();
  let head = `--${BOUNDARY}\r\nContent-Disposition: form-data; name="file"; filename="audio.m4a"\r\nContent-Type: audio/m4a\r\n\r\n`;
  const parts: Uint8Array[] = [enc.encode(head), new Uint8Array([0, 1, 2, 255, 13, 10])];
  let tail = "";
  for (const [k, v] of Object.entries(fields)) tail += `\r\n--${BOUNDARY}\r\nContent-Disposition: form-data; name="${k}"\r\n\r\n${v}`;
  tail += `\r\n--${BOUNDARY}--\r\n`;
  parts.push(enc.encode(tail));
  const all = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let o = 0;
  for (const p of parts) {
    all.set(p, o);
    o += p.length;
  }
  head = "";
  return all;
}
const CT = `multipart/form-data; boundary=${BOUNDARY}`;

const GPT: TranscriptionRoute = { mode: "transcription", provider: "openai", model: "gpt-transcribe", params: { languageField: "languages", maxKeywords: 30 } };
const WHISPER: TranscriptionRoute = { mode: "transcription", provider: "openai", model: "whisper-1", params: { languageField: "language", maxKeywords: 0 } };

describe("multipart hacia el proveedor", () => {
  it("gpt-transcribe: modelo de la fila, languages[] (sin language) y keywords[] desde el prompt de la app", async () => {
    const form = await buildTranscriptionForm(appMultipart({ model: "whisper-1", language: "es", prompt: "Plaza Vea\nRappi\nTaxi" }), CT, GPT);
    expect(form).not.toBeNull();
    expect(form!.get("model")).toBe("gpt-transcribe");
    expect(form!.getAll("languages[]")).toEqual(["es"]);
    expect(form!.get("language")).toBeNull();
    expect(form!.getAll("keywords[]")).toEqual(["Plaza Vea", "Rappi", "Taxi"]);
    expect(form!.get("prompt")).toBeNull();
    const file = form!.get("file") as unknown as File;
    expect(new Uint8Array(await file.arrayBuffer())).toEqual(new Uint8Array([0, 1, 2, 255, 13, 10]));
  });

  it("whisper-1: language singular y ningún keyword", async () => {
    const form = await buildTranscriptionForm(appMultipart({ model: "whisper-1", language: "ja", prompt: "Lawson" }), CT, WHISPER);
    expect(form!.get("language")).toBe("ja");
    expect(form!.getAll("languages[]")).toEqual([]);
    expect(form!.getAll("keywords[]")).toEqual([]);
  });

  it("una versión instalada (sin prompt) sale sin keywords", async () => {
    const form = await buildTranscriptionForm(appMultipart({ model: "whisper-1", language: "pt" }), CT, GPT);
    expect(form!.getAll("keywords[]")).toEqual([]);
    expect(form!.getAll("languages[]")).toEqual(["pt"]);
  });

  it("un multipart roto devuelve null (400), sin llamar a nadie", async () => {
    const doFetch = vi.fn();
    const res = await sendTranscription(new TextEncoder().encode("no es multipart"), CT, GPT, "sk-x", doFetch as unknown as typeof fetch);
    expect(res.status).toBe(400);
    expect(doFetch).not.toHaveBeenCalled();
  });
});

describe("saneado de lo que manda la app", () => {
  it("keywords: sin <, > ni saltos, sin repetir (mayúsculas aparte), con tope", () => {
    expect(sanitizeKeyword("  <Wong>  ")).toBe("Wong");
    expect(sanitizeKeyword("a")).toBeNull();
    expect(keywordsFrom("Wong\nwong\nTottus, Metro\n\n", 10)).toEqual(["Wong", "Tottus", "Metro"]);
    expect(keywordsFrom(Array.from({ length: 50 }, (_, i) => `Comercio ${i}`).join("\n"), 30)).toHaveLength(30);
  });

  it("idioma: ISO 639-1 o zh regional; lo demás no se manda", () => {
    expect(languageFrom("es")).toBe("es");
    expect(languageFrom("ZH")).toBe("zh");
    expect(languageFrom("zh-TW")).toBe("zh-tw");
    expect(languageFrom("español")).toBeNull();
    expect(languageFrom(null)).toBeNull();
  });
});
