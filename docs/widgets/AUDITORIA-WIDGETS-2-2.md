# Auditoría de los widgets de Yala · 2.2

**Fecha:** 2026-10-31 · **Sesión:** S35f (`widgets-auditoria-rediseno`) · **Card:** `tablero-widgets-auditoria-veloz-y-rediseno-para-hzag`

Pedido de Jürgen (31-oct): «están horribles… que se vean bien, dinámicos, modernos, que den valor», «funcionales, con
gráficas agradables, fondo adecuado de las cards, respetando el design system».

## Cómo se miró

- **Los 18 widgets y los 2 controles** del target `YalaWidgets`, en todos los tamaños que admiten.
- **Datos reales**: la foto que escribe la app con la semilla `realista` (2 cuentas, 6 presupuestos —dos pasados—,
  8 pagos planificados, dos años de movimientos), congelada en `qa/widget-render/fixtures/realista-2026-10-31.plist`.
  Antes y después salen de la misma foto y del mismo «ahora» (31-oct-2026, 20:06 de Lima).
- **Banco de render** (`qa/widget-render/`): pinta las vistas del widget fuera de WidgetKit con las medidas del
  iPhone 17 Pro, en claro, oscuro y StandBy (sin tarjeta, sobre negro). Tintado y pantalla de inicio real se miran
  aparte en el simulador. Ver su README.
- **Capturas**: `capturas/widgets/antes/` y `capturas/widgets/despues/` (copiadas al cerrar a
  `~/Claude/worktrees/_capturas/2026-10-31-widgets-auditoria-rediseno/`), una por widget, tamaño y modo:
  `<widget>-<tamaño>-<modo>.png` con tamaño `s · m · l · xl · xlv · circ · rect` y modo `claro · oscuro · standby`.

## Lo que falla en todos

| # | Qué pasa | Por qué importa | Qué se hace |
|---|---|---|---|
| G1 | **Nada responde «¿voy bien?»**. Saldo, Gastos y Flujo enseñan una cifra suelta; ninguno compara con nada (mes pasado, presupuesto, inicio del período). | Una cifra sin referencia no se puede juzgar desde la pantalla de inicio: hay que abrir la app. | Tanda 1: variación del saldo en el período, gasto contra el mes/año pasado a la misma altura, ritmo de cada presupuesto. |
| G2 | **Colorean la norma**: todos los gastos en rosa (Gastos, Pagos, Últimos registros) y los porcentajes en el color de la categoría. | La regla de la app es colorear la excepción (`swiftui-ds.md`); además el rosa y los colores de categoría como texto no pasan el AA sobre blanco (3,77:1 y menos). | Solo el ingreso y lo que avisa llevan color, con los tokens de texto AA de la app (`incomeAmount`, `overBudgetText`). |
| G3 | **Degradados** en las áreas de las curvas y en las barras (`.gradient`). | Jürgen los rechazó el 13-oct («se ve hecho con IA»). | Rellenos sólidos con opacidad baja, líneas limpias. |
| G4 | **Gráficas con ejes de 8 pt** («80K», «1 oct») que no se leen a distancia de brazo. | Ruido que no informa en un widget. | Sin ejes; la información va en la cifra, la píldora y una referencia (línea del mes pasado, marca de hoy). |
| G5 | **Jerarquía invertida**: el título del widget (`headline` 17 pt + icono gris) compite con la cifra, y en pequeño deja medio widget vacío. | El ojo va al rótulo y no al dato. | Cabecera de la app: insignia sólida + título `subheadline` semibold (como `PanelSmallWidgetHeader`), cifra del hero del Panel (36 semibold). |
| G6 | **Tintado y StandBy sin pensar**: `widgetAccentable()` repartido en iconos, barras e importes a la vez; círculos de color con icono que en tintado se vuelven manchas. | Con tintado (iOS 18) y transparente (iOS 26) todo sale del mismo color y no hay foco. | Una sola cosa teñida por widget (la cifra o la gráfica); insignias translúcidas en tintado. |
| G7 | **Los grandes dejan un tercio vacío** (Presupuestos L, Pagos L, Últimos registros L). | Parece roto. | Filas que reparten el alto y un pie con la frescura de los datos. |
| G8 | **Tokens propios** (`WDS`) que no coinciden con los de la app (`sm` 6 vs 8, `md` 8 vs 12…). | «Respeta el design system» no se puede comprobar. | `WidgetDS`, espejo de `DS` con test de paridad. El `WDS` viejo se retira en la última tanda. |
| G9 | **El widget no avisa si sus datos son viejos**: si la app no se abre, «Este mes» puede seguir siendo el mes anterior. | Cifras que mienten sin decirlo. | Pie «Actualizado ayer / el 29 oct.» cuando la foto no es de hoy. |
| G10 | **Refresco desigual**: unos cada 2 h, otros cada 4 h; los de fechas («Hoy», «Mañana») no cambian a medianoche salvo Pagos. | «Mañana» se queda escrito el día del pago. | Política común: medianoche o +4 h, lo que llegue antes. La recarga tras guardar ya existía (`WidgetDataCache.updateCache` → `reloadAllTimelines`). |

## Widget por widget

Tanda: **1** = este PR · **2** = card S35f1 · **3** = card S35f2.

| Widget | Tamaños | Qué está feo o no aporta | Qué se hace | Tanda |
|---|---|---|---|---|
| **Saldo** | S · M | S: rótulo «Disponible · Este mes» (un saldo no es de un mes), cifra sola, medio widget vacío. M: cifra pequeña arriba a la derecha y curva con ejes de 8 pt y degradado. | Cifra del hero + cuánto subió o bajó en el período (píldora) + curva sin ejes con el punto de hoy. | 1 |
| **Gastos** | S · M | Cifra en rosa sin referencia; M con la curva acumulada y ejes. | Gastado + comparación con el mes/año pasado **a la misma fecha** + curva acumulada contra la del período anterior (punteada); en los demás períodos, el promedio diario. | 1 |
| **Presupuestos** | M · L | «S/2,967/1,800» críptico; porcentajes en rosa; barras gruesas; L con un tercio vacío. | Fila del Panel: insignia sólida, «Te quedan / Te pasaste», barra índigo (rosa al pasarse) con la **marca del ritmo** (cuánto del mes ya pasó). | 1 |
| **Pagos planificados** | M · L · XLV | Importes en rosa; fechas sin «cuándo» («3 nov.» en vez de «En 3 días»); el vencido cambiaba el icono del pago por «!». | Fecha relativa («Hoy», «Mañana», «En 3 días», «Vencido»), importe sin color salvo ingreso, «Te falta pagar este mes» arriba; el extragrande vertical comparte filas y cabecera. | 1 |
| **Últimos registros** | M · L | Título = categoría cuando no hay nota («Entretenimiento» / «Deportes y recreación»); gastos en rosa; sin fecha; L con hueco. | Título = nota o subcategoría, «Categoría · Hoy/Ayer/29 oct.», importe con signo (solo el ingreso en color) y botón **«+»** que abre Nuevo registro. | 1 |
| **Nuevo registro / Por voz / Escanear recibo** | S | Círculo tenue con icono sobre blanco: tres widgets que se ven como uno genérico. | Azulejo sólido de marca con icono y texto en blanco (los rellenos AA de la app) y un tamaño **mediano nuevo** en «Nuevo registro» con las tres acciones. | 1 |
| **Pantalla bloqueada: Saldo y Gastos** | circular | «79.4K» con punto decimal en español; icono + cifra + rótulo apretados. | Cifra compacta con el separador del idioma («79,4 k»). | 1 |
| **Pantalla bloqueada: Presupuesto** | rectangular | Barra del sistema; solo el %; nada de «cuánto queda». | Nombre, «Te quedan S/ X» y la barra con el ritmo; tamaño **circular nuevo** con aro (`Gauge`). | 1 |
| **Pantalla bloqueada: Próximo pago** | rectangular | «150 · 3 nov.» sin divisa. | Importe con divisa y «En 3 días». | 1 |
| **Entradas y salidas** | S · M · L · XLV | L y XLV: «cascada» de barras con degradado que no se entiende de un vistazo; leyenda de texto pegado; ejes de 8 pt. S: tres cifras en 10 pt. | Barras de ingreso y gasto por día/mes sólidas y el neto; mismo lenguaje de la tanda 1. | 2 |
| **Resumen del mes** | XL (iPad) · XLV | Los `Link` tiñen de **azul** los nombres de categorías y presupuestos y los títulos de sección; donut sin importes. | Recomponer con las piezas de la tanda 1; enlaces sin tinte. | 2 |
| **Categorías / Subcategorías que más gastas** | M | Título truncado («Categorías que más gas…»); porcentaje en el color de la categoría (no pasa AA). | Ranking con barras sólidas e importes legibles. | 3 |
| **Categorías / Subcategorías (tarta)** | L | Burbujas que se solapan y se cortan («0 %», «38 %» fuera del widget); sin leyenda con importes. | Donut con el total en el centro y leyenda con importe y %. | 3 |
| **Controles** (voz, foto) | Centro de Control | Correctos. Falta «Nuevo registro» como control. | Sin cambios en esta tanda (ver propuestas). | — |

> El formato de los importes en las filas («S/ -150 .00»: símbolo, signo, entero y decimales en gris más pequeños) es el
> de `AmountText` en toda la app, y los widgets lo copian con `WidgetAmountText`. No es un fallo del widget y se deja.

## Estados vacíos y sin datos

| Caso | Hoy | Qué se hace |
|---|---|---|
| Sin datos de Yala todavía | «Abre Yala para ver tu saldo» (bien desde L15-2). | Se queda. |
| Sin presupuestos / pagos | «Aún no tienes… · Toca para crear uno» (bien desde L15-2). | Misma idea con la insignia nueva (tanda 1). |
| Sin registros | Icono de bandeja y «Sin registros» en gris terciario (no se lee). | Mensaje legible y el «+» de la cabecera (tanda 1). |

## Lo que no entra en el rediseño y queda como card

- **Widget de Grupos** (saldos por grupo): los grupos no viajan en la foto del App Group; necesita campos opcionales
  nuevos en `WidgetDataSnapshot` (molde de `paymentsMonth`).
- **Acciones en el sitio con App Intents** (marcar un pago como pagado, repetir un favorito): escriben datos de la app
  — decisión de Jürgen.
- **Control «Nuevo registro»** en el Centro de Control.

## Tanda 1: cómo quedó

- **Pares antes/después** de cada widget, tamaño y modo: `pares/<widget>-<tamaño>-<modo>.png` (90 imágenes, en la
  carpeta de capturas de la sesión). El modo tintado del banco es aproximado.
- **Pantalla de inicio real** (simulador iPhone 17 Pro, iOS 27.0): Disponible pequeño, Gastos mediano y Presupuestos
  grande añadidos desde la galería, en claro, oscuro y Teñido: `real/inicio-*.png`. La casilla pequeña mide 164 × 164
  en el iPhone 17 Pro, la que usa el banco.
- **Reglas** que deja: `.claude/rules/widgets.md`. **Red**: `WidgetInsightsLogicTests` y
  `WidgetDesignSystemParityTests`.
- **Tamaños de iPad**: no se pintaron en esta tanda (las vistas son flexibles); el extragrande de iPad es del Resumen
  del mes, tanda 2.
- **Lo que cazó la review adversarial y se arregló**: las cuentas nuevas (variación, comparación, ritmo) se medían con
  el reloj y las cifras son de la hora de la foto, así que a medianoche del día 1 la comparación cruzaba meses; ahora
  todo se mide a la hora de la foto. También: un mes anterior relleno de ceros ya no da «S/ 0 a esta fecha», el eje de
  la gráfica es el período entero, el aviso «N se pasaron» cuenta todos los presupuestos, «Hoy/Mañana» cambian a
  medianoche con una entrada propia, la pantalla bloqueada respeta «símbolo o código», y el Resumen del mes conserva
  su fila de presupuesto hasta su tanda.

## Tanda 2: cómo quedó (S35f1)

- **Entradas y salidas** (S · M · L · XLV): el neto es la cifra grande, con signo; en «Este mes» y «Este año», la
  diferencia con el neto del período anterior a la misma fecha («↓ S/ 4,394 vs. setiembre» y «Neto en setiembre a esta
  fecha: S/ +3,334»). Ingresos y gastos en dos barras sólidas (turquesa y rosa de marca); en el grande y el vertical, lo
  de cada día (o mes) en barras sin ejes, lo que entró hacia arriba y lo que salió hacia abajo. En «Solo gastos», lo
  gastado, su promedio diario y sus barras, sin repetir la cifra. El pequeño dice el período bajo la cifra.
- **Resumen del mes** (XL de iPad · XLV): cabecera e insignia de la tanda 1, cifras en `title2`, aro sólido con la leyenda
  con importe y porcentaje, y los presupuestos con la fila de Presupuestos («Te quedan / Te pasaste por» y el ritmo). Sin
  azul: los enlaces pasan por `WidgetPlainLink`. El vertical reparte el alto y enseña hasta cinco presupuestos.
- **«Comparar con el período anterior» llega a los widgets**: apagada en la app, Saldo pierde su píldora, Gastos enseña
  el promedio diario y Entradas y salidas no compara.
- **Capturas**: `antes/`, `despues/`, `sin-variaciones/`, `solo-gastos/` y `real/` (pantalla de inicio del simulador
  iPhone 17 Pro, iOS 27.0: Entradas y salidas grande en claro, oscuro y Teñido; Resumen del mes vertical en claro y
  Teñido), en la carpeta de capturas de la sesión.
- **Lo que cazó la review adversarial y se arregló**: la escala de las barras no contaba las devoluciones ni lo apilado
  de un día (se salían de la gráfica); «Solo gastos» repetía lo gastado con una barra siempre llena; el pequeño no decía
  el período; la frase de VoiceOver de la comparación sonaba al neto del mes; el signo iba en dos sitios distintos;
  «Todo el tiempo» arrancaba en otro día que Gastos y su promedio diario no coincidía; y faltaban tests de los meses a
  partir de mitad de mes.
