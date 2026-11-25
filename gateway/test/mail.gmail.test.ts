/**
 * La confirmación de Gmail (2026-11-24). Lo que fija, por gravedad si se rompiera:
 *  - un correo de Gmail SIN código pero con enlace guarda el enlace y la app lo recibe (el bug: se guardaba nada y la
 *    guía buscaba para siempre);
 *  - la forma de `gmail_confirmation` no cambia (solo con código): la build 8 decodifica `code` como obligatorio;
 *  - solo se guarda un enlace `https` de Gmail: un enlace de otro host del correo nunca llega a la app;
 *  - el log de diagnóstico no lleva el código, la dirección ni el enlace.
 *
 * Los correos son SINTÉTICOS, con la forma medida en Email Routing ese día (asunto «(Gmail Forwarding Confirmation -
 * Receive Mail from …»); el cuerpo real no se guardó nunca.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";
import { formatAddress, mailConfig } from "../src/mail/address";
import { processIncomingMail, type IncomingMail } from "../src/mail/email";
import {
  gmailConfirmationCode,
  gmailConfirmationLink,
  gmailTemplateShape,
  isConfirmationLink,
} from "../src/mail/gmail";
import { addressBody } from "../src/mail/routes";
import { getAddressByUser, getOrCreateAddress, GMAIL_CODE_TTL_MS } from "../src/mail/store";
import { makeMailD1 } from "./mail.fakeD1";

const SUB = "11111111-2222-3333-4444-555555555555";
const LINK = "https://mail-settings.google.com/mail/vf-%5BANGjdJ8abc%5D-Xyz_123";
const SUBJECT_2026 = "(Gmail Forwarding Confirmation - Receive Mail from yo@gmail.com";

function envWith(db: D1Database): Env {
  return { DB: db, ENFORCE: "observe", OPENAI_API_KEY: "sk-test" } as unknown as Env;
}

function rawMail(opts: { subject: string; text?: string; html?: string }): string {
  const headers = ["From: Gmail Team <forwarding-noreply@google.com>", "To: yo@gmail.com", `Subject: ${opts.subject}`, "MIME-Version: 1.0"];
  if (opts.html) return [...headers, "Content-Type: text/html; charset=utf-8", "", opts.html].join("\r\n");
  return [...headers, "Content-Type: text/plain; charset=utf-8", "", opts.text ?? ""].join("\r\n");
}

function incoming(to: string, raw: string): IncomingMail {
  const bytes = new TextEncoder().encode(raw);
  return {
    to,
    rawSize: bytes.byteLength,
    raw: async () => bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer,
    setReject: () => {},
  };
}

async function setup() {
  const { db, sqlite } = makeMailD1();
  const env = envWith(db);
  const row = await getOrCreateAddress(env, SUB);
  return { env, sqlite, to: formatAddress(row.code, mailConfig({})) };
}

afterEach(() => vi.restoreAllMocks());

describe("el código de Gmail, en sus formas", () => {
  it("en el asunto, con o sin rótulo", () => {
    expect(gmailConfirmationCode({ subject: "(#123456789) Gmail Forwarding Confirmation", text: "" })).toBe("123456789");
    expect(gmailConfirmationCode({ subject: "(Nr. 123456789) Gmail-Weiterleitungsbestätigung", text: "" })).toBe("123456789");
  });

  it("en el cuerpo, con rótulo en varios idiomas", () => {
    expect(gmailConfirmationCode({ subject: SUBJECT_2026, text: "Confirmation code: 482913765" })).toBe("482913765");
    expect(gmailConfirmationCode({ subject: SUBJECT_2026, text: "Código de confirmação: 482913765" })).toBe("482913765");
    expect(gmailConfirmationCode({ subject: SUBJECT_2026, text: "Bestätigungscode: 482913765" })).toBe("482913765");
  });

  it("sin rótulo: el único número suelto de 9 cifras; si hay dos distintos, nada", () => {
    expect(gmailConfirmationCode({ subject: SUBJECT_2026, text: "Para confirmar escribe 482913765 en Gmail." })).toBe("482913765");
    expect(gmailConfirmationCode({ subject: SUBJECT_2026, text: "482913765 o 111222333" })).toBeNull();
  });

  it("no confunde las cifras del enlace con un código", () => {
    expect(gmailConfirmationCode({ subject: SUBJECT_2026, text: `Abre ${LINK}123456789 para confirmar.` })).toBeNull();
  });

  it("la plantilla medida el 24-nov (asunto sin número, cuerpo sin código) no da código", () => {
    expect(gmailConfirmationCode({ subject: SUBJECT_2026, text: `To allow yo@gmail.com to forward mail, click: ${LINK}` })).toBeNull();
  });
});

describe("el enlace de confirmación", () => {
  it("lo saca del texto y del href del HTML", () => {
    expect(gmailConfirmationLink({ text: `click the link: ${LINK}.` })).toBe(LINK);
    expect(gmailConfirmationLink({ text: "Haz clic aquí", html: `<a href="${LINK.replace("&", "&amp;")}">aquí</a>` })).toBe(LINK);
  });

  it("solo https y solo los hosts de Gmail", () => {
    expect(isConfirmationLink(LINK)).toBe(true);
    expect(isConfirmationLink(LINK.replace("https:", "http:"))).toBe(false);
    expect(isConfirmationLink("https://mail-settings.google.com.evil.pe/mail/vf-abc")).toBe(false);
    expect(isConfirmationLink("https://evil.pe/mail/vf-abc")).toBe(false);
    expect(isConfirmationLink("https://user@mail-settings.google.com/mail/vf-abc")).toBe(false);
    expect(isConfirmationLink("https://mail.google.com/mail/u/0/#settings/fwdandpop")).toBe(false);
  });

  it("con varios enlaces, elige el de confirmación y no el de ayuda", () => {
    const text = `Help: https://support.google.com/mail/answer/10957 — confirm: ${LINK} — settings: https://mail.google.com/mail/u/0/#settings`;
    expect(gmailConfirmationLink({ text })).toBe(LINK);
  });
});

describe("la entrada guarda lo que trae el correo", () => {
  it("solo enlace: lo guarda y la app lo recibe en `gmail_link`, sin tocar `gmail_confirmation`", async () => {
    const { env, to } = await setup();
    const read = vi.fn();
    const raw = rawMail({ subject: SUBJECT_2026, text: `To allow yo@gmail.com to automatically forward mail, click the link below:\n${LINK}` });
    expect(await processIncomingMail(incoming(to, raw), env, { read })).toBe("gmail_code");
    expect(read).not.toHaveBeenCalled();
    const row = await getAddressByUser(env, SUB);
    expect(row).toMatchObject({ gmail_code: null, gmail_link: LINK, trial_used: 0 });
    const body = addressBody(row!, env, false, row!.gmail_code_at! + 1000);
    expect(body.gmail_confirmation).toBeNull();
    expect(body.gmail_link).toEqual({ url: LINK, received_at_ms: row!.gmail_code_at });
  });

  it("código y enlace: los dos, y `gmail_confirmation` con la forma de siempre", async () => {
    const { env, to } = await setup();
    const raw = rawMail({ subject: "(#482913765) Gmail Forwarding Confirmation", text: `Confirmation code: 482913765\n${LINK}` });
    await processIncomingMail(incoming(to, raw), env, { read: vi.fn() });
    const row = await getAddressByUser(env, SUB);
    const body = addressBody(row!, env, false, row!.gmail_code_at! + 1000);
    expect(body.gmail_confirmation).toEqual({ code: "482913765", received_at_ms: row!.gmail_code_at });
    expect(body.gmail_link).toEqual({ url: LINK, received_at_ms: row!.gmail_code_at });
  });

  it("un correo nuevo reemplaza al anterior: el código viejo no se queda con el enlace nuevo", async () => {
    const { env, to } = await setup();
    await processIncomingMail(incoming(to, rawMail({ subject: "(#111222333) Gmail Forwarding Confirmation", text: "" })), env, { read: vi.fn(), now: () => 1_000 });
    await processIncomingMail(incoming(to, rawMail({ subject: SUBJECT_2026, text: LINK })), env, { read: vi.fn(), now: () => 2_000 });
    expect(await getAddressByUser(env, SUB)).toMatchObject({ gmail_code: null, gmail_link: LINK, gmail_code_at: 2_000 });
  });

  it("sin nada útil no borra lo que había", async () => {
    const { env, to } = await setup();
    await processIncomingMail(incoming(to, rawMail({ subject: SUBJECT_2026, text: LINK })), env, { read: vi.fn(), now: () => 1_000 });
    await processIncomingMail(incoming(to, rawMail({ subject: SUBJECT_2026, text: "Nada que ver aquí." })), env, { read: vi.fn(), now: () => 2_000 });
    expect(await getAddressByUser(env, SUB)).toMatchObject({ gmail_link: LINK, gmail_code_at: 1_000 });
  });

  it("un enlace de otro host no se guarda", async () => {
    const { env, to } = await setup();
    await processIncomingMail(incoming(to, rawMail({ subject: SUBJECT_2026, text: "Confirma en https://evil.pe/mail/vf-abc" })), env, { read: vi.fn() });
    expect(await getAddressByUser(env, SUB)).toMatchObject({ gmail_link: null, gmail_code: null });
  });

  it("pasadas 24 h, ni código ni enlace", async () => {
    const { env, to } = await setup();
    await processIncomingMail(incoming(to, rawMail({ subject: "(#482913765) x", text: LINK })), env, { read: vi.fn(), now: () => 1_000 });
    const row = await getAddressByUser(env, SUB);
    const body = addressBody(row!, env, false, 1_000 + GMAIL_CODE_TTL_MS + 1);
    expect(body.gmail_confirmation).toBeNull();
    expect(body.gmail_link).toBeNull();
  });
});

describe("el log de diagnóstico", () => {
  it("dice qué encontró y, sin código, la forma del correo sin datos", async () => {
    const { env, to } = await setup();
    const logs: string[] = [];
    vi.spyOn(console, "log").mockImplementation((s: string) => void logs.push(s));
    const raw = rawMail({ subject: SUBJECT_2026, text: `yo@gmail.com pidió reenviar a ${to}. Abre ${LINK} (válido 30 días). Ref 482913765.` });
    await processIncomingMail(incoming(to, raw), env, { read: vi.fn() });
    const line = logs.find((l) => l.startsWith("[mail] gmail")) ?? "";
    expect(line).toContain("found=both");
  });

  it("la forma no lleva el código, los correos ni el enlace", () => {
    const shape = gmailTemplateShape({ subject: SUBJECT_2026, text: `yo@gmail.com pidió reenviar a auto+abc@yalainbox.com. Abre ${LINK} (482913765).` });
    expect(shape).not.toMatch(/482913765|yo@gmail\.com|auto\+abc|vf-/);
    expect(shape).toContain("<mail-settings.google.com/…>");
    expect(shape).toContain("#9");
  });
});
