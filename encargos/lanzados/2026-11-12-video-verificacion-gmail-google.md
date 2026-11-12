Yala
# Grabar el video nuevo para la verificación de Gmail de Google
---
toca: docs de verificación Google, guion y video del demo (sin cambiar código de producción salvo que haga falta)
cierre: cierra-sola
---
El 11-nov Google (Third-Party Data Safety Team) pidió un video nuevo para la verificación OAuth de Yala. El correo llegó a jur211296@gmail.com con el asunto «[Action Needed] OAuth Verification Request Acknowledgement». Dice que el demo no demuestra por qué hace falta `https://www.googleapis.com/auth/gmail.readonly` ni por qué no sirve un permiso más reducido. El video nuevo tiene que:
- Mostrar completo cada uso de ese permiso dentro de la app, es decir, cómo Yala lee los correos del banco y crea los movimientos de principio a fin, y explicar en pantalla por qué no alcanza un permiso más reducido.
- Mostrar la pantalla de consentimiento OAuth con todos los permisos expandidos y legibles (usar «Show all services» si hace falta).
- Usar permisos que coincidan exactamente con los configurados en Google Cloud Console. Verifícalo y anota la diferencia si hay alguna.
- No activar permisos sin verificar para usuarios reales. Grabar en staging o en un entorno de prueba dentro de la app, con el estado de publicación todavía «In Production».
Tareas: revisa el envío anterior (PR 613 y docs de la verificación), escribe el guion, graba el video en el simulador o en el iPhone 14 por DeviceMCP (puedes usar un segundo simulador), con narración o subtítulos en inglés, y deja el video y el texto de respuesta en inglés listos para que Jürgen responda el correo. No respondas a Google ni lo subas tú. Si hace falta iniciar sesión en Google, pedir credenciales o entrar a Cloud Console sin acceso, márcalo como BLOQUEANTE con lo que falta; no lo inventes.
Entrega un artifact visual de Claude con el guion, el link al video, la verificación de permisos y el texto de respuesta. Al terminar, cierra con `/cerrar-total` en el mismo turno.

## Paso 0 — decisiones (semi, 12-nov 11:20 Lima)

1. **Qué build se graba:** la de Yala Dev de la rama del PR de «Conectar Gmail» mínimo (abierto contra 2.3, sin mergear). Es la versión que se pidió verificar (decisión del 9-nov: lectura en el teléfono). No se mergea ni se toca su código.
2. **Dónde:** simulador propio `Yala-Gmail-Video` (iPhone 17 Pro) en la Max. Jürgen eligió simulador y entra él a su cuenta de Google (pregunta del 12-nov).
3. **Consola:** la mide Frank en Chrome con la sesión de admin@yala-app.pe; la llave de acceso la aprueba Jürgen (lo eligió).
4. **Idioma:** simulador y app en inglés (cambiado al grabar: la página de Google sigue el idioma del sistema, y su selector no se abre con toques sintéticos). La hoja de Gmail, con textos fijos en español, se traduce en el rótulo.
5. **Formato:** 1920×1080, iPhone a la izquierda y rótulo a la derecha, más tarjetas de título, «por qué no un permiso menor» y cierre. Sin voz (subtítulos bastan: lo permite el encargo).
6. **Base de la rama:** 2.3 (decisión del 11-nov: los encargos nuevos van solo a 2.3). Solo docs: el guion y la respuesta en `docs/verificacion-google/video-v2-2026-11-12.md`, nombre distinto a los del PR de Gmail para no chocar.
7. **Video:** no va al repo (peso). Va a `~/Claude/entregas/2026-11-12-video-verificacion-gmail-google/` y se le envía a Jürgen. No se sube a YouTube ni se responde a Google.
8. **Consola:** la llave de acceso de admin@yala-app.pe no pasó en la pestaña del MCP; se midió con la sesión ya abierta de jur211296@gmail.com (`authuser=1`), dueña del proyecto. Solo lectura.
9. **Tercer cliente OAuth** («Yala Web (MCP)», 4-nov): no estaba en el guion anterior. Se nombra en la tarjeta final y en la respuesta, con su scope medido (`email profile`).
