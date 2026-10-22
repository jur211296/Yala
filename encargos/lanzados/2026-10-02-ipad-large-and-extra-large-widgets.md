# iPad · paso 13/13: widgets grandes y uno extragrande

## Contexto
Carril adaptativo, último paso (fase 5). Tras PR #324 (multiwindow) y el cierre Cola A #325. Ticket: `tickets/backlog/ipad-large-and-extra-large-widgets.md`. Exploración: `docs/exploracion/ipad-nativo.md` §5.5 y `docs/exploracion/adaptativo-ipad-duo.md` paso 13.

Hoy solo tres widgets admiten `.systemLarge` (donuts + Flujo de caja) y ninguno `.systemExtraLarge`.

## Que se pide
- Añadir `.systemLarge` a Presupuestos, Últimos registros y Pagos planificados.
- Un `.systemExtraLarge` «Resumen del mes» (saldo + gasto por categoría + presupuestos).
- Si el DTO del App Group gana campos, actualizar las DOS copias (app y widgets) para no apagar widgets.
- Capturas en claro/oscuro en `YalaLane-Adapt-iPad-Pro-13` y `YalaLane-Adapt-iPad-mini`; regresion visual en `YalaLane-Adapt-iPhone-ProMax` de widgets existentes.
- Test de que el DTO decodifica igual en ambas copias. Gate verde. PR a 2.1 con auto-merge.
- Al terminar: `/cerrar-total` autónomo (no dejes la sesión colgada).

## Sims y pipeline Mini (obligatorio)
- Solo sims `YalaLane-Adapt-*` por UDID (`-destination id=<UDID>`), nunca por nombre genérico ni `booted`. Prohibido `simctl shutdown all` / `erase all` / tocar sims ajenos.
- Norma flota: **1 simulador a la vez**.
- Pipeline SERIAL: (1) limpiar sims muertos/basura (2) `xcodebuild -jobs 2` **sin** sim booteado (3) boot 1 sim (4) tests (5) apagar/limpiar ese sim. No solapar swift-frontend + SpringBoard + app + UITests.
- DerivedData del worktree: `-derivedDataPath .ddp`.
- En `/cerrar-total`: apagar sims usados → erase/limpiar data de esos devices → si PR mergeado/worktree inútil quitar worktree+.ddp → kill tmux. Mini limpia.

## Que NO hay que tocar
- Cola A / cloud sync / grupos salvo lo mínimo del DTO compartido.
- Widgets del Duo (ticket aparte si hace falta).
- Sims que no sean `YalaLane-Adapt-*`.
- No preguntar a Jürgen por detalles de layout: decide con HIG / prácticas nativas Apple.

## Como se sabe que esta bien
Criterios del ticket «Hecho cuando» + gate verde + PR en cola de merge a 2.1 + `/cerrar-total` limpio.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **DTO del App Group: no se toca.** El «Resumen del mes» sale de campos que ya viajan: balance de `periodSummaries[thisMonth].periodBalance` (vía `getBalance(for:)`), gasto y `topCategories` de `calculateSummary(.thisMonth)`, y `budgets`. Sin campo nuevo no hay riesgo de `keyNotFound` que apague widgets.
2. **Test de paridad del DTO**: el target `YalaTests` no compila `YalaWidgets`, así que no puede decodificar con la copia del widget. Se escribe (a) un scan estructural que extrae las propiedades guardadas de los 11 structs Codable de las dos copias y exige: mismas claves, mismo tipo base, y que ninguna clave obligatoria en el lector sea opcional (o ausente) en el escritor; y (b) un round-trip real: el escritor codifica un snapshot con todos los opcionales a `nil` y se comprueba que el JSON trae cada clave que el lector exige.
3. **Filas en `.systemLarge`**: Presupuestos 6, Últimos registros 7, Pagos planificados 7. Misma fila que en mediano, más espaciado; el número exacto se ajusta midiendo en captura.
4. **Placeholders** ampliados a 6–7 elementos para que la galería no enseñe un grande medio vacío; el mediano sigue recortando a 3 en la vista.
5. **Extragrande**: `StaticConfiguration`, sin intent (el nombre ya dice «del mes»). Dos columnas: izquierda balance + gasto del mes + donut sin burbujas con leyenda top 5 + «Otros»; derecha 4 presupuestos más apretados con la fila del widget de Presupuestos. `Link` por columna (categorías / presupuestos) y `widgetURL` al Panel.
6. **Copy**: 3 claves nuevas en los 16 `.lproj` del widget (`widget.gallery.monthSummary`, `.desc`, `widget.ui.monthSummary`), siguiendo el vocabulario existente («Balance» en es).
7. **Duo**: fuera, como dice el encargo.
