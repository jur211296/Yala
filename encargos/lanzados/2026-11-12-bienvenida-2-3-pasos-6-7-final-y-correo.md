Yala
# Bienvenida 2.3 · Pasos 6 y 7, el final y el correo automático
card: tablero-bienvenida-2-3-paso-6-mira-a-donde-va-tu-3fcj,tablero-bienvenida-2-3-paso-7-anota-sin-abrir-ya-arjq,tablero-bienvenida-2-3-final-primeros-pasos-comp-l1c5,tablero-bienvenida-2-3-correo-automatico-i9d8
toca: Yala/App/Views/More/, Yala/App/Views/Panel/, Yala/App/Views/Subscription/, Yala/App/Logic/, Yala/App/Views/Settings/, YalaWidgets/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3, Yala/bienvenida-2-3-pasos-3-4-y-5-presupuesto-pagos-grupos

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 05 de 5 de la implementación oficial de Primeros pasos de Yala 2.3. Fuente: docs/onboarding-2-3/SPEC.md, cards Y23-14, Y23-16, Y23-18 y Y23-19. Prototipo oficial v35, pestaña 8 · Pasos 6 y 7: https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6. Depende del lote 04 (el mazo llega al paso 6). La oferta Pro es la opción C a 30 días, ya decidida; no se activa sola (norma Apple 3.1.2). «Tu correo» (Y23-19) es una feature nueva que todavía no existe; hasta que esté lista de verdad, el paso 7 muestra 4 maneras. No se reabren decisiones de experiencia.

## Encargo y criterio de terminado
Implementar SOLO estas 4 cards, cada una tal como está en su sección del SPEC:
1. Y23-14 · Paso 6 · Mira a dónde va tu dinero (atajo `#fin7`). Guía «Tus gráficas viven en Más» con foco en Estadísticas. El disparador «días después» es del lote 01 (Y23-15); no lo dupliques, solo úsalo.
2. Y23-16 · Paso 7 · Anota sin abrir Yala (atajo `#fin7-s_fin7.s7`). Mini tutoriales omitibles. Hay que construir sobre todo la guía de compartir (hoy no existe). Reutilizar widget, Apple Pay, la extensión de compartir y Siri. El mini tutorial del correo solo se muestra si Y23-19 está listo; si no, 4 maneras.
3. Y23-18 · Final · Primeros pasos completos y prueba de Pro de 30 días (atajo `#fin7-s_fin7.end`). Plan anual preseleccionado, línea de tiempo y aviso local el día 28. Precios reales de la App Store, no los marcadores del prototipo. Sin confirmar en la hoja de pago no hay Pro. Fuera de alcance: activar la prueba sola o regalar 30 días por la app.
4. Y23-19 · Correo automático (atajo `#fin7-s_fin7.mail`). Dirección por persona, gateway que lee el correo con IA, borrador a la Bandeja y el mini tutorial «Tu dirección de Yala» con «Copiar». «Pronto: conectar Gmail y Outlook» es solo el texto; no es esta card. No pises la card «Pedir la verificación de Google para leer Gmail» (es de Jürgen y es otro trabajo). Si falta infraestructura (DNS, buzón, claves, cupo o backend) que no está en el SPEC, para con `BLOQUEANTE:` y no inventes. Mientras esta feature no esté lista, no des esta card por hecha y deja el paso 7 en 4 maneras.

Reglas del lote:
- Los textos exactos y el comportamiento salen del SPEC y del prototipo. No se reabren decisiones. Si el artifact y la ficha no coinciden, manda la ficha y se avisa en el cierre.
- Compara con el prototipo (https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6, versión 35) y deja capturas antes y después de lo que se vea, en `capturas/` del worktree.
- Accesibilidad de la ficha «Cómo usar esta especificación»: Reducir movimiento deja solo fundidos y las páginas que avanzan solas se quedan quietas; VoiceOver no avanza solo; texto grande no corta.
- Textos en español neutro, con «tú», según docs/planning/BRAND-VOICE.md. Los textos marcados «de la app» se copian de Localizable.strings, no se reescriben.
- Un test de comportamiento por card (unit o XCUITest según `qa/coverage-index.json`). Review adversarial obligatoria.
- Si un punto exige una decisión de producto que no esté ya en el SPEC, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa. Infraestructura o un hueco del servidor: `BLOQUEANTE:`, sin inventar.
- No choques con otras sesiones de bienvenida ni con los lotes 2.3 ya en cola: si comparten fichero, rebasa y cita.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:55 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- La especificación oficial vive en `docs/onboarding-2-3/SPEC.md` (entró por el PR 873 en 2.2; tras el merge tiene que estar en origin/2.3). Léela completa para las cards de este lote y no implementes lo que sea de otra card.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve las cards a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0

Medido antes de decidir (2026-11-12, Max):

- 2.2 ya está en 2.3 (la punta de 2.2, «Merge pull request #909», es antecesora de `origin/2.3`; la rama 2.2 se borró).
- El lote 04 (PR 939) está en cola de auto-merge: la rama nace de su punta y se rebasa sobre `origin/2.3` antes del PR.
- El artifact v35 no se puede leer desde esta sesión; la fuente del prototipo está en la Max
  (`~/Claude/entregas/onboarding-yala-20261107/prototipo/fuente-actual/09j-final.js`) y es la que se compara.

Decisiones:

1. **Y23-14 (paso 6).** La guía `chartsStep` y sus textos los dejó el lote 01, idénticos a la ficha. Falta lo del
   prototipo: «Omitir» en la guía pasa el mazo al paso 7 (se da por omitido). Cambiar de pestaña a otra no lo resuelve.
2. **Y23-16 (paso 7).** Pantalla completa desde el mazo, como los pasos 3-5: página corta de 4 partes (patrón
   `TutorialStoryPage`), un mini tutorial por manera (widget, Apple Pay, compartir, Siri) y la pantalla «entre una y
   otra». Terminar con al menos una manera vista = paso hecho; todas omitidas u «Omitir este paso» = omitido; «Atrás»
   desde la primera parte = el mazo sigue en el 7. Apple Pay usa los pasos y la garantía de Tutoriales (textos de la
   app); Siri, las frases de la ficha (incluye «Nuevo registro en Yala», que existe en `AppShortcuts.xcstrings`).
3. **Y23-19 (correo).** El reenvío está programado (ticket `bank-email-forwarding-to-the-inbox` en `done`), pero el
   RUNBOOK del gateway dice «Nada desplegado» y el dominio `yalainbox.com` está pendiente de compra (card del dominio).
   No está listo de verdad ⇒ el paso 7 enseña 4 maneras, el mini tutorial del correo no se construye todavía (no hay
   servidor contra el que probarlo) y la card no se da por hecha. `BLOQUEANTE:` de infraestructura en el cierre.
4. **Y23-18 (final).** Tarjeta «¡Primeros pasos completos!» con chispas en las instalaciones con mazo; la oferta sube
   a los 1,6 s (0,2 s con Reducir movimiento, como el prototipo) por el router de siempre, con su diseño propio: anual
   preseleccionado con «El más elegido», precios reales de StoreKit, línea de tiempo y salida «Seguir con la versión
   gratis». **Duración: «1 mes» y fechas reales** (respuesta de Jürgen por su bot, 2026-11-12, y su decisión D21 del
   21-oct): la App Store no admite 30 días y la prueba configurada es P1M. Se avisa en el cierre que la ficha dice
   «30 días». Aviso local 2 días antes del primer cobro, solo tras confirmar en la hoja de pago.
5. **Permiso del aviso del final** (decidido por Jürgen, 12-nov, opción A): sin permiso de avisos no se promete el aviso;
   la línea de tiempo quita ese paso y el «¡Listo!» dice solo hasta cuándo va la prueba. El permiso de iOS se sigue
   pidiendo solo al elegir «sí, recuérdame» (Y23-17), sin provisional (la review mostró que el provisional apaga después
   la pregunta de los avisos de pagos, presupuestos y grupos).
