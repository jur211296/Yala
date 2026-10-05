# El alta de cuenta, en un sheet de media altura (medium detent)

## Contexto
Ticket: `tickets/backlog/account-form-as-medium-detent-sheet.md` (backlog, medium; idea Jürgen 2026-09-09).
Cola B autónoma (orden vivo): acaba de cerrar `cola-b-redesigns-must-hold-up-at-ipad-width` (PR #340 en cola de merge a 2.1). Cola A vacía; adaptive 13/13 hecho. Una sola sesión Yala a la vez.

Siguiente en la cola tras este: `panel-accounts-redesign` → `more-tab-missing-profile-button` → `trends-insight-card-v2-bullets` → barrido QA. NO los implementes aquí; Frank lanza el siguiente al `/cerrar-total`.

Medido en el ticket (2026-09-09, vigente en espíritu):
- Alta de cuenta: `.sheet(item: $sheets.accountFormSheet)` en `PanelSheetsModifier` sin `presentationDetents` en `AccountFormView` → toma el grande por defecto.
- El patrón ya existe: `DS.Adaptive.sheetDetents` / `.yalaSheetDetents(_:)` (decide por la ventana) y ~16 sheets ya abren en `[.medium]`.
- En iPad / ventana ancha, `.yalaSheetDetents` puede forzar `.large` (ver `sheet-size-follows-the-device-not-the-window`). Decidirlo a propósito y documentarlo en el PR — no inventar un bypass por `userInterfaceIdiom`.

Decisión YA tomada (no reabrir): el alcance es el **formulario de cuenta** (alta/edición), no el alta de transacción. El id del ticket y la checklist de Cola B lo fijan. Si el alta de transacción también merece medium, ticket propio `--solo-crear`, no este PR.

## Que se pide
1. Leer el ticket entero + relacionados citados (`panel-accounts-redesign` solo como contexto; no implementarlo).
2. Presentar el alta/edición de cuenta como sheet a media altura al estilo Wallet: `.presentationDetents` / `.yalaSheetDetents([.medium])` (o el helper del DS que ya usa el resto de la app), sin llevarse la pantalla entera cuando el espacio lo permite.
3. En ventana ancha (iPad / split): decidir a propósito qué detent aplica (respetando que el helper decide por ancho de ventana, no por aparato). Documentar la decisión en Paso 0 + PR. Nada de `if UIDevice` / orientación.
4. Verificar en simuladores dedicados `YalaLane-Adapt-*` por UDID (`-destination id=<UDID>`), nunca nombre genérico ni `booted`. Capturar al menos iPhone SE + ProMax y un iPad (mini o Pro-13). DerivedData en `.ddp` del worktree.
5. Pipeline SERIAL Mini (obligatorio): (1) limpiar sims muertos/basura (2) build `xcodebuild -jobs 2` SIN sim booteado (3) boot 1 solo sim (4) tests/capturas (5) apagar y erase/limpiar data de ese sim. Norma: **1 simulador a la vez**. Prohibido solapar swift-frontend + SpringBoard + app + UITests. No `shutdown all` / `erase all` / tocar sims sin prefijo `YalaLane-Adapt-`.
6. Gate verde. Un PR a `2.1` con auto-merge. Mover el ticket a done cuando cumpla. Board + `docs/TICKETS.md` al día. Hallazgos → ticket `--solo-crear`.
7. Al terminar: **`/cerrar-total` autónomo**. Deja Mini limpia: apagar sim → erase/limpiar data del device → si PR mergeado/worktree inútil quitar worktree+`.ddp` → kill tmux. Mientras el PR solo esté en cola de merge, conserva el worktree. No acumular Devices apagados ni worktrees.

## Que NO hay que tocar
- No Cola A en paralelo. No marketing/. No clinicas.
- No implementar: `panel-accounts-redesign`, `more-tab-missing-profile-button`, `trends-insight-card-v2-bullets`, barrido QA.
- No cambiar el alta de transacción a medium en este PR (ticket aparte si aplica).
- No secrets nuevos en Llavero; si creas alguno, anótalo explícitamente en el cierre para 1Password.
- Disco ~31 GB libres en Data (umbral limpiar-mac 32 GB): no llenar DerivedData; limpia `.ddp` al cerrar si el worktree se retira.

## Como se sabe que esta bien
- Alta/edición de cuenta abre a media altura donde el espacio lo permite; en ancho regular la decisión de detent está documentada y es coherente con `.yalaSheetDetents`.
- Capturas iPhone (+ AX si toca el layout) e iPad; gate verde; PR en cola de merge a 2.1; ticket done; Mini limpia tras `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, merge/auto-merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen (secreto, deploy, o ambigüedad de producto que no cubra el Paso 0). El Paso 0 lo escribes tú al final del encargo y te lo auto-contestas (opción robusta alineada con el ticket); no esperes rondas.

## Paso 0

*Auto-contestado (MODO AUTÓNOMO), 2026-10-03. Medido en `0566959d0`.*

1. **¿`[.medium]` a secas o `[.medium, .large]`?** → **`[.medium, .large]`, abriendo en medium.** El formulario no
   son «dos campos»: General, guía contextual, Divisa (con un selector que empuja una lista), Tarjeta de crédito,
   Ajuste, Saldo, enlace a la calculadora y Acciones, más el teclado que se abre solo en el alta. Un `[.medium]`
   cerrado obliga a hacer todo eso por una rendija de media pantalla. Abrir en medium y dejar tirar hacia arriba es lo
   que hace Wallet y lo que ya hacen `DatePickerSheet` y `TransactionAssociationSheet`.
2. **¿Dónde se declara?** → **Dentro de `AccountFormView`**, como `DatePickerSheet`. Cubre los tres sitios que lo
   presentan (Panel, alta y edición en Ajustes › Cuentas) y la vista ya necesita el detent para elegir fondo. Medido:
   `AccountFormView(` solo se presenta como hoja.
3. **Alta y edición** → las dos. Es el mismo formulario; el ticket dice «crear o editar».
4. **Ventana ancha (iPad a pantalla completa, Duo abierto, Mac)** → **se respeta `.yalaSheetDetents`: fuerza
   `.large`**, igual que el resto de formularios. En ancho regular la hoja de iPad sale como hoja de formulario
   centrada y un medium ahí se queda corto. Sin `UIDevice` ni orientación. En iPad con ventana estrecha o Split View
   el espacio es de iPhone y abre en medium.
5. **Fondo** → medium: `.transparent` (fondo de sistema, convención de hojas parciales); grande —arrastrada o forzada
   por la ventana—: `.subtle`, el de hoy. El «grande» se lee como `usesLargeSheets || selectedDetent == .large`: con la
   ventana ancha el helper fuerza `[.large]` pero `selectedDetent` se queda en `.medium`, y mirar solo el detent
   dejaría una hoja grande sin fondo.
6. **Fuera:** el alta de transacción (decidido en el encargo), las hojas internas del formulario (color, calculadora)
   y el rediseño de cuentas del Panel.
7. **Texto de accesibilidad (AX1–AX5)** → **abre grande** (`[.large]`). *Decidido tras medir*: en el iPhone SE con
   AX5, media altura enseña la cabecera «General» y un solo campo, y el gesto deja de servir. Con tamaños normales,
   medium.
