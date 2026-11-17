---
id: 2026-11-16-web-app-lote-2-iconos-categoria
status: done
priority: high
area: web
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-web-app-lote-2-iconos-categoria (maqueta «Yala web como la app», aprobada el 16-nov)
---
# Yala web como la app, lote 2: íconos y colores de categoría

Segundo de los seis lotes del plan de `docs/web-app/parecida-a-la-app/`. La nube ya guardaba el ícono y el color que la
persona eligió en la app para cada cuenta, categoría y subcategoría; la web no los pedía.

## Qué cambia para quien usa la web

- Las filas de registros (Panel, Registros, Buscar) llevan el ícono y el color de su categoría, como el iPhone, en vez de
  una inicial con un color sacado del nombre. Un gasto de grupo que aún no tiene subcategoría lleva el «!» rosa de la app.
- La navegación entera (barra lateral, pestañas del celular, botones de arriba) usa los íconos Lucide equivalentes a los
  SF Symbols de la app.
- Cada tarjeta de cuenta del Panel enseña el ícono de la cuenta.

## Cómo llega

- `ToolContext.apariencia` (`shared-core/src/toolCore.ts`): solo lo pone el Worker de la web. Con él, `listar_cuentas`,
  `listar_categorias` y `buscar_movimientos` piden también `icon_name,color_hex` y añaden, AL FINAL de cada fila:
  cuentas `icono` (regla `displayIconName`) y `color`; categorías y subcategorías `icono` y `color` crudos; registros
  `categoria_id`, `subcategoria_id`, `cuenta_id`, `icono` (subcategoría, si no categoría), `color` (de la categoría) y
  `necesidad` (`effectiveNeed`).
- El conector de Claude y el gateway no lo ponen: piden y devuelven lo mismo, byte a byte
  (`mcp/test/shared-core-parity.test.ts`, sin cambios). No hizo falta desplegar el gateway.
- El color sale solo como `#RRGGBB` y el ícono solo con forma de SF Symbol: lo demás, `null`.
- `webapp/src/client/app/simbolos.ts`: tabla de SF Symbol a Lucide (los 187 del selector, los de fábrica, los de
  cuentas y los que la app escribe sola: ajuste de saldo, «Otros», «Sin asignar», la cuenta de Grupos). `lucide-react`
  1.66.0.

## Decisiones que un lote siguiente no debe deshacer

- Las reglas de qué ícono, color y necesidad lleva cada cosa viven en el núcleo, una vez; la página solo traduce el
  símbolo y pone el respaldo de la app (etiqueta e índigo) cuando llega `null`.
- Las tarjetas de cuenta mantienen su fondo de la base: con el color de la cuenta, el texto blanco no siempre se lee. Lo
  resuelve el lote 4 con las tarjetas de la app.

## Fuera de este lote

- Píldoras de necesidad, fila de 40 px y detalle de registro: lote 4 (los datos ya llegan).
- Íconos en Estadísticas, Presupuestos y Pagos, que hoy agrupan por nombre: lote 5.

## Pruebas

- `webapp`: `npm run typecheck` y `npm test` (226 casos), con `test/simbolos.test.ts` (lee las listas de Swift) y
  `test/apariencia.test.ts` (las rutas traen los campos y la web pide las columnas).
- `mcp`: 303 casos, con `test/apariencia.test.ts` (reglas contra la app y, con `apariencia`, las seis herramientas
  devuelven lo del conector más los campos nuevos en todos los escenarios del golden).
- `gateway`: 743 casos en verde.
- Revisión adversarial con dos lentes. Contrato del conector y del gateway: sin hallazgos. Fidelidad y seguridad: cuatro,
  arreglados (cuatro símbolos que la app escribe sola, el «!» rosa, un comentario sobre el ícono de cuenta y nombres
  como «constructor» que tumbaban la página).
- Capturas de antes y después en `docs/web-app/parecida-a-la-app/capturas/lote-2/`.
