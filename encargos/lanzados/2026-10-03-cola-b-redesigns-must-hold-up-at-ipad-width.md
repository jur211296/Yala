# Los rediseños de Cola B tienen que valer también en el ancho del iPad

## Contexto
Ticket: `tickets/backlog/cola-b-redesigns-must-hold-up-at-ipad-width.md`.
Cola autónoma Jürgen 2026-10-02 (sigue activa): tras floating-buttons (PR #339 en cola de merge a 2.1), toca este.
Cola A vacía; adaptive 13/13 hecho. Una sola sesión Yala a la vez.

Es la lista de comprobación Cola B: lo que ya se rediseñó (y lo que falta de este ticket) no debe rehacerse en la fase 1 de iPad. Settings agrupadas (PR #331) y chat mensajería (PR #332) ya están; floating-buttons (PR #339) en cola. Los tickets siguientes de la cola (account-form-as-medium-detent-sheet → panel-accounts-redesign → more-tab-missing-profile-button → trends-insight-card-v2-bullets) NO se implementan aquí: van después.

## Qué se pide
1. Leer el ticket completo y cumplir lo que queda de su lista (items no hechos), sin soltar los tickets siguientes de la cola.
2. **Ancho legible**: listas/formularios de los rediseños Cola B ya shippeados (Settings, chat, y pantallas tocadas por ellos) con tope ~700 pt centrados en ancho regular y `DS.Adaptive.horizontalPadding` como margen. Hoy tiene muy pocos usos — aplicar donde falte en lo ya rediseñado.
3. Verificar Settings (listas agrupadas) y chat en iPad: sirven como columna / no asumen hoja; capturar en `YalaLane-Adapt-iPad-mini` y `YalaLane-Adapt-iPad-Pro-13`, y en iPhone `YalaLane-Adapt-iPhone-SE` + `-ProMax` (default + AX5). Receta `docs/exploracion/adaptativo-ipad-duo.md` §6.2.
4. Nada decide por tipo de dispositivo ni orientación: size class o ancho del contenedor (ADR 2026-09-27). Vale igual para Duo abierto.
5. Si faltan sims `YalaLane-Adapt-*`, créalos UNA vez con runtime iOS 27.0. Usa siempre `-destination id=<UDID>`, nunca nombre genérico ni `booted`. DerivedData en `.ddp` del worktree. Sims actuales (Shutdown): SE `0D705C9A-30E1-44A3-BB28-940B452FDF15`, ProMax `72EB411B-3CCF-4DB0-A5C4-79949C19740D`, iPad-mini `A7086B76-4ED5-4FAE-806F-6A3D0F2E5900`, iPad-Pro-13 `DE089C7E-9F12-4CC4-AB50-592A3F87BD4C`.
6. Pipeline SERIAL Mini (obligatorio): (1) limpiar sims muertos/basura (2) build `xcodebuild -jobs 2` SIN sim booteado (3) boot 1 solo sim (4) tests/capturas (5) apagar y erase/limpiar data de ese sim. Norma: 1 simulador a la vez. Prohibido solapar swift-frontend + SpringBoard + app + UITests. No `shutdown all` / `erase all` / tocar sims sin prefijo YalaLane-Adapt-.
7. Evidencia bajo `qa/evidencia-adaptativo-AAAAMMDD/cola-b-redesigns-must-hold-up-at-ipad-width/`. Gate verde. PR a 2.1 con auto-merge. Ticket a done cuando cumpla.
8. Al terminar: `/cerrar-total` autónomo. Deja Mini limpia: apagar sim → erase/limpiar data del device → si PR mergeado/worktree inútil quitar worktree+.ddp → kill tmux. Mientras el PR solo esté en cola de merge, conserva el worktree. No acumular Devices apagados ni worktrees.

## Qué NO hay que tocar
- No Cola A en paralelo. No marketing.
- No implementar aún: `account-form-as-medium-detent-sheet`, `panel-accounts-redesign`, `more-tab-missing-profile-button`, `trends-insight-card-v2-bullets` (siguientes de la cola).
- En Más/iPad: no invertir en rediseñar Más como pantalla (el ticket lo dice: en iPad deja de ser pantalla / barra lateral).
- No secrets nuevos en Llavero; si creas alguno, anótalo para 1Password al cerrar.
- Disco ~28–30 GB libres (umbral limpiar-mac 32 GB): no llenar DerivedData; limpia `.ddp` al cerrar si el worktree se retira.

## Como se sabe que esta bien
Lista del ticket marcada/cumplida para lo de este encargo; capturas iPad+iPhone (default+AX5); gate verde; PR en cola de merge a 2.1; Mini limpia tras `/cerrar-total`.

## Paso 0 (Frank, 2026-10-03, auto-contestado: MODO AUTÓNOMO)

Medido en el árbol `b474ce098` antes de decidir:

- **Ancho legible ya está en los dos rediseños.** Las seis pantallas migradas a lista agrupada
  (Personalización, Privacidad IA, Resumen IA, Divisa, Vaciar datos, Tutoriales) usan `YalaSettingsList`,
  que topa a 700 pt con `readableListMargin` medido por ancho. El hilo y la caja del chat, topados a
  `readableWidth` (`ChatSheetView.swift:525`). Ajustes ya es lista-detalle en ancho (commit `20a5520a7`).
  ⇒ El «un solo uso» del ticket envejeció. Decisión: **no tocar código a ciegas**; capturar y medir el
  ancho real de los bloques en los 4 simuladores, y solo si algo de lo rediseñado pasa de ~700 pt o no
  lleva el margen adaptativo, arreglarlo.
- **«Pantallas tocadas por ellos»** = la lista de Ajustes (columna del split), las seis migradas y el chat.
  Las demás de Settings (listas de cosas: cuentas, categorías…) NO son rediseño de Cola B: su ancho legible
  es fase 1 (`ipad-sidebar-and-list-detail-for-records-and-planning`, en qa) y Reportes/Buscar tienen
  ticket propio. Asumido.
- **Items 4-6 del ticket** (account-form, panel-accounts, more-tab): son los tickets siguientes de la cola.
  Aquí no se implementan; en la lista quedan anotados como «va en su ticket», no marcados.
- **Item «nada decide por aparato»**: se verifica por grep (`userInterfaceIdiom`, `UIDevice`, orientación)
  sobre `Yala/`. Medido: los 4 usos de `UIDevice` son identificador/versión, no layout.
- **No tocar `DesignTokens.swift`** si se puede: el PR #339 (en cola) lo modifica.
- Evidencia con un XCUITest temporal (borrado antes del commit) que abre cada pantalla, mide el marco de
  las celdas frente a la ventana y captura. Simuladores de uno en uno, por UDID, iOS 27.0.
