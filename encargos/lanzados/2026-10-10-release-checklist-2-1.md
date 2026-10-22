---
esfuerzo: medium
---
# Checklist de envío de 2.1 a App Store, verificada contra el código

**Card:** tablero-checklist-de-envio-de-2-1-a-app-store-ve-d0ui · **Prioridad:** high

Objetivo: `docs/RELEASE-CHECKLIST-2.1.md`, la lista que Jürgen sigue para enviar 2.1 a App Store, con cada punto VERIFICADO contra el código de origin/2.1 (cita fichero y línea).

## Que se pide (solo docs: no toques código, ni `Web/`, ni `marketing/`, ni App Store Connect)
1. **Etiquetas de privacidad (App Privacy):** inventario real de lo que sale del teléfono en 2.1: Modo Nube (Supabase: qué tablas, identificadores, cuenta Apple/Google), Grupos en el backend, IA (gateway, proveedores, qué se manda), tipos de cambio, analítica/crash si hay, compras. Propuesta de respuestas por categoría de Apple (Data Linked / Not Linked / Tracking) y diferencias con lo que hay hoy en la ficha.
2. **Política y términos:** qué dice hoy `yala-app.pe/privacy` y `/terms` (rama 1.0) y qué es falso con 2.1 (p. ej. «Grupos por CloudKit, no en servidores nuestros»). Enlaza el ticket `session-redesign-web-and-store-copy` (card i6tj); es bloqueante: tiene que estar en producción ANTES del envío. No lo edites tú.
3. **Capturas:** qué pantallas cambiaron desde 1.x y qué tamaños pide App Store hoy (iPhone 6,9", iPad 13" si aplica); lista de capturas a rehacer.
4. **Notas de la versión** (es, en y los idiomas que soporta la app) y **ficha** (subtítulo, descripción, keywords) con lo que realmente entra en 2.1, sacado de `tickets/done` y `tickets/qa`.
5. **Técnico:** versión y build, esquema de CloudKit en Production (enlaza el ticket `personal-cloudkit-schema-snapshot-misses-optional-fields`), migraciones y Worker/Edge desplegados, entitlements, cifrado (ITSAppUsesNonExemptEncryption), compras/suscripciones, cuenta de review con datos de prueba y notas para el revisor (Modo Nube, Grupos, borrado de cuenta in-app).
6. **Bloqueantes abiertos:** cards in qa high y blocked de 2.1 que deben cerrarse antes, con su id.
7. Cada punto con casilla, responsable (Jürgen, Lola o Frank) y estado verificado/no verificado.

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

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **Un solo fichero, `docs/RELEASE-CHECKLIST-2.1.md`.** Solo docs: sin código, sin `Web/`, sin `marketing/` y sin App Store Connect. El diff cae entero en `docs/` y `encargos/`, así que el gate se queda en la validación del índice.
2. **«Verificado» quiere decir medido en `origin/2.1` (6937828ff) con `fichero:línea`.** Lo que vive fuera del repo —consola de CloudKit, Supabase de producción, App Store Connect, la web publicada— queda «no verificado» con el comando que lo comprueba. No se toca ninguna de esas superficies: el encargo prohíbe ASC y no tengo por qué acceder a producción.
3. **Bloqueantes = cards de 2.1 en `blocked`, más las de `in qa` con prioridad `high`, más `session-redesign-web-and-store-copy` (i6tj).** Las de `espera decisión` medium se listan aparte, como «decidir si bloquean»: decidir eso es de Jürgen.
4. **Notas de la versión y ficha: borrador en es y en.** Los otros idiomas los traduce Lola en `marketing/`; aquí queda como tarea suya con casilla.
5. **Pase de estrés: no aplica.** Este encargo no toca UI. Se dice en el PR y en el cierre.
6. **Responsables:** Jürgen (ASC, consola, deploys, device-QA, decisiones), Lola (ficha, capturas, traducciones), Frank (lo verificable en código y los tickets que salgan).
