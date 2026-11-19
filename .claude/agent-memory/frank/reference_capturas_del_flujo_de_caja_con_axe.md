---
name: capturas-del-flujo-de-caja-con-axe
description: Cómo capturar Flujo de caja (mes futuro y hojas «Otros») con axe sin XCUITest: plan que no persiste, barra plegada en el SE, gestos en el iPad, hojas fuera del árbol
metadata:
  type: reference
---

Medido el 2026-11-19 (proyección inteligente), con `YalaUITests/` vedado por el encargo:

- **Con `-uitest` el plan NO sobrevive a un relanzamiento**, aunque no pases `-uitest-reset`: hay que crearlo en cada
  lanzamiento (Reportes → chip Flujo de caja → «Crear mi plan», `primary_button`).
- **Cada toque se reintenta hasta ver la pantalla siguiente** (`report_chip_flujoDeCaja`, `cashflow_setup_view`,
  `cashflow_month_title`): un toque justo tras un arrastre se pierde sin error, y «Crear mi plan» falló así 2 veces.
- **Ir a un mes**: volver arriba primero; tocar la cápsula por el centro de su marco (`cashflow_month_capsule_AAAA-MM`)
  y comprobar el título («Diciembre de 2026»). `axe tap --id` sobre la cápsula no cambia de mes.
- **SE**: la barra de pestañas sale plegada; tocar el `RadioButton` «Panel» la despliega y aparece «Reportes».
- **iPad**: el contenido va en columna legible; los arrastres en x=120 no desplazan nada (usar x≈500), y un botón al
  final de la página puede quedar por debajo del 82 % del alto: tocarlo por su marco.
- **Las hojas no están en el árbol de axe**: la de «Otros» se cierra arrastrando desde su asa a media altura (~49 % del
  alto → 97 %). Si antes la estiraste, ese gesto ya no la cierra.
- Las líneas de la pantalla de armado se desmarcan por su `Button` con el nombre de la línea, siempre que estén a la
  vista (a letra grande quedan debajo: desplazar antes).

Guiones de esa sesión (scratchpad, se pierden): `hasta-plan.sh` + `desde-mes.sh` + `centro.py`. Ver
[[capturas-con-conductor-xcuitest]] cuando sí se pueda tocar `YalaUITests/`.
