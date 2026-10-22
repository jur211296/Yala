# Evidencia · ipad-narrowing-the-window-on-groups-crashes-the-app (2026-09-29)

Estrechar la ventana de Yala en un iPad cerraba la app con cinco de las seis páginas seleccionadas. Ahora no.

## Cómo se sacó

- `YalaLane-Adapt-iPad-Pro-13` (`8B01FB45…`, iOS 27.0), horizontal, Ajustes → Multitarea y gestos → **Apps en
  ventanas**; `YalaLane-Adapt-iPhone-ProMax` (`CDA87FB8…`). Siempre por UDID, DerivedData del worktree.
- Un XCUITest temporal (borrado antes del commit) lanza con `seed: grupos`, elige cada página en la barra lateral y
  arrastra la esquina de la ventana con los elementos de SpringBoard (`XCUIApplication+Window`, que sí se commitea).
- «Antes» es `2.1` (`a9e6fc37d`); «después», el árbol del PR. JPG con el lado mayor a 640 px.

## Lo que se midió

| Qué | Antes | Después |
|---|---|---|
| Estrechar con Panel, Estadísticas, Planificación, Reportes o Grupos | la app se cierra (5 de 5) | pestañas abajo con la misma página (5 de 5) |
| Estrechar con Registros | no se cierra | no se cierra |
| Grupo abierto al lado de la lista y estrechar | se cierra | el grupo sigue a la vista, empujado, con su chevron |
| Volver a ancho tras estrechar (las seis) | no automatizable | vuelve la barra lateral |
| iPhone Pro Max: barra y Grupos | — | iguales: 0 px en Grupos ×3, Panel y Estadísticas; en Registros solo cambia el cristal de la barra |

## Por qué se cerraba (medido con lldb en el crash)

Al estrechar, UIKit reconstruye la barra de pestañas con las que tenía en la barra lateral —las seis páginas y
Buscar— y, como son más de cinco, mete el ítem de las cuatro primeras. Registros y Reportes **no tenían ítem**: SwiftUI
las añadió al ensanchar, con la barra lateral ya puesta, y una pestaña así no tiene controlador hasta que se visita.
El `nil` de la cuarta (Registros) es el `insertObject:atIndex:: object cannot be nil`. Con Registros seleccionado, las
cuatro primeras sí tenían ítem, y por eso no pasaba. `.tabPlacement(.sidebarOnly)` no lo evita: UIKit las recorre igual.

El arreglo monta las seis páginas desde el primer arranque (las que ya estaban entonces sí tienen controlador) y en la
barra de pestañas oculta las que no tocan, nunca la seleccionada.

| Captura | Qué se ve |
|---|---|
| `ipad-pro-13__h-01-antes-grupos-pantalla-completa` | Grupos en la barra lateral, a pantalla completa |
| `ipad-pro-13__h-02-antes-grupos-al-estrechar-se-cierra` | Al estrechar, la app se ha cerrado y el sistema la reabre |
| `ipad-pro-13__h-03-despues-grupos-estrecha` | Ventana estrecha: Panel · Estadísticas · Planificación · Grupos · Más |
| `ipad-pro-13__h-04-despues-panel-estrecha` | Ventana estrecha con Panel: Panel · Estadísticas · Planificación · Más · Buscar |
| `promax__v-01…v-02` | Grupos en el iPhone, antes y después: iguales al píxel |
