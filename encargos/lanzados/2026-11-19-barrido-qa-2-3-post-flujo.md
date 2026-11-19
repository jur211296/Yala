Yala
# Barrido de QA de la 2.3 sobre la build de TestFlight con Flujo de caja nuevo
---
toca: docs/qa/barrido-2-3-post-flujo/,YalaTests/BarridoQA23PostFlujo/,tickets/backlog/2026-11-19-barrido-qa-2-3-post-flujo.md,tickets/done/2026-11-19-barrido-qa-2-3-post-flujo.md
esfuerzo: high
cierre: cierra-sola
depende: Yala/subir-testflight-2-3
---

Pedido de Jürgen (18-nov, 19:42 Lima): después de las sesiones de Flujo de caja, revisar CI, subir a TestFlight y luego un barrido de QA. Esta es la tercera.

## Contexto
- Ya hubo un barrido de la 2.3 (`docs/qa/barrido-2-3-final/`) y uno en iPhone (`docs/qa/barrido-iphone-2026-11-14/`); úsalos como lista base. Desde entonces entraron, entre otros, el replanteo de Flujo de caja (seis sesiones), Perfil como tarjeta y la hoja de cuenta del Panel.

## Qué se pide
1. Recorre todas las pantallas de la 2.3 en iPhone (17 y SE), iPad y Duo, claro y oscuro y con el texto al máximo, con foco en lo nuevo desde el barrido anterior (Flujo de caja, Panel, widget, Tendencias, Perfil, hojas de cuenta). Cifras de Flujo de caja, Panel y widget deben coincidir.
2. Lo grave: primero lo mides contra la versión publicada y después decides si entra.
3. Lo chico se arregla en este PR solo si el archivo no está en el `toca` de otra sesión viva o pendiente; cada arreglo fuera de lo declarado se anota en «Saltado o asumido sin preguntar». Lo grande: card de bug 2.3 prioridad alta con cierre autónomo.
4. Termina con una lista corta de lo que Jürgen tiene que probar en su iPhone con la build de TestFlight.
- Presupuesto de pruebas de interfaz: corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. Si una prueba falla 2 veces por timeout, anótala como inestable y sigue. Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo. Ninguna espera de más de 3 min sin escribir avance. No compiles iOS en paralelo con otra sesión en la misma máquina si la carga pasa los núcleos.
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.

## Cómo entregar
- Base 2.3, un PR, sin firma de IA. Textos nuevos solo en una tabla de strings propia de cada `.lproj`, nunca en `Localizable.strings`. Nunca un botón debajo del otro.
- Entregable visual: artifact de Claude con lo recorrido, hallazgos con capturas y la lista de prueba para Jürgen.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto). Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (resueltas en semi, sin consultar: ninguna es vital)

1. **Qué build se barre.** TestFlight 2.3 (4) se archivó desde `origin/2.3` en 96d404d7f + el número de build (PR de subida abierto). El worktree nace en ese mismo commit ⇒ Yala Dev compilado aquí = el código de la build 4. La «proyección inteligente» (PR abierto) NO está en la build 4 y queda fuera.
2. **Cómo se recorre.** Un conductor XCUITest temporal (`YalaUITests/ZZBarrido23PostFlujo/`, se retira antes del commit) con semilla `realista`, «Este mes» y variantes por argumento (oscuro, claro, texto al máximo). Dispositivos: iPhone 17 Pro, iPhone SE (o el más pequeño con iOS 27), iPad Pro 11 y Duo si el runtime arranca. Capturas a `~/Claude/entregas/2026-11-19-barrido-qa-2-3-post-flujo/` (sobreviven al worktree).
3. **Cifras.** Panel («Ver proyectado»), Tendencias y Flujo de caja se leen en el mismo arranque, sin plan y con plan. El widget de Saldo se mide leyendo la foto que la app deja en el App Group (saldo + proyección acumulada hasta fin de mes), y se fija con una prueba unitaria propia sobre la semilla `realista` en `YalaTests/BarridoQA23PostFlujo/` si la paridad no está cubierta con datos reales.
4. **Lo grave** se mide contra la 2.2 publicada (rama `1.0`) antes de decidir: regresión ⇒ card alta con cierre autónomo; ya estaba ⇒ card normal.
5. **Lo chico** se arregla aquí solo si su fichero no está en el `toca` de un encargo pendiente o un PR abierto (Flujo de caja tiene PR abierto: sus vistas no se tocan aquí).
6. **Tope de 30 min** de pruebas de interfaz: el conductor cuenta. Si se llega, se pregunta al bot y se sigue con lo que no pide simulador.
7. **Entregable:** `docs/qa/barrido-2-3-post-flujo/` (lista + tanda corta para el iPhone) y un artifact con capturas y hallazgos.
