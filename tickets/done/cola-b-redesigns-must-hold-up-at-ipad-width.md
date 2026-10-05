---
id: cola-b-redesigns-must-hold-up-at-ipad-width
status: done
priority: medium
area: "design-system, settings, chat, accounts, ipad, cola-b"
created: 2026-09-26
updated: 2026-10-03
source: "exploración iPad (docs/exploracion/ipad-nativo.md §7), 2026-09-26"
---

# Los rediseños de Cola B tienen que valer también en el ancho del iPad

**Entra en Cola B.** No es trabajo aparte: es una lista de comprobación para que lo que se rediseña
ahora no haya que rehacerlo en la fase 1 de iPad.

## La lista

- [x] **Ancho legible**: listas y formularios con tope de ~700 pt centrados cuando la pantalla es
      ancha, y `DS.Adaptive.horizontalPadding` como margen. Hoy tiene **un solo uso** en `Yala/`. **Hecho 2026-10-03**
      para lo rediseñado en Cola B: las seis pantallas de `YalaSettingsList` ya topaban a 700 (`readableListMargin`) y
      el chat a `readableWidth`; faltaba que, junto a la columna de la lista, el margen se contara desde ella (arrancaba
      pegado, 0 pt). El resto de pantallas es de la fase 1 (`ipad-sidebar-and-list-detail-for-records-and-planning`).
- [x] [[settings-redesign-as-grouped-lists-like-ios]]: con `List` agrupada del sistema, no con tarjetas
      propias. Así la misma lista sirve como columna de una `NavigationSplitView` en iPad. **Hecho**: es una `List`
      del sistema y ya va en la columna de detalle del split de Ajustes; medida en los cuatro simuladores el 2026-10-03.
- [x] [[ai-chat-reads-heavier-than-a-messaging-app]]: la vista del chat no debe asumir que vive en una
      hoja (sin tirador ni cierre dentro del hilo). En iPad irá en un `.inspector`. **Hecho 2026-10-02**: sin
      tirador ni cierre en el hilo; en iPad va en columna propia (no `.inspector`, medido el 29-sep); hilo y caja
      topados a `DS.Adaptive.readableWidth`; capturado en iPhone 17 Pro y en `YalaLane-Adapt-iPad-Pro-13`.
- [ ] → **va en su ticket** (requisito copiado allí el 2026-10-03). [[account-form-as-medium-detent-sheet]]: en iPad el detent medio no se aplica, porque
      `.yalaSheetDetents(_:)` fuerza `.large` en una ventana ancha (desde el 29-sep lo decide la ventana, no el
      aparato: [[sheet-size-follows-the-device-not-the-window]]). Decidirlo a propósito.
- [ ] → **va en su ticket** (requisito copiado allí el 2026-10-03). [[panel-accounts-redesign]]: el detalle de cuenta, pensado para poder ir en columna en iPad.
- [ ] → **va en su ticket** (requisito copiado allí el 2026-10-03). [[more-tab-missing-profile-button]]: Más deja de ser pantalla en iPad (barra lateral). No
      invertir en rediseñar Más como pantalla.
- [x] Cada rediseño se captura también en `YalaLane-Adapt-iPad-mini` y `YalaLane-Adapt-iPad-Pro-13`, y en iPhone
      en `YalaLane-Adapt-iPhone-SE` y `-ProMax` con texto por defecto y AX5 (receta en
      `docs/exploracion/adaptativo-ipad-duo.md` §6.2).
- [x] Nada decide por tipo de dispositivo ni por orientación: por size class o ancho del contenedor. Vale igual para
      el iPhone Duo abierto, que es un iPhone con ancho regular. **Medido 2026-10-03**: en `Yala/` no hay ningún
      `userInterfaceIdiom` ni orientación; los cuatro `UIDevice.current` son identificador y versión (soporte, sync), no
      layout. Ajustes decide por el ancho medido y el área segura; el chat, por el size class de la ventana.

## Hecho (2026-10-03, encargo `2026-10-03-cola-b-redesigns-must-hold-up-at-ipad-width`)

- **Qué cambia para el usuario**: en el iPad (y en el iPhone Pro Max girado), al abrir un ajuste con la lista de
  Ajustes al lado, el ajuste ya no arranca pegado a la lista: deja su margen. En el iPad Pro 13 girado además deja de
  pasar de 700 pt. En el iPhone en vertical no cambia nada, salvo tres cabeceras (Personalización, Tutoriales, Divisa)
  que llevan 8 pt de aire a los lados: la de Tutoriales **ya salía cortada en el SE**, y ahora se parte en dos líneas.
- **Por qué pasaba**: junto a la columna de la lista la lista agrupada tiene área segura (400 pt en el iPad mini
  girado) y el sistema se quedaba con el mayor entre esa área y el margen, no con la suma. `YalaSettingsList` mide el
  área segura de cada lado y le pasa a `contentMargins` área + margen (`DS.Adaptive.readableListInsets`). Probadas y
  descartadas: `safeAreaPadding` (movía 2 pt las filas en el iPhone) y rehacer la lista con `.id`.
- **Yala IA** ya cumplía: columna propia en iPad, hilo y caja topados a 700, sin tirador ni cierre en el hilo.
- **Red**: `AdaptiveNavigationUITests#test_settingsDetail_keepsItsMarginBesideTheListColumn_inWideWindow` (rojo con el
  mutante: 36 pt frente a ≥ 56) + 3 casos en `SettingsListLayoutTests`. Convención en `.claude/rules/swiftui-ds.md`.
- **Evidencia**: `qa/evidencia-adaptativo-20261003/cola-b-redesigns-must-hold-up-at-ipad-width/` (antes/después y
  todas las pantallas en los cuatro simuladores, iPhone con texto por defecto y AX5).
- **Fuera, con ticket**: [[ipad-records-empty-detail-half-hidden-with-chat-open]]. Y una medida nueva anotada en
  [[ipad-settings-sheet-size-depends-on-where-it-opens]] (desde el Panel ya sale lado a lado).
- **No probado**: Split View o ventana estrecha con Ajustes abierto. `YalaSettingsList` decide por lo que mide, así que
  debería comportarse como en el iPad mini en vertical; si alguien lo ve distinto, es un ticket nuevo.

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
