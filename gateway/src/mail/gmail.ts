import type { ParsedMail } from "./mime";

/**
 * El correo con que Gmail confirma una dirección de reenvío nueva. Gmail no reenvía nada hasta que la persona escribe
 * ese código en su configuración, y el correo llega a NUESTRA dirección: la app lo enseña en la guía (decisión de
 * Jürgen: «la app recoge el código con el que Gmail confirma la dirección»).
 *
 * Remitente fijo `forwarding-noreply@google.com`. El asunto trae el código entre paréntesis en todos los idiomas
 * («(#123456789) Gmail Forwarding Confirmation…», «(n.º 123456789) Confirmación de reenvío de Gmail…»); el cuerpo,
 * también. No pasa por la IA ni gasta cupo.
 */
export const GMAIL_FORWARDING_SENDER = "forwarding-noreply@google.com";

export function isGmailForwardingConfirmation(mail: Pick<ParsedMail, "from">): boolean {
  return mail.from.toLowerCase() === GMAIL_FORWARDING_SENDER;
}

export function gmailConfirmationCode(mail: Pick<ParsedMail, "subject" | "text">): string | null {
  const inSubject = /\([^)\d]*(\d{6,12})\)/.exec(mail.subject);
  if (inSubject) return inSubject[1];
  const inBody = /(?:confirmation code|código de confirmación|codigo de confirmacion|código|code)\D{0,20}(\d{6,12})/i.exec(mail.text);
  return inBody ? inBody[1] : null;
}
