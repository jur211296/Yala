---
id: navigation-uitests-look-for-the-iphone-tab-bar-on-ipad
status: backlog
priority: medium
area: "qa, ipad, navigation"
updated: 2026-09-27
created: 2026-09-27
source: "fase 0 del carril adaptativo (ipad-multiple-windows-share-one-navigation-state), 2026-09-27"
---

# Los XCUITest de navegación buscan la barra de pestañas del iPhone y en iPad fallan siempre

## Qué pasa

Cada fase del carril adaptativo pide «XCUITest de navegación en verde en `YalaLane-Adapt-iPad-Pro-13`». Hoy eso es
imposible sin tocar nada: los tests buscan `app.tabBars`, y en iPad la `TabView` de iOS 26 no se dibuja como la
barra de abajo del iPhone, así que XCUITest no encuentra ninguna `TabBar`.

## Lo medido (2026-09-27)

`DeeplinkRoutingUITests`, `StatisticsNavigationUITests` y `LaunchSliceUITests` (6 tests), por UDID:

| Simulador | Con la fase 0 | Base `2.1` sin ella |
|---|---|---|
| `YalaLane-Adapt-iPhone-ProMax` (iOS 26.5) | 6/6 ✓ | — |
| `YalaLane-Adapt-iPad-Pro-13` (iOS 26.5) | 1/6 | 1/6, los mismos 5 rojos en las mismas líneas |

Los cinco rojos son `No matches found for Descendants matching type TabBar` o sus hermanos
(`app.tabBars.firstMatch.waitForExistence` → false). Pasa solo `test_deeplinkToHiddenGroupsTabNavigatesDirect`, que
no toca la barra. `grep -rn "tabBars" YalaUITests` da **19 usos en 16 ficheros**: el problema no es de estas tres
suites.

## Qué hacer

- Un helper en `YalaUITests/Support/XCUIApplication+Yala.swift` que seleccione una pestaña por su identificador de
  accesibilidad, sin depender de si la `TabView` sale como barra (iPhone) o como pestañas arriba / barra lateral
  (iPad). Y migrar los 19 usos.
- Encaja con la fase 1 (`ipad-sidebar-and-list-detail-for-records-and-planning`), que cambia la navegación del
  iPad a barra lateral: si se hace antes, el helper nace con el caso de la barra lateral dentro.

## Hecho cuando

- Las tres suites de arriba en verde en `YalaLane-Adapt-iPad-Pro-13` y en `YalaLane-Adapt-iPhone-ProMax`, por UDID.
- `grep -rn "tabBars" YalaUITests` solo dentro del helper.

## Relacionados

- [[ipad-multiple-windows-share-one-navigation-state]] — donde se midió.
- [[ipad-sidebar-and-list-detail-for-records-and-planning]] — la fase que más lo necesita.
