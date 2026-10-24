# Justificación del permiso `gmail.readonly`

Google la lee en inglés. La versión en inglés es la que está **guardada desde el 23-oct-2026** en la consola
(Google Auth Platform › Acceso a los datos › «¿Cómo se usarán los permisos?», 890 de 1000 caracteres). Si se
cambia aquí, se cambia allí.

Tipo de uso elegido en la consola: **«Productividad del correo electrónico»**. Las otras tres opciones eran
copia de seguridad, cliente de correo e informes de supervisión, y ninguna describe convertir avisos en
borradores.

## En español (para Jürgen)

Yala es una app de finanzas personales para iPhone. Cuando la persona toca «Conectar Gmail» y da el permiso,
Yala busca en su buzón solo los avisos de movimientos de su banco (la búsqueda se limita a los remitentes de
bancos conocidos, por ejemplo notificaciones@notificacionesbcp.com.pe), lee esos mensajes y convierte cada uno
en un borrador de gasto en la Bandeja de la app (importe, divisa, comercio y fecha). La persona revisa y
guarda cada borrador, así que ya no tiene que escribir a mano cada compra con tarjeta.

Un permiso más limitado no alcanza: `gmail.metadata` no da el cuerpo del mensaje, que es donde están el
importe y el comercio, y los demás permisos de Gmail no permiten leer. Yala nunca envía, modifica ni borra
correos, no lee otros mensajes, no vende los datos, no los usa para publicidad ni para entrenar modelos de IA.
La persona puede desconectar Gmail cuando quiera, en la app o en su cuenta de Google.

## In English (sent to Google)

Yala is a personal finance app for iPhone. When the user taps "Connect Gmail" and grants access, Yala searches
the mailbox only for transaction alerts from the user's bank (the query is restricted to known bank sender
addresses, e.g. notificaciones@notificacionesbcp.com.pe), reads those messages and turns each one into a draft
expense in the app's Inbox (amount, currency, merchant, date). The user reviews and saves each draft, so card
purchases no longer have to be typed by hand. A narrower scope is not enough: gmail.metadata does not expose
the message body, where the amount and merchant are, and the other Gmail scopes do not allow reading. Yala
never sends, modifies or deletes email, does not read other messages, does not sell the data, does not use it
for ads and does not use it to train AI models. Users can disconnect Gmail at any time in the app or in their
Google Account.

## Lo que esta justificación promete, y hay que cumplir

Cada frase es un compromiso que Google puede comprobar en el video, en la política o en la auditoría:

- **Solo los avisos del banco.** La búsqueda va por remitente (`GmailBankAlertImporter.searchQuery`). Añadir
  un banco es añadir su remitente a `BankAlertEmailParser.knownSenders`, no abrir la búsqueda.
- **Desconectar desde la app.** La hoja de Yala Dev tiene «Quitar el permiso de Gmail». La versión final
  también tiene que tenerlo.
- **No entrenar modelos de IA.** Si la versión del servidor lee el correo con IA (como dice el roadmap), el
  proveedor tiene que tener el entrenamiento apagado por contrato, y la política tiene que decirlo (ver
  `propuesta-politica-y-terminos.md`).
