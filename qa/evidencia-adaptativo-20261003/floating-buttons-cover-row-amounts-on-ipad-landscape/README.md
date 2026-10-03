# Evidencia · floating-buttons-cover-row-amounts-on-ipad-landscape (2026-10-03)

Al llegar al final de Registros, de Estadísticas › Registros o del Panel, la última fila quedaba debajo de Yala IA y
«+», con el importe tapado. Ahora la lista reserva el alto de los dos botones y la última fila sube por encima.

## Cómo se sacaron

- Simuladores del carril, por UDID y de uno en uno: `YalaLane-Adapt-iPad-Pro-13` (`DE089C7E…`, horizontal),
  `YalaLane-Adapt-iPhone-SE` (`0D705C9A…`) y `YalaLane-Adapt-iPhone-ProMax` (`72EB411B…`), en vertical y girados, con
  texto por defecto y con AX5. iOS 27.0.
- Un XCUITest temporal (borrado antes del commit) lanza cada pantalla, **arrastra hasta que la pantalla deja de
  cambiar** y pide el árbol de accesibilidad: cuenta los textos cuyo marco cruza el de los botones flotantes
  (`textos tapados`) y la distancia del texto más bajo de la franja de los botones a su techo (`holgura`, negativa =
  debajo).
- Registros y Estadísticas › Registros con la semilla `minimal` (7 días): con `realista` (2 años) el arrastre no llega
  al final. El resto, `realista`; Grupos, `grupos`.
- «Antes» es `2.1` en `3b65622e6`; «después», el árbol del PR. Barra de estado a las 9:41.
- `comparativa-*.jpg`: antes a la izquierda, después a la derecha. `antes/`: las pantallas que no cambian de código
  (revisadas, una sola captura).

## Qué cambia (medido al final del scroll)

| Pantalla | Aparato | Textos tapados antes → después | Holgura antes → después |
|---|---|---|---|
| Registros | iPad Pro 13 horizontal | 3 → 0 | −34 → 30 |
| Estadísticas › Registros | iPad Pro 13 horizontal | 3 → 0 | −34 → 30 |
| Registros | SE, vertical y girado | 3 → 0 | −34 → 30 |
| Registros | Pro Max, vertical y girado | 3 → 0 | −33 → 30 |
| Registros | SE AX5 vertical | 1 → 0 | −33 → 30 |
| Panel | SE, vertical y girado | 7 → 0 | −98 → 34 |
| Panel | Pro Max vertical / girado | 7 / 3 → 0 | −97 / −36 → 34 / 95 |

Estadísticas › Registros en el SE y el Pro Max da lo mismo que Registros: es la misma lista.

## Pantallas con botón flotante revisadas (todas)

| Pantalla | Botones (`id`) | Estado |
|---|---|---|
| Panel | `fab_chat` + `fab_new_transaction` | **Arreglada** (32 pt → 164) |
| Estadísticas › Registros | `fab_chat` + `fab_new_transaction` | **Arreglada** (100 → 164, lista compartida) |
| Registros | `fab_chat` + `fab_new_transaction` | **Arreglada** (100 → 164) |
| Presupuestos | `budgets_create_fab` | Ya cumplía: 0 tapados, holgura 56-223 |
| Pagos planificados | `scheduled_payments_create_fab` | Ya cumplía: 0 tapados, holgura 33-55 |
| Grupos | `groups_fab_new` | Ya cumplía: 0 tapados |
| Detalle de grupo | `group_detail_fab_new_expense` | Ya cumplía: 0 tapados, holgura 34-184 |

Las de un botón reservan `DS.Spacing.safeBottom` (100) y su botón ocupa 80 sobre el área segura; las de dos
necesitan 148. El menú desplegado de «+» (`fab_voice`, `fab_image`, `fab_manual`, `panel_fab_group`) es temporal y
no se cuenta.

## Lo que se ve y no es de aquí

- **Panel en el iPad Pro 13 horizontal**: antes los botones no llegaban a salir —el contenido no daba el scroll que
  los enciende (180 pt)— y la fila de acciones seguía a la vista. Con el margen nuevo sí se llega, y salen al final,
  sin tapar nada (holgura 96). Es la regla de siempre: salen cuando la fila de acciones se va por arriba.
- **A mitad de scroll los botones siguen encima de las filas**, como cualquier botón flotante: el arreglo es para que
  la última pueda subir. Las capturas del ticket de Planificación y Grupos en el iPad mini eran a mitad de scroll.
- **Pro Max girado, Grupos**: con la lista de grupos sin desplazar, «+» roza el importe de la segunda tarjeta (2 pt).
  La lista tiene dos grupos; al desplazarla, sube.
- **SE con AX5 girado, Estadísticas › Registros**: el test no alcanza el chip de Registros (queda fuera de la barra
  de chips), así que esa pareja no mide la lista; Registros, que es la misma lista, sí: 0 tapados.
- Con el SE girado solo quedan ~150 pt por encima de los dos botones: al final cabe una fila. Es el precio de dos
  botones de 56 pt en 375 de alto.
