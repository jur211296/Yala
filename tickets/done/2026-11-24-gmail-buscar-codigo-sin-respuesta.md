---
id: 2026-11-24-gmail-buscar-codigo-sin-respuesta
status: done
priority: high
area: "gateway, settings"
created: 2026-11-24
updated: 2026-11-24
source: "bug de Jürgen del 24-nov (16:02 Lima), con captura en su iPhone: paso 3 de «Reenviar desde Gmail»"
---

# Correo del banco, Gmail paso 3: «Buscar el código» no mostraba nada y el código nunca llegaba

## Qué pasaba

En «Reenviar desde Gmail», paso 3 («Confirma con el código de Gmail»), tocar «Buscar el código» no hacía nada visible:
sin animación, sin bloquearse y sin decir nada. Y el código no aparecía nunca.

## Causa (medida el 24-nov)

- **El correo sí llegaba.** Email Routing registró los dos correos de confirmación de Gmail a la dirección de producción
  de Jürgen (21:00:49 y 21:03:25 UTC, SPF/DKIM/DMARC en pass, entregados al Worker). La fila de su cuenta contó 2 correos
  ese día y ninguno pasó a «vistos»: entraron por la rama de Gmail.
- **Gmail ya no manda código.** El correo real (capturado en staging con la forma redactada) dice «please click the link
  below to confirm the request» y trae solo un enlace `https://mail-settings.google.com/mail/vf-…`. El asunto es
  «(Gmail Forwarding Confirmation - Receive Mail from …», sin número. Y Ajustes › Reenvío de Gmail ya no tiene recuadro
  para escribir un código: solo «Verify <dirección> · Re-send email · Remove address».
- El gateway solo buscaba el código, no lo encontraba y no guardaba nada; la app pedía la dirección otra vez sin enseñar
  carga ni resultado.

## Qué cambió

- **Gateway** (`gateway/src/mail/`): guarda el enlace de confirmación (solo `https` de los hosts de Gmail) en la columna
  nueva `gmail_link` (migración `0006_mail_gmail_link.sql`) y lo devuelve en `gmail_link` de `POST /mail/address`.
  `gmail_confirmation` no cambia de forma (la build 8 lo decodifica con `code` obligatorio). El código se sigue buscando,
  con más rótulos y un número suelto único. Sin código, el log deja la forma del correo sin cifras, correos ni enlaces.
- **App**: el paso 3 se llama «Confirma tu dirección de Yala en Gmail». Busca solo al abrirse y cada 10 s durante
  2 minutos; el botón «Buscar ahora» enseña «Buscando…» y se apaga mientras busca y entre búsquedas; debajo dice
  «Todavía no llegó. Nueva búsqueda en N s.», o que no pudo conectar. A los 2 minutos deja de buscar, explica cómo
  reenviar el correo desde Gmail y ofrece «Abrir Gmail»; «Me atasqué» sigue al pie. Cuando llega el enlace, el botón
  pasa a «Confirmar en Google» y abre la página de Google que confirma. Textos en los 16 idiomas.

## Pruebas

- `gateway/test/mail.gmail.test.ts` (13 casos) + `mail.test.ts` y `mail.wrangler.test.ts`: 47 verdes.
- `YalaTests/GmailBuscarCodigo/` (lógica de búsqueda, modelo, decodificación con y sin `gmail_link`, enlaces que no se
  abren, cableado) + guía y paridad de idiomas: 52 verdes.
- `YalaUITests/Flows/BankEmailGuideUITests`: el paso sin confirmación dice que no llegó y espera su turno; con el enlace
  ofrece «Confirmar en Google».
- Staging: correo real de Gmail → `found=link`, enlace guardado (`mail-settings.google.com/mail/vf-…`, 181 caracteres).

## Fuera de esto

- **Producción no está desplegada**: falta aplicar la migración `0006` y luego el Worker con `src/mail/`. Hasta entonces
  la app nueva busca, dice que no llegó y a los 2 minutos ofrece las salidas, pero el enlace no llega.
- El iPhone de Jürgen tiene su dirección de producción pendiente de verificar en Gmail («Verify auto+rqm…»): con
  producción desplegada, «Re-send email» en Gmail y luego «Buscar ahora» en Yala.
