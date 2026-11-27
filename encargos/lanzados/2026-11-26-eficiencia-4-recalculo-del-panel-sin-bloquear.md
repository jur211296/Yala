Yala
# Eficiencia 4: el recálculo del Panel deja de bloquear (por tramos, presupuestos y salud financiera en un solo recorrido)
---
toca: Yala/App/ViewModels/PanelViewModel.swift,Yala/App/ViewModels/BudgetsViewModel.swift,Yala/App/Logic/Calculators/FinancialScoreCalculator.swift,Yala/App/Logic/RecalculoPanel,YalaTests/EficienciaRecalculoPanel,docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-4-recalculo-del-panel-sin-bloquear/,tickets/backlog/2026-11-26-eficiencia-4-recalculo-del-panel-sin-bloquear.md,tickets/done/2026-11-26-eficiencia-4-recalculo-del-panel-sin-bloquear.md
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: no
depende: Yala/eficiencia-3-no-morir-en-segundo-plano
---

Lote del plan de eficiencia que salió del análisis de calentamiento, batería y scroll en el iPhone 14. Espera al lote 3 porque los dos cambian `PanelViewModel.swift` y la cancelación del recálculo.

## Qué se pide
1. `performCalculation` por tramos que cedan el hilo (como ya hace la lectura), o fuera del hilo principal sobre valores copiados (no sobre `@Model`). Piezas nuevas en `Yala/App/Logic/RecalculoPanel/`.
2. Presupuestos: un solo recorrido de los movimientos para todos (índice por fecha/categoría) en vez de uno por presupuesto (`BudgetsViewModel.filterTransactions`, `calculateBudgetsWidget`).
3. Salud financiera: `calculateRhythm` sin ordenar todos los movimientos; reusar los días ya agrupados.
4. Leer `date`, `amount`, `account` y `category` de cada `TransactionItem` una vez por recálculo (como `FlujoMotorMesEntrada.movimientos`) y pasar valores, no modelos.
5. Que cada recálculo cancelable pueda abandonarse al pasar a segundo plano sin dejar el hilo ocupado.
- Las cifras del Panel, presupuestos, salud financiera, Flujo de caja y widget tienen que quedar idénticas: pruebas que comparen el cálculo viejo contra el nuevo con datos de ejemplo grandes.
- Pruebas nuevas en `YalaTests/EficienciaRecalculoPanel/`.

## Mejora esperada y cómo se mide
El recálculo completo de 7 s pasa a pasos de < 50 ms (sin congelar) y su total baja. Medir con marcas `Panel.performCalculation` (intervalo) y `potential-hangs` del Time Profiler al arrancar y al tirar para actualizar: ningún bloqueo > 250 ms.

## Qué NO hay que tocar
- Nada fuera de `toca:`; si necesitas otro archivo, anótalo en «Saltado o asumido sin preguntar» con el motivo.
- Lo de los otros lotes del plan (cada uno va en su sesión).

## Contexto común
- Informe de origen: `docs/qa/rendimiento-iphone14-2026-11-26/README.md` (sección «Lotes propuestos» y «Causas raíz, ordenadas por impacto medido»), con datos en `docs/qa/rendimiento-iphone14-2026-11-26/datos/` y los guiones de medición en `docs/qa/rendimiento-iphone14-2026-11-26/scripts/` (por ejemplo `scripts/pasada.sh`). Lo hizo la sesión «Análisis profundo de calentamiento, batería y scroll en iPhone 14» el 26-nov midiendo en el iPhone 14 de Jürgen con un almacén de 16.004 movimientos. Si al arrancar el informe todavía no está en `origin/2.3`, búscalo en la rama `encargo/2026-11-26-analisis-rendimiento-calentamiento-scroll-iphone14`.
- Pedido de Jürgen (26-nov, 10:44 Lima): «encola los 6 lotes de mejoras de eficiencia de la sesión del calor». Él siente que Yala calienta el teléfono al ir y volver de otra app y que el scroll al volver va lento.
- Las líneas citadas en el informe son de `origin/2.3` en `b5c6e98c5`; confírmalas en el código de hoy, porque otros lotes ya pueden haber cambiado esos archivos.

## Cómo medir
- **Antes y después en el iPhone 14 real** («iPhone de JURGEN», conectado por cable a la Max) con DeviceMCP, `devicectl` y `xcrun xctrace`, usando los mismos guiones y el mismo almacén de 16 k que el informe, para que las cifras sean comparables. Las cifras de rendimiento solo valen si salen del iPhone 14; el simulador sirve para desarrollar y para las pruebas, no como evidencia de rendimiento. En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Apaga y limpia los que enciendas.
- Al arrancar, comprueba con `xcrun devicectl device info lockState --device 00008110-001A35A6267A401E` que el iPhone no está bloqueado. Si está bloqueado o no responde: en semiautónomo, pídele a Jürgen que lo desbloquee (y que ponga Bloqueo automático en «Nunca» mientras dure la prueba) y espera con la sesión viva; en nocturno, termina lo que no necesite el teléfono, deja checkpoint y anota la medición pendiente como `BLOQUEANTE:` con el error exacto. Si el iPhone lo está usando otra sesión, espera en tramos cortos con aviso.
- Deja las mediciones de este lote en `docs/qa/rendimiento-iphone14-2026-11-26/despues-<slug-del-lote>/` (resumen numérico antes/después y extractos de trazas, nada pesado) y compáralas contra la «mejora esperada» del informe.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Cada cambio con su prueba en la carpeta de pruebas de este lote. Textos nuevos, si hiciera falta alguno, solo en una tabla de strings propia del lote en cada `.lproj`, nunca en `Localizable.strings`.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo; para medir, compilación de perfilado (Release con símbolos) instalada como Yala Dev en el iPhone 14. Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Antes de compilar en iOS mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Nada de cambios de esquema de SwiftData, CloudKit ni Supabase; si crees que hace falta uno, es pregunta vital para Jürgen. No cambies lo que la persona ve, salvo lo que diga el lote.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- No borres datos del iPhone ni la base de desarrollo.

## Cierre
- Un solo PR a `2.3`, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Entrega: artifact visual de Claude con antes/después medido en el iPhone 14 (cifras y gráficas), qué se cambió y qué quedó pendiente; enlázalo en el cierre. No Markdown, PDF ni documento de puro texto.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada». `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones

> Resueltas por la sesión (semiautónomo; ninguna es de producto ni irreversible): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: el lote 3 (PR abierto en auto-merge) ya parte `performCalculation` en 5 etapas que ceden el hilo y se cortan al irse; la sesión «novedades del Panel» que señalaba el aviso de `lanzar-sesion` ya mergeó (PR #1111): no hay choque. Lo caro son recorridos repetidos de los 16 k movimientos: cada presupuesto (×24, dos veces: gastado y hoy), cada ciclo de presupuesto de la nota de salud, las alertas de la nota, y los filtros completos de la tendencia, con `TransactionItem.date` leída de SwiftData en cada uno.

**D1 · ¿Base?** → la rama del lote 3 (`encargo/2026-11-26-eficiencia-3-no-morir-en-segundo-plano`), y rebase sobre `origin/2.3` cuando entre.
Por qué: el encargo declara `depende:` de ese lote y los dos tocan la cancelación del recálculo. Alternativa descartada: esperar al merge (bloquea la sesión sin necesidad).

**D2 · ¿Fuera del hilo principal o por tramos?** → por tramos en el hilo principal, con cesión cooperativa por tiempo (un tramo cede al pasar de ~25 ms) dentro de las etapas, y menos trabajo por tramo.
Por qué: los `@Model` son del main actor (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, ya lo midió el lote 3 con Spotlight); llevarlo fuera exige copiar a valores TODO lo que leen las calculadoras (decenas de piezas compartidas con Estadísticas, Registros y widgets), con riesgo alto para la regla «cifras idénticas». Alternativa descartada: reescribir las calculadoras sobre valores (fuera de alcance de un lote).

**D3 · ¿Cómo quedan las cifras idénticas?** → los recorridos se acotan con un índice por fecha armado una vez por recálculo, que devuelve los movimientos de un intervalo EN EL ORDEN del arreglo original; cada calculadora sigue filtrando igual por dentro, así que recibe los mismos elementos en el mismo orden (las sumas de `Double` no cambian ni en el último bit). Pruebas que comparan el cálculo viejo contra el nuevo con un almacén grande.
Por qué: es el único camino que no toca la regla de cada cifra. Alternativa descartada: acumular por presupuesto en una sola pasada (cambia el orden de suma y duplica la regla de `filterTransactions`).

**D4 · Item 4 del encargo (leer date/amount/account/category una vez y pasar valores)** → solo la fecha, en el índice.
Por qué: la fecha es la lectura que se repetía (el 40 % del bloqueo); importe, cuenta y categoría los leen calculadoras compartidas que reciben modelos, y pasarlas a valores es D2-descartada. Queda anotado como parcial.

**D5 · Un guardado a mitad del cálculo** → si entre dos tramos alguien guardó y hay movimientos borrados en lo que el cálculo tiene, se corta y se pide la recarga; si no hay borrados, sigue.
Por qué: leer un `@Model` borrado aborta en el iPhone, y con más cesiones hay más ventanas en las que un borrado diferido («Deshacer» que vence) puede colarse. Cortar en cada guardado dejaría el Panel sin terminar durante una importación o la sincronización.

**D6 · Archivo fuera de `toca:`** → `Yala/App/Logic/FinancialScoreAlertsLogic.swift`, para que las alertas de la nota también acoten los presupuestos por fecha (otra pasada de 24 × 16 k). Se anota en «Saltado o asumido».

**D7 · Medición** → copia de perfilado (`Release-Dev` + `DEBUG` solo en la copia), mismo almacén de 16 k en el iPhone 14, arranque en frío con consola (resumen `PERF panel-calculo` por cálculo: total, tramo más largo sin ceder y etapas) y una pasada de Instruments (`potential-hangs`). Las marcas (`os_signpost` «Panel.performCalculation» y por etapa) se quedan en el código: son baratas y es lo que pide el encargo para medir.

**D8 · Pruebas de interfaz** → ninguna nueva (`pruebas-ui: no`); unit en `YalaTests/EficienciaRecalculoPanel/` y el gate con lo que elija para las áreas tocadas.
