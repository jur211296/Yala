# iPhone · en la pantalla más pequeña, que nada quede tapado ni cortado (carril adaptativo, paso 3/13)

## Contexto
Carril adaptativo iPad/iPhone Duo en paralelo a Cola A. Acaba de mergear a 2.1 el paso 2 (PR #293 · texto muy grande: importes ya no se cortan). Plan vigente: `docs/exploracion/adaptativo-ipad-duo.md`. Ticket: `tickets/backlog/iphone-small-screens-and-safe-areas-audit.md`. Cola A sigue viva en otra sesión (`Yala--groups-outbox-rows-without-a-live-session-have-no-exit`): no la toques.

MODO AUTÓNOMO: decide tú las opciones robustas / Apple-recommended sin preguntar a Jürgen salvo que haga falta su dispositivo, secretos o algo irreversible.

## Que se pide
Auditar y arreglar lo barato en iPhone SE (pantalla más pequeña) para que nada quede tapado ni cortado, también con teclado y con texto AX5.

1. Recorrer en el simulador dedicado las mismas diez pantallas del paso 2 (`iphone-large-text-sizes-break-layouts`), más suscripción y formularios con teclado (Nuevo registro, presupuesto, cuenta).
2. Buscar: contenido bajo barra de estado o indicador de inicio, botones que el teclado tapa, alturas fijas que cortan gráfica/texto, scroll que no llega al final.
3. Revisar los 29 `ignoresSafeArea`: se queda el fondo; se va el que meta contenido o controles bajo el borde.
4. Arreglar lo barato (márgenes, `safeAreaInset`, alturas relativas). Lo que cambie la estructura de una pantalla → ticket aparte.
5. Evidencia: capturas antes/después en SE y Pro Max, tamaño normal y AX5, en `qa/evidencia-adaptativo-AAAAMMDD/iphone-small-screens-and-safe-areas-audit/`. Lista de hallazgos en el ticket (arreglado aquí o con ticket nuevo). XCUITest de áreas tocadas en verde por UDID. Gate verde. PR a 2.1.

## Simuladores (obligatorio — no chocar con Cola A)
Solo estos, siempre por UDID (`-destination id=<UDID>`), nunca por nombre genérico ni `booted`. DerivedData del worktree (`-derivedDataPath .ddp`).

- YalaLane-Adapt-iPhone-SE → `AF88C006-D42F-4573-9BA0-B0B3707A8E4C`
- YalaLane-Adapt-iPhone-ProMax → `A918242C-437C-4166-8748-6A24DCCC0F7B`

Prohibido: `simctl shutdown all`, `erase all`, `killall Simulator`, o tocar simuladores sin prefijo `YalaLane-Adapt-`.

## Que NO hay que tocar
- Simuladores de Cola A ni sesiones tmux ajenas.
- Flujos de release 2.1 ni cambios que rompan iPhone a tamaño normal.
- Fase Duo / Xcode 27.1 (no está instalado; no bloquea este paso).
- Cola A / sync / cloud.

## Como se sabe que esta bien
- En SE y Pro Max (normal y AX5) nada queda tapado ni cortado en las pantallas del recorrido; capturas antes/después en la carpeta de evidencia.
- Hallazgos listados en el ticket (hechos aquí o con ticket nuevo).
- Tests tocados verdes por UDID; gate verde; PR mergeable a 2.1.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir (árbol `f1589562`).** Los «29 `ignoresSafeArea`» son 29 líneas, pero 2 son
comentarios (`ViewModifiers.swift:634`, `GroupShareableSummarySheet.swift:100`): quedan **27 llamadas**, 3 de ellas en
`#Preview`. Las alturas fijas de 200 pt o más son **27**, no 24 (corregido al cerrar: al principio conté 26 a mano). La configuración de StoreKit solo cuelga del `Run`
del scheme, no del `Test`.

**D1 · Cómo se recorre** → XCUITest temporal de capturas, como el paso 2, con `-uitest-seed grupos`; se borra antes
del commit. «Antes» es `f1589562`.
Por qué: es repetible en los dos iPhone y los dos tamaños, y el paso 2 ya lo validó. Alternativa descartada: tocar
a mano con XcodeBuildMCP, que no se puede repetir para el «después».

**D2 · Qué `ignoresSafeArea` se queda** → fondos, velos oscuros y confeti se quedan. Los que envuelven contenido
(splash y guía de primeros pasos) se miden en captura, y solo se tocan si algo queda bajo el borde.
Por qué: es el criterio del ticket, y un fondo que no llega al borde deja una franja visible.

**D3 · Qué altura fija se toca** → las que estén dentro de un scroll no se tocan salvo que corten algo. Las de
pantallas sin scroll (suscripción, pantallas de éxito, splash, bienvenida) se miden en el SE.
Por qué: dentro de un scroll una altura fija no puede tapar nada, solo alarga.

**D4 · Qué cuenta como barato** → márgenes, `safeAreaInset`/`padding`, alturas relativas, y envolver en scroll un
contenido que no cabe **sin reordenarlo**. Reordenar, cambiar la navegación o quitar piezas → ticket aparte.
Por qué: envolver en scroll no cambia qué ve el usuario cuando cabe, y es lo que Apple recomienda para Dynamic Type.

**D5 · Suscripción** → se captura con la cuenta gratis (`pro: false`), que es quien ve el muro de pago. Si las
tarjetas de producto no cargan en test (StoreKit no cuelga del `Test`), se anota y se juzga el resto del layout.
Por qué: montar StoreKit en el test es otro trabajo y no cambia el hero ni los márgenes.

**D6 · Duplicados** → lo que ya esté en `floating-buttons-cover-row-amounts-on-ipad-landscape` o en
`large-text-leftovers-outside-the-main-iphone-screens` se referencia, no se abre de nuevo.
Por qué: lo manda el propio ticket y la memoria («ticket nuevo: busca el duplicado primero»).

**D7 · Evidencia y verificación** → `qa/evidencia-adaptativo-20260928/iphone-small-screens-and-safe-areas-audit/`,
JPG a 320 px como el paso 2. A tamaño por defecto, las pantallas no tocadas se comparan píxel a píxel. XCUITest de
las áreas tocadas en `YalaLane-Adapt-iPhone-ProMax` por UDID, en cola con `sim-lock.sh`.
Por qué: el paso 2 cazó así un truncado que el ojo había pasado.
