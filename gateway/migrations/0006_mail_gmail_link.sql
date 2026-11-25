-- 0006_mail_gmail_link — el enlace con que Gmail confirma una dirección de reenvío (2026-11-24).
--
-- Medido ese día en producción: el correo de confirmación de Gmail llegó sin código en el asunto ni en el cuerpo, así que
-- no se guardó nada y la guía de la app se quedó buscando. Gmail también confirma abriendo un enlace de Google; se guarda
-- aquí, con la misma hora (`gmail_code_at`) y la misma caducidad (24 h) que el código. Solo enlaces `https` de los hosts de
-- Gmail (`src/mail/gmail.ts`). Lo demás del correo sigue sin guardarse.
ALTER TABLE mail_addresses ADD COLUMN gmail_link TEXT;
