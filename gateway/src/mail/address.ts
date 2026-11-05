/**
 * La dirección de reenvío de cada persona: `auto+<code>@yala-app.pe` (decisión de Jürgen del 2026-11-04).
 *
 * El código es lo único que separa el correo de una persona del de otra, así que se trata como un secreto corto:
 * 10 caracteres de un alfabeto de 31 (sin 0/o, 1/l/i, que se confunden al copiarlo a mano) ≈ 49 bits, sacados de
 * `crypto.getRandomValues`. Adivinar uno no da acceso a nada —solo deja borradores por confirmar en la Bandeja de otro—,
 * y el techo diario de `email.ts` acota ese abuso.
 */
export const CODE_ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789";
export const CODE_LENGTH = 10;

const CODE_RE = new RegExp(`^[${CODE_ALPHABET}]{${CODE_LENGTH}}$`);

export function generateCode(random: (bytes: Uint8Array) => Uint8Array = (b) => crypto.getRandomValues(b)): string {
  // Rechazo por encima del múltiplo más alto del alfabeto: sin sesgo hacia las primeras letras.
  const limit = 256 - (256 % CODE_ALPHABET.length);
  let out = "";
  while (out.length < CODE_LENGTH) {
    const bytes = random(new Uint8Array(CODE_LENGTH * 2));
    for (const b of bytes) {
      if (b >= limit) continue;
      out += CODE_ALPHABET[b % CODE_ALPHABET.length];
      if (out.length === CODE_LENGTH) break;
    }
  }
  return out;
}

export function isValidCode(code: string): boolean {
  return CODE_RE.test(code);
}

export interface MailAddressConfig {
  local: string;
  domain: string;
}

export function mailConfig(env: { MAIL_ADDRESS_LOCAL?: string; MAIL_ADDRESS_DOMAIN?: string }): MailAddressConfig {
  return { local: env.MAIL_ADDRESS_LOCAL || "auto", domain: env.MAIL_ADDRESS_DOMAIN || "yala-app.pe" };
}

export function formatAddress(code: string, cfg: MailAddressConfig): string {
  return `${cfg.local}+${code}@${cfg.domain}`;
}

/**
 * El código de un destinatario, o `null` si no es una dirección nuestra. Acepta mayúsculas (algunos clientes las
 * cambian al reenviar) y los `<>` de una cabecera. El destinatario que manda es el del SOBRE (`message.to` de Email
 * Routing), no el `To:` del correo: un reenvío automático deja el `To:` original del banco.
 */
export function codeFromRecipient(recipient: string, cfg: MailAddressConfig): string | null {
  const addr = recipient.trim().replace(/^<|>$/g, "").toLowerCase();
  const at = addr.lastIndexOf("@");
  if (at < 0) return null;
  const local = addr.slice(0, at);
  const domain = addr.slice(at + 1);
  if (domain !== cfg.domain.toLowerCase()) return null;
  const prefix = `${cfg.local.toLowerCase()}+`;
  if (!local.startsWith(prefix)) return null;
  const code = local.slice(prefix.length);
  return isValidCode(code) ? code : null;
}
