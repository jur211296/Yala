# Con «Grupos en el total» apagado, el total de Yala IA deja de sumar las cuentas de Grupos, igual que el Panel

## Contexto
Card del tablero `tablero-con-grupos-en-el-total-apagado-yala-ia-s-snvr` (lista para lanzar, prioridad low). Ticket: `tickets/backlog/chat-total-ignores-the-panel-groups-toggle.md` (salió del PR #418, `chat-context-archived-accounts-and-mtd`).

**Decisión de Jürgen (2026-10-09 13:18): opción A.** El total de Yala IA sigue el ajuste «Grupos en el total» del Panel, y las cuentas de Grupos siguen listadas en `balances.accounts` para que la IA pueda nombrarlas. No hay nada más que decidir.

CADENA tras cerrar `exchange-rate-readable-in-any-currency` (PR #420 en cola de auto-merge a 2.1; card 8amy en done). No depende de ella: trabaja sin esperarla.

Lo que le pasa al usuario: apaga en Ajustes que las cuentas de Grupos sumen en el total del Panel. El Panel deja de contarlas, pero Yala IA las sigue sumando cuando le pregunta «¿cuánto tengo en total?».

Pistas del ticket (verifícalas en este árbol antes de tocar nada):
- El Panel recorta las cuentas sistema de Grupos con `PanelTotalAccountsLogic.accountsForTotal(..., includeGroups: appPreferences.includeGroupsInPanelTotal, ...)` en `PanelViewModel.displayedBalanceInDefaultCurrency`.
- `FullFinancialContextBuilder.buildBalances` usa desde el PR #418 `PanelTotalAccountsLogic.countableAccounts`, pero no lee el ajuste: el builder no recibe preferencias. Hay que pasárselo (inyectado, para poder testearlo) desde quien construye el contexto del chat.
- El prompt del chat vive en la app (`ChatAssistantService`). Si el total cambia de significado, que el prompt diga en una línea que el total sigue el ajuste del Panel. No renumeres las reglas 16 y 17: el banco las busca literalmente.
- El conector de Claude (`mcp/`) no conoce las preferencias del teléfono. No lo toques; si su golden de paridad se pone rojo, para y anótalo en el cierre en vez de cambiar el conector (cambiarlo obligaría a desplegarlo).

**Sin gasto de API**: los créditos los paga Jürgen. Nada de corridas del banco ni llamadas de pago a modelos; todo se prueba con tests locales. Si la réplica TS del contexto en `gateway/bench/lib/chatContext.ts` necesita el campo para seguir igual que la app, actualízala y pasa `npm test` del gateway en local, sin red.

Para orientarte: `CLAUDE.md`, `.claude/rules/session-filters.md`, `.claude/rules/testing.md` y el ticket.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de producto o de riesgo nueva, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket.

## Que se pide
1. Test rojo con el código de hoy: con `includeGroupsInPanelTotal = false`, el total del contexto del chat coincide con el del Panel (sin las cuentas de Grupos); con `true`, las incluye, igual que el Panel. Las cuentas de Grupos siguen apareciendo listadas en los dos casos.
2. Pasar el ajuste al builder (inyectado) y aplicar la misma regla que el Panel con `PanelTotalAccountsLogic.accountsForTotal`. Una sola fuente de verdad, sin copiar la lógica.
3. Ajustar en una línea el prompt si hace falta para que la IA sepa qué incluye el total.
4. Tests de paridad con el Panel en los dos valores del ajuste; control rojo con el código viejo. Builds `Yala` y `Yala Dev` verdes.
5. Anota lo hecho en el ticket y muévelo según las convenciones del repo; `coverage-index` si aplica.
6. Card `snvr`: sin cambio visible → **done → frank**.
7. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, card bien puesta, quitar worktree/tmux/DerivedData/cachés de XcodeBuildMCP de este worktree, ningún sim encendido).
8. Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).

## Que NO hay que tocar
- El Panel, Estadísticas ni los widgets: ya siguen el ajuste.
- El conector `mcp/` ni el Worker del gateway (nada que desplegar).
- Ni secretos ni llamadas de pago a APIs de IA.
- No relajar aserciones existentes.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. Disco: ~28 GB libres el 2026-10-09, por debajo del umbral de 32; si baja de ~20 GB, para, limpia y sigue.
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador. Si hay otro simulador o un `xcodebuild` ajeno corriendo (`xcrun simctl list devices booted`, `pgrep -fl xcodebuild`), no lo toques: espera a que la Mini quede libre.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Rebase al final, sin esperar a nadie: la sesión arranca ya sobre `origin/2.1` y trabaja sin esperar el CI de ningún otro PR. Justo antes de abrir su PR, hace `git fetch` y rebasa sobre `origin/2.1`, y resuelve ahí cualquier conflicto (el ruleset de `2.1` tiene strict=false). Si el rebase trajo cambios que tocan lo suyo, vuelve a compilar y a correr los tests afectados sobre el árbol rebasado, con un solo simulador.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Con «Grupos en el total» apagado, el total del contexto de Yala IA es el del Panel; encendido, también. Las cuentas de Grupos siguen listadas.
- Tests con control rojo con el código viejo; builds verdes; golden del conector sin cambios.
- PR a 2.1 en auto-merge, ticket movido, card en done, Mini limpia.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cómo llega el ajuste al builder?** → Parámetro `includeGroupsInTotal: Bool` en `build(...)` (obligatorio) y en `buildFromArrays(...)` (default `true`, el default del ajuste). Lo lee `ChatAssistantViewModel` de `AppPreferences` (inyectado por `ChatSheetView` con `setAppPreferences`, molde de `PanelViewModel`) y lo pasa por `ChatAssistantService.processQuestion` (obligatorio).
Por qué: inyectado y testeable sin `UserDefaults.standard`; obligatorio en producción para que ningún camino lo olvide. Alternativa descartada: leer la key de `UserDefaults` en el builder (duplica la carga de `AppPreferences` y no se inyecta).

**D2 · ¿Cómo sabe el modelo qué incluye el total?** → Campo nuevo `balances.total_includes_groups` en el JSON y una línea estática `15b. SALDO TOTAL` en el prompt que lo explica (cuentas de Grupos = `type` "system").
Por qué: el prompt estático no lleva interpolación nueva (el banco interpola por nombre y la parte estática es la cacheable); el dato viaja en la parte dinámica. Alternativa descartada: interpolar el ajuste en la parte estática (rompe la caché de prefijo y obliga a tocar el banco).

**D3 · Caché de 60 s del builder** → La entrada guarda el ajuste y no se sirve si cambió.
Por qué: apagar el ajuste entre dos preguntas daría el total viejo un minuto.

**D4 · Réplica TS del banco** → Añade `total_includes_groups: true` (sus personas no tienen cuentas de Grupos); `npm test` local. El conector `mcp/` no se toca.

**D5 · Numeración** → La regla nueva es `15b`; 16 y 17 intactas.
