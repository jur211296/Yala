# Con el kill-switch de Grupos abajo, «Asociar una cuenta» ya no abre un sign-in contra un canal apagado

## Contexto
Cola A (riesgo real, medium). Ticket: `tickets/backlog/associate-cta-ignores-the-groups-kill-switch.md`.
Carril: una sola sesión Yala a la vez (alternancia Cola A ↔ adaptive). Adaptive 13/13 ya cerró; esta es la Cola A que quedó interrumpida cuando entró el fix de CI #327 — retómala desde cero sobre `origin/2.1` fresco.
Día (Lima): si hace falta una decisión de producto/riesgo, pregunta; si no, decide en autónomo.

## Qué se pide
1. Lee el ticket entero y mide en código actual (no asumas el snapshot del 11-sep): el CTA «Asociar una cuenta» en Ajustes → «¿Dónde viven tus datos?» y el drenado de `presentGroupsSignIn` deben respetar `CloudRemoteFlags.groupsBackendEnabled` (o el flag vigente equivalente).
2. Comportamiento esperado: con el canal de Grupos matado remotamente, ese CTA no lleva a crear/entrar en una cuenta contra un backend en pausa. O bien el CTA se oculta/deshabilita y la sección explica por qué no está disponible, o (solo si mides que el sign-in con canal apagado es aceptable de producto) corriges los comentarios/docs que prometen un gate que no existe — y documentas el porqué en el PR.
3. Preferencia: gate real en el CTA + copy clara en la sección. No dejes afirmaciones falsas en comentarios (`ContentView` drenado / `GroupsSignInView`).
4. Tests que cubran kill-switch OFF → CTA no presenta sign-in; kill-switch ON → flujo intacto.
5. Mueve el ticket a `qa` (o `done` si no aplica device-QA) y deja el PR en cola de auto-merge a `2.1`.

## Pipeline Mini (obligatorio — serial, 1 sim)
1. Limpiar sims muertos / basura previa
2. Build con `xcodebuild -jobs 2` **sin** sim booteado
3. Boot **1** solo sim
4. Tests
5. Apagar y erase/limpiar data de ese sim
Prohibido solapar swift-frontend + SpringBoard + app + UITests. Norma flota: 1 sim a la vez.

## Qué NO hay que tocar
- No CI de GitHub runner / workflows salvo que el ticket lo pida (no lo pide).
- No marketing/, no clinicas.
- No CloudKit Production schema ni cambios de infra ajenos al CTA/kill-switch.
- No relanzar adaptive ni otro ticket en paralelo.

## Cierre
Al terminar (PR listo o bloqueo real): `/cerrar-total` **autónomo** sin esperar. Deja la Mini limpia: apagar sim de la sesión → erase/limpiar data del device → si el PR ya mergeó o el worktree ya no sirve, quitar worktree + `.ddp`/caches → no acumular Devices apagados ni worktrees. No dejes la sesión colgada.

## Cómo se sabe que está bien
- Con kill-switch de Grupos OFF, el CTA no abre sign-in contra canal apagado; la UI lo deja claro.
- Con kill-switch ON, asociar sigue funcionando.
- Gate/tests verdes en local; PR a `2.1` con auto-merge; ticket fuera de backlog.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Gate real o corregir los comentarios?** → Gate real en la sección «Grupos» de «¿Dónde viven tus datos?».
Por qué: firmar contra un canal matado es una cuenta real sin nada detrás; el encargo prefiere el gate. Alternativa descartada: aceptar el sign-in y corregir solo los comentarios — no hay motivo de producto medido para aceptarlo.

**D2 · ¿Dónde vive el gate: en el CTA o en el drenado de `.presentGroupsSignIn` (ContentView)?** → En el CTA. El drenado no se gatea; sus comentarios se corrigen para decir la verdad.
Por qué: medido, todos los demás productores ya deciden con el flag antes de submitear (crear grupo y form → `GroupCreateRoutingLogic`, empty states y onboarding del tab → `flagOn`, invitaciones → `GroupInviteChannelRoutingLogic`, re-unirse → `GroupBackendCapability.current`); el CTA de Ajustes era el único que no. Un guard silencioso en el drenado dejaría sin salida un flujo ya abierto (el re-ofrecimiento «Usar otra cuenta» del organizador) y un toque sin respuesta. Alternativa descartada: guard en el drenado — mudo para el usuario y con caminos muertos.

**D3 · ¿Qué ve el usuario con el canal matado?** → La sección mantiene su texto y, en lugar del botón «Asociar» / «Entrar», una nota: los grupos están en pausa por algo de nuestro lado y podrá seguir desde aquí cuando vuelvan. «Desasociar» se queda (es teardown y ya avisa él con `channelPaused`).
Por qué: el encargo pide que la sección explique por qué no está disponible. Alternativa descartada: botón deshabilitado sin explicación.

**D4 · ¿Con qué snapshot se decide?** → Al tocar: `refreshIfDue(force: true)` y luego se lee `CloudSyncFlags.groupsBackendEnabled`; si sale apagado, alerta con el copy existente `welcome.groups.channelOff*` (precedente de crear grupo) y la sección pasa a la nota. Al montar en pausa: un refresh forzado para que un kill ya levantado no deje la nota hasta 6 h.
Por qué: el snapshot puede tener hasta 6 h; «la intención del usuario es evidencia» (regla C4). Bajo `-uitest` no se toca red, como en el tab.

**D5 · Copy nuevo** → Una key, `storage.groups.channelPausedNote`, en los 16 locales.
Por qué: los textos de pausa existentes hablan de «tus cambios siguen…» o de «no se ha guardado nada», que no describen la sección en reposo.

**D6 · Tests** → Tabla pura `GroupsAssociationLogic.signInEntry` (OFF → `.channelPaused`, ON → flujo intacto) + source-scan del orden refresh-antes-de-leer en el CTA; los XCUITest existentes de la sección cubren el ON (bajo `-uitest` el flag es ON en Yala Dev; el OFF no es alcanzable en el harness, ver `GroupCreateRoutingLogic`).

**D7 · ¿ADR?** → No. Es un arreglo de un CTA; la convención ya existe (las entradas leen el compuesto).
