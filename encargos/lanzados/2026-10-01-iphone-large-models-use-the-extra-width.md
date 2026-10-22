# iPhone · modelos grandes aprovechan el ancho (carril adaptativo, paso 10/13)

---
ticket: iphone-large-models-use-the-extra-width
modo: autonomo
cola: adaptativo
---

## Contexto
Cierre limpio de PR #315 (Cola A: un intent que supersede el Welcome ya no deja el cierre de sesión sin dueño). Orden Jürgen 2026-09-28 16:31: una sola sesión Yala a la vez, alternando Cola A ↔ carril adaptativo. Tras esa Cola A toca el carril adaptativo.

Plan vigente: `docs/exploracion/adaptativo-ipad-duo.md` §7 fila 10 (fase iPhone · más espacio en los grandes) y §6.1. Ticket: `tickets/backlog/iphone-large-models-use-the-extra-width.md` (low, tamaño S). Depende de pasos 2 y 3 (ambos en `done`: large-text + small-screens). Fase 3 teclado/puntero (paso 9, PR #313) ya cerrada. Fase Duo (paso 6) sigue bloqueada por `xcode-27-1-with-the-iphone-duo-simulator` — no la toques.

Los simuladores `YalaLane-Adapt-*` se recrearon el 2026-10-01 ~07:05 Lima (habían desaparecido; solo quedaba un iPhone 17 Pro genérico). UDIDs nuevos abajo — no uses UDIDs viejos de encargos anteriores. Runtime: iOS 27.0.

ADR «[2026-09-27] Yala se adapta por espacio, no por dispositivo». Frank y Claude deciden el detalle Apple-recommended sin preguntar a Jürgen.

MODO AUTÓNOMO: elige las opciones recomendadas / robustas sin preguntar a Jürgen salvo device físico, secretos o irreversible. Mergea a `2.1` cuando el gate esté verde (cola de auto-merge / ADR-054).

## Qué se pide
Cierra el ticket `tickets/backlog/iphone-large-models-use-the-extra-width.md`.

1. Leer el ticket entero, el plan §6.1 / §7, el ADR de adaptación por espacio, y el código actual (p. ej. `AccountsCarouselView` — hoy 2 cuentas en compact / 4 solo en regular; gráficas con alturas fijas).
2. Comparar capturas SE vs ProMax en Panel, Registros, Estadísticas y Planificación. Anotar dónde el Pro Max deja espacio vacío.
3. Proponer en el ticket (o en el PR), **antes de tocar**, qué gana cada pantalla. Solo cambios de **cantidad** (una tarjeta más a la vista, una gráfica algo más alta), nunca de **sitio** ni de función.
4. Decidir por el ancho del contenedor (`onGeometryChange` / ancho disponible), no por el modelo de iPhone ni por idiom.
5. Evidencia solo en simuladores del carril por UDID, DerivedData del worktree (`-derivedDataPath .ddp`):
   - `YalaLane-Adapt-iPhone-SE` → `C248A9E8-BBBE-4370-AF7E-77ADB01A1A07`
   - `YalaLane-Adapt-iPhone-ProMax` → `AACA53D7-DCAE-456A-A779-6BF0D8F9926A`
   - `YalaLane-Adapt-iPad-mini` → `91B4E3F8-B14D-478A-8FF5-07DC0D3EFAC1` (regresión breve si tocas layout compartido)
   - `YalaLane-Adapt-iPad-Pro-13` → `A31B3363-C8F4-4F96-8C1F-1772D1140C7E` (igual)
   Capturas antes/después en SE y ProMax a tamaño por defecto y AX5 (`xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large`). En el SE, sin diferencias respecto al antes. Evidencia en `qa/evidencia-adaptativo-20261001/iphone-large-models-use-the-extra-width/` (o fecha del día).
6. XCUITest de las áreas tocadas en verde por UDID. Gate verde, PR a `2.1`, merge (auto-merge), board del repo, `/cerrar-total`.

## Decisiones ya tomadas (Frank; no las vuelvas a preguntar)
- Layout por espacio / size class / ancho del contenedor, nunca por tipo de dispositivo ni orientación (ADR vigente).
- Solo cantidad, no sitio ni función (§6.1 + ticket).
- Si una mejora no cumple las tres condiciones del §6.1 (capturas SE/ProMax+AX5, XCUITest verdes, sin cambiar qué hace un botón): ticket propio, no ampliar.
- Apple-recommended / más eficiente nativo: decide tú; no preguntes detalle de producto.
- iPhone landscape (paso 11) y Duo (paso 6) quedan fuera de este encargo.

## Qué NO hay que tocar
- Simuladores sin prefijo `YalaLane-Adapt-`. Siempre `-destination id=<UDID>`, nunca por nombre genérico ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator`.
- No instalar Xcode 27.1 ni crear el simulador Duo.
- No arrancar Cola A / sync / nube ni Cola B (rediseño UI).
- No abrir otra sesión Yala en paralelo.
- No tocar `iphone-supports-landscape-orientation` ni `iphone-duo-native-app` en este encargo.
- Producción / deploy.
- No preguntar a Jürgen por decisiones de producto reversibles.
- Disco: limpia DerivedData (`.ddp`) y scratchpads propios al cerrar (~36 GB libres ahora; umbral 25 GB).

## Cómo se sabe que está bien
Criterios «Hecho cuando» del ticket + capturas SE/ProMax (default + AX5) + SE sin diferencias + XCUITest verdes + gate verde + PR mergeado a `2.1` + cierre limpio con `/cerrar-total`. Residual a ticket propio.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge (auto-merge), board (`tickets/` y `docs/TICKETS.md` si aplica) y `/cerrar-total` sin dejar la sesión colgada. Si el riesgo es alto (datos/prod/irreversible), aplaza a ticket.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR; (3) terminaste y vas a /cerrar-total, con resumen corto en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro, una vez. NO avises por test rojo que vas a reclasificar ni ruido de CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿De dónde sale el «antes»?** → Del propio árbol del worktree antes de editar (es `2.1` en `f8c893cb3`).
Por qué: aún no hay cambios, así que no hace falta copia limpia. Alternativa descartada: `git archive` (sobra).

**D2 · ¿Cómo se capturan las pantallas?** → XCUITest temporal (`ZZTempWidthCaptureUITests`, se borra antes del
commit) con `-uitest-seed realista`, Pro, por deeplink, guardando en el host; corridas por `sim-lock.sh` y UDID.
Por qué: es el método de las fases anteriores y da pantallas repetibles. Alternativa descartada: capturas a mano.

**D3 · ¿Qué pantallas?** → Panel (arriba y desplazado), Registros, Estadísticas (Resumen, Tendencias, Categorías)
y Planificación/Presupuestos, en SE y Pro Max, texto por defecto y AX5.
Por qué: las cuatro del ticket.

**D4 · ¿Con qué se decide «más»?** → Con el ancho medido del contenedor (`onGeometryChange`) contra un ancho mínimo
por elemento que escala con el texto (`@ScaledMetric`), nunca con el modelo, el idiom ni el size class.
Por qué: ADR de adaptación por espacio; y con AX5 el mismo ancho debe volver a enseñar menos. Alternativa
descartada: umbral fijo en pt (en AX5 metería tres tarjetas que no caben).

**D5 · Qué gana cada pantalla** → se decide tras medir las capturas y se anota abajo (D6+) antes de tocar código.

**D6 · Las gráficas de tendencia ganan alto con el ancho** → la del Panel (Tendencias), la de Estadísticas ›
Tendencias y la de comparación (las tres a 170 pt fijos) pasan a `170 × clamp(ancho / 320, 1, 1,2)`, medido con
`onGeometryChange` sobre su contenedor y solo en ancho compacto.
Por qué: medido, en el SE la gráfica mide ~311 pt de ancho (por debajo de 320 → idéntica) y en el Pro Max ~376 pt,
donde 170 pt la dejan aplastada; conserva la proporción del SE con techo +20 % (≈200 pt). En ancho regular (iPad)
no cambia nada: esa composición es de la fase 2b. Alternativa descartada: umbral por modelo o escalón fijo.

**D7 · El carrusel de cuentas NO gana una tercera tarjeta** → se queda en 2 en compacto.
Por qué: medido, el Pro Max deja ~408 pt; tres tarjetas saldrían a ~128 pt, por debajo del mínimo de 140 pt que el
propio carrusel exige para cuatro en ancho (`fourCardsMinWidth`), con el nombre tapado por el botón de ajustes; y
§4.3 pide rejillas en pares. Además viene plegado por defecto. Alternativa descartada: bajar el mínimo solo en iPhone.

**D8 · Registros y Planificación no cambian** → sus listas ya enseñan más filas en el Pro Max por alto, y por ancho
no hay nada que añadir sin cambiar de sitio. Las gráficas del detalle de presupuesto (pantalla empujada) y la de
Distribución (donut + leyenda) quedan fuera: cambiarlas toca composición, no cantidad.

**D9 · Red** → test unitario del cálculo (SE igual, Pro Max más alto, techo, regular sin cambio) + XCUITest del Panel
y Estadísticas en SE y Pro Max por UDID + diff de píxeles en el SE.
