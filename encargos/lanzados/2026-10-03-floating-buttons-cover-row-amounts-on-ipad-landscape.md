# En iPad (y iPhone) en horizontal, los botones flotantes dejan de tapar los importes de las filas

## Contexto
Ticket Cola B: `tickets/backlog/floating-buttons-cover-row-amounts-on-ipad-landscape.md`.
Cola autónoma Jürgen 2026-10-02: tras commit de notas de encargos (PR #338 en cola de merge), toca este.
Cola A vacía; adaptive 13/13 hecho. Una sola sesión Yala a la vez.

Antes: en iPad Pro 13 horizontal (y también iPhone SE/Pro Max al final del scroll, y Pro Max girado), Yala IA y «+» tapan el importe de las filas de abajo en Registros, Planificación y Grupos.
Después: margen inferior del scroll = alto de la pila de botones (contentMargins / safeAreaInset), última fila visible por encima. Buscar todas las pantallas con `fab_` en identificadores.

## Qué se pide
1. Leer el ticket completo y seguir sus «Hecho cuando» y reglas del carril.
2. Si faltan los sims `YalaLane-Adapt-*`, créalos UNA vez con runtime iOS 27.0 (`com.apple.CoreSimulator.SimRuntime.iOS-27-0`) según `docs/exploracion/adaptativo-ipad-duo.md` §6.2 (SE, ProMax, iPad-mini, iPad-Pro-13). Usa siempre `-destination id=<UDID>`, nunca nombre genérico ni `booted`. DerivedData en `.ddp` del worktree.
3. Pipeline SERIAL Mini (obligatorio): (1) limpiar sims muertos/basura (2) build `xcodebuild -jobs 2` SIN sim booteado (3) boot 1 solo sim (4) tests/capturas (5) apagar y erase/limpiar data de ese sim. Norma: 1 simulador a la vez. Prohibido solapar swift-frontend + SpringBoard + app + UITests. No `shutdown all` / `erase all` / tocar sims sin prefijo YalaLane-Adapt-.
4. Reservar sitio inferior para FABs en todas las pantallas con `fab_`; listarlas en el ticket/PR.
5. Evidencia antes/después en Adapt-iPad-Pro-13 horizontal (Registros, Planificación, Grupos) y Adapt-iPhone-SE + ProMax al final del scroll (default + AX5), bajo `qa/evidencia-adaptativo-AAAAMMDD/floating-buttons-cover-row-amounts-on-ipad-landscape/`.
6. Gate verde. PR a 2.1 con auto-merge. Ticket a done cuando cumpla.
7. Al terminar: `/cerrar-total` autónomo. Deja Mini limpia: apagar sim → erase/limpiar data del device → si PR mergeado/worktree inútil quitar worktree+.ddp → kill tmux. No acumular Devices apagados ni worktrees.

## Qué NO hay que tocar
- No Cola A en paralelo. No marketing. No soltar otros tickets Cola B (van después: cola-b-redesigns-must-hold-up-at-ipad-width, account-form-as-medium-detent-sheet, panel-accounts-redesign, more-tab-missing-profile-button, trends-insight-card-v2-bullets).
- No cambiar qué hacen los botones; solo layout/margen.
- No secrets nuevos en Llavero; si creas alguno, anótalo para 1Password al cerrar.

## Como se sabe que esta bien
Capturas antes/después cumplen el ticket; pantallas `fab_` listadas; gate verde; PR en cola de merge a 2.1; Mini limpia tras `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: hay **7 pantallas con botón flotante** (Panel, Estadísticas › Registros, Registros,
Presupuestos, Pagos planificados, Grupos, detalle de grupo). Las cuatro de un solo botón ya reservan 100 pt dentro del
scroll (`DS.Spacing.safeBottom`), y su botón ocupa 80 (56 + 24 de margen). Las de dos botones (Yala IA + «+») no:
Registros y Estadísticas › Registros reservan 100 para una pila de 148, y el Panel solo 32. Las capturas del ticket de
Planificación y Grupos son a mitad de scroll, no al final.

**D1 · ¿Qué mecanismo reserva el sitio?** → Margen inferior **dentro del contenido del scroll**, cuyo valor sale de una
sola función del DS calculada con los mismos tokens que dibujan la pila (`fabSize`, `Spacing.md`, `Spacing.xxl`).
Por qué: el scroll ya suma el área segura por debajo, así que el margen es relativo a ella (lo que pide la nota del
Duo), y es el mecanismo que ya usan las cuatro pantallas que funcionan. Alternativa descartada: `contentMargins` en el
contenedor — se hereda a los scroll horizontales de dentro (chips de filtros) y les metería margen inferior.

**D2 · ¿Cuántos botones cuenta la reserva de las pantallas de dos?** → Siempre dos, aunque el usuario haya ocultado Yala
IA. Por qué: 68 pt de más al final de la lista no se ven como fallo; quedarse corto sí. Alternativa descartada: leer la
preferencia en `RecordsTabView` — acopla la lista a una preferencia de los botones para ahorrar un hueco.

**D3 · ¿Se tocan las cuatro pantallas de un botón?** → No, si la medición al final del scroll da cero textos tapados.
Por qué: ya cumplen (100 ≥ 80 + holgura) y cambiarles el token es mover lo que funciona. Se revisan, se miden y se
listan en el ticket. Si alguna sale tapada, entra.

**D4 · ¿Y la pila desplegada (menú de cuatro acciones)?** → Fuera. Es un menú temporal que se cierra al tocar; tapar la
lista mientras está abierto es su función.

**D5 · ¿Cómo se mide?** → XCUITest temporal (se borra antes del commit) que baja hasta el final en cada pantalla y cuenta
los textos cuyo marco cruza el de los botones. Antes = árbol base; después = árbol del PR. iPad Pro 13 en horizontal;
SE y Pro Max en vertical y girados, a tamaño por defecto y AX5.
