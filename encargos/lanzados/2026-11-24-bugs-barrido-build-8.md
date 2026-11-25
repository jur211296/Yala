Yala
# Arreglar los bugs del barrido de la build 8: guía de Atajos en iOS 27, «Ver detalle» del Panel, cifra grande con texto grande, saldo del Panel y período viejo en Estadísticas
---
toca: Yala/App/Views/Settings/AtajoBanco/,Yala/Utils/L10n+CapturaAtajoParte2.swift,Yala/App/Views/Panel/HeroMonthView.swift,Yala/App/Views/Panel/Sections/PanelHeroSection.swift,Yala/App/Logic/PanelHeroFigureLogic.swift,Yala/App/Views/Statistics/StatsHeroView.swift,YalaTests/BugsBarridoBuild8/,tickets/backlog/2026-11-24-cifra-del-hero-pequena-con-texto-de-accesibilidad.md,tickets/done/2026-11-24-cifra-del-hero-pequena-con-texto-de-accesibilidad.md,tickets/backlog/2026-11-24-bugs-barrido-build-8.md,tickets/done/2026-11-24-bugs-barrido-build-8.md
esfuerzo: high
cierre: cierra-sola
depende: Yala/subir-testflight-2-3-build-8
---

Pedido de Jürgen (24-nov, 15:25 Lima): «los bugs del barrido también encólalos». Es un lote: los cinco van en una sola sesión, con un solo PR contra 2.3. El detalle y la evidencia están en `docs/qa/barrido-2-3-antes-build-8/lista.md` («Hallazgos») y en `~/Claude/entregas/2026-11-24-barrido-qa-2-3-antes-build-8/evidencia/`.

## Qué se pide
1. **Guía de Atajos de los avisos del banco** (card «Avisos del banco: la guía de Atajos describe iOS 26», prioridad alta). Reescribe los pasos para iOS 27.2: «Automatización» es una fila de Biblioteca, el «+» está abajo al centro y abre «Nuevo atajo», y el disparador se elige en la pestaña «Automatización» de la hoja de acciones. Quita «Ejecutar inmediatamente», «Siguiente», «Nueva automatización en blanco» y «Agregar acción». Para borrar se usa la pulsación larga. Si iOS 26 sigue soportado, muestra la guía según la versión. Verifícalo paso a paso en el iPhone 14 (iOS 27.2) y, si puedes, termina el paso 5 con una compra real simulada para liberar la card «Avisos del banco: guía, región, activo al confirmar», que sigue en QA.
2. **Panel: «Ver detalle ›» oculta los montos en vez de abrir Estadísticas** (card de prioridad alta, viene desde 2.2). El toque en «Ver detalle» abre Estadísticas, y el ojo sigue ocultando montos solo con su propio toque.
3. **Con texto de accesibilidad, la cifra grande del hero sale más pequeña que sus líneas** en Estadísticas, Registros y «Te falta pagar». Sigue el ticket `2026-11-24-cifra-del-hero-pequena-con-texto-de-accesibilidad.md` y su criterio de «Hecho cuando».
4. **Con escrituras seguidas, el saldo grande del Panel no sale** hasta 46 s después. Que el cálculo no se reinicie con cada guardado (por ejemplo, con un rebote corto o mostrando el último valor mientras recalcula). Mídelo con la semilla `pesado`.
5. **Al cambiar de período en Estadísticas con datos pesados, quedan unos segundos los montos del período anterior bajo el rótulo nuevo.** Muestra un esqueleto o el estado de carga en vez de cifras viejas.

El hallazgo de `-uitest-reset`, que pasa de 20 s con un almacén de diez años, es solo del gancho de pruebas: anótalo en «Encontrado», no lo arregles aquí.

## Cómo entregar
- Un PR contra 2.3, sin firma de IA. Deja el auto merge activado y cierra; no esperes al CI. Pruebas nuevas en `YalaTests/BugsBarridoBuild8/`. Si cambian textos, ponte al día con el catálogo de 2.3 antes del PR y agrega las claves en todos los idiomas.
- Si necesitas un archivo fuera de `toca:`, tócalo solo si es imprescindible y anótalo en «Decidido sin consultar».
- Pruebas en el iPhone 14 (DeviceMCP): verifica primero que esté libre; si no, usa un simulador (en la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo). iPad para el punto 3.
- **Entregable visual:** artifact público de Claude con capturas antes y después de cada bug. Pon el link en «Qué salió».
- Cierra las dos cards de prioridad alta y el ticket al terminar, con su evidencia.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión».
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones (resueltas en modo semi, sin consultar: todas menores y reversibles)

1. **Guía de Atajos por versión.** iOS 26 sigue soportado (target 26.0): la guía de iOS 26 se queda tal cual y la de
   iOS 27 o posterior lleva textos propios (claves nuevas en los 16 idiomas), elegidos por la versión del sistema en una
   lógica pura con test. Los pasos de iOS 27 se copian del recorrido real en el iPhone 14 (iOS 27.2.1), no del hallazgo.
2. **«Ver detalle ›» del Panel.** Pasa a ser un botón propio que abre Estadísticas, con su zona de toque; el ojo no
   cambia. Se mide en el iPhone 14 antes y después.
3. **Cifra del hero con texto de accesibilidad.** `StatsHeroView` escala la cifra como el Panel (`@ScaledMetric` con el
   mismo techo de 60 pt) y topa las líneas de ingreso y gasto en AX2, como el Panel. «Te falta pagar» lleva lo mismo.
4. **Saldo del Panel con guardados seguidos.** El saldo grande deja de esperar al pase por tramos del hero: fuera de
   «Solo gastos» sale en cuanto el saldo está calculado. Primero se probó que el pase en curso terminara en vez de
   relanzarse: en el iPhone 14 no bastó, porque lo que corta el pase es el aviso de cambio del almacén de cada guardado
   (protege de leer filas borradas), no el recálculo. Fuera de `toca:`, imprescindible: `PanelViewModel.swift`.
5. **Período viejo en Estadísticas.** Al cambiar de período, mientras el cálculo no ha terminado, las cifras del hero
   salen con el esqueleto (`redacted`) en vez de las del período anterior.
6. **Fuera de `toca:` también:** los `.strings` de `CapturaAtajoParte2` en los 16 idiomas y `qa/coverage-index.json`
   (regla del repo).
7. **El hallazgo de `-uitest-reset`** va a «Encontrado», sin tocarlo.
