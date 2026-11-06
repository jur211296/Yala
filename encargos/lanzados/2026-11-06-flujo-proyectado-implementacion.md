# Flujo proyectado · implementación en Tendencias, Panel y WidgetKit
toca: Tendencias, Panel, flujo de caja, WidgetKit, Flujo proyectado

Rama base: origin/2.3. Un solo PR contra 2.3, un solo cierre. Máquina: la libre (máx. 1 Yala o marketing por máquina). Si la prueba va mejor en el celular que en el simulador, usa el iPhone 14 conectado por DeviceMCP. Si corres en la Max y otra sesión de otro proyecto ya usa un simulador, puedes abrir un segundo (tope 2 en la Max) o usar el iPhone 14 conectado por DeviceMCP. En la Mini el tope de simuladores es 1. Cierre autónomo. Termina con `/cerrar-total`. Commits y PR sin firma de IA.

Card: «Flujo proyectado en Tendencias y Panel». Ticket y plan: salieron de la exploración (PR 830 mergeado). Las 13 respuestas de producto ya están en el repo; no reabras el interrogatorio salvo un hueco nuevo que cambie el resultado (entonces `preguntar-bot`).

## Contexto
Jürgen quiere Flujo proyectado en Tendencias y Panel, con control «Ver proyectado» que muestra una continuación punteada del gráfico diario estimada con pagos planificados y bases de gasto (puede apoyarse en flujo de caja). Debe incluir WidgetKit.

## Qué se pide
1. Implementar según el plan y las respuestas de la exploración.
2. Incluir WidgetKit.
3. Pruebas en pantalla (DeviceMCP o simulador) y cards a `in qa` con guion corto.
4. Si falta un detalle de producto que bloquee, `preguntar-bot` con 2–3 opciones; no asumas.

## Qué NO hay que tocar
marketing/. No redesplesgues infra. No reabras decisiones ya respondidas en la exploración.

## Cómo se sabe que está bien
Se ve «Ver proyectado» con la continuación punteada; WidgetKit muestra el proyectado; gate verde; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR. Las 13 de producto ya
> estaban respondidas (todas A, ticket `flujo-proyectado-en-tendencias-y-panel`); estas son las técnicas que dejaban abiertas.

**D0 · Rama base** → la rama nació de `2.2`; se movió a `origin/2.3` (sin commits propios). Por qué: el encargo pide 2.3 y el plan solo existe ahí.

**D1 · Qué gráficas** → el proyectado se calcula por día y, si la gráfica va por semanas o meses (Panel en «Este año»), se muestrea por grupo. El control sale solo si queda al menos un día del período por delante. Por qué: la misma píldora en las dos pantallas para el mismo período. Alternativa descartada: solo agrupación diaria (Tendencias lo mostraría en «Este año» y el Panel no).

**D2 · Lo que falta de una línea del plan** → `max(planeado − real − pagos planificados pendientes de esa línea en el mes, 0)`, repartido entre los días que quedan del mes; las líneas de método «pago planificado» no suman aparte (sus pagos ya van en su día). «Otros gastos» no se proyecta. Por qué: sin restar los pagos de la línea, un pago se contaría dos veces.

**D3 · Ritmo** → últimos 90 días completos antes de hoy, sin ajustes de saldo, transferencias ni movimientos enlazados a un pago planificado; se divide entre los días con historia (máx. 90); con menos de 14 días no hay ritmo y solo se proyectan pagos y movimientos futuros (rótulo «Estimado con tus pagos planificados»). Por qué: un usuario nuevo proyectaría su primera semana sobre el mes entero (riesgo del ticket).

**D4 · Plan o ritmo** → por lado (gasto/ingreso): plan si hay plan con líneas activas de ese lado y no hay filtros de sesión; si no, ritmo con los movimientos filtrados. Por qué: 10A pide ritmo filtrado con filtro de cuenta; el plan tampoco se puede repartir por categoría ni etiqueta, así que cualquier filtro cae al ritmo.

**D5 · Pago vencido** → ocurrencias desde el inicio del mes en curso (o del período, si empieza antes) no pagadas se dibujan mañana; pagada = movimiento enlazado ese día o fecha ≤ `lastPaidDate`. Por qué: 6A sin arrastrar años de ocurrencias viejas.

**D6 · Widgets** → la foto lleva un campo OPCIONAL con lo esperado por día (de mañana a fin de año) sin filtros de sesión; cada widget lo acumula sobre su propio último punto. «Mostrar proyectado» en «Gasto» y «Saldo», apagado; línea punteada del color de la métrica, distinta del gris del período anterior. Por qué: el ancla de cada widget es su curva, y un solo campo sirve a todos los períodos.

**D7 · Preferencia** → `AppPreferences.showsProjectedFlow` (apagada), compartida por Tendencias y Panel; encenderla apaga «Ver el mes anterior» y al revés (8A).

**D8 · Cifra** → bajo la gráfica de la app: «Proyectado al cierre» + monto (oculto con «Ocultar montos») y el rótulo de la fuente; el «≈» sale si alguna conversión fue aproximada (11A).
