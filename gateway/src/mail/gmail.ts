import type { ParsedMail } from "./mime";

/**
 * El correo con que Gmail confirma una dirección de reenvío nueva. Gmail no reenvía nada hasta que la persona confirma, y
 * el correo llega a NUESTRA dirección: la app enseña en la guía lo que haga falta para confirmar (decisión de Jürgen:
 * «la app recoge el código con el que Gmail confirma la dirección»).
 *
 * Remitente fijo `forwarding-noreply@google.com`. Dos formas de confirmar, y el correo puede traer una o las dos:
 *   - el CÓDIGO numérico que se escribe en Ajustes › Reenvío de Gmail. Antes venía en el asunto entre paréntesis
 *     («(#123456789) Gmail Forwarding Confirmation…») y en el cuerpo;
 *   - el ENLACE de confirmación (`https://mail-settings.google.com/mail/vf-…`), que confirma al abrirlo.
 * Medido el 2026-11-24 en producción: los dos correos de Jürgen llegaron con el asunto «(Gmail Forwarding Confirmation -
 * Receive Mail from …», sin número, y no se guardó nada: la app se quedó buscando un código que no iba a llegar.
 * No pasa por la IA ni gasta cupo.
 */
export const GMAIL_FORWARDING_SENDER = "forwarding-noreply@google.com";

export function isGmailForwardingConfirmation(mail: Pick<ParsedMail, "from">): boolean {
  return mail.from.toLowerCase() === GMAIL_FORWARDING_SENDER;
}

/** Hosts de Google que sirven el enlace de confirmación. Cualquier otro enlace del correo no se guarda ni se enseña. */
const LINK_HOSTS = new Set(["mail-settings.google.com", "mail.google.com", "isolated.mail.google.com"]);
const MAX_LINK_CHARS = 2048;

/** Lo que el correo de Gmail trae para confirmar. Puede faltar uno de los dos, o los dos. */
export interface GmailConfirmationParts {
  code: string | null;
  link: string | null;
}

type GmailMail = Pick<ParsedMail, "subject" | "text"> & { html?: string };

/** Rótulos del código en los idiomas en que Gmail manda el correo. Los largos primero: «código» no se come a «código de…». */
const CODE_LABELS = [
  "confirmation code", "verification code", "code de confirmation", "código de confirmación", "codigo de confirmacion",
  "código de confirmação", "codigo de confirmacao", "bestätigungscode", "codice di conferma", "bevestigingscode",
  "kod potwierdzenia", "onay kodu", "код подтверждения", "确认码", "確認コード", "확인 코드",
  "código", "codigo", "code", "kod", "код",
];
const CODE_IN_BODY = new RegExp(`(?:${CODE_LABELS.map(escapeRegExp).join("|")})\\D{0,20}?(\\d{6,12})(?!\\d)`, "i");

export function gmailConfirmationCode(mail: Pick<ParsedMail, "subject" | "text">): string | null {
  // Asunto: «(#123456789) …», «(n.º 123456789) …», «(Nr. 123456789) …».
  const inSubject = /\([^)\d]{0,12}(\d{6,12})\s*\)/.exec(mail.subject);
  if (inSubject) return inSubject[1];
  const body = stripUrls(mail.text);
  const labelled = CODE_IN_BODY.exec(body);
  if (labelled) return labelled[1];
  // Sin rótulo reconocible: el único número suelto de 8 a 10 cifras del cuerpo (el código de Gmail mide 9). Si hay más de
  // uno distinto, no se adivina.
  const loose = [...new Set([...body.matchAll(/(?<!\d|\d[.,])(\d{8,10})(?!\d|[.,]\d)/g)].map((m) => m[1]))];
  return loose.length === 1 ? loose[0] : null;
}

/** El enlace de confirmación, solo si es de Google y con `https`. Se busca en el texto y en el HTML (el `href`). */
export function gmailConfirmationLink(mail: Pick<GmailMail, "text" | "html">): string | null {
  const candidates: string[] = [];
  for (const src of [mail.text, decodeHtmlAttr(mail.html ?? "")]) {
    for (const m of src.matchAll(/https:\/\/[^\s"'<>()\]]+/g)) candidates.push(m[0].replace(/[.,;:]+$/, ""));
  }
  const valid = candidates.filter(isConfirmationLink);
  // Primero el de la forma conocida (`/mail/vf-`, con o sin `/u/N/`); si no, cualquiera de los hosts de Gmail con `vf`.
  return valid.find((u) => /\/mail\/(?:u\/\d+\/)?vf-/.test(new URL(u).pathname)) ?? valid[0] ?? null;
}

export function isConfirmationLink(raw: string): boolean {
  if (raw.length > MAX_LINK_CHARS) return false;
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }
  if (url.protocol !== "https:" || url.username || url.password || url.port) return false;
  if (!LINK_HOSTS.has(url.hostname.toLowerCase())) return false;
  return /vf[-_]/i.test(url.pathname + url.search);
}

export function gmailConfirmationParts(mail: GmailMail): GmailConfirmationParts {
  return { code: gmailConfirmationCode(mail), link: gmailConfirmationLink(mail) };
}

/**
 * La FORMA del correo de Gmail, sin nada que identifique: cifras → `#<n>`, correos → `<correo>`, enlaces → `<host/…>`.
 * Sale al log solo cuando no se encontró el código, para ver en qué cambió la plantilla de Google sin guardar el correo
 * (el 24-nov el log solo decía `outcome=gmail_code` y no había nada que mirar).
 */
export function gmailTemplateShape(mail: GmailMail, maxChars = 700): string {
  const redact = (s: string) =>
    s
      .replace(/https?:\/\/([^/\s"'<>]+)[^\s"'<>]*/gi, (_, host: string) => `<${host.toLowerCase()}/…>`)
      .replace(/[^\s@<>"'(]+@[^\s@<>"')]+/g, "<correo>")
      .replace(/\d+/g, (d) => `#${d.length}`)
      .replace(/\s+/g, " ")
      .trim();
  const html = mail.html ?? "";
  const htmlHosts = [...new Set([...html.matchAll(/href\s*=\s*["']?https?:\/\/([^/"'\s>]+)/gi)].map((m) => m[1].toLowerCase()))];
  return `subject="${redact(mail.subject)}" text_len=${mail.text.length} html_len=${html.length} html_hosts=${htmlHosts.join(",")} text="${redact(mail.text).slice(0, maxChars)}"`;
}

function stripUrls(s: string): string {
  return s.replace(/https?:\/\/[^\s"'<>]+/gi, " ");
}

function decodeHtmlAttr(s: string): string {
  return s.replace(/&amp;/gi, "&").replace(/&#x3d;|&#61;/gi, "=").replace(/&#x2f;|&#47;/gi, "/");
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
