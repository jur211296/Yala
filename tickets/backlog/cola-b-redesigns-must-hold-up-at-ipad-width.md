---
id: cola-b-redesigns-must-hold-up-at-ipad-width
status: backlog
priority: medium
area: "design-system, settings, chat, accounts, ipad, cola-b"
created: 2026-09-26
updated: 2026-09-27
source: "exploración iPad (docs/exploracion/ipad-nativo.md §7), 2026-09-26"
---

# Los rediseños de Cola B tienen que valer también en el ancho del iPad

**Entra en Cola B.** No es trabajo aparte: es una lista de comprobación para que lo que se rediseña
ahora no haya que rehacerlo en la fase 1 de iPad.

## La lista

- [ ] **Ancho legible**: listas y formularios con tope de ~700 pt centrados cuando la pantalla es
      ancha, y `DS.Adaptive.horizontalPadding` como margen. Hoy tiene **un solo uso** en `Yala/`.
- [ ] [[settings-redesign-as-grouped-lists-like-ios]]: con `List` agrupada del sistema, no con tarjetas
      propias. Así la misma lista sirve como columna de una `NavigationSplitView` en iPad.
- [x] [[ai-chat-reads-heavier-than-a-messaging-app]]: la vista del chat no debe asumir que vive en una
      hoja (sin tirador ni cierre dentro del hilo). En iPad irá en un `.inspector`. **Hecho 2026-10-02**: sin
      tirador ni cierre en el hilo; en iPad va en columna propia (no `.inspector`, medido el 29-sep); hilo y caja
      topados a `DS.Adaptive.readableWidth`; capturado en iPhone 17 Pro y en `YalaLane-Adapt-iPad-Pro-13`.
- [ ] [[account-form-as-medium-detent-sheet]]: en iPad el detent medio no se aplica, porque
      `.yalaSheetDetents(_:)` fuerza `.large` en una ventana ancha (desde el 29-sep lo decide la ventana, no el
      aparato: [[sheet-size-follows-the-device-not-the-window]]). Decidirlo a propósito.
- [ ] [[panel-accounts-redesign]]: el detalle de cuenta, pensado para poder ir en columna en iPad.
- [ ] [[more-tab-missing-profile-button]]: Más deja de ser pantalla en iPad (barra lateral). No
      invertir en rediseñar Más como pantalla.
- [ ] Cada rediseño se captura también en `YalaLane-Adapt-iPad-mini` y `YalaLane-Adapt-iPad-Pro-13`, y en iPhone
      en `YalaLane-Adapt-iPhone-SE` y `-ProMax` con texto por defecto y AX5 (receta en
      `docs/exploracion/adaptativo-ipad-duo.md` §6.2).
- [ ] Nada decide por tipo de dispositivo ni por orientación: por size class o ancho del contenedor. Vale igual para
      el iPhone Duo abierto, que es un iPhone con ancho regular.

## Relacionados

- [[ipad-native-app]] — paraguas. [[floating-buttons-cover-row-amounts-on-ipad-landscape]].

## Reglas del carril adaptativo (obligatorias)

**Simulador** (Jürgen, 2026-09-27). Este carril usa simuladores dedicados creados con `xcrun simctl create` con
prefijo fijo `YalaLane-Adapt-` (p. ej. YalaLane-Adapt-iPhone-SE, YalaLane-Adapt-iPhone-ProMax,
YalaLane-Adapt-iPad-Pro-13, YalaLane-Adapt-iPad-mini) y los usa SIEMPRE por UDID (`-destination id=<UDID>`), nunca
por nombre genérico ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator` o tocar
simuladores sin ese prefijo (los usa la sesión de Cola A en paralelo). DerivedData propio del worktree
(`-derivedDataPath .ddp`). Receta para crearlos: `docs/exploracion/adaptativo-ipad-duo.md` §6.2.

**iPhone** (Jürgen, 2026-09-27). Se permiten mejoras de adaptación en iPhone si no rompen flujos ni ponen en riesgo
la release 2.1; cada una verificable en simulador con capturas antes/después en tamaños iPhone pequeño/grande y
Dynamic Type grande (`adaptativo-ipad-duo.md` §6.1).

**Layout** (ADR «[2026-09-27] Yala se adapta por espacio, no por dispositivo»). Se decide por size class y ancho del
contenedor, nunca por tipo de dispositivo ni orientación; un contenedor que se adapta, no un `if` por size class en
la raíz; APIs de iOS 27.1 solo tras `if #available`.
