import PostalMime from "postal-mime";

/**
 * El texto de un correo, listo para leerlo. `postal-mime` resuelve MIME (multipart, base64, quoted-printable, juegos de
 * caracteres); aquí solo se elige el cuerpo y se limpia el HTML, que es como mandan sus avisos casi todos los bancos.
 *
 * Nada de esto se guarda ni se loguea: vive lo que dura la petición.
 */
export interface ParsedMail {
  messageId: string | null;
  from: string;
  subject: string;
  text: string;
}

/** Techo de lo que se le pasa al modelo, en caracteres (≈2.000 tokens). Un aviso de banco cabe de sobra. */
export const MAX_TEXT_CHARS = 6000;

export async function parseMail(raw: ArrayBuffer | Uint8Array | string): Promise<ParsedMail> {
  const email = await PostalMime.parse(raw);
  const plain = (email.text ?? "").trim();
  const text = plain.length > 0 ? plain : htmlToText(email.html ?? "");
  return {
    messageId: email.messageId ?? null,
    from: email.from?.address?.toLowerCase() ?? "",
    subject: email.subject ?? "",
    text: normalizeWhitespace(text),
  };
}

/** HTML → texto plano, sin dependencias: quita estilos y scripts, convierte saltos de bloque y decodifica entidades. */
export function htmlToText(html: string): string {
  return decodeEntities(
    html
      .replace(/<(style|script|head)[^>]*>[\s\S]*?<\/\1>/gi, " ")
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<\/(p|div|tr|li|h[1-6]|table)>/gi, "\n")
      .replace(/<\/t[dh]>/gi, " ")
      .replace(/<[^>]+>/g, " "),
  );
}

const ENTITIES: Record<string, string> = {
  nbsp: " ", amp: "&", lt: "<", gt: ">", quot: '"', apos: "'",
  aacute: "á", eacute: "é", iacute: "í", oacute: "ó", uacute: "ú", ntilde: "ñ",
  Aacute: "Á", Eacute: "É", Iacute: "Í", Oacute: "Ó", Uacute: "Ú", Ntilde: "Ñ",
  uuml: "ü", Uuml: "Ü", iexcl: "¡", iquest: "¿", deg: "°", ordm: "º", ordf: "ª", euro: "€",
};

export function decodeEntities(s: string): string {
  return s
    .replace(/&#(\d+);/g, (_, d: string) => String.fromCodePoint(Number(d)))
    .replace(/&#x([0-9a-f]+);/gi, (_, h: string) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&([a-z]+);/gi, (m, name: string) => ENTITIES[name] ?? m);
}

export function normalizeWhitespace(s: string): string {
  return s
    .replace(/\r/g, "")
    .replace(/[ \t ]+/g, " ")
    .replace(/ *\n */g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/** Lo que se manda al modelo: asunto + cuerpo, recortado al techo. El asunto suele traer el importe. */
export function textForModel(mail: ParsedMail): string {
  const joined = `Asunto: ${mail.subject}\nDe: ${mail.from}\n\n${mail.text}`;
  return joined.length > MAX_TEXT_CHARS ? joined.slice(0, MAX_TEXT_CHARS) : joined;
}
