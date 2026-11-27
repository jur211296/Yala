Yala
# Eficiencia 8: calculadoras compartidas y carga inicial del Panel
---
toca: Yala/App/Logic/Calculators/LiveBalanceCalculator.swift,Yala/App/Logic/Calculators/BalanceValuation.swift,Yala/Utils/AccountBalanceCalculator.swift,Yala/App/ViewModels/PanelViewModel.swift,Yala/Services/WidgetDataCache.swift,Yala/App/Logic/FotoWidgetsArranque/,Yala/App/Logic/RecalculoPanel/,Yala/App/Logic/Eficiencia8CalculadorasYCargaPanel/,YalaTests/Eficiencia8CalculadorasYCargaPanel/,docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-8-calculadoras-y-carga-panel/,tickets/backlog/2026-11-27-eficiencia-8-calculadoras-y-carga-panel.md,tickets/done/2026-11-27-eficiencia-8-calculadoras-y-carga-panel.md,docs/TICKETS.md
modelo: opus
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: si
---

Decisión de Jürgen (27-nov-2026, ~10:14 Lima; t2014u): «sobre eficiencia 8 también a cola antes del barrido de una vez». Entra en 2.3, antes del barrido QA de la build 12.

## Contexto
- Sale de lo que dejó anotado Eficiencia 7 (PR #1208, «Eficiencia 7: foto de los widgets, arranque en frío y proyección sin trabar la app»): `tickets/done/2026-11-27-eficiencia-7-foto-widgets-y-arranque.md` y `docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-7-foto-widgets-y-arranque/README.md` (sección «Lo que queda en la foto» y datos en `datos/V_despues2_foto_arranque.txt`). Medido en el iPhone 14 con 16 mil movimientos.
- **Requisito de arranque:** este encargo construye sobre #1208 (`RecorridoConReloj`, `FilaFotoWidget`, `EmpujonFinDeArranque`, `LecturaMovimientosPorTramos`). A las 10:15 Lima estaba abierto con auto-merge. Si al arrancar no está mergeado en `origin/2.3`, revisa su estado con `gh pr view 1208`; espera en tramos cortos con aviso (no más de 3 min mudos) y, si sigue sin entrar tras 30 min o su CI falla, es pregunta vital para Jürgen (no lo arregles tú: no es de este encargo).
- Lo que queda:
  1. **Tres tramos de 170 a 216 ms** en calculadoras compartidas que la foto de los widgets no puede partir sin tocarlas: saldo vivo (`LiveBalanceCalculator.liveBalanceBreakdown`, `Yala/App/Logic/Calculators/LiveBalanceCalculator.swift`), valoración de la curva (`BalanceValuation`, `Yala/App/Logic/Calculators/BalanceValuation.swift`) y saldos por cuenta (`AccountBalanceCalculator.batchCalculateBalances`, `Yala/Utils/AccountBalanceCalculator.swift`).
  2. **Bloque de ~0,55 s al cargar el Panel en el arranque**: `PanelViewModel.loadData` más los saldos de cuentas (`calculateAccountBalances`), en `Yala/App/ViewModels/PanelViewModel.swift`.

## Qué se pide
1. Que ninguno de esos tres tramos pase de ~50 ms sin ceder el hilo en la foto de los widgets y en el Panel: hazlos reanudables o por trozos con el molde de Eficiencia 7 (`RecorridoConReloj`, cortes de ~20 ms, `CesionDelHilo`), o quita trabajo repetido si la traza lo muestra. Las versiones de una vez que usan otros llamadores (Tendencias, saldo a fin de mes, alertas, notificaciones, borrado de cuenta, flujo de caja) tienen que seguir dando lo mismo y con la misma firma: un solo cuerpo de reglas, como en Eficiencia 7.
2. Que la carga del Panel al abrir la app no deje un bloque de más de ~100 ms en el hilo principal (hoy ~0,55 s).
3. **Paridad**: pruebas contra copias congeladas del código previo de las tres calculadoras y de la carga del Panel (moneda distinta, cuenta excluida, cuenta archivada, fechas futuras, ajustes de saldo y transferencias), por trozos = de una vez, con mutantes que pongan las pruebas en rojo. Todo en `YalaTests/Eficiencia8CalculadorasYCargaPanel/`; lógica nueva en `Yala/App/Logic/Eficiencia8CalculadorasYCargaPanel/`.
4. **Medición antes/después en el iPhone 14** (mismo método y almacén que Eficiencia 7: foto al abrir, cuelgues de más de 250 ms en el primer minuto, Panel listo tras abrir, 3 arranques), con los datos en `docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-8-calculadoras-y-carga-panel/`.
5. Ticket `tickets/backlog/2026-11-27-eficiencia-8-calculadoras-y-carga-panel.md` con lo hecho, movido a `tickets/done/` al cerrar; `docs/TICKETS.md` al final, después de rebasear.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Dependencias: la sesión arranca ya sobre la rama base, sin esperar CI ni merge del PR anterior (salvo el requisito de #1208 de arriba); justo antes de abrir el PR, `git fetch` y un solo rebase sobre `origin/2.3`, y build y simulador una vez después. Solo si dos sesiones tocan el mismo archivo o una necesita el código de la otra, la segunda espera el merge.
- Pipeline serial: limpiar (simuladores muertos, DerivedData y cachés de worktrees cerrados), build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo y limpiarlo.
- Presupuesto de pruebas de interfaz:
  - Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final.
  - Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue.
  - Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo.
  - Ninguna espera de más de 3 min sin escribir avance (qué corre, cuánto lleva).
  - Antes de compilar en iOS mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso, no en paralelo.
- **Dispositivos:** en la Mini, un solo simulador. Tienes permiso explícito para usar un segundo simulador en la Max (además del de otra sesión; tope 2 allí) o el **iPhone 14** («iPhone de JURGEN», UDID `00008110-001A35A6267A401E`) por DeviceMCP, que es donde se mide. Tiene candado de flota (ADR-132, hook `candado_dispositivo.py`; ver quién lo tiene con `python3 ~/.claude/hooks/candado_dispositivo.py estado`). Si te dice que está ocupado por otra sesión, **no reintentes en bucle**: sigue con el simulador u otra parte y vuelve a probar una sola vez más tarde; si sigue ocupado, anótalo en «Saltado o asumido sin preguntar». Antes comprueba con `xcrun devicectl device info lockState --device 00008110-001A35A6267A401E` que no esté bloqueado. No borres datos del iPhone. Apaga y limpia los simuladores que enciendas; no apagues el de otra sesión viva.
- Sin cambios de esquema de SwiftData, CloudKit ni Supabase; si crees que hace falta uno, es pregunta vital para Jürgen.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Modelo: Opus. Fable está prohibido en este encargo.

## Qué NO hay que tocar
- Nada fuera de `toca:`. En paralelo corren «Pulido: botones de registro arriba en Grupos y Personas sin gastos, y «Esto leí» en grande» y «Arreglos pre-build 12» (que toca `FlujoMotorMes.swift`, Tendencias y la torta de Distribución): no toques `FlujoMotorMes*`, `CashFlowProjectionCalculator.swift`, `ProjectedFlowViews.swift`, `TrendsTabView.swift`, `CategoriesTabView.swift`, `CategoriesPieWidget.swift`, `StatisticsViewModel` ni vistas. Si necesitas otro archivo, no lo toques: anótalo en «Saltado o asumido sin preguntar» con el motivo.
- No cambies ninguna cifra que ve la persona: solo cuándo y cómo se calcula.

## Cómo se sabe que está bien
- Paridad verde con mutantes en rojo; suite unitaria completa verde una vez al final.
- En el iPhone 14: ningún tramo de las tres calculadoras por encima de ~50 ms sin ceder, el bloque de la carga del Panel por debajo de ~100 ms y cifras antes/después en la carpeta de QA y en el cierre.

## Cierre
- Tabla antes/después en un **artifact visual de Claude** enlazado en el cierre. Entrega final: artifact visual de Claude que facilite decidir; no Markdown, PDF ni documento de puro texto.
- Base 2.3, un solo PR, **sin firma de IA en commits ni PR** (el hook la rechaza), con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Lo vital, según el modo fijado al arrancar: en semiautónomo preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin mergear ni subir lo incompleto. Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre autónomo con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada», y el link del artifact. `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones

> Resueltas por la sesión (modo semi; son técnicas, ninguna es de producto ni de acceso). Se discuten en el PR.

**D1 · ¿Cómo se parten las tres calculadoras sin duplicar reglas?** → Cada calculadora gana un acumulador fila a fila
(`LiveBalanceCalculator.SumaSaldoVivo`, `AccountBalanceCalculator.SumaSaldosPorCuenta`) con una entrada sobre el
`TransactionItem` y otra sobre valores ya leídos; la versión de una vez (misma firma) recorre con ese mismo acumulador.
Por qué: un solo cuerpo de reglas, como en Eficiencia 7. Alternativa descartada: copiar el bucle en un helper por
trozos (dos copias que divergen).

**D2 · ¿La foto de los widgets suma sobre `FilaFotoWidget` o vuelve a leer SwiftData?** → Sobre las filas (ya traen
cuenta, fecha, divisa e importe nativo), por tramos con `RecorridoConReloj`. Por qué: quita la segunda lectura de los
16 k movimientos además de partirla. Alternativa descartada: partir la lectura de `TransactionItem` (sigue pagando las
lecturas).

**D3 · `BalanceValuation`: qué se parte.** → Se decide con la traza del «antes»: si el tramo es la lectura de tasas en
bloque (`rateFactors`), se pide por tandas de fechas con el mismo resultado por fecha; si es otra cosa, lo que la traza
diga. `TrendDataProcessor` no está en `toca:` y no se toca: lo que requiera tocarlo se anota.

**D4 · Carga del Panel (~0,55 s).** → La recarga (`scheduleRecalculation(reload:)`) pasa a una carga que cede el hilo
con `CesionDelHilo` entre pasos y por tramos dentro de los largos (saldos por cuenta, líneas de Grupos, y el ajuste de
grupos y el recuento de huérfanos sobre las filas que les importan). `loadData()` público sigue de una vez y con el
mismo resultado. Alternativa descartada: mover la carga a otro hilo (los `@Model` no son `Sendable`).

**D5 · ¿Se pueden pasar a `GroupBridgeStatsAdjustment.build` y `orphanCount` solo las filas con puntero de grupo o sin
cuenta?** → Sí, si la prueba de paridad lo confirma: las dos funciones ignoran (y solo leen para descartar) las filas con
cuenta y sin puntero. Sus ficheros no están en `toca:` y no se tocan; el prefiltro va por tramos en el Panel.

**D6 · Medición.** → Mismo método y almacén que Eficiencia 7 (copia `Release-Dev` con `DEBUG`, `YalaModel-UITest` de
16.004, `-uitest -uitest-skip-onboarding`), en el iPhone 14 por cable a la Mini. Traza de arranque de 60 s (Time
Profiler + os_signpost) y 3 arranques con consola, antes y después. Guiones nuevos: `tramos_calculadoras.py`,
`bloques_panel.py`.

**D7 · Sin cambios de esquema ni de cifras.** → Ninguno: solo cuándo y cómo se calcula. Paridad contra copias
congeladas del código previo con mutantes.
