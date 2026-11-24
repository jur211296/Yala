Yala
# Correo del banco, Gmail paso 3: «Buscar el código» no muestra que busca, no avisa y el código nunca llega
---
toca: Yala/App/Views/Settings/BankEmailForwardingView.swift,Yala/Utils/L10n+BankEmail.swift,gateway/src/mail/,gateway/test/,YalaTests/GmailBuscarCodigo/,tickets/backlog/2026-11-24-gmail-buscar-codigo-sin-respuesta.md,tickets/done/2026-11-24-gmail-buscar-codigo-sin-respuesta.md
esfuerzo: high
cierre: cierra-sola
---

Bug reportado por Jürgen (24-nov, 16:02 Lima), con captura en su iPhone: en «Reenviar desde Gmail», paso 3 de 5 («Confirma con el código de Gmail»), «aquí he apretado mil veces "Buscar código" y no tiene una animación, ni se bloquea ni me dice nada. Ni encuentra el código». Su dirección tiene la forma `auto+<código>@yalainbox.com`.

Pista leída en el código (sin medir): en `BankEmailForwardingView.swift`, la acción de `L10n.BankEmail.checkCode` solo hace `Task { await model.refresh() }`: no hay estado de carga, no desactiva el botón y no informa nada si `gmailConfirmation` sigue vacío o si `refresh()` falla. El barrido de la build 8 dejó «en espera» la card del paso de correo del banco por «buzón y gateway de correo», así que puede que el correo de confirmación de Gmail nunca llegue al gateway (`gateway/src/mail/`).

## Qué se pide
1. **Diagnóstico de punta a punta:** el correo de confirmación de Gmail a `auto+…@yalainbox.com` ¿llega al buzón? ¿El gateway lo reconoce como confirmación de reenvío de Gmail y guarda el código? ¿La app lo pide al endpoint correcto del entorno de la build? Mídelo con datos reales de staging. Para producción, solo lectura de logs o estado, sin desplegar nada.
2. **App:** al tocar, el botón muestra que está buscando y se desactiva mientras tanto. Si no hay código todavía, lo dice claramente («Todavía no llegó, prueba en un minuto») y cuánto falta para volver a intentar. Si hay error de red o servidor, lo dice. Considera buscar solo cada pocos segundos mientras la pantalla está abierta, con un límite. Agrega una salida clara si no llega nunca, por ejemplo abrir Gmail para ver el código en el correo reenviado o la ayuda de «Me atasqué».
3. **Gateway:** si el código no se reconoce o no se guarda, arréglalo con pruebas en `gateway/test/` y despliega en **staging**. Producción no: deja escrito en «Qué salió» exactamente qué falta desplegar.
4. Pruebas en `YalaTests/GmailBuscarCodigo/`. Si cambian textos, ponte al día con el catálogo de 2.3 antes del PR y agrega las claves en todos los idiomas.
5. Pruébalo en el iPhone 14 (DeviceMCP). Verifica primero que esté libre; si no, usa un simulador (en la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo).

## Cómo entregar
- Un PR contra 2.3, sin firma de IA. Deja el auto merge activado y cierra; no esperes al CI.
- **Entregable visual:** artifact público de Claude con la causa, el recorrido del correo y capturas antes y después del paso 3. Pon el link en «Qué salió».
- No inventes credenciales ni accesos. Si falta acceso al buzón o a staging, `BLOQUEANTE:`.
- Si necesitas un archivo fuera de `toca:`, tócalo solo si es imprescindible y anótalo en «Decidido sin consultar».
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión».
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones

> Sesión semi con Jürgen en el chat. D0 la contestó él (AskUserQuestion, 24-nov); el resto, recomendaciones mías que se dan por buenas y se discuten en el PR.

**Hechos medidos (producción, solo lectura, 24-nov):** los dos correos de confirmación de Gmail llegaron a `auto+rqm…@yalainbox.com` (21:00:49 y 21:03:25 UTC, SPF/DKIM/DMARC pass, entregados al Worker). La fila de la cuenta tiene `day_count=2`, `gmail_code` NULL, `mail_seen` vacío: entraron por la rama de Gmail y `gmailConfirmationCode` devolvió null. El asunto que registra Email Routing es «(Gmail Forwarding Confirmation - Receive Mail from …», sin número. La app pide al endpoint correcto (dirección `auto+`, el de producción).

**D0 · ¿Cómo se ve el correo real sin tocar producción?** → Frank añade en el Gmail de Jürgen (Chrome) la dirección de staging de la cuenta de prueba, el gateway de staging registra la FORMA del correo sin datos, y la dirección se quita al terminar. Lo eligió Jürgen.

**D1 · ¿Qué guarda el gateway?** → El código si lo hay (asunto, cuerpo con rótulos en varios idiomas o un único número suelto de 8-10 cifras) **y** el enlace de confirmación de Google (`https`, hosts de Gmail, `vf-`). Columna nueva `gmail_link` (migración 0006). Por qué: si Gmail ya solo manda enlace, el código nunca va a llegar. Descartado: meter el enlace en `gmail_code` (mezcla dos cosas en una columna).

**D2 · ¿Cómo viaja a la app sin romper la build 8?** → `gmail_confirmation` sigue igual (solo con código); el enlace va en un campo nuevo `gmail_link` (`{url, received_at_ms}`). Por qué: la build 8 decodifica `code` como obligatorio; con `code: null` fallaría la dirección entera.

**D3 · ¿Qué hace el paso 3 en la app?** → «Buscar el código» enseña que busca y se desactiva; si no llegó, lo dice y cuándo se puede volver a tocar; si falla la red, lo dice; mientras la guía está en ese paso busca sola cada 10 s, hasta 2 minutos; con enlace, el botón pasa a «Confirmar en Google» (abre el enlace); si no llega nada, salida «Abrir Gmail» + «Me atasqué» (el pie que ya existe). Por qué: lo que pidió el encargo, con el enlace como camino principal si existe.

**D4 · Diagnóstico futuro** → cuando no se encuentra el código, el Worker registra la plantilla redactada (cifras → `#n`, correos y enlaces ocultos). Nunca el código, la dirección ni el cuerpo. Por qué: el 24-nov el log solo decía `outcome=gmail_code` y no había nada que mirar.

**D5 · Despliegue** → staging: migración 0006 + Worker sobre la base que ya corre (verificada) + solo este parche. Producción: nada; queda escrito en «Qué salió» (primero la migración, luego el Worker).
