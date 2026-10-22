# iPad y Duo · fase 2b: Panel y Estadísticas aprovechan el ancho (carril adaptativo, paso 8/13)

---
ticket: ipad-and-duo-panel-and-statistics-use-the-width
modo: autonomo
cola: adaptativo
---

## Contexto
Cierre limpio de PR #304 (Cola A: si el borrado de arranque no puede borrar el teléfono, la puerta de Grupos muestra «No pudimos preparar este teléfono» una vez y no reintenta sola). Orden Jürgen 2026-09-28 16:31: una sola sesión Yala a la vez, alternando Cola A ↔ carril adaptativo. Tras esta Cola A toca el carril adaptativo.

Plan vigente: `docs/exploracion/adaptativo-ipad-duo.md` §7 fila 8 (fase 2b) y §8. Ticket: `tickets/backlog/ipad-and-duo-panel-and-statistics-use-the-width.md` (low, tamaño M). Sale de la fase 2 para que aquélla quede en lista-detalle e inspector; depende de la fase 1 (ya en `qa` / mergeada: sidebar + list-detail Registros/Planificación; fase 2 Grupos/Ajustes/chat ya mergeada; crash de estrechar ventana #303 mergeado).

Capturas del antes: `docs/exploracion/ipad-nativo/01`, `02`, `03`, `20`, `21`, `22`. ADR «[2026-09-27] Yala se adapta por espacio, no por dispositivo». Frank y Claude deciden el detalle Apple-recommended sin preguntar a Jürgen.

Los simuladores `YalaLane-Adapt-*` se recrearon el 2026-09-30 ~02:10 Lima (habían desaparecido; solo quedaba un iPhone 17 Pro genérico). UDIDs nuevos abajo — no uses UDIDs viejos de encargos anteriores.

MODO AUTÓNOMO (noche Lima, ≥21:00): elige las opciones recomendadas / robustas sin preguntar a Jürgen salvo device físico, secretos o irreversible. Mergea a `2.1` cuando el gate esté verde.

## Qué se pide
Cierra el ticket `tickets/backlog/ipad-and-duo-panel-and-statistics-use-the-width.md`.

1. Leer el ticket entero, el plan §6 / §7 / §8, el ADR de adaptación por espacio, `swiftui-ds.md` «Layout adaptativo», y el código actual de Panel (`PanelWidgetsGrid` ya hace rejilla en pares) y Estadísticas (Resumen / Tendencias / chip Registros dentro de `DetailContainerView`).
2. En pantalla ancha (iPad, Duo abierto / regular width):
   - **Panel**: cabecera (saldo, acciones, «Tus finanzas») deja de comerse un tercio en horizontal; Últimos registros ocupa las dos columnas (no media fila vacía).
   - **Estadísticas · Resumen**: tarjetas en rejilla de dos columnas (hoy es iPhone estirado con barras de ~900 pt para tres números).
   - **Estadísticas · Tendencias**: sin comparación, gráfica e indicadores lado a lado (como ya hace con comparación).
   - **Estadísticas · Registros** (chip): el detalle de un registro sigue saliendo en hoja en ancho; mismo molde que fase 1 resolvió en la página Registros — `RecordsViewModel.opensDetailInColumn` / cuidado con el encadenado del editor en `DetailContainerView.showTransactionDetail`.
3. Cómo: rejillas en **pares** (dos columnas) para que en Duo a medio plegar el pliegue caiga entre dos (HIG Duo). Cambiar de fila a rejilla con `AnyLayout` o con el contenedor, no con dos árboles por size class.
4. Evidencia solo en simuladores del carril por UDID (iOS 27.0), DerivedData del worktree (`-derivedDataPath .ddp`):
   - `YalaLane-Adapt-iPad-mini` → `58107B17-4B59-4263-B8A5-39FCF8DEB64E`
   - `YalaLane-Adapt-iPad-Pro-13` → `1CCA105A-8F1C-4F32-8BA2-9C7564BC2C83`
   - `YalaLane-Adapt-iPhone-SE` → `B7BA0730-5D21-40FC-B6B9-10408F3FDAD4`
   - `YalaLane-Adapt-iPhone-ProMax` → `02D8473F-E804-4261-B744-CC9D5676AE24`
   Capturas antes/después vertical y horizontal en los dos iPad. En SE y ProMax: sin diferencias (regla del iPhone) a tamaño por defecto y AX5. iPad redimensionado a ventana estrecha (Device Hub / Apps en ventanas): vuelve a una columna sin perder pestaña ni período. Duo a medio plegar solo si ya existe `YalaLane-Adapt-iPhone-Duo` (no lo crees).
5. Gate verde, PR a `2.1`, merge, board del repo, `/cerrar-total`.

## Decisiones ya tomadas (Frank; no las vuelvas a preguntar)
- Layout por espacio / size class / ancho del contenedor, nunca por tipo de dispositivo ni orientación (ADR vigente).
- Rejillas en pares; `AnyLayout` o contenedor único — no dos árboles por size class.
- Mejoras iPhone solo si no rompen flujos ni 2.1; verificables con capturas SE/ProMax + AX5 (§6.1). Si no caben las tres condiciones, ticket propio.
- Si un subcaso no cabe: ticket propio, no ampliar alcance.
- Apple-recommended / más eficiente nativo: decide tú; no preguntes detalle de producto.

## Qué NO hay que tocar
- Simuladores sin prefijo `YalaLane-Adapt-`. Siempre `-destination id=<UDID>`, nunca por nombre genérico ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator`.
- No instalar Xcode 27.1 ni crear el simulador Duo.
- No arrancar Cola A / sync / nube ni Cola B (rediseño UI).
- No abrir otra sesión Yala en paralelo.
- Producción / deploy.
- No preguntar a Jürgen por decisiones de producto reversibles.
- Disco: limpia DerivedData (`.ddp`) y scratchpads propios al cerrar (~46 GB libres ahora).

## Cómo se sabe que está bien
Criterios «Hecho cuando» del ticket + capturas en los Adapt sims + gate verde + PR mergeado a `2.1` + cierre limpio. Residual a ticket propio (o a `qa` con guion si el redimensionado no se puede demostrar en simulador).

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge, board (`tickets/` y `docs/TICKETS.md`) y `/cerrar-total` sin preguntar. Ahora es noche (≥21:00 Lima): no preguntes; elige la opción recomendada o aplaza a ticket si el riesgo es alto (datos/prod/irreversible).

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR; (3) terminaste y vas a /cerrar-total, con resumen corto en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro, una vez. NO avises por test rojo que vas a reclasificar ni ruido de CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cuándo es «ancho»?** → Size class regular **y** que quepan dos columnas de al menos 320 pt (el ancho de una
tarjeta de iPhone SE, 343, con margen); si no caben, una columna. Lo decide el propio contenedor con el ancho que le
proponen, sin `GeometryReader` ni estado.
Por qué: el ADR pide espacio, no dispositivo; con Yala IA abierto al lado el Panel/Estadísticas siguen en regular pero
estrechos. Alternativa descartada: solo size class (dos columnas de 290 con el chat abierto).

**D2 · ¿Con qué se cambia de fila a rejilla?** → `AnyLayout`: en compacta `VStackLayout` con los mismos parámetros de
hoy (el iPhone queda idéntico por construcción); en regular un `Layout` propio en pares (`PairedColumnsLayout`), con
marca `spansAllColumns` para cabeceras y selectores. Mismos hijos, misma identidad al redimensionar.
Alternativa descartada: `Grid`/`LazyVGrid` con filas troceadas (cambia la identidad al pasar de 1 a 2 columnas).

**D3 · Panel, cabecera.** → En regular, banda de dos columnas: saldo + acciones a la izquierda, «Tus finanzas» a la
derecha; los avisos (Siri, actualización, prueba, checklist…) pasan debajo de la banda. «Tus finanzas» sale de
`PanelFilterAndWidgetsSection` al contenedor de la cabecera; en iPhone el orden y los espacios no cambian.
Por qué: la altura baja de ~290 a ~180 pt en horizontal. Alternativa descartada: acciones a la derecha del saldo
(ahorra ~60 pt, deja «Tus finanzas» igual).

**D4 · Carrusel de cuentas en media columna.** → Cuántas tarjetas se ven lo decide el ancho del carrusel, no el size
class (4 en ancho de pantalla, 2 en media columna o iPhone).
Por qué: con el size class saldrían 4 tarjetas de ~110 pt en la columna derecha.

**D5 · Últimos registros.** → Un widget que se queda solo en su fila y sabe repartir su contenido (solo
`latestRecords`) ocupa la fila entera en regular; dentro, sus cinco filas van en pares. Los demás widgets huérfanos
siguen en media fila.
Por qué: estirar Top gastos o un donut a 1000 pt es el «iPhone estirado» otra vez; y una tarjeta partida en pares no
cruza el pliegue con una fila.

**D6 · Estadísticas · Resumen.** → En regular: [Salud financiera | Resumen inteligente], selector Detalle/Observaciones
a lo ancho, «Tus cifras» con [Promedio diario + Suscripciones | las cuatro cifras], [Compromisos | Por necesidad], y las
observaciones en pares. Un impar va a la columna izquierda (no cruza el pliegue).

**D7 · Estadísticas · Tendencias.** → En regular todas las tarjetas en pares: con comparación, [Tendencia | Comparación]
como hoy; sin ella, [Tendencia | Flujo de efectivo], [Promedio por día | Hallazgos].

**D8 · Estadísticas · Registros.** → Mismo molde que la página Registros: en regular el toque abre el registro en una
columna a la derecha de la lista (`opensDetailInColumn`); si no caben lista y detalle (< 2 × 375), el detalle tapa la
lista y se cierra con su X. En compacta, la hoja de siempre. Sin `NavigationSplitView`: el chip vive dentro de la pila
de Estadísticas y un split dentro de una pila no está soportado. El detalle en columna lleva cabecera propia (X +
Editar) en vez de meter botones y el título inline en la barra de Estadísticas; Editar abre el editor directo, sin el
encadenado de la hoja. Estrechar a compacta con un registro abierto lo pasa a la hoja.

**D9 · Evidencia.** → XCUITest temporal (no se commitea) con `seed realista` + Pro en los cuatro Adapt por UDID;
redimensionado con `XCUIApplication+Window`. Sin Duo (no existe el simulador).
