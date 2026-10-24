# Verificación de Google para leer Gmail

Paquete para pedir a Google que apruebe el permiso `gmail.readonly` del proyecto `yala-502622` (número
295312853864). Sin esa aprobación, «Conectar Gmail» no puede salir a la App Store: cada usuario vería la
pantalla de «app no verificada» y el proyecto tiene un tope de 100 usuarios para siempre.

Encargo: `encargos/lanzados/2026-10-23-conectar-gmail-minimo-verificacion-google.md` (fase 1, 23-oct-2026).
Roadmap: `docs/ROADMAP.md`, 2.3, «Correo del banco».

| Documento | Para qué |
|---|---|
| [checklist-consola.md](checklist-consola.md) | Qué está hecho en la consola de Google y qué falta, en orden. **Empieza aquí.** |
| [justificacion-scope.md](justificacion-scope.md) | Por qué Yala necesita `gmail.readonly`, en español y en inglés (el inglés va a Google). |
| [guion-video.md](guion-video.md) | El video de demostración, escena por escena. |
| [propuesta-politica-y-terminos.md](propuesta-politica-y-terminos.md) | Cambios a la política de privacidad y a los términos de yala-app.pe. **Propuesta, no publicada.** |

## Lo que hay en la app

En **Yala Dev** (nunca en producción), la Bandeja tiene un botón con un sobre: «Conectar Gmail». Abre una
hoja que explica qué se lee y pide el permiso con la pantalla real de Google. Tras aceptar, Yala busca los
avisos del BCP de los últimos seis meses, lee los cinco más recientes y deja cada uno como borrador en la
Bandeja. El correo se lee en el iPhone; no sale a ningún servidor.

**La versión final no será así.** El roadmap la pone en el servidor y con cuenta en la nube. Ese cambio
afecta a la verificación: lo que Google aprueba es el uso que se le enseña, y la auditoría de seguridad
(CASA) mira el servidor que guarde o procese el correo. Ver «Antes de enviar» en la checklist.
