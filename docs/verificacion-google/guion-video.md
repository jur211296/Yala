# Guion del video de demostración

Lo que Google pide en el video (medido el 23-oct-2026 en su ayuda, `support.google.com/cloud/answer/13804565`):

1. El recorrido entero, **con el permiso pedido dentro de la app**.
2. La pantalla de consentimiento **completa**, con el selector de idioma (abajo a la izquierda) en **English**.
3. Que la pantalla muestre el nombre de la app (Yala) y **el mismo permiso que se pide** (`gmail.readonly`).
4. Para qué se usa el permiso en la app, enseñado, no contado.
5. **Todos los clientes de OAuth del proyecto.** Hay dos: «Yala iOS (dev)» y «Yala iOS (prod)» (ver escena 9).
6. En una app iOS nativa **no** hace falta enseñar el client ID en la barra de direcciones.

La pantalla de «Google no verificó esta app» va a salir: Google dice que es normal y que **debe verse** en el
video. Duración objetivo: 2-3 minutos. Subida a YouTube como **«No listado»**.

## Antes de grabar

1. Una cuenta de Gmail de prueba con **al menos un aviso real del BCP** (remitente
   `notificaciones@notificacionesbcp.com.pe`, de los últimos seis meses). Si la de prueba no tiene, reenvíale
   uno desde la tuya **conservando el remitente** no funciona: el reenvío cambia el remitente. Usa la cuenta que
   recibe los avisos.
2. Si esa cuenta ya dio el permiso en otra toma: en la hoja de Yala toca «Quitar el permiso de Gmail», o en
   `myaccount.google.com/permissions` quita «Yala». Si no, Google no vuelve a enseñar el consentimiento.
3. Yala Dev en el simulador (iPhone 17 Pro) con datos de ejemplo, para que la app no se vea vacía. La toma de
   este encargo usó `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed minimal` y después se relanza sin
   `-uitest-reset`.
4. Grabar: `xcrun simctl io <UDID> recordVideo --codec=h264 ~/Desktop/yala-gmail-demo.mp4` y `Ctrl+C` para
   parar. Los rótulos en inglés de cada escena se añaden después con cualquier editor (iMovie vale).

## Escenas

| # | Qué se ve | Rótulo en pantalla (inglés, para el revisor) |
|---|---|---|
| 1 | El Panel de Yala unos segundos: nombre de la app y su propósito. | *Yala – personal finance app for iPhone. Demo of "Connect Gmail" (gmail.readonly).* |
| 2 | Toca el icono de la Bandeja (arriba a la izquierda). Se ven los borradores pendientes. | *The Inbox holds draft expenses for the user to review.* |
| 3 | Toca el sobre («Conectar Gmail») arriba a la derecha. Sale la hoja «Correo del banco». Quieto 5 s para que se lea. | *In-app disclosure: Yala only searches bank alert emails, reads them on the device, never sends, edits or deletes email, and access can be removed at any time.* |
| 4 | Toca «Continuar con Google». Aviso de iOS «"Yala" quiere utilizar "accounts.google.com"» → «Continuar». | *The user starts the Google OAuth flow.* |
| 5 | En la página de Google, **antes de nada**, cambia el idioma abajo a la izquierda a **English**. Elige la cuenta de prueba. | *Consent screen language set to English.* |
| 6 | «Google hasn't verified this app» → «Advanced» → «Go to Yala (unsafe)». | *Unverified-app screen: verification is pending.* |
| 7 | La pantalla de consentimiento: nombre **Yala**, el permiso **«Read your email messages and settings»** (o el texto que salga para Gmail). Marca su casilla y **quieto 3 s** antes de «Continue». | *Requested scope: https://www.googleapis.com/auth/gmail.readonly* |
| 8 | Vuelve a Yala: «1 borrador nuevo en la Bandeja» → «Ver la Bandeja». Abre el borrador del BCP: importe, comercio, fecha. Elige cuenta y categoría y guárdalo. | *How the scope is used: the bank alert becomes a draft expense; the user reviews and saves it.* |
| 9 | Vuelve a abrir el sobre: «Conectado como …» y «Quitar el permiso de Gmail». Tócalo. | *The user can revoke Gmail access from the app.* |
| 10 | Pantalla final, solo texto. | *Both OAuth clients in this project ("Yala iOS (dev)" and "Yala iOS (prod)") are the same iOS app (development and App Store builds) and show this same consent screen and flow. This recording uses the development build.* |

## Lo que no puede salir en el video

- Correos que no sean del banco (la búsqueda ya los filtra; no abras Gmail en pantalla).
- Datos reales de otras personas. El aviso del BCP enseña tu nombre y los últimos dígitos de la tarjeta: si no
  quieres que salgan, tápalos en la edición.
- La palabra «OpenAI».

## Si Google pide más

Lo habitual es un correo del equipo de verificación con preguntas. Se contesta a ese correo; si piden otro
video, se repite este guion con lo que señalen.
