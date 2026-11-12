# Cola 2.2 · lote 12.5 Gráficas, estadísticas y flujo de caja (11 cards)

## Contexto
Jürgen (24-oct): seguir la cola 2.2 por lotes 12.x hasta cerrar todas las cards de 2.2; el barrido de QA estricto es el cierre final de 2.2. Ya cerraron 12.1–12.4, Duo interactivo (PR #628), Fundido Welcome (PR #629) y el pack marketing assets X (PR #630). Esta es la sesión **12.5 · Gráficas, estadísticas y flujo de caja**. Base: `origin/2.2`, PR contra 2.2.

Son once cards en «lista para lanzar», versión 2.2. Léelas enteras con `tablero ver <id>` antes de tocar código (traen contexto, siguiente paso y hecha-cuando):

1. `tablero-al-tocar-un-segmento-de-una-grafica-con-5g94` — Al tocar un segmento de una gráfica con exclusiones activas, que la app pregunte si excluirlo o ver solo ese segmento
2. `tablero-bug-2-2-en-ocultar-con-una-sola-moneda-m-0xsk` — Bug 2.2 · En «Ocultar», con una sola moneda marcada, el monto se filtra en la moneda que se oculta
3. `tablero-con-la-semilla-ficha-mx-vida-el-saldo-ca-8iwf` — Con la semilla ficha-mx-vida el saldo cae de golpe el último día
4. `tablero-estadisticas-distribucion-arranca-en-gra-th3p` — Estadísticas › Distribución arranca en Gráficas; debería abrir en Detalle
5. `tablero-grafica-del-saldo-apr-26-pisa-a-oct-26-y-bjab` — Gráfica del Saldo: «apr 26» pisa a «oct 26» y la pastilla «Today» tapa «100K»
6. `tablero-la-frase-de-ia-del-flujo-de-caja-se-pide-xxau` — La frase de IA del flujo de caja se pide aunque la persona ya no sea Pro
7. `tablero-los-totales-de-este-mes-cuentan-un-movim-wluh` — Los totales de «Este mes» cuentan un movimiento fechado mañana a las 00:00
8. `tablero-tendencias-no-se-entera-de-que-editaste-m40j` — Tendencias no se entera de que editaste el importe de un movimiento
9. `tablero-un-pago-planificado-de-una-sola-vez-apar-0nba` — Un pago planificado de «Una sola vez» aparece como «Mensual» en la lista de Pagos planificados
10. `tablero-un-registro-que-espera-su-borrado-con-de-g7xn` — Un registro que espera su borrado con «Deshacer» sigue contando fuera de Registros
11. `tablero-ux-2-2-en-modo-duplicados-sin-el-criteri-fyxe` — UX 2.2 · En modo duplicados, sin el criterio «Fecha», no se ve de qué día es cada registro

No entran en este lote las cards de flujo/estadísticas de otra versión (2.4/2.5) ni las de «propuesta visual» de alineación de diseño (p. ej. «Flujo de caja tiene que sentirse la misma app»).

## Qué se pide
1. Al empezar: mueve las once a «in progress» con `--agente frank`.
2. Arregla cada una según su «hecha cuando». Preferible tests (unit / XCUITest) que fijen la regresión (filtros de gráfica, totales de periodo, refresh de Tendencias, etiqueta de frecuencia de pago). Criterio estricto de barrido: solo deja en «in qa» a jurgen (con guion corto) lo grave que el simulador no valida; lo demás a done.
3. UI sin decidir (p. ej. el diálogo al tocar un segmento con exclusiones): si el «hecha cuando» ya fija el comportamiento, impleméntalo; si hace falta elegir copy/layout, deja 2 propuestas con capturas y tu recomendación, card en «espera decisión» a jurgen, y sigue con el resto.
4. Dudas reversibles: toma la opción recomendada y anótala en la card. Solo lo irreversible queda en «espera decisión» a jurgen.
5. Tickets nuevos de lo que encuentres, con su card.
6. Si hay cambio visible, capturas antes/después en `capturas/` del worktree y listarlas en el cierre.

## Probe opcional simslim (no bloquea el lote)
Jürgen pidió probar simslim (MobAI) en la siguiente sesión no-Duo. Si al bootear el iPhone de Yala puedes clonar el sim y aplicar simslim sin alargar ni romper el pipeline, hazlo y deja 5–10 líneas en el cierre (memoria antes/después, si boot/build/UITests siguen OK). Si falla, falta el binario o complica el lote: sigue con el sim normal y anota «simslim no probado: <motivo>». No es requisito del lote.

## Qué NO hay que tocar
- marketing/ y Web/ (los lleva Lola).
- Ningún despliegue de esquema CloudKit a producción ni cambios en Supabase de producción.
- No desactivar tests ni saltarse protecciones de rama.
- No mezclar cards de 12.6/12.7 ni propuestas visuales de diseño de Flujo/Grupos.

## Cómo se sabe que está bien
Las once cards cumplen su «hecha cuando» (o quedan en in qa / espera decisión con motivo), suite unit en verde, PR a 2.2 en auto-merge, `/cerrar-total`.

## Gate después del CI del PR anterior
Arranca ya sobre `origin/2.2`. Justo antes del gate, si #629/#630 (u otro PR de la cola) sigue en CI, espera a que entre y rebasea una sola vez con el simulador apagado. Si 2.2 no se movió, sigue. Si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador después de ese rebase, una sola vez.

## Mini
Pipeline serial Yala: limpiar sims muertos / DerivedData de sesiones cerradas / cachés de XcodeBuildMCP de worktrees que ya no existen (sin preguntar); build con `xcodebuild -jobs 2` sin sim booteado; un solo simulador iPhone para tests; al cerrar apagar y borrar ese sim y el DerivedData de esta sesión. Disco: hay ~27 GB libres, por debajo del umbral APRETADO de 32 GB: limpia sin preguntar antes del build (`limpiar-mac --apply` si hace falta).

## Ritmo
Después van 12.6 → 12.7 → FAB → barrido. Ve directo: no alargues el lote con trabajo fuera de estas once cards.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Card 5g94 (tocar un segmento con exclusiones): ¿implementar la opción B entera en este lote?** → No: `/spec` en el ticket + 2 propuestas de UI con capturas y recomendación, card a «espera decisión» de Jürgen.
Por qué: B toca `SessionState`, `FilterService` y todas las barras de filtros, y el diálogo y cómo se pintan incluidos y excluidos a la vez son copy y layout por elegir (punto 3 del encargo). Alternativa descartada: implementar B con un diseño elegido por mí; si no gusta, se rehace la parte más cara.

**D2 · Distribución en Detalle: ¿qué pasa con el enlace de los widgets de subcategorías, que promete la gráfica?** → El enlace cambia a Gráficas antes de mover el carrusel.
Por qué: el enlace dice «la gráfica de subcategorías» y su XCUITest lo fija. Alternativa descartada: abrir en Detalle con la lista en subcategorías; contradice lo que el widget promete.

**D3 · «Ocultar» con una moneda marcada: ¿qué moneda usa el monto?** → La única que queda sin ocultar; si quedan varias o ninguna, no hay monto y la línea de ayuda dice «deja a la vista una sola moneda» (clave nueva en los 16 locales).
Por qué: el monto compara el importe de cada fila en su moneda, y lo que queda a la vista es lo que filtra. Alternativa descartada: no ofrecer nunca monto en «Ocultar»; quita algo útil con dos monedas.

**D4 · Frase de IA del flujo de caja: ¿el chip también refleja el plan?** → Sí: el chip se pinta encendido solo si la frase está de verdad activa (Pro + aviso + chip).
Por qué: encendido sin Pro diría que hay frase de IA y no la hay. Alternativa descartada: tocar solo la llamada; deja la pantalla contradiciéndose.

**D5 · «Este mes» y la medianoche de mañana: ¿arreglo por consumidor o en la fuente?** → En la fuente: los períodos en curso de `DetailPeriod.dateInterval` y su espejo `WidgetPeriod.dateInterval` cierran en `startOfTomorrow − 1 s`, como ya cierran los cerrados; y se auditan los consumidores que cuentan días o hacen buckets con `end`.
Por qué: los consumidores ya tienen que tratar bien un `end` en 23:59:59 (mes y año pasados); parchear uno a uno deja huecos (CLAUDE.md, corolario del 2026-09-02). Es cálculo financiero: lleva review adversarial. Alternativa descartada: los cuatro sitios del ticket; hay ~84 usos y quedarían los demás.

**D6 · Borrado con «Deshacer»: ¿cómo conserva cada borrado su «Deshacer» con un solo aviso?** → Los borrados seguidos comparten aviso y plazo: «Eliminaste 2 registros · Deshacer» devuelve todos, y el plazo se alarga al del último. Y lo pendiente se quita en Panel, Estadísticas, Buscar, widgets, ficha de cuenta y Presupuestos.
Por qué: ningún borrado pierde su «Deshacer» antes de tiempo y no hace falta un componente nuevo de avisos apilados. Alternativa descartada: dos cápsulas apiladas (diseño nuevo) o deshacer en pila LIFO (el primero queda sin botón mientras se ve el segundo).

**D7 · Modo duplicados sin «Fecha»: ¿fecha en la fila o rango en la cabecera?** → Fecha corta con año en cada fila («14 oct 2026»), y la lee VoiceOver.
Por qué: es lo que pide el «hecha cuando» y deja decidir fila a fila. Alternativa descartada: rango en la cabecera; no dice cuál es cuál.

**D8 · Pagos de «Una sola vez» (0nba) y gráfica del Saldo (bjab): ya hay código que lo arregla (lote 10 B1 y L3-17).** → Se mide en el simulador y, si se confirma, se cierran con evidencia sin tocar código.
Por qué: medir antes de obedecer al documento.

**D9 · Semilla `ficha-mx-vida` (8iwf)** → Medir primero qué tasa tienen las filas de ayer y hoy. Si es la petición de la tasa del día, que la semilla deje sembrada la fila de hoy con la clave que usa `ExchangeRateService` (UTC). Aviso a Lola en la card antes de que cambie su semilla.
Por qué: el ticket marca la causa como inferida.
