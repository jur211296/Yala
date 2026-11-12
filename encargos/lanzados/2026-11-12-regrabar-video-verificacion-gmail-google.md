Yala
# Regrabar el video de verificación de Gmail para Google con tres correcciones
---
toca: docs/verificacion-google/ (guion, plan.json, montar.py y respuesta), video del demo fuera del repo
esfuerzo: medium
cierre: cierra-sola
---
Continuación del encargo «Grabar el video nuevo para la verificación de Gmail de Google» (PR 934, mergeado en 2.3). Ese video (`~/Claude/entregas/2026-11-12-video-verificacion-gmail-google/yala-gmail-readonly-demo-v2.mp4` en la Max) se revisó y todavía no está listo para Google. Mantén todo lo que ya funciona: el formato 1920×1080, los rótulos en inglés, las tarjetas, la build Yala Dev de la rama del PR de «Conectar Gmail» mínimo, el simulador `Yala-Gmail-Video` en la Max y las decisiones del Paso 0 de ese encargo. Corrige estas tres cosas:

1. **Consentimiento con TODOS los permisos expandidos.** Hoy solo se abre el de Gmail. En «See the 3 services that Yala has some access to», toca la flecha de cada uno (profile, email y openid) para que se vea su descripción y deja cada uno quieto el tiempo suficiente para leerlo. Gmail se queda como está.
2. **El borrador que se abre tiene que verse claramente como un aviso del banco.** Hoy se abre «Disney Plus» y el revisor puede pensar que leímos un correo de Disney, lo que contradice que la búsqueda solo trae avisos del banco. Abre un borrador que salga de un aviso del BCP donde se vea el remitente del banco, o, si ese borrador es un aviso del BCP por una compra en Disney Plus, dilo en el rótulo («BCP card alert: purchase at Disney Plus», con el remitente). Mide primero qué remitente generó cada borrador y no inventes nada.
3. **Que se vea la elección de cuenta de Google**, sin la contraseña: entre «Continuar con Google» y «Google hasn't verified this app» tiene que verse el paso de elegir o escribir la cuenta. Solo se corta el tramo en que se escribe la contraseña o el 2FA.

Revisa también la tarjeta final y la respuesta: si cambia algo en el video, ajusta `respuesta-google.txt` para que diga lo mismo. Jürgen inicia sesión con su cuenta de Google como la vez pasada. Si hace falta que él esté, pídelo como `BLOQUEANTE:` con lo que necesitas, sin inventar credenciales. Puedes usar un segundo simulador en la Max o el iPhone 14 por DeviceMCP. No subas el video a YouTube ni respondas a Google: eso lo hace Dan cuando Jürgen lo apruebe.

Entrega: el video nuevo en `~/Claude/entregas/2026-11-12-video-verificacion-gmail-google-v3/` (en la Max) junto con la respuesta en inglés, más un artifact visual de Claude con el video, una tabla de las tres correcciones con el segundo exacto donde se ve cada una, y el texto de respuesta. Base 2.3, solo documentación. Si el trabajo está completo, cierra con `/cerrar-total` en el mismo turno.
