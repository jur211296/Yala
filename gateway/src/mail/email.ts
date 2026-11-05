import type { Env } from "../env";
import { getAccountEntitlement, isAccountProActive } from "../db";
import { recordUsage, usageRecord, usageSink, type AIUsageSink } from "../ai/usage";
import { codeFromRecipient, mailConfig } from "./address";
import { gmailConfirmationCode, isGmailForwardingConfirmation } from "./gmail";
import { parseMail, textForModel, type ParsedMail } from "./mime";
import { isUsableReading, MAIL_READ_ROUTE, readBankEmail, type ReadOutcome } from "./read";
import {
  countReceived,
  countSkipped,
  forgetSeen,
  getAddressByCode,
  insertDraft,
  markSeen,
  refundTrial,
  reserveTrial,
  saveGmailCode,
} from "./store";

/**
 * Entrada de Email Routing: `auto+<code>@yala-app.pe` → este Worker (el `email` del export de `index.ts`).
 *
 * El orden importa, y cada paso corta antes de gastar en el siguiente:
 *   1. ¿Es nuestra la dirección? Si no, se rechaza (rebota a quien la mandó).
 *   2. Tamaño: un aviso de banco pesa unos KB; más de 256 KB se rechaza sin leerlo.
 *   3. Techo diario por dirección (50).
 *   4. El código de Gmail: se guarda y termina. No pasa por la IA ni gasta cupo.
 *   5. El mismo aviso dos veces (Message-ID) se lee una vez.
 *   6. Pro por CUENTA, o el cupo de prueba (5 correos leídos). Sin ninguno, no se lee: se cuenta para avisar en la app.
 *   7. La IA lee el aviso. Un fallo del proveedor devuelve el cupo y olvida el «visto» para que un reenvío lo reintente.
 *   8. Si es un movimiento con importe, queda en la cola de la cuenta hasta que la app lo recoja.
 *
 * Nunca se loguea ni se guarda el correo: los logs llevan el desenlace y, como mucho, los tokens.
 */
export const MAX_RAW_BYTES = 256 * 1024;

export type MailOutcome =
  | "rejected_unknown"
  | "rejected_size"
  | "daily_cap"
  | "gmail_code"
  | "duplicate"
  | "quota_exhausted"
  | "provider_failed"
  | "unreadable"
  | "not_transaction"
  | "draft";

export interface IncomingMail {
  to: string;
  rawSize: number;
  raw(): Promise<ArrayBuffer>;
  setReject(reason: string): void;
}

export interface MailDeps {
  read?: (text: string, env: Env, today: string) => Promise<ReadOutcome>;
  now?: () => number;
  /** Registro de uso de S1 (`ai/usage.ts`); por defecto el de `env`. */
  usage?: AIUsageSink;
}

/** Tarea y cubo con que la lectura del correo aparece en `yala_ai_usage`. */
export const MAIL_USAGE_TASK = "mail.read";
export const MAIL_USAGE_CATEGORY = "mail";

const defaultRead = (text: string, env: Env, today: string) => readBankEmail(text, { keys: { openai: env.OPENAI_API_KEY } }, today);

export async function processIncomingMail(msg: IncomingMail, env: Env, deps: MailDeps = {}): Promise<MailOutcome> {
  const now = deps.now?.() ?? Date.now();
  const read = deps.read ?? defaultRead;

  const code = codeFromRecipient(msg.to, mailConfig(env));
  const address = code ? await getAddressByCode(env, code) : null;
  if (!address) {
    msg.setReject("Esta dirección de Yala no existe.");
    return "rejected_unknown";
  }
  if (msg.rawSize > MAX_RAW_BYTES) {
    msg.setReject("El correo es demasiado grande para leerlo.");
    return "rejected_size";
  }
  if (!(await countReceived(env, address.user_id, now))) return "daily_cap";

  const mail = await parseMail(await msg.raw());

  if (isGmailForwardingConfirmation(mail)) {
    const gmailCode = gmailConfirmationCode(mail);
    if (gmailCode) await saveGmailCode(env, address.user_id, gmailCode, now);
    return "gmail_code";
  }

  const hash = await messageHash(mail);
  if (!(await markSeen(env, address.user_id, hash, now))) return "duplicate";

  const pro = isAccountProActive(await getAccountEntitlement(env, address.user_id), now);
  if (!pro && !(await reserveTrial(env, address.user_id))) {
    await countSkipped(env, address.user_id);
    return "quota_exhausted";
  }

  const startedAt = Date.now();
  const outcome = await read(textForModel(mail), env, new Date(now).toISOString().slice(0, 10));
  if (outcome.call) {
    recordUsage(
      deps.usage ?? usageSink(env),
      usageRecord({
        task: MAIL_USAGE_TASK,
        category: MAIL_USAGE_CATEGORY,
        provider: MAIL_READ_ROUTE.provider,
        model: outcome.call.model,
        status: outcome.call.status,
        finishReason: outcome.call.finishReason,
        usage: outcome.call.usage,
        ms: Date.now() - startedAt,
        attempts: outcome.call.attempts,
      }),
    );
  }
  if (!outcome.ok) {
    if (outcome.providerFailed) {
      if (!pro) await refundTrial(env, address.user_id);
      await forgetSeen(env, address.user_id, hash);
      console.log(`[mail] provider_failed status=${outcome.status}`);
      return "provider_failed";
    }
    console.log(`[mail] unreadable status=${outcome.status}`);
    return "unreadable";
  }
  const r = outcome.reading;
  if (!isUsableReading(r) || r.amount === null) return "not_transaction";

  await insertDraft(
    env,
    address.user_id,
    {
      kind: r.kind,
      amount: r.amount,
      currency: r.currency,
      merchant: r.merchant,
      date: r.date,
      bank: r.bank,
      account_last4: r.accountLast4,
    },
    now,
  );
  return "draft";
}

/** Huella de un aviso: su Message-ID; sin él, el asunto y el cuerpo. SHA-256 en hex: nunca se guarda el texto. */
export async function messageHash(mail: Pick<ParsedMail, "messageId" | "subject" | "text" | "from">): Promise<string> {
  const basis = mail.messageId?.trim() || `${mail.from}\n${mail.subject}\n${mail.text}`;
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(basis));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Adaptador del `ForwardableEmailMessage` de Cloudflare a lo que usa `processIncomingMail`. */
export async function handleEmail(message: ForwardableEmailMessage, env: Env): Promise<void> {
  const outcome = await processIncomingMail(
    {
      to: message.to,
      rawSize: message.rawSize,
      raw: () => new Response(message.raw).arrayBuffer(),
      setReject: (reason) => message.setReject(reason),
    },
    env,
  );
  console.log(`[mail] outcome=${outcome}`);
}
