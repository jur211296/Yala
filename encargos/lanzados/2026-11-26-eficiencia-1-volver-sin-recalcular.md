Yala
# Eficiencia 1: volver a Yala no recalcula lo que no cambió (Panel, Estadísticas, Registros, Grupos, Informes y Spotlight)
---
toca: Yala/App/Views/Panel/PanelView.swift,Yala/App/Views/Statistics/DetailContainerView.swift,Yala/App/Views/Records/RecordsStandaloneView.swift,Yala/App/Views/Groups/GroupsContainerView.swift,Yala/App/Views/Groups/GroupDetailView.swift,Yala/App/Views/Reports/FinancialReportView.swift,Yala/App/AppBootstrapper.swift,Yala/App/Logic/PanelReloadFreshness.swift,Yala/App/Logic/StatisticsEntryFreshness.swift,Yala/App/Services/StoreSaveCounter.swift,Yala/App/Logic/FrescuraAlVolver,YalaTests/EficienciaVolverSinRecalcular,docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-1-volver-sin-recalcular/,tickets/backlog/2026-11-26-eficiencia-1-volver-sin-recalcular.md,tickets/done/2026-11-26-eficiencia-1-volver-sin-recalcular.md
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: no
depende: Yala/analisis-rendimiento-calentamiento-scroll-iphone14, Yala/dividir-boleta-sin-grupo-1a
---

Lote del plan de eficiencia que salió del análisis de calentamiento, batería y scroll en el iPhone 14. Va primero porque es el de mayor impacto. Espera a que cierre el análisis (para tener su informe en 2.3) y a «Implementar dividir boleta sin grupo», que también toca `GroupsContainerView.swift`.

## Qué se pide
1. Panel: en `.active`, usar la firma de frescura (`reloadOnAppearIfStale()` de `PanelReloadFreshness`) en vez de `reloadAndRecalculate()` (`PanelView.swift`, `onChange(of: scenePhase)`).
2. Estadísticas, Registros, Grupos, detalle de grupo e Informes: el mismo cambio, con su propia firma (`DetailContainerView.swift`, `RecordsStandaloneView.swift`, `GroupsContainerView.swift`, `GroupDetailView.swift`, `FinancialReportView.swift`). Si hace falta una pieza compartida, va en `Yala/App/Logic/FrescuraAlVolver/`.
3. Una pantalla oculta no recalcula al volver: lo marca como pendiente y calcula al aparecer.
4. Spotlight: reindexar solo si cambió algo desde la última vez (contador de guardados, `StoreSaveCounter`), no en cada vuelta (`AppBootstrapper.swift`).
5. Pin: un test de cableado que prohíba `reloadAndRecalculate()` a pelo dentro de un `onChange(of: scenePhase)`.
- Cuidado: lo que sí cambió (un guardado, una sincronización que trajo datos, un cambio de día) tiene que seguir recalculando; pruébalo.
- Pruebas nuevas en `YalaTests/EficienciaVolverSinRecalcular/`.

## Mejora esperada y cómo se mide
De ~33 s de CPU en los 36 s siguientes a volver a ~1,5 s en 20 s (−95 %); el scroll tras volver deja de congelarse. Medir con `scripts/pasada.sh`, 10 ciclos sobre Yala Dev 16 k (Time Profiler + Hitches): bloque ≥ 90 % tras volver = 0 s y ningún tirón > 250 ms.

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

> Resueltas en semiautónomo, sin Jürgen delante: son decisiones técnicas y reversibles, y las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué hace una pantalla a la vista al volver?** → Suelta el freno como hoy (`ForegroundResume`) y, una vuelta del main actor después, comprueba su firma; solo recarga si algo cambió.
Por qué: `handleBecameActive` aplica en esa misma pasada los cambios remotos pendientes y materializa borradores; esperando una vuelta, la firma los ve. Alternativa descartada: comprobar en el acto (podía adelantarse a esos guardados y no verlos).

**D2 · ¿Qué hace una pantalla oculta al volver?** → Nada: suelta el freno y deja la firma sin tocar. Calcula al aparecer: Panel, Estadísticas e Informes ya comprueban su firma en el `onAppear`/al mostrarse; Registros y Grupos marcan pendiente.
Por qué: es el punto 3 del encargo y reutiliza la comprobación que ya existe. Alternativa descartada: un `onChange(of: isRootPageShown)` además del `onAppear` (en el Panel pediría dos recargas seguidas).

**D3 · ¿Qué firma usa cada pantalla?** → Panel: `PanelReloadFreshness` (la de la card zpgm). Estadísticas: `StatisticsEntryFreshness` (`requestCalculationOnEntry`). Informes: la de la Comparativa (`comparativaDebeCalcular`). Registros, Grupos y detalle de grupo: una firma nueva compartida, `FirmaAlVolver` (dataVersion + guardados de SwiftData + día), tomada al irse, más «trabajo sin terminar» y cambios sin guardar.
Por qué: cada pantalla ya tiene su forma de saber si cambió algo; donde no la hay, la pregunta exacta es «¿cambió algo mientras no estaba delante?». Alternativa descartada: guardar la firma en cada carga de esos ViewModels (Grupos tiene ~19 llamadores de `loadData`).

**D4 · ¿Qué pasa con el trabajo que el freno descartó o cortó en segundo plano?** → Cuenta como cambio: el Panel lo apunta en `hasInterruptedWork`, el debouncer de Grupos en un testigo nuevo, Registros en su propio estado.
Por qué: antes lo cubría la recarga incondicional; sin ella, un recálculo de filtros o de tasas pedido con la app fuera se perdía. Requiere tocar `PanelViewModel.swift`, `RecalculationDebouncer.swift`, `GroupsViewModel.swift` y `GroupDetailViewModel.swift` (fuera de `toca:`; se anota en el cierre).

**D5 · Spotlight: ¿cuándo se reindexa al volver?** → Solo si cambió `dataVersion`, el contador de guardados o el contexto del índice (vista solo-grupos, «Solo gastos», gastos de grupo en Registros) desde la última reconciliación. La firma se apunta en la propia reconciliación (`SpotlightIndexService.reconcile`) y se borra si falla.
Por qué: los cambios de la nube suben `dataVersion` al volver (antes de esta comprobación) y los de la app ya reconcilian por `WidgetDataCache.updateCache`. Requiere tocar `SpotlightIndexService.swift` (fuera de `toca:`, anotado). Alternativa descartada: apuntar la firma solo en la vuelta (la primera vuelta tras el arranque reindexaría siempre).

**D6 · Medición** → «Antes» y «después» en el iPhone 14 hoy, con la misma copia de perfilado (Release-Dev + DEBUG temporal) y el mismo almacén de 16 k, el «antes» sobre `origin/2.3` actual (no el `b5c6e98c5` del informe), para que la comparación sea del mismo día y la misma base.
Por qué: el informe midió sobre otra base; comparar contra él mezclaría otros cambios.
