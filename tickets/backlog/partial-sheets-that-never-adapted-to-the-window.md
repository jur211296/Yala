---
id: partial-sheets-that-never-adapted-to-the-window
status: backlog
priority: low
area: "design-system, ipad, adaptativo"
created: 2026-09-29
source: "hallazgo de sheet-size-follows-the-device-not-the-window, 2026-09-29"
---

# 19 hojas con detent parcial no se adaptan a la ventana

## Qué le pasa al usuario

**Inferido del código, no visto.** En un iPad a pantalla completa, la mayoría de las hojas medias de Yala se abren
grandes, porque ahí el detent medio se queda corto para selectores y contenido complejo. Estas 19 no: salen a media
altura en cualquier ventana, así que en un iPad de 13" enseñan poco contenido en una hoja enorme de ancho. En iPhone
no cambia nada.

## Lo medido (2026-09-29, este árbol)

Nunca pasaron por el helper de hojas (`DS.Adaptive.sheetDetents`, hoy `.yalaSheetDetents(_:)`), ni antes ni después
de `sheet-size-follows-the-device-not-the-window`. Es preexistente: ese ticket cambió qué decide el helper, no quién
lo usa.

| Pantalla | Dónde |
|---|---|
| Panel · secciones y preferencias (4) | `PanelSectionPreferencesSheet.swift:79` y `:173`, `PanelSectionsConfigView.swift:75` y `:231` |
| Panel · detalle de puntuación, ganancia por tipo de cambio, ancla del saldo, info de widget (4) | `FinancialScoreDetailSheet.swift:75`, `FXPnLDetailSheet.swift:49`, `BalanceLiveAnchorEducationSheet.swift:67`, `WidgetInfoSheet.swift:79` |
| Flujo de caja (5) | `CashFlowLineConfigSheet.swift:82`, `CashFlowOthersSheet.swift:56`, `CashFlowTableView.swift:224`, `CashFlowHorizonSheet.swift:74`, `CashFlowSetupView.swift:460` |
| Grupos · saldo inicial y puente (4) | `GroupOpeningBalanceFormView.swift:122` y `:130`, `BridgeActivationSheet.swift:83`, `BridgeDeactivationSheet.swift:83` |
| Yala IA · personalización (1) | `AIPersonalizationSheet.swift:46` |
| Perfil (1) | `ProfileView.swift:1522` |

## Qué hacer

Decidir, hoja por hoja, si en ventana ancha debe ser grande. Si sí, `.presentationDetents` → `.yalaSheetDetents`, y su
fondo a `.yalaScreenBackground(.partialSheet)` si hoy es `.transparent`. Capturas en `YalaLane-Adapt-iPad-Pro-13` a
pantalla completa antes y después; en iPhone no debe cambiar nada. Con la fase 1 en marcha, alguna de estas puede dejar
de ser hoja (columna o inspector) y entonces sobra.

## Relacionados

- [[sheet-size-follows-the-device-not-the-window]] — de donde sale.
- [[ipad-native-app]] — paraguas del carril.
- [[cola-b-redesigns-must-hold-up-at-ipad-width]] — Panel y Flujo de caja se rediseñan allí.
