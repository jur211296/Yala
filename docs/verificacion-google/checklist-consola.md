# Checklist de la consola de Google

Proyecto `yala-502622` (número 295312853864), en `console.cloud.google.com/auth/…?project=yala-502622`.
Estado **medido el 23-oct-2026** con la sesión de jur211296@gmail.com. Los clics los hace Frank; lo que
necesita a Jürgen está marcado **[Jürgen]**.

## Lo que había antes de este encargo

| Pantalla | Estado |
|---|---|
| **Público** | **En producción**, usuarios externos. Límite de usuarios para permisos sin verificar: **3 de 100** usados. |
| **Información de la marca** | Nombre «Yala»; correo de asistencia jur211296@gmail.com; **sin logotipo**; página principal `https://yala-app.pe`; política `https://yala-app.pe/privacy`; términos `https://yala-app.pe/terms`; dominio autorizado `yala-app.pe`; contacto del desarrollador jur211296@gmail.com. **Marca sin verificar** («Verificar la marca» pendiente). |
| **Clientes** | Dos, los dos iOS: «Yala iOS (dev)» (`295312853864-uagl…`, el de Yala Dev) y «Yala iOS (prod)» (`295312853864-7dt8…`, el de la App Store). |
| **Acceso a los datos** | Ningún permiso declarado. |
| **API de Gmail** | Apagada. |

## Hecho en este encargo

- [x] **API de Gmail activada** (`gcloud services enable gmail.googleapis.com --project yala-502622`).
- [x] **Permisos declarados** en «Acceso a los datos»: `openid`, `userinfo.email`, `userinfo.profile` (los que
  ya pide el inicio de sesión con Google) y **`gmail.readonly`** (restringido). Guardado: «Se guardaron los
  cambios de acceso a los datos».
- [x] **Tipo de uso:** «Productividad del correo electrónico».
- [x] **Justificación** en inglés (890/1000), la de `justificacion-scope.md`.
- [x] Dominio autorizado `yala-app.pe`: ya estaba. Nada que añadir: en iOS nativo no hay URI de redirección web.

## Lo que el encargo pedía y no aplica

- **Usuario de prueba jur211296@gmail.com:** la lista de usuarios de prueba solo existe con la app en modo
  «Prueba», y la app está **en producción** (la usa el inicio de sesión con Google de la cuenta en la nube).
  **No se vuelve a modo prueba**: cortaría el inicio de sesión a todos los usuarios reales. En producción,
  cualquier cuenta puede dar el permiso sin verificar pasando por la pantalla de «app no verificada», y cuenta
  para el tope de 100 usuarios, que **no se puede reiniciar nunca**. Para grabar y probar basta una o dos cuentas.

## Lo que falta, en orden

1. [ ] **[Jürgen] Política y términos publicados** con la sección de Gmail y la declaración de Uso Limitado
   (`propuesta-politica-y-terminos.md`). Es un hotfix de la web desde `1.0`.
2. [ ] **[Jürgen] Dominio `yala-app.pe` verificado en Google Search Console** con una cuenta propietaria o
   editora del proyecto. Sin eso la marca no se verifica. Frank puede comprobar si ya lo está y, si no, dejar
   preparado el registro DNS TXT; añadirlo en el DNS lo hace quien tenga acceso al dominio.
3. [ ] **Logotipo** de 120×120 en «Información de la marca» (recomendado; subirlo obliga a verificar la marca,
   que ya hace falta de todos modos).
4. [ ] **Verificar la marca** (botón «Verificar la marca»). **Google no deja pedir la verificación del acceso a
   datos sin la marca verificada y publicada** (Centro de verificación, medido el 23-oct). Tarda unos días.
5. [ ] **[Jürgen] Grabar el video** con `guion-video.md` y subirlo a YouTube como «No listado». Necesita su
   cuenta de Google con avisos reales del BCP: Frank no inicia sesión con cuentas de Jürgen.
6. [ ] **Pegar el enlace de YouTube** en «Acceso a los datos» › «Vínculo de YouTube» y guardar.
7. [ ] **Centro de verificación › «Prepare for verification»** y enviar. Google contesta por correo a
   jur211296@gmail.com; las preguntas se responden en ese hilo.
8. [ ] **Auditoría de seguridad (CASA)**: cuando Google la pida, tras aprobar el uso. Es anual y de pago, con un
   laboratorio autorizado. Ver «Antes de enviar».

## Antes de enviar: una decisión que cambia la verificación

Google aprueba **el uso que se le enseña**. Hoy el video enseña la lectura **en el teléfono**; el roadmap
quiere la versión final **en el servidor**, con cuenta en la nube y lectura con IA. Si se verifica una y se
publica la otra, la política, el video y la auditoría dejan de cuadrar y toca volver a pedirla.

- **Opción A — verificar la versión del teléfono y publicar esa.** Es lo que está hecho. Encaja con el
  «atajo del banco» (todo en el iPhone) y Google puede pedir una auditoría más ligera si el correo nunca sale
  del teléfono. *Sin medir*: la exención de CASA para apps que no guardan ni envían los datos a un servidor no
  aparece en la ayuda actual de Google (`support.google.com/cloud/answer/13465431`); hay que preguntárselo.
- **Opción B — construir antes la versión del servidor y grabar con ella.** Es la del roadmap. Retrasa el
  envío hasta tenerla, y la auditoría mira el servidor (Cloudflare, Supabase y el proveedor de IA).

Recomendación: **B**, si la versión final va a ser la del servidor: la verificación tarda semanas y hacerla dos
veces cuesta más que esperar a tener lo que se va a publicar. Mientras tanto, los pasos 1-4 (política, dominio,
logotipo y marca) sirven para las dos y se pueden ir haciendo.
