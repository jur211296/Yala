---
id: ipad-narrowing-the-window-on-groups-crashes-the-app
status: done
priority: high
area: "ipad, navigation, adaptativo, crash"
updated: 2026-09-29
created: 2026-09-29
source: "fase 2 del carril adaptativo (ipad-list-detail-for-groups-and-settings-and-chat-inspector), 2026-09-29"
---

# En iPad, estrechar la ventana con Grupos abierto cierra la app

## Qué pasa

En un iPad con «Apps en ventanas», con **Grupos** seleccionado en la barra lateral, estrechar la ventana hasta que
pasa a pestañas abajo **cierra la app**. Da igual que haya un grupo abierto o solo la lista. Con Registros
seleccionado no pasa (medido en la fase 1 y otra vez aquí, con Yala IA abierto al lado).

**Viene de la fase 1 (`2.1`, `4534371bf`), no de la fase 2**: reproducido con una copia limpia de `2.1` (`git archive
HEAD`) el 2026-09-29, mismo crash.

Medido el 2026-09-29 en `YalaLane-Adapt-iPad-Pro-13` (iOS 27.0), en horizontal, tres veces:

```
*** -[__NSArrayM insertObject:atIndex:]: object cannot be nil
-[UITabBarController _tabs_rebuildTabBarItemsAnimated:]
-[_UITabBarControllerAdaptiveVisualStyle updateViewControllers:]
-[UITabBarController _updateLayoutForTraitCollection:]
-[UITabBarController traitCollectionDidChange:]
```

UIKit reconstruye la barra de pestañas en el cambio de size class, antes de que SwiftUI le pase las pestañas de
compacta (`RootTabLayoutLogic.shownTabs`).

## Lo que ya se probó y no funcionó

- Marcar en la barra lateral las páginas que en compacta no van con `.defaultVisibility(.hidden, for: .tabBar)`
  (la seleccionada nunca): mismo crash. Revertido.

Hipótesis sin medir: la diferencia con Registros es la posición en la lateral (Grupos es la sexta; Registros cabe entre
las cuatro primeras). Probar con Reportes (quinta) lo confirmaría o la tumbaría.

## Cómo reproducirlo

1. `xcrun simctl erase` del `YalaLane-Adapt-iPad-Pro-13` (la ventana recuerda su tamaño), Ajustes → Multitarea y
   gestos → **Apps en ventanas**.
2. XCUITest en horizontal: `launchForUITest(pro: true, seed: "grupos", deeplink: "groups")`, luego
   `app.coordinate(0.995, 0.995).press(forDuration: 0.6, thenDragTo: app.coordinate(0.4, 0.995))`.
3. `com.jurgenschmidt.yala.dev crashed`; el `.ips` en `~/Library/Logs/DiagnosticReports/`.

## Hecho cuando

Estrechar la ventana con Grupos (y con cada una de las seis páginas) seleccionado no cierra la app, y con un grupo
abierto el grupo sigue a la vista, empujado. Con un XCUITest que lo cubra.

## Hecho (2026-09-29, PR del encargo `2026-09-29-ipad-narrowing-the-window-on-groups-crashes-the-app`)

**La premisa del ticket era corta: no era Grupos, eran cinco de las seis páginas.** Medido en el iPad Pro 13 con la
ventana a pantalla completa: estrechar cerraba la app con Panel, Estadísticas, Planificación, Reportes y Grupos; solo
con Registros no. La hipótesis de la posición en la lateral cae (Panel es la primera).

**Causa, medida con lldb en el crash.** Al estrechar, UIKit reconstruye la barra con las pestañas que tenía en la
lateral —las seis páginas y Buscar— y, como son más de cinco, mete el ítem de las cuatro primeras (`_tabs_compactTabs`
hasta `_effectiveMaxItems`, 5). Registros y Reportes no tenían ítem: SwiftUI las añadió al ensanchar, con la lateral ya
puesta, y una pestaña así no tiene controlador hasta que se visita. El `nil` es el de Registros, la cuarta. Con
Registros seleccionado, las cuatro primeras sí tenían ítem.

**Arreglo.** La raíz monta las seis páginas desde el primer arranque, en el mismo orden en los dos tamaños, y en la
barra de pestañas oculta las que no tocan (`RootTabLayoutLogic.mountedTabs` / `hiddenTabs`). Nunca la seleccionada
—`shownTabs` la incluye siempre—, porque una oculta y seleccionada también tumba la app (fase 1). La shell de solo
grupos sigue quitando, como antes. Regla en `swiftui-ds.md`, «Layout adaptativo».

**Lo que se probó y no funcionó:** `.tabPlacement(.sidebarOnly)` para las que no van en compacta (UIKit las recorre
igual, mismo crash en las cinco); pedir `UITab.viewController` a mano (fabrica un `UIViewController` vacío, no la
pantalla).

**Cobertura.**
- XCUITest `AdaptiveNavigationUITests.test_narrowingTheWindow_keepsEveryPageOpen_andWideningBringsTheSidebarBack`: las
  seis páginas, estrechar y volver a ancho en un solo arranque. Con el código de `2.1` cae en la primera (Panel).
- XCUITest `…test_narrowingTheWindow_withAGroupOpen_keepsTheGroupPushed`: el grupo sigue a la vista, empujado, con su
  chevron.
- Los dos redimensionan con `XCUIApplication+Window` (marcos de SpringBoard) y se saltan, diciéndolo, en iPhone o en un
  iPad sin «Apps en ventanas». **Volver a ancho ya se automatiza**: el botón de maximizar de los controles de ventana.
- Unit `RootTabLayoutLogicTests` (montadas, ocultas, nunca la seleccionada, shell de solo grupos).
- iPhone Pro Max: la barra y Grupos iguales al píxel antes y después.
- Evidencia: `qa/evidencia-adaptativo-20260929/ipad-narrowing-the-window-on-groups-crashes-the-app/`.

