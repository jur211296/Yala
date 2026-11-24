---
name: reference-probar-el-reenvio-de-gmail
description: Cómo provocar y leer el correo de confirmación de reenvío de Gmail contra staging sin tocar producción, y las dos trampas de la página de Ajustes de Gmail en Chrome
metadata:
  type: reference
---

Medido el 2026-11-24 (bug «Buscar el código» del paso 3 de Gmail).

- **Leer lo que llegó al buzón, sin desplegar nada:** la API GraphQL de Cloudflare, `emailRoutingAdaptive` de la zona
  `yalainbox.com` (datetime, from, to, subject, status, spf/dkim/dmarc), con el token OAuth de wrangler de la Mini
  (receta en [[secretos-de-staging-en-la-mini]]). Y el estado en D1 con `/d1/database/<id>/query` en solo `SELECT`.
  Email Routing no guarda cuerpos: para la forma del correo, el log de staging (`wrangler tail`) con
  `gmailTemplateShape`, que tapa cifras, correos y enlaces.
- **Provocar el correo:** en el Gmail de Jürgen (Chrome de la Max, `mail.google.com/mail/u/1/`, jur211296; `u/0` es
  admin@yala-app.pe y pide reautenticar) → «Add a forwarding address» con `auto-staging+vscjpcbjxn@yalainbox.com` (la
  cuenta de prueba de staging). El «Proceed» sale en una ventana emergente que Claude in Chrome no alcanza: se le pide a
  Jürgen (la primera vez preguntó cómo; «ábrela de nuevo» = volver a darle a Next). Al terminar, «Remove address».
- **Trampa 1:** recién abierta, la página de Reenvío carga primero una versión básica con un campo de texto y radios.
  Escribir ahí y guardar da «Invalid forwarding address», pero deja un aviso rojo «You are forwarding your email to …»
  que parece real. Recarga y espera a ver «Add a forwarding address» antes de tocar nada; si ves el aviso, marca
  «Disable forwarding» y guarda.
- **Trampa 2:** Device MCP puede estar espejando un iPhone de Jürgen (Free: uno a la vez). Para el simulador, `axe` con
  el marco leído de `axe describe-ui` (AXUniqueId) y un toque por coordenada en la franja visible; `axe tap --id` tras
  desplazar tocó otra fila.
