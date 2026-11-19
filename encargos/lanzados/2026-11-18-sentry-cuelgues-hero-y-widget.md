Yala
# Quitar del hilo principal el cálculo del hero del Panel y la foto del widget (dos cuelgues de Sentry)
---
toca: Yala/App/ViewModels/PanelViewModel.swift,Yala/App/Logic/Calculators/HeroBucketsCalculator.swift,Yala/Services/WidgetDataCache.swift,YalaTests/CuelguesHeroWidget/,tickets/done/2026-11-18-sentry-cuelgues-hero-y-widget.md
esfuerzo: medium
cierre: cierra-sola
---

Dos cards del tablero en «lista para lanzar», con OK de Jürgen del 18-nov para ir juntas en una sesión: «El Panel se cuelga unos segundos al recalcular el hero» (Sentry YALA-IOS-N) y «La app se cuelga unos segundos al actualizar los datos del widget» (Sentry YALA-IOS-M). Ambas en TestFlight 2.3 (3), iPhone con iOS 27.3 beta, un evento cada una.

## Pilas
- YALA-IOS-N: `PanelViewModel.scheduleRecalculation → performCalculation → calculateHeroWidget → HeroBucketsCalculator.calculate (l.114) → CashFlowCalculator.resolvedAmount → TransactionItem.amountInPreferredCurrency` en el hilo principal.
- YALA-IOS-M: `WidgetDataCache.updateCache → flushPendingUpdate → updateCacheNow → buildSnapshot (l.806) → buildProjectedFlow (l.909) → ProjectedFlowBuilder → TransactionItem.date` en el hilo principal.

## Qué hacer
- Encuentra la causa y saca el cálculo pesado del hilo principal sin cambiar resultados (foto de valores, trabajo en segundo plano, coalescer recálculos, o lo que mida mejor). Mide antes y después con `sample` o Instruments.
- No toques `CashFlowCalculator.swift` ni `ProjectedFlowBuilder.swift`: hay una serie de sesiones del flujo de caja que los rehace. Arregla desde los llamadores declarados.
- Tests en `YalaTests/CuelguesHeroWidget/` que fijen que el cálculo no bloquea el hilo principal. Mueve las dos cards a done y marca los dos issues como resueltos en Sentry (`scripts` y token según `reference_sentry_tokens_y_api`).

## Cómo entregar
- Base 2.3, un PR. Toca solo lo declarado; si algo imprescindible queda fuera, ponlo en una carpeta nueva dentro de lo declarado y anótalo.
- Tests de lo nuevo. Capturas antes y después (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad) cuando haya UI.
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después y lo decidido.
- Commits y PR sin firma de IA. Textos nuevos solo en la tabla de strings declarada de cada `.lproj`, nunca en `Localizable.strings`. Nunca un botón debajo del otro.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto). Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas por la sesión (modo semi, recomendación propia): se dan por buenas y se discuten en el PR.

Hechos medidos antes de decidir: las dos pilas de Sentry (iPhone 18 Pro, iOS 27.3 beta, «Non Fully Blocked») acaban en
el getter de una propiedad `@Model` (`amountInPreferredCurrency`, `date`) instanciando su keypath; el coste es leer el
historial entero en el hilo principal. El target compila con aislamiento por defecto `MainActor`, los `@Model` viven en
el contexto principal y `ProjectedFlowBuilder` es `@MainActor` y no se toca.

**D1 · ¿Hilo de fondo o ceder el hilo principal?** → Ceder el hilo principal por tramos, como YALA-IOS-K.
Por qué: llevar el cálculo a otro hilo exige otro `ModelContext` y quitar el `MainActor` de calculadores que no se
pueden tocar (`CashFlowCalculator`, `ProjectedFlowBuilder`). Alternativa descartada: `@ModelActor` con foto de valores,
por alcance y por riesgo de cambiar cifras.

**D2 · Hero del Panel** → `HeroBucketsCalculator` acumula por tramos (un acumulador que usa también `calculate`, así
la cifra es la misma por construcción) y el Panel lo recorre en tramos con una cesión de 1 ms entre uno y otro cuando
el historial pasa de un tramo; con uno solo, síncrono como hoy. Un cálculo nuevo cancela el tramado en curso.
Por qué: el coste está en el bucle sobre todos los movimientos. Alternativa descartada: cachear filas del hero por
recarga, porque el cuelgue llegó justo tras una recarga (pull de la nube).

**D3 · Foto del widget** → La reconstrucción diferida (la del segundo de espera) se hace por etapas con cesión entre
ellas; el paso a segundo plano y las tareas de fondo siguen con la versión de una vez. La foto es la misma: mismas
piezas, mismo «ahora».
Por qué: la foto la pide cada alta y cada página de la nube con la app delante; en segundo plano no hay toques que
atender. Alternativa descartada: rehacerla solo al salir de la app (cambia cuándo Siri y los widgets ven los datos).

**D4 · Medición** → Prueba de medida con 20.000 movimientos (bloque más largo del hilo principal) antes y después, más
`sample` del simulador. El simulador es iOS 27.2: el coste del getter de 27.3 beta no se reproduce y queda en el cierre.

**D5 · Sentry** → Los dos issues se marcan resueltos «en la próxima versión» (aún no existe build con el arreglo).
