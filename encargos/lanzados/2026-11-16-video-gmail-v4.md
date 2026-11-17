Yala
# Regrabar el video de verificación de Gmail mostrando también la cuenta de Gmail de origen, de punta a punta
---
toca: docs/verificacion-google/, tickets/done/2026-11-16-video-verificacion-gmail-v4.md
esfuerzo: medium
cierre: cierra-sola
---
Encargo autorizado por Jürgen el 16-nov en el chat («también encolemos esto»). Continuación de «Regrabar el video de verificación de Gmail para Google con tres correcciones» (video v3 en `~/Claude/entregas/2026-11-12-video-verificacion-gmail-google-v3/` en la Max). Google volvió a rechazar el 15-nov (hilo en el Gmail jur211296@gmail.com, proyecto `yala-502622`, scope `gmail.readonly`). Ya NO observa la pantalla de consentimiento ni la coincidencia de permisos: no cambies eso. Lo que pide ahora:

1. **Source Account Impact:** si la app «lee», el video tiene que mostrar ese mismo correo en la cuenta de Gmail de origen.
2. **End-to-End:** la función en Yala y, en paralelo, lo que le corresponde en la cuenta de Google del usuario.

El video anterior solo mostraba Yala y nunca abrió Gmail. Guion recomendado (ajústalo si mides algo mejor, sin inventar nada):
- Abrir Gmail (web en Safari del simulador o app) en la MISMA cuenta y buscar `from:notificaciones@notificacionesbcp.com.pe`, con los correos visibles (monto, comercio, fecha).
- Abrir uno, por ejemplo el aviso del BCP por la compra en Disney Plus de $ 20.78, y mostrar el cuerpo.
- Pasar a Yala: conectar Gmail (consentimiento como en v3), importar y abrir ese mismo borrador mostrando que los datos coinciden.
- Volver a Gmail y mostrar que no se tocó nada: nada borrado, enviado ni marcado.
- Terminar quitando el permiso en la app y mostrarlo también en https://myaccount.google.com/permissions.

Mantén lo que ya funciona en v3 (1920×1080, rótulos en inglés, tarjetas, build Yala Dev de la rama de «Conectar Gmail» mínimo, simulador `Yala-Gmail-Video` en la Max). Mide primero qué correos hay en la cuenta. Jürgen inicia sesión en Google en el simulador: pídelo como `BLOQUEANTE:` diciendo qué necesitas, sin inventar credenciales; se corta solo el tramo de contraseña o 2FA. Ajusta `respuesta-google.txt` en inglés para que responda punto por punto a lo que pidió Google y coincida con el video. No subas el video a YouTube ni respondas a Google: eso lo hace Dan cuando Jürgen lo apruebe.

Entrega: el video en `~/Claude/entregas/2026-11-16-video-verificacion-gmail-google-v4/` (Max) con la respuesta, y un artifact visual de Claude con el video, una tabla de lo que pidió Google con el segundo exacto donde se ve cada punto, y el texto de respuesta. Base 2.3, solo documentación; commit y PR sin firma de IA. Puedes usar un segundo simulador en la Max o el iPhone 14 por DeviceMCP. Cierre según el modo fijado al arrancar: semi con trabajo completo, `/cerrar-total`; nocturno, si falta el inicio de sesión de Jürgen, checkpoint con card «Espera decisión». El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar».

## Paso 0 — decisiones (resueltas en semi, sin consultar salvo el login)

1. **Simulador:** el `Yala-Gmail-Video` de la v3 ya no existía en la Max → se creó uno nuevo con el mismo nombre (iPhone 17 Pro, iOS 27.2, sistema en inglés). Build Yala Dev (Debug-Dev) de la rama `encargo/2026-10-23-conectar-gmail-minimo-verificacion-google`, compilada en un worktree temporal.
2. **Correo de ejemplo:** el aviso de Disney Plus del guion ya no entra entre los 5 más recientes del BCP (Yala lee los 5 últimos, sin filtrar). Se usa el más reciente medido en la cuenta: **Ouraring, $ 6.83, 16-nov-2026 04:37**, que es el primero de los 5 borradores (leído de la base del simulador tras el ensayo).
3. **Gmail de origen:** Gmail web en Safari del mismo simulador (la app de Gmail no se instala en simulador). Se entra directo a la búsqueda para no enseñar la bandeja personal; «Details» del correo muestra remitente y destinatario (jur211296@gmail.com) en un clip aparte (`raw2.mp4`).
4. **«No se tocó nada»:** misma búsqueda recargada (todo sigue con la etiqueta Inbox) + `in:sent newer_than:1d` sin resultados + `in:trash from:…bcp…` sin resultados.
5. **Permisos en Google:** myaccount.google.com/permissions **filtrado por «Yala»**, para no mostrar las demás apps conectadas. Antes: Yala con «View your email messages and settings». Después de quitar el permiso en la app: «No results found».
6. **Consentimiento:** el ensayo terminó revocando todo, así que la toma muestra el consentimiento en dos pantallas (inicio de sesión y luego la casilla de Gmail), no el «already has some access» de la v3. Google ya no observa esa pantalla: se deja como salió.
7. **Nombre del titular:** sin caja (`mask`) esta vez. El nombre ya aparece en las pantallas de Google (selector de cuenta) y en la lista de Gmail, y una caja parcial llama más la atención que tapa.
8. **Guardar el borrador:** el simulador nuevo tiene categorías, así que la toma elige categoría y guarda (la v3 no podía).
9. **Montaje:** `montar.py` de la v3 con un cambio mínimo (`raw` por tramo y rutas relativas al plan). Pillow en un venv del scratchpad (la Max no lo trae).
