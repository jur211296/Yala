# En iPad, estrechar la ventana con Grupos abierto ya no cierra la app

## Contexto
Cierre limpio de PR #302 (Cola A: el aviso del cambio de Apple ID ahora dice, cuando toca, que también se quitan los grupos del teléfono). Orden Jürgen 2026-09-29 ~20:35 Lima: el ticket high `ipad-narrowing-the-window-on-groups-crashes-the-app` **frena la release 2.1** — arreglarlo antes de ship, y lanzarlo justo después de apple-id-close-notice (antes que el siguiente paso del carril adaptativo). Una sola sesión Yala a la vez.

Ticket: `tickets/backlog/ipad-narrowing-the-window-on-groups-crashes-the-app.md` (high). Viene de la fase 1 (`4534371bf` / #299), no de la fase 2: medido otra vez con `2.1` limpio. Stack: `*** -[__NSArrayM insertObject:atIndex:]: object cannot be nil` en `UITabBarController _tabs_rebuildTabBarItemsAnimated:` al pasar a compacta con Grupos (sexta página) seleccionado. Con Registros no pasa. Hipótesis sin medir: posición en la lateral. Lee el ticket entero, `swiftui-ds.md` «Layout adaptativo», `RootTabLayoutLogic`, y lo medido en #299/#301.

## Qué se pide
Cierra el ticket.

1. Reproducir el crash en `YalaLane-Adapt-iPad-Pro-13` (Apps en ventanas, horizontal, Grupos seleccionado; erase del sim si la ventana recuerda tamaño). Confirmar también con las otras páginas de la lateral si hace falta acotar.
2. Arreglar sin romper la navegación adaptativa ya en 2.1 (sidebarAdaptable + list-detail). No ocultar pestañas con `.hidden(_:)` de la pestaña seleccionada (ya crasheó en fase 1). La prueba `.defaultVisibility(.hidden, for: .tabBar)` ya falló y se revirtió — no la repitas como único plan.
3. «Hecho cuando» del ticket: estrechar con cada una de las seis páginas (y con un grupo abierto) no cierra la app; el grupo abierto sigue a la vista empujado. XCUITest que lo cubra.
4. Evidencia solo en simuladores `YalaLane-Adapt-*` por UDID, DerivedData del worktree (`.ddp`):
   - `YalaLane-Adapt-iPad-Pro-13` → `8B01FB45-08DB-4816-9CBD-E42F6F4950E6` (recreado 2026-09-29; el UDID viejo `AE7C6D3F-…` ya no existe)
   - `YalaLane-Adapt-iPad-mini` → `8BBAB498-9F59-40D6-9101-5CF4C0CCC7F3`
   - `YalaLane-Adapt-iPhone-ProMax` → `CDA87FB8-1261-431E-B85B-62786395C8F9`
   (El SE Adapt no está en la máquina; no lo crees salvo que el gate lo exija de verdad.)
5. Gate verde, PR a `2.1`, merge, board del repo, `/cerrar-total`.

## Decisiones ya tomadas (Frank; no las vuelvas a preguntar)
- Este ticket **bloquea 2.1** para iPad: hay que shippear el fix.
- Layout por espacio, no por aparato (ADR vigente). Reusa `RootTabLayoutLogic` / patrones de #299–#301.
- Si un subcaso no cabe (p. ej. solo una página rara): ticket propio, no ampliar alcance.
- iPhone compact no debe cambiar comportamiento (medir en ProMax).

## Qué NO hay que tocar
- Simuladores sin prefijo `YalaLane-Adapt-`. Siempre `-destination id=<UDID>`, nunca por nombre ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator`.
- No instalar Xcode 27.1 ni crear el simulador Duo.
- No arrancar Cola A / sync / nube ni Cola B.
- No abrir otra sesión Yala en paralelo.
- Producción / deploy.
- Disco: limpia DerivedData y scratchpads propios al cerrar (~42 GB libres ahora).

## Cómo se sabe que está bien
Criterios «Hecho cuando» del ticket + XCUITest + gate verde + PR mergeado a `2.1` + cierre limpio. Residual a ticket propio.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge, board (`tickets/` y `docs/TICKETS.md`) y `/cerrar-total` sin preguntar. Ahora es noche (≥21:00 Lima): no preguntes; elige la opción recomendada o aplaza a ticket si el riesgo es alto (datos/prod/irreversible).

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR; (3) terminaste y vas a /cerrar-total, con resumen corto en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro, una vez. NO avises por test rojo que vas a reclasificar ni ruido de CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Se arregla antes de medir la causa?** → No. Primero un sondeo XCUITest temporal por página (las seis) en el
iPad Pro 13 con «Apps en ventanas», erase entre corridas; el fix sale de lo medido.
Por qué: la hipótesis del ticket (posición en la lateral) está sin medir. Alternativa descartada: probar fixes a ciegas.

**D2 · ¿Dónde vive el arreglo?** → En `RootTabLayoutLogic` (qué pestañas y en qué orden) y su uso en `MainTabView`,
con unit test. Sin `.hidden(_:)` ni `.defaultVisibility` como plan único (prohibidos por el encargo).
Por qué: es la pieza que decide la lista de pestañas que UIKit reconstruye. Alternativa descartada: parche en la vista
de Grupos, que no explicaría por qué solo pasa con ciertas páginas.

**D3 · ¿Cómo cubre el XCUITest seis páginas si la ventana no se puede ensanchar de vuelta?** → Un caso por página (y
uno con un grupo abierto) en `AdaptiveNavigationUITests`; cada uno arranca con la ventana a pantalla completa. Si al
arrancar la ventana no está a pantalla completa o no hay «Apps en ventanas», el caso lo dice con `XCTSkip` explícito
(no pasa en verde en silencio); en iPhone se salta (no hay ventana que estrechar). La corrida de evidencia se hace
con erase entre casos, por UDID.
Por qué: la ventana recuerda su tamaño y XCUITest no sabe ensancharla. Alternativa descartada: un solo caso que
recorra las seis en un arranque (imposible sin volver a ancho).

**D4 · iPhone** → sin cambio de comportamiento; se mide en ProMax (barra de pestañas igual que antes).

**D5 · Residual** → cualquier subcaso que no quepa va a ticket propio.
