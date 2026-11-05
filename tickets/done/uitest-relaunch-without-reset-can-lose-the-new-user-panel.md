---
id: uitest-relaunch-without-reset-can-lose-the-new-user-panel
status: done
priority: low
area: testing, panel
created: 2026-10-16
updated: 2026-11-05
source: molde de capturas de la ficha (encargo 2026-10-16-capturas-video-app-store-en-pt) · card `tablero-relanzar-sin-uitest-reset-a-veces-ensena-by3z`
---

# Relanzar sin `-uitest-reset` a veces enseña el Panel con todas las secciones

Medido el 16-oct-2026 en el iPad Pro 13 (iOS 27.0), con el scheme Yala (Debug): tras un arranque con
`-uitest -uitest-reset -uitest-seed ficha`, que deja el Panel de usuario nuevo (Tendencias, Planificación, Últimos
registros), un segundo arranque **sin** `-uitest-reset` enseñó a veces todas las secciones (Distribución, Herramientas
y los widgets de Tendencias que nacen apagados). Con el sistema del simulador en inglés: 3 de 5 relanzamientos; en
pt-BR no salió en 4. Con el simulador recién borrado también pasa, así que no es estado viejo del simulador.

Hipótesis sin medir: en ese segundo arranque `PanelPreferencesMigration` encuentra el blob viejo
`panel_widget_configs_v1` que escribió `applyDefaultSizes` en el primero y toma la rama de actualización. El bloque
de `-uitest-reset` de `AppBootstrapper` siembra y marca `panelPrefsMigratedV2`; habría que ver si esa marca llega a
disco antes de que se mate la app.

Solo afecta a recorridos de dos arranques sobre el mismo store (capturas, demos grabadas, un XCUITest de «usuario
nuevo» que relance). El molde de la ficha lo esquiva fijando el Panel por argumentos (`ficha-app-store/capturas/lanzar.sh`).

## Qué hay que hacer

1. Instrumentar el segundo arranque: el valor de `panelPrefsMigratedV2` al entrar en la migración y qué rama toma.
2. Decidir si es solo del modo `-uitest` o si un usuario real puede llegar ahí.

## Resuelto (2026-11-05, lote T4)

**Causa, medida con un test:** el bloque `-uitest-reset` de `AppBootstrapper` borra del disco las claves del Panel y resiembra sobre la copia en memoria de `AppPreferences`, que se cargó ANTES del borrado. Si ya valía lo mismo que los predeterminados (lo normal tras una corrida anterior), cada `didSet` ve «sin cambio» y no escribe nada: el disco se queda sin secciones ocultas ni centinela. El arranque siguiente sin reset encuentra el blob de tamaños `panel_widget_configs_v1` y toma la rama de actualización de `PanelPreferencesMigration`: todas las secciones. Salía en arranques alternos (la corrida que partía de un disco vacío sí escribía), de ahí el «3 de 5».

- Solo es del modo `-uitest`: un usuario real no pasa por ese bloque.
- Arreglo: `AppPreferences.reseedPanelDefaultsAfterDiskWipe()` vacía la copia en memoria sin escribir y siembra por el camino normal.
- Lo fijan `SeedRelaunchT4Tests` (el control que reproduce el bug, el arreglo y el arranque siguiente con el blob) y `SeedRelaunchT4UITests#test_relaunchWithoutReset_keepsTheNewUserPanel` (dos parejas reset → relanzar).
