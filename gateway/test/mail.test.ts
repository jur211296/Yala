/**
 * Correo del banco por reenvío (2.3). Lo que fija, por gravedad si se rompiera:
 *  - el cupo de prueba: 5 correos leídos sin Pro y ni uno más; un fallo del proveedor devuelve el uso;
 *  - una dirección que no es nuestra se rechaza sin leer nada, y el código de Gmail no gasta cupo ni pasa por la IA;
 *  - la cola es de la CUENTA: `ack` con el id de otra cuenta no borra nada;
 *  - la lectura sale con su propio tope de tokens y el texto recortado (hasta reconciliar con S1);
 *  - el correo no se guarda: en D1 solo queda el movimiento.
 *
 * Los correos de aquí son SINTÉTICOS, escritos con la forma de los avisos de bancos peruanos; no son avisos reales.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";
import { codeFromRecipient, CODE_ALPHABET, CODE_LENGTH, generateCode, mailConfig } from "../src/mail/address";
import { gmailConfirmationCode, isGmailForwardingConfirmation } from "../src/mail/gmail";
import { MAX_TEXT_CHARS, parseMail, textForModel } from "../src/mail/mime";
import { MAIL_READ_MAX_OUTPUT_TOKENS, parseReading, readBankEmail, type ReadOutcome } from "../src/mail/read";
import { processIncomingMail, MAX_RAW_BYTES, MAIL_USAGE_TASK, type IncomingMail } from "../src/mail/email";
import type { AIUsageRecord } from "../src/ai/usage";
import { getOrCreateAddress, TRIAL_LIMIT } from "../src/mail/store";
import { makeMailD1 } from "./mail.fakeD1";

const SUB = "11111111-2222-3333-4444-555555555555";
const OTHER = "99999999-8888-7777-6666-555555555555";
const CFG = mailConfig({});

function envWith(db: D1Database): Env {
  return { DB: db, ENFORCE: "observe", OPENAI_API_KEY: "sk-test" } as unknown as Env;
}

function rawMail(opts: { from: string; subject: string; html?: string; text?: string; messageId?: string }): string {
  const headers = [
    `From: ${opts.from}`,
    `To: yo@gmail.com`,
    `Subject: ${opts.subject}`,
    opts.messageId ? `Message-ID: <${opts.messageId}>` : "",
    "MIME-Version: 1.0",
  ].filter(Boolean);
  if (opts.html) {
    return [...headers, "Content-Type: text/html; charset=utf-8", "Content-Transfer-Encoding: quoted-printable", "", opts.html].join("\r\n");
  }
  return [...headers, "Content-Type: text/plain; charset=utf-8", "", opts.text ?? ""].join("\r\n");
}

function incoming(to: string, raw: string): IncomingMail & { rejected: string | null } {
  const bytes = new TextEncoder().encode(raw);
  const msg = {
    to,
    rawSize: bytes.byteLength,
    rejected: null as string | null,
    raw: async () => bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer,
    setReject(reason: string) {
      msg.rejected = reason;
    },
  };
  return msg;
}

const BCP_PURCHASE = rawMail({
  from: "BCP <notificaciones@notificacionesbcp.com.pe>",
  subject: "Realizaste un consumo con tu Tarjeta de Débito BCP",
  messageId: "bcp-1@example.test",
  html: "<html><body><table><tr><td>Monto</td><td>S/ 45.90</td></tr><tr><td>Empresa</td><td>TAMBO SAN ISIDRO</td></tr><tr><td>N=C3=BAmero de Tarjeta</td><td>****4321</td></tr></table></body></html>",
});

const reading = (over: Partial<Record<string, unknown>> = {}): ReadOutcome => ({
  ok: true,
  usage: { inputTokens: 300, outputTokens: 60, cachedInputTokens: 0, reasoningTokens: 20 },
  reading: {
    isTransaction: true,
    kind: "expense",
    amount: 45.9,
    currency: "PEN",
    merchant: "TAMBO SAN ISIDRO",
    date: "2026-11-04",
    bank: "BCP",
    accountLast4: "4321",
    ...over,
  },
});

afterEach(() => vi.restoreAllMocks());

describe("la dirección", () => {
  it("genera 10 caracteres del alfabeto sin ambiguos", () => {
    for (let i = 0; i < 50; i++) {
      const code = generateCode();
      expect(code).toHaveLength(CODE_LENGTH);
      for (const ch of code) expect(CODE_ALPHABET).toContain(ch);
    }
    expect(CODE_ALPHABET).not.toMatch(/[01ilo]/);
  });

  it("lee el código del destinatario del sobre, con mayúsculas y <>", () => {
    expect(codeFromRecipient("auto+abcdefghjk@yala-app.pe", CFG)).toBe("abcdefghjk");
    expect(codeFromRecipient("<AUTO+ABCDEFGHJK@Yala-App.pe>", CFG)).toBe("abcdefghjk");
  });

  it("rechaza lo que no es nuestro", () => {
    expect(codeFromRecipient("auto@yala-app.pe", CFG)).toBeNull();
    expect(codeFromRecipient("auto+abcdefghjk@otro.pe", CFG)).toBeNull();
    expect(codeFromRecipient("otro+abcdefghjk@yala-app.pe", CFG)).toBeNull();
    expect(codeFromRecipient("auto+abc@yala-app.pe", CFG)).toBeNull();
    expect(codeFromRecipient("auto+abcdefghj0@yala-app.pe", CFG)).toBeNull(); // 0 no está en el alfabeto
  });
});

describe("el código de Gmail", () => {
  it("sale del asunto en inglés y en español", () => {
    expect(gmailConfirmationCode({ subject: "(#123456789) Gmail Forwarding Confirmation - Receive Mail from yo@gmail.com", text: "" })).toBe("123456789");
    expect(gmailConfirmationCode({ subject: "(n.º 987654321) Confirmación de reenvío de Gmail - Recibir correo de yo@gmail.com", text: "" })).toBe("987654321");
  });

  it("y del cuerpo si el asunto no lo trae", () => {
    expect(gmailConfirmationCode({ subject: "Confirmación de reenvío", text: "Código de confirmación: 555666777" })).toBe("555666777");
  });

  it("solo cuenta el remitente de Google", () => {
    expect(isGmailForwardingConfirmation({ from: "forwarding-noreply@google.com" })).toBe(true);
    expect(isGmailForwardingConfirmation({ from: "forwarding-noreply@google.com.evil.pe" })).toBe(false);
  });
});

describe("el texto del correo", () => {
  it("convierte el HTML quoted-printable del banco en texto", async () => {
    const mail = await parseMail(BCP_PURCHASE);
    expect(mail.from).toBe("notificaciones@notificacionesbcp.com.pe");
    expect(mail.text).toContain("S/ 45.90");
    expect(mail.text).toContain("Número de Tarjeta");
    expect(mail.text).not.toContain("<td>");
  });

  it("recorta lo que va al modelo", async () => {
    const mail = await parseMail(rawMail({ from: "x@y.pe", subject: "largo", text: "a".repeat(20000) }));
    expect(textForModel(mail).length).toBe(MAX_TEXT_CHARS);
  });
});

describe("la lectura con IA", () => {
  it("sale con su tope propio, esquema estricto y el modelo de la fila", async () => {
    let sent: Record<string, unknown> = {};
    const fetchStub = vi.fn(async (_url: string, init: RequestInit) => {
      sent = JSON.parse(String(init.body)) as Record<string, unknown>;
      const content = JSON.stringify({ is_transaction: true, kind: "expense", amount: 45.9, currency: "pen", merchant: "TAMBO", date: "2026-11-04", bank: "BCP", account_last4: "4321" });
      return new Response(JSON.stringify({ model: "gpt-6-luna", choices: [{ message: { content } }], usage: { prompt_tokens: 10, completion_tokens: 5 } }), { status: 200 });
    });
    const out = await readBankEmail("Asunto: x", { keys: { openai: "sk" }, fetch: fetchStub }, "2026-11-04");
    expect(sent.max_completion_tokens).toBe(MAIL_READ_MAX_OUTPUT_TOKENS);
    expect((sent.response_format as { type: string }).type).toBe("json_schema");
    expect(sent.model).toBe("gpt-6-luna");
    expect(out.ok && out.reading.currency).toBe("PEN");
  });

  it("un 5xx es fallo del proveedor; un 400, no", async () => {
    const f = (status: number) => vi.fn(async () => new Response("{}", { status }));
    expect(await readBankEmail("x", { keys: { openai: "sk" }, fetch: f(503) }, "2026-11-04")).toMatchObject({ ok: false, providerFailed: true, status: 503 });
    expect(await readBankEmail("x", { keys: { openai: "sk" }, fetch: f(400) }, "2026-11-04")).toMatchObject({ ok: false, providerFailed: false, status: 400 });
  });

  it("valida lo que contesta el modelo", () => {
    const r = parseReading(JSON.stringify({ is_transaction: true, kind: "expense", amount: -3, currency: "soles", merchant: "  ", date: "4/11/2026", bank: "BCP", account_last4: "12345" }));
    expect(r).toEqual({ isTransaction: true, kind: "expense", amount: null, currency: null, merchant: null, date: null, bank: "BCP", accountLast4: null });
    expect(parseReading("no es json")).toBeNull();
    expect(parseReading(JSON.stringify({ kind: "expense" }))).toBeNull();
  });
});

describe("la entrada de Email Routing", () => {
  async function setup(pro = false) {
    const { db, sqlite } = makeMailD1();
    const env = envWith(db);
    const row = await getOrCreateAddress(env, SUB);
    if (pro) {
      sqlite.prepare("INSERT INTO account_entitlements VALUES (?, 'pro', ?, 'txn', 'jwt', 0, 0)").run(SUB, Date.now() + 86_400_000);
    }
    return { env, sqlite, to: `auto+${row.code}@yala-app.pe` };
  }

  it("rechaza una dirección que no existe sin leer nada", async () => {
    const { env } = await setup();
    const read = vi.fn();
    const msg = incoming("auto+zzzzzzzzzz@yala-app.pe", BCP_PURCHASE);
    expect(await processIncomingMail(msg, env, { read })).toBe("rejected_unknown");
    expect(msg.rejected).not.toBeNull();
    expect(read).not.toHaveBeenCalled();
  });

  it("deja el movimiento en la cola, sin guardar el correo", async () => {
    const { env, sqlite, to } = await setup();
    expect(await processIncomingMail(incoming(to, BCP_PURCHASE), env, { read: async () => reading() })).toBe("draft");
    const rows = sqlite.prepare("SELECT payload FROM mail_drafts WHERE user_id = ?").all(SUB) as { payload: string }[];
    expect(rows).toHaveLength(1);
    const payload = JSON.parse(rows[0].payload) as Record<string, unknown>;
    expect(payload).toEqual({ kind: "expense", amount: 45.9, currency: "PEN", merchant: "TAMBO SAN ISIDRO", date: "2026-11-04", bank: "BCP", account_last4: "4321" });
    expect(rows[0].payload).not.toContain("consumo con tu Tarjeta"); // ni el asunto
  });

  it("respeta el cupo de 5 correos leídos sin Pro", async () => {
    const { env, sqlite, to } = await setup();
    const read = vi.fn(async () => reading());
    for (let i = 0; i < TRIAL_LIMIT; i++) {
      const raw = BCP_PURCHASE.replace("bcp-1@example.test", `bcp-${i}@example.test`);
      expect(await processIncomingMail(incoming(to, raw), env, { read })).toBe("draft");
    }
    const sixth = BCP_PURCHASE.replace("bcp-1@example.test", "bcp-6@example.test");
    expect(await processIncomingMail(incoming(to, sixth), env, { read })).toBe("quota_exhausted");
    expect(read).toHaveBeenCalledTimes(TRIAL_LIMIT);
    const row = sqlite.prepare("SELECT trial_used, skipped_quota FROM mail_addresses WHERE user_id = ?").get(SUB) as Record<string, number>;
    expect(row).toEqual({ trial_used: 5, skipped_quota: 1 });
  });

  it("un correo que no es movimiento también gasta cupo", async () => {
    const { env, sqlite, to } = await setup();
    expect(await processIncomingMail(incoming(to, BCP_PURCHASE), env, { read: async () => reading({ isTransaction: false, amount: null, kind: null }) })).toBe("not_transaction");
    expect((sqlite.prepare("SELECT trial_used FROM mail_addresses").get() as { trial_used: number }).trial_used).toBe(1);
  });

  it("con Pro no hay cupo", async () => {
    const { env, sqlite, to } = await setup(true);
    for (let i = 0; i < TRIAL_LIMIT + 3; i++) {
      const raw = BCP_PURCHASE.replace("bcp-1@example.test", `p-${i}@example.test`);
      expect(await processIncomingMail(incoming(to, raw), env, { read: async () => reading() })).toBe("draft");
    }
    expect((sqlite.prepare("SELECT trial_used FROM mail_addresses").get() as { trial_used: number }).trial_used).toBe(0);
  });

  it("un fallo del proveedor devuelve el cupo y deja reintentar el mismo aviso", async () => {
    const { env, sqlite, to } = await setup();
    const failed: ReadOutcome = { ok: false, providerFailed: true, status: 503 };
    expect(await processIncomingMail(incoming(to, BCP_PURCHASE), env, { read: async () => failed })).toBe("provider_failed");
    expect((sqlite.prepare("SELECT trial_used FROM mail_addresses").get() as { trial_used: number }).trial_used).toBe(0);
    expect(await processIncomingMail(incoming(to, BCP_PURCHASE), env, { read: async () => reading() })).toBe("draft");
  });

  it("el mismo aviso dos veces se lee una", async () => {
    const { env, to } = await setup();
    const read = vi.fn(async () => reading());
    expect(await processIncomingMail(incoming(to, BCP_PURCHASE), env, { read })).toBe("draft");
    expect(await processIncomingMail(incoming(to, BCP_PURCHASE), env, { read })).toBe("duplicate");
    expect(read).toHaveBeenCalledTimes(1);
  });

  it("guarda el código de Gmail sin IA ni cupo", async () => {
    const { env, sqlite, to } = await setup();
    const read = vi.fn();
    const raw = rawMail({ from: "Gmail Team <forwarding-noreply@google.com>", subject: "(#123456789) Gmail Forwarding Confirmation - Receive Mail from yo@gmail.com", text: "Confirmation code: 123456789" });
    expect(await processIncomingMail(incoming(to, raw), env, { read })).toBe("gmail_code");
    expect(read).not.toHaveBeenCalled();
    const row = sqlite.prepare("SELECT gmail_code, trial_used FROM mail_addresses").get() as Record<string, unknown>;
    expect(row).toEqual({ gmail_code: "123456789", trial_used: 0 });
  });

  it("deja su fila en el registro de uso de S1, sin nada del correo", async () => {
    const { env, to } = await setup();
    const rows: AIUsageRecord[] = [];
    const sink = { record: (e: AIUsageRecord) => rows.push(e) };
    const withCall: ReadOutcome = {
      ...reading(),
      call: { status: 200, usage: { inputTokens: 300, outputTokens: 60, cachedInputTokens: 0, reasoningTokens: 20 }, model: "gpt-6-luna", finishReason: "stop", attempts: 1 },
    } as ReadOutcome;
    expect(await processIncomingMail(incoming(to, BCP_PURCHASE), env, { read: async () => withCall, usage: sink })).toBe("draft");
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ task: MAIL_USAGE_TASK, category: "mail", provider: "openai", model: "gpt-6-luna", status: 200, inputTokens: 300, outputTokens: 60 });
    expect(JSON.stringify(rows[0])).not.toMatch(/TAMBO|BCP|4321|45\.9/);
  });

  it("el código de Gmail no deja fila de uso (no pasa por la IA)", async () => {
    const { env, to } = await setup();
    const rows: AIUsageRecord[] = [];
    const raw = rawMail({ from: "forwarding-noreply@google.com", subject: "(#123456789) Gmail Forwarding Confirmation", text: "" });
    await processIncomingMail(incoming(to, raw), env, { read: vi.fn(), usage: { record: (e: AIUsageRecord) => rows.push(e) } });
    expect(rows).toHaveLength(0);
  });

  it("rechaza lo que pasa de 256 KB", async () => {
    const { env, to } = await setup();
    const msg = incoming(to, BCP_PURCHASE);
    msg.rawSize = MAX_RAW_BYTES + 1;
    expect(await processIncomingMail(msg, env, { read: vi.fn() })).toBe("rejected_size");
    expect(msg.rejected).not.toBeNull();
  });

  it("corta en 50 correos al día por dirección", async () => {
    const { env, sqlite, to } = await setup(true);
    const today = new Date().toISOString().slice(0, 10);
    sqlite.prepare("UPDATE mail_addresses SET day_key = ?, day_count = 50").run(today);
    expect(await processIncomingMail(incoming(to, BCP_PURCHASE), env, { read: vi.fn() })).toBe("daily_cap");
    sqlite.prepare("UPDATE mail_addresses SET day_key = '2000-01-01', day_count = 50").run();
    expect(await processIncomingMail(incoming(to, BCP_PURCHASE), env, { read: async () => reading() })).toBe("draft");
  });
});

describe("las rutas de la app", () => {
  async function appWith() {
    vi.resetModules();
    vi.doMock("../src/sync/userauth", async (importOriginal) => {
      const actual = await importOriginal<typeof import("../src/sync/userauth")>();
      return {
        ...actual,
        verifyUserToken: vi.fn(async (_env: Env, token: string) =>
          token === "jwt-a" ? { sub: SUB, token } : token === "jwt-b" ? { sub: OTHER, token } : null,
        ),
      };
    });
    const { default: app } = await import("../src/index");
    const { db, sqlite } = makeMailD1();
    const env = envWith(db);
    const call = (method: string, path: string, jwt: string, body?: unknown) =>
      app.request(path, { method, headers: { authorization: `Bearer ${jwt}`, "content-type": "application/json" }, body: body ? JSON.stringify(body) : undefined }, env);
    return { call, sqlite };
  }

  it("crea una sola dirección por cuenta y dice el cupo", async () => {
    const { call } = await appWith();
    const a = (await (await call("POST", "/mail/address", "jwt-a")).json()) as Record<string, unknown>;
    const b = (await (await call("POST", "/mail/address", "jwt-a")).json()) as Record<string, unknown>;
    expect(a.address).toMatch(/^auto\+[a-z2-9]{10}@yala-app\.pe$/);
    expect(b.address).toBe(a.address);
    expect(a).toMatchObject({ pro: false, trial_limit: 5, trial_used: 0, gmail_confirmation: null });
  });

  it("sin JWT, 401", async () => {
    const { call } = await appWith();
    expect((await call("POST", "/mail/address", "malo")).status).toBe(401);
  });

  it("ack con el id de otra cuenta no borra nada", async () => {
    const { call, sqlite } = await appWith();
    sqlite.prepare("INSERT INTO mail_drafts VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', ?, ?, '{\"amount\":1}')").run(SUB, Date.now());
    const other = (await (await call("POST", "/mail/drafts/ack", "jwt-b", { ids: ["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"] })).json()) as { deleted: number };
    expect(other.deleted).toBe(0);
    const list = (await (await call("GET", "/mail/drafts", "jwt-a")).json()) as { drafts: { id: string; amount: number }[] };
    expect(list.drafts).toEqual([expect.objectContaining({ id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", amount: 1 })]);
    const mine = (await (await call("POST", "/mail/drafts/ack", "jwt-a", { ids: ["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"] })).json()) as { deleted: number };
    expect(mine.deleted).toBe(1);
  });
});
