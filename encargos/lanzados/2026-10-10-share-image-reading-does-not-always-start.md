---
esfuerzo: high
---
# Al compartir una imagen a Yala, la lectura no siempre arranca hasta reiniciar la app

**Card:** tablero-al-compartir-una-imagen-a-yala-la-lectur-nxle · **Prioridad:** high · **Versión:** 2.1

Reporte de Jürgen (10-oct 10:48): al mandar algo con la hoja de compartir, a veces no arranca la lectura y tiene que cerrar Yala del todo y reabrirla para que empiece el registro por imagen. Quiere además revisar **todas** las formas de entrar a la app y el orden en que se presentan los avisos y las hojas al entrar.

## Pistas medidas por Frank (origin/2.1)
- `Yala/App/Models/RouterEntryGate.swift` → `submit`: si `shouldDefer` (onboarding o bootstrap sin terminar), el intent va a `DeferredIntentBuffer`, que **descarta en silencio** los que no son serializables, como `.presentSharedImage`. Ya existe el canario «DROP non-serializable deferred intent» (ver `Bugs/qa_cold-launch-share-image-no-registro`).
- `AppBootstrapper`: `checkForPendingSharedImage(site: "bootstrap")` (paso 21), `checkForPendingSharedImage(site: "becameActive")` y `handleIncomingURL` → `yala://shared-image` → `enqueueSharedImage`. Revisa la carrera en caliente (scenePhase contra onOpenURL) y qué pasa si ya hay una hoja o un aviso abierto (el corte de la hoja de la Bandeja en el paso 1b, fullScreenCover detrás de otra hoja, avisos de arranque).
- Si el archivo se queda en `PendingImages/` sin consumir, solo se recoge en el siguiente bootstrap en frío, que es justo el síntoma.

## Qué se pide
1. **Reproducir primero** con XCUITest (y unit si se puede): compartir una imagen (o inyectar el archivo en el contenedor compartido y abrir `yala://shared-image`) con la app a) en frío, b) en segundo plano, c) con otra hoja ya abierta (Bandeja, formulario o un aviso de arranque). Debe fallar en 2.1 en al menos un caso.
2. **Auditar todos los puntos de entrada** en frío y en caliente: hoja de compartir, deep links y universal links (invitaciones, Google), widgets, Siri y App Intents, notificaciones (y sus acciones), Spotlight, accesos rápidos del icono y Apple Pay si aplica. Deja una tabla en `docs/entry-points.md` con: origen, cómo llega (onOpenURL, userActivity, notificación, scenePhase), si se difiere, si es serializable, qué presenta y con qué prioridad.
3. **Un único coordinador** (sobre `RouterEntryGate`, sin reescribirlo todo) con prioridad y orden explícitos para avisos y hojas al entrar. Que ningún intent se pierda: los no serializables se convierten en serializables (p. ej. `.presentSharedImage` lleva solo la ruta del archivo) o se reintentan cuando la app está lista. Al cerrar la hoja que bloqueaba, se presenta lo pendiente.
4. El share tiene que arrancar la lectura el 100 % de las veces en los tres casos, con tests en verde. Sin cambios de UI visibles más allá del orden. Si hace falta decidir una prioridad de producto (p. ej. qué gana entre una invitación y una imagen compartida), propón una por defecto razonable y anótala para Jürgen.
5. Device-QA corto para Jürgen en el cierre (frío, en segundo plano y con la Bandeja abierta).
## Reglas de siempre
- Arranca sobre `origin/2.1` y trabaja sin esperar a nadie. Justo antes de abrir el PR: `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí los conflictos (strict=false); si el rebase toca lo tuyo, recompila y repite los tests afectados con un solo simulador.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo en `tickets/`, mira con `tablero listar --proyecto Yala --todas` que no tenga card y, si no, `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url>"`. SIN --fecha (opcional desde el ADR-068; sin fecha de relleno). Lista esas cards en el aviso de cierre.
- Sin deploy, sin secretos y sin decisiones de UI de Jürgen: si algo lo pide, para y anótalo en el cierre.
- Cierre: `/cerrar-total` autónomo (PR a 2.1 en auto-merge, limpieza de simulador, worktree y DerivedData).

## Carga de la Mini (OBLIGATORIO)
- Todo xcodebuild va con `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca dos builds o tests a la vez (ni build + tests); pipeline serie: build → 1 simulador → tests → erase.
- Antes de cada build espera a que la carga baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- Nunca pases xcodebuild por `| head` (mata el build): escribe a un log y lee el log.
- Los `-only-testing:` van en un array de zsh, no en un string.

## Paso 0

Decisiones tomadas antes de escribir código (sesión autónoma; lo asumido va marcado).

1. **Cómo se reproduce.** El share real no se conduce desde XCUITest (otro proceso). Seam DEBUG: `yala(dev)://shared-image?uitest-stage=readable` deja el recibo de ejemplo en `PendingImages/` *antes* de seguir por el camino real de `handleIncomingURL`, igual que haría la extensión. Caliente: `app.open(url)` con la app delante o tras `Home`. Frío: `-uitest-deeplink-url`, que entra pre-init. La lectura «arranca» = `image_review_title` con `-uitest-image-result one`.
2. **Dónde vive el coordinador.** Sobre `RouterEntryGate` + `AppRouter`, sin reescribirlos: la fuente durable de una imagen compartida es el fichero de `PendingImages/`, así que el intent que se difiere lleva la ruta (`SerializableIntent.presentSharedImage(path:)`) y se reconstruye al drenar si el fichero sigue ahí. Lo que no se puede serializar se re-emite desde su fuente en la próxima ventana lista.
3. **Hoja ajena abierta.** El intent no se consume tapado (regla de Presentaciones): espera en cola y se presenta al cerrarse lo que tapa. **Asumido:** no se cierra por código una hoja del usuario para abrir la lectura (podría tener un formulario a medias); la alternativa queda en `shared-photo-waits-silently-behind-an-open-panel-sheet`. Se probó además una comprobación a UIKit en el Panel para hojas que ningún flag publica: su mutante sobrevivió y se retiró.
4. **Prioridad por defecto (asumida, para Jürgen):** lo crítico del sistema y la respuesta a un enlace de invitación van primero (ya son `.critical`); después lo que el usuario acaba de pedir desde fuera (imagen compartida, deep link); después los avisos que la app saca sola (bandeja, oferta, novedades, reseña). Entre una invitación y una imagen compartida, gana la invitación y la imagen espera en cola.
5. **Pro en frío.** La puerta Pro de la imagen compartida no se decide antes de saber la suscripción: pre-arranque no se borra la foto, la decide la recuperación post-arranque.
6. **Fuera de alcance:** la decisión A/B/C de `declining-ai-consent-keeps-a-dropped-or-shared-photo-pending` (es de Jürgen) y cualquier cambio visible de UI.
