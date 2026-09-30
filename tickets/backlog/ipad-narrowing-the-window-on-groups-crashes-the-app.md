---
id: ipad-narrowing-the-window-on-groups-crashes-the-app
status: backlog
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
