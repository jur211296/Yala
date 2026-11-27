Yala
# Arreglos pre-build 12: motor del mes en Flujo de caja, enlace en Tendencias y ayuda en Distribución
---
toca: Yala/App/Logic/FlujoMotorMes/FlujoMotorMes.swift,Yala/App/Views/Shared/ProjectedFlowViews.swift,Yala/App/Views/Statistics/TrendsTabView.swift,Yala/App/Views/Statistics/CategoriesTabView.swift,Yala/App/Views/Panel/CategoriesPieWidget.swift,YalaUITests/Flows/ProjectedFlowUITests.swift,YalaTests/ArreglosPreBuild12/,YalaUITests/ArreglosPreBuild12/,tickets/backlog/2026-11-27-arreglos-flujo-tendencias-y-ayuda-distribucion.md,tickets/done/2026-11-27-arreglos-flujo-tendencias-y-ayuda-distribucion.md,tickets/backlog/2026-11-27-tendencias-enlace-al-plan-queda-bajo-la-barra.md,tickets/done/2026-11-27-tendencias-enlace-al-plan-queda-bajo-la-barra.md,docs/TICKETS.md
modelo: opus
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: si
---

Decisión de Jürgen (27-nov-2026, ~10:05 Lima; t2013u): aprobó encolar este lote de tres arreglos **antes** del barrido QA de la build 12 de 2.3, para que el barrido ya los incluya.

## Contexto
- Los tres salieron de cierres de esta mañana y ninguno está hecho en `origin/2.3` (verificado a las 10:15 Lima):
  1. **Flujo de caja, motor del mes** (seguimiento del PR #1207, «Flujo de caja sin trabas en la proyección inteligente»; ver «Sigue» en `tickets/done/2026-11-27-trabas-flujo-proyeccion-y-convertir-a-compartido.md`). En `Yala/App/Logic/FlujoMotorMes/FlujoMotorMes.swift` (~línea 489) el orden de las partidas de «otros» compara `($0.total, orden($0.base)) > ($1.total, orden($1.base))`, y `orden` (~línea 498) hace `String(describing:)` del `PersistentIdentifier` en cada comparación. Con la detección ya arreglada, es el **34 %** del motor del mes en la traza de 13 meses y 16 mil movimientos (~230 ms por cálculo en el simulador). El PR #1208 (Eficiencia 7) no tocó `FlujoMotorMes*`.
  2. **Tendencias: «Afinar con un plan de flujo de caja» queda bajo la barra de pestañas.** Ticket `tickets/backlog/2026-11-27-tendencias-enlace-al-plan-queda-bajo-la-barra.md`, que viene en el PR #1208 (abierto con auto-merge a las 10:15). Si al arrancar todavía no está en `origin/2.3`, léelo de la rama `encargo/2026-11-27-eficiencia-7-foto-widgets-y-arranque` y, antes del PR, rebasea: lo normal es que #1208 ya haya entrado. La prueba que cae es `YalaUITests/Flows/ProjectedFlowUITests.swift:142` (`test_trends_projectionWithoutAPlan_linksToSettingUpTheCashFlowPlan`); el enlace es `trend_projected_link_setup` en `Yala/App/Views/Shared/ProjectedFlowViews.swift:99`.
  3. **Estadísticas › Distribución › Gráficas: el «?» de la torta de categorías no responde al toque y VoiceOver no lo encuentra** (hallazgo del PR #1209, «Textos del reparto»): queda dentro del botón o gesto de la tarjeta. Se inyecta como `headerInfoButton: AnyView(WidgetInfoButton(kind: .categoriesPie))` en `Yala/App/Views/Statistics/CategoriesTabView.swift` (~línea 584) y lo pinta `Yala/App/Views/Panel/CategoriesPieWidget.swift` (hay `.accessibilityElement(children: .ignore)` ~línea 592 y gestos de toque en la tarjeta). Revisa también las de subcategorías y etiquetas, que usan el mismo camino.
- Card del tablero de Yala 2.3 del punto 1: búscala con `tablero listar --proyecto Yala` (la del orden de «otros» en el motor del mes). Al terminar, muévela a «in qa» con nota del PR.

## Qué se pide
1. **Motor del mes:** calcula la clave de orden una sola vez por partida (no en cada comparación), con el mismo resultado exacto, desempates incluidos. Prueba de paridad contra una copia congelada del orden anterior (molde de `YalaTests/TrabasFlujoYConvertir/ProyeccionInteligenteAntes.swift`), con varias semillas y casos de borde (totales iguales, categoría y subcategoría), y un testigo de que la clave se calcula una vez por partida. Mide antes y después en el simulador con el almacén grande y deja las cifras en el cierre.
2. **Tendencias:** sigue el plan del ticket. Abre Tendencias con «Ver proyectado» y sin plan, y comprueba a mano si el enlace se alcanza desplazando. Si se alcanza, arregla el desplazamiento de la prueba (arrastres cortos hasta la franja central, molde `openObservations`; regla de `isHittable` en `.claude/rules/testing.md`). Si no se alcanza, da al contenido de Tendencias el margen inferior de la barra de pestañas. La prueba tiene que quedar verde. Mueve ese ticket a `tickets/done/`.
3. **Ayuda «?» de Distribución:** que se pueda tocar (abre su hoja de ayuda) sin disparar el toque de la tarjeta ni el de la torta, y que VoiceOver lo encuentre como botón con su etiqueta, en las tortas de categorías, subcategorías y etiquetas de Distribución › Gráficas. Comprueba que en el Panel (`CategoriesPieWidget` también se usa allí) el «?» y el toque de la torta siguen igual. Sin textos nuevos: usa la etiqueta que ya tiene `WidgetInfoButton`; si hiciera falta un texto nuevo, no toques `Localizable.strings`: anótalo.
4. Crea el ticket del lote `tickets/backlog/2026-11-27-arreglos-flujo-tendencias-y-ayuda-distribucion.md` con lo hecho y muévelo a `tickets/done/` al cerrar; actualiza `docs/TICKETS.md` al final, después de rebasear.
5. Pruebas: unitarias en `YalaTests/ArreglosPreBuild12/` y de interfaz del «?» (toque y VoiceOver) en `YalaUITests/ArreglosPreBuild12/`.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Dependencias: la sesión arranca ya sobre la rama base, sin esperar CI ni merge del PR anterior; justo antes de abrir el PR, `git fetch` y un solo rebase sobre `origin/2.3`, y build y simulador una vez después. Solo si dos sesiones tocan el mismo archivo o una necesita el código de la otra, la segunda espera el merge.
- Pipeline serial: limpiar (simuladores muertos, DerivedData y cachés de worktrees cerrados), build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo y limpiarlo.
- Presupuesto de pruebas de interfaz:
  - Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final.
  - Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue.
  - Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo.
  - Ninguna espera de más de 3 min sin escribir avance (qué corre, cuánto lleva).
  - Antes de compilar en iOS mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso, no en paralelo.
- **Dispositivos:** en la Mini, un solo simulador. Tienes permiso explícito para usar un segundo simulador en la Max (además del de otra sesión; tope 2 allí) si lo necesitas, o el **iPhone 14** («iPhone de JURGEN», UDID `00008110-001A35A6267A401E`) por DeviceMCP. El iPhone tiene candado de flota (ADR-132, hook `candado_dispositivo.py`; ver quién lo tiene con `python3 ~/.claude/hooks/candado_dispositivo.py estado`). Si te dice que está ocupado por otra sesión, **no reintentes en bucle**: sigue con el simulador u otra parte y vuelve a probar una sola vez más tarde; si sigue ocupado, anótalo en «Saltado o asumido sin preguntar». Antes comprueba con `xcrun devicectl device info lockState --device 00008110-001A35A6267A401E` que no esté bloqueado. No borres datos del iPhone. Apaga y limpia los simuladores que enciendas; no apagues el de otra sesión viva.
- Sin cambios de esquema de SwiftData, CloudKit ni Supabase; si crees que hace falta uno, es pregunta vital para Jürgen.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Modelo: Opus. Fable está prohibido en este encargo.

## Qué NO hay que tocar
- Nada fuera de `toca:`. En la Max corre en paralelo «Pulido: botones de registro arriba en Grupos y Personas sin gastos, y «Esto leí» en grande»: no toques `GroupRecordsView.swift`, las vistas de Voz ni de Foto, ni `Localizable.strings`, `CashFlowProjectionCalculator.swift`, `WidgetInfoButton.swift` ni `PanelWidgetSection.swift`. Si necesitas otro archivo, no lo toques: anótalo en «Saltado o asumido sin preguntar» con el motivo.
- No cambies los resultados del motor del mes: solo el costo del orden.

## Cómo se sabe que está bien
- Paridad del orden verde y cifras antes/después del motor del mes en el cierre.
- `test_trends_projectionWithoutAPlan_linksToSettingUpTheCashFlowPlan` verde y el enlace alcanzable a mano en Tendencias.
- El «?» de las tres tortas de Distribución abre su ayuda al tocarlo y VoiceOver lo anuncia como botón; el Panel sigue igual.

## Cierre
- Capturas antes/después de Tendencias y del «?» de Distribución en un **artifact visual de Claude** enlazado en el cierre. Entrega final: artifact visual de Claude que facilite decidir; no Markdown, PDF ni documento de puro texto.
- Base 2.3, un solo PR, **sin firma de IA en commits ni PR** (el hook la rechaza), con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Lo vital, según el modo fijado al arrancar: en semiautónomo preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin mergear ni subir lo incompleto. Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre autónomo con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada», y el link del artifact. `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0

Decidido al arrancar (10:20 Lima, Mini, semi). Ficheros: `FlujoMotorMes.swift` (orden de partidas), `ProjectedFlowViews.swift` / `TrendsTabView.swift` / `ProjectedFlowUITests.swift` (según lo que mida el punto 2), `CategoriesPieWidget.swift` / `CategoriesTabView.swift` (según lo que mida el punto 3), pruebas nuevas en `YalaTests/ArreglosPreBuild12/` y `YalaUITests/ArreglosPreBuild12/`, tickets y `docs/TICKETS.md`.

1. **Motor del mes:** decorar-ordenar-desdecorar. La clave (`orden(base)`) se calcula una vez por partida en una función `ordenarPartidas` interna; mismo comparador `(total, clave) >` sobre la clave ya calculada ⇒ mismo resultado, desempates incluidos. Testigo `_testClavesDeOrden` (molde de `_testOrdenes`). Paridad: copia congelada del orden de antes en el test, con semillas, totales iguales, categoría/subcategoría/sin categoría y el motor entero de 13 meses con 16 k movimientos.
2. **Tendencias:** primero se mide en el simulador si el enlace se alcanza desplazando. Si se alcanza, se arregla la prueba (arrastres cortos, molde `openObservations`); si no, margen inferior en Tendencias.
3. **«?» de Distribución:** primero se mide en el simulador (árbol de accesibilidad y toque). La causa del hallazgo del PR anterior («queda dentro del botón de la tarjeta») es inferida; no hay botón envolviendo la tarjeta en el código. Sospecha a medir: el `accessibilityIdentifier` de la página del carrusel (`distribution_page_*`) pisa los de dentro.
4. **Ticket de Tendencias:** viene en el PR de eficiencia 7 (abierto, sin mergear a las 10:20). Si al rebasear ya está en `2.3`, `git mv` a `done/`; si no, se crea directamente en `done/` con la misma id.
5. **`qa/coverage-index.json`:** no está en `toca:`, pero el contrato anti-drift lo pide al tocar `Yala/`; se actualiza solo si el gate lo exige, al final y tras rebasear (es índice compartido).
