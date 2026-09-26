---
id: cola-b-redesigns-must-hold-up-at-ipad-width
status: backlog
priority: medium
area: "design-system, settings, chat, accounts, ipad, cola-b"
created: 2026-09-26
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
- [ ] [[ai-chat-reads-heavier-than-a-messaging-app]]: la vista del chat no debe asumir que vive en una
      hoja (sin tirador ni cierre dentro del hilo). En iPad irá en un `.inspector`.
- [ ] [[account-form-as-medium-detent-sheet]]: en iPad el detent medio no se aplica, porque
      `DS.Adaptive.usesLargeSheets` fuerza `.large` (`DesignTokens.swift:430`). Decidirlo a propósito.
- [ ] [[panel-accounts-redesign]]: el detalle de cuenta, pensado para poder ir en columna en iPad.
- [ ] [[more-tab-missing-profile-button]]: Más deja de ser pantalla en iPad (barra lateral). No
      invertir en rediseñar Más como pantalla.
- [ ] Cada rediseño se captura también en el iPad mini y el iPad Pro 13" (receta en
      `docs/exploracion/ipad-nativo.md` §1).

## Relacionados

- [[ipad-native-app]] — paraguas. [[floating-buttons-cover-row-amounts-on-ipad-landscape]].
