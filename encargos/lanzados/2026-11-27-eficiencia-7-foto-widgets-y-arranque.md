Yala
# Eficiencia 7: foto de los widgets, arranque en frío y render de fondo más livianos, medidos en el iPhone 14
---
toca: Yala/Services/WidgetDataCache.swift,Yala/App/AppBootstrapper.swift,Yala/App/ViewModels/PanelViewModel.swift,Yala/App/Logic/RecalculoPanel,Yala/App/Logic/Calculators/ProjectedFlowBuilder.swift,Yala/App/Views/Panel,Yala/App/Logic/FotoWidgetsArranque,docs/qa/rendimiento-iphone14-2026-11-26/,YalaTests/EficienciaFotoWidgetsArranque,tickets/backlog/2026-11-27-foto-widget-por-etapas-rojo-en-la-suite-completa.md,tickets/done/2026-11-27-foto-widget-por-etapas-rojo-en-la-suite-completa.md,tickets/backlog/2026-11-27-eficiencia-7-foto-widgets-y-arranque.md,tickets/done/2026-11-27-eficiencia-7-foto-widgets-y-arranque.md
modelo: opus
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: si
---

Decisión de Jürgen (27-nov, 06:17 Lima): aprobó encolar tal cual los tres lotes propuestos a partir de los hallazgos de los cierres del 26-nov y de los pendientes de 2.3. Corre en paralelo con «Trabas: proyección inteligente…» (otra máquina): sus `toca:` no se cruzan.

## Contexto
- Cards del tablero de Yala 2.3 (búscalas por título con `tablero listar --proyecto Yala`): «Eficiencia 7: foto de los widgets y arranque en frío más livianos»; «La app se traba unos segundos armando el resumen del período del widget (Sentry YALA-IOS-16)». Al terminar, muévelas a «in qa» con una nota del PR y las cifras.

## Qué se pide
Sigue al plan de eficiencia 1 a 6 (informe en `docs/qa/rendimiento-iphone14-2026-11-26/`, con sus guiones en `scripts/` y la pasada final del lote 6). Pendientes que dejaron sus cierres:
1. **Foto de los widgets al salir** (~280 ms por salida) **y al abrir** (bloqueos de hasta 1,4 s; hoy lo más largo del arranque), en `WidgetDataCache.swift` y su disparo en `AppBootstrapper.swift`: que no bloquee el hilo principal (por tramos, fuera del hilo sobre valores copiados, o solo si cambió algo).
2. **Traba al armar el resumen del período del widget (Sentry YALA-IOS-16):** `WidgetDataCache.rebuildPendingInStages` → `buildSnapshot` → `buildPeriodSummary` → `TransactionItem.amountInPreferredCurrency` en el hilo principal. Mismo arreglo que el punto 1, con prueba de paridad de las cifras del widget.
3. **Arranque en frío con dos cálculos completos seguidos del Panel** (~16 s con 16 mil movimientos): que haga uno solo (`PanelViewModel` / `AppBootstrapper`), sin perder lo que el segundo corregía (por ejemplo, datos que llegan de la nube): pruébalo.
4. **Proyección del saldo** (~0,9 s de una vez en `ProjectedFlowBuilder`, compartido con Flujo de caja, Tendencias y el widget): por tramos o fuera del hilo principal, con paridad. Si para eso hay que tocar `FlujoMotorMes` (fuera de `toca:`, lo usa otra sesión en paralelo), no lo toques: anótalo.
5. **Suelo de 23 a 34 pasadas de render fuera de pantalla** en Panel, Tendencias, Distribución y Pagos: primero mide qué lo causa (candidatos sin medir: barras del sistema y gráficas). Corrige solo lo que esté en `Yala/App/Views/Panel/`; lo de Estadísticas o Pagos queda medido y anotado para otro lote.
6. Mueve a `tickets/done/` el ticket repetido `tickets/backlog/2026-11-27-foto-widget-por-etapas-rojo-en-la-suite-completa.md`, con una línea: lo resolvió el PR 1204 (deuda de 2.3).
- **Medición antes y después en el iPhone 14** con los guiones del informe y el mismo almacén de 16 k (arranque en frío, salidas y vueltas, reposo y scroll), en `docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-7-foto-widgets-y-arranque/`. Si el iPhone está ocupado (candado), mide primero en el simulador y deja la pasada del iPhone para el final; las cifras de rendimiento valen solo del iPhone 14.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Cada cambio de código con su prueba en la carpeta de pruebas de este encargo.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo. Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Puedes usar un segundo simulador en la Max; en la Mini, uno solo. Apaga lo que enciendas.
- **iPhone 14** («iPhone de JURGEN», conectado a la Max) por DeviceMCP: tiene candado (ADR-132 de casa, hook `candado_dispositivo.py`). Si al usarlo te dice que está ocupado por otra sesión, **no reintentes en bucle**: sigue con el simulador o con otra parte del trabajo y vuelve a probar una sola vez más tarde; si sigue ocupado, anótalo en «Saltado o asumido sin preguntar». Antes, comprueba con `xcrun devicectl device info lockState --device 00008110-001A35A6267A401E` que no esté bloqueado. No borres datos del iPhone.
- Antes de compilar en iOS mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Sin cambios de esquema de SwiftData, CloudKit ni Supabase; si crees que hace falta uno, es pregunta vital para Jürgen.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Nada fuera de `toca:`. Este lote corre en paralelo con otros que tienen archivos vecinos: si necesitas otro archivo, no lo toques; anótalo en «Saltado o asumido sin preguntar» con el motivo.

## Cierre
- Antes/después medido en el iPhone 14 (cifras y gráficas) en un **artifact visual de Claude** enlazado en el cierre (ADR-130 de casa).
- Un solo PR a `2.3`, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada». `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones

> Resueltas en semiautónomo, sin preguntar: son técnicas y reversibles. Se discuten en el PR.

Hechos medidos antes de decidir (traza `V_final` del lote 6, iPhone 14, 16.004 movimientos): la foto de los widgets ocupa
5,7 s de hilo principal en el arranque (resúmenes de período 3,2 s, proyección 0,8 s, lectura y filtro 0,5 s, tendencia
0,5 s), en bloques de hasta 1,3 s; después del arranque, 0 ms (la foto ya no corre al salir si nada cambió).

**D1 · ¿Foto fuera del hilo principal o por tramos en él?** → Por tramos en el hilo principal, sobre filas leídas una vez.
Por qué: los `@Model` son del main actor y las calculadoras compartidas también; sacarlo del hilo es reescribir media app.
Alternativa descartada: contexto en segundo plano (cascada de aislamiento en calculadoras de otras áreas).

**D2 · ¿Cómo se parte sin romper la API de etapas que usan los tests?** → Etapas reanudables con reloj (~20 ms por tramo)
por dentro; `buildSnapshot(context:now:stages:)` sigue devolviendo `[() -> Void]` corriendo cada etapa hasta el final.
Por qué: los tests de otras carpetas (fuera de `toca:`) siguen valiendo sin tocarlos.

**D3 · ¿Una implementación o dos del resumen de período?** → Una: las funciones de siempre leen filas y llaman al mismo
cuerpo. La paridad se prueba contra una copia congelada del código previo, solo en el test.
Por qué: dos implementaciones de la misma regla divergen. Alternativa descartada: variante nueva solo para la foto.

**D4 · Doble cálculo del Panel en el arranque** → El aviso del final del arranque (`incrementDataVersion` del paso 19) no
recarga el Panel si, desde que empezó su carga, no hubo guardados, ni cambios remotos, ni cambios sin guardar, ni otra
subida de `dataVersion`. Cualquier otra señal recarga como hoy. Por qué: `dataVersion` también avisa de cosas sin guardado
(borrado con «Deshacer»), así que no se puede ignorar en general; solo esa subida concreta es un empujón sin datos.

**D5 · Proyección del saldo** → En `ProjectedFlowBuilder`, la conversión de movimientos del motor (`FlujoMotorMesEntrada`)
se hace por tramos para el widget y el Panel; `FlujoMotorMes*` no se toca. El camino «con plan»
(`CashFlowProjectionCalculator`) queda anotado. Estadísticas y el saldo a fin de mes siguen con la versión de una vez.

**D6 · Pasadas fuera de pantalla** → Se mide primero; solo se corrige lo que esté en `Yala/App/Views/Panel/`.

**D7 · Antes y después** → «Antes» = `origin/2.3` en `a5e93673f`, copia de perfilado como en los lotes 1-6, mismo almacén.

**D8 · Dos source-scans de `ApproximateMarkWiringTests` (fuera de `toca:`) fijaban el texto de la regla dentro de
`buildPeriodSummary`** → se actualizan para fijarla donde vive ahora (`FilaFotoWidget`), y suman que `sumarNativo` sea espejo
exacto de `LiveBalanceCalculator.addNative`. Por qué: sin eso el gate queda rojo por texto movido, no por una regla rota.
Alternativa descartada: escribir el código para que el texto viejo siguiera apareciendo (un scan que se cumple por letra).

**D9 · La lectura por tramos del Panel se comparte con la foto** (`LecturaMovimientosPorTramos`, en `RecalculoPanel/`).
Por qué: la foto leía los 16 mil de una vez (414 ms) y el algoritmo del Panel es sutil (claves repetidas, borrados a mitad);
una sola copia. Alternativa descartada: duplicarlo en la foto.

**D6, resultado** → El suelo de pasadas son las barras del sistema (32 → 18 sin ellas); las gráficas no lo mueven. No es
código del Panel y tocar el cristal es diseño: medido y propuesto, sin cambio.
