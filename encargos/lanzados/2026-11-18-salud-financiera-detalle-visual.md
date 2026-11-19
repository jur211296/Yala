Yala
# Detalle de Salud financiera visual y útil: alertas, presupuestos y racha de registro en vez de texto
---
toca: Yala/App/Views/Panel/Sheets/FinancialScoreDetailSheet.swift,Yala/App/Views/Panel/Sheets/SaludFinanciera/,Yala/Resources/de.lproj/SaludFinancieraDetalle.strings,Yala/Resources/en-GB.lproj/SaludFinancieraDetalle.strings,Yala/Resources/en.lproj/SaludFinancieraDetalle.strings,Yala/Resources/es-419.lproj/SaludFinancieraDetalle.strings,Yala/Resources/es-AR.lproj/SaludFinancieraDetalle.strings,Yala/Resources/es-ES.lproj/SaludFinancieraDetalle.strings,Yala/Resources/es.lproj/SaludFinancieraDetalle.strings,Yala/Resources/fr.lproj/SaludFinancieraDetalle.strings,Yala/Resources/it.lproj/SaludFinancieraDetalle.strings,Yala/Resources/ja.lproj/SaludFinancieraDetalle.strings,Yala/Resources/nl.lproj/SaludFinancieraDetalle.strings,Yala/Resources/pl.lproj/SaludFinancieraDetalle.strings,Yala/Resources/pt-BR.lproj/SaludFinancieraDetalle.strings,Yala/Resources/pt-PT.lproj/SaludFinancieraDetalle.strings,Yala/Resources/pt.lproj/SaludFinancieraDetalle.strings,Yala/Resources/zh-Hans.lproj/SaludFinancieraDetalle.strings,YalaTests/SaludFinancieraDetalle/,YalaUITests/SaludFinancieraDetalle/,tickets/done/2026-11-17-salud-financiera-detalle-visual.md
esfuerzo: medium
cierre: cierra-sola
---

Pedido de Jürgen del 17-nov (20:52 Lima), con captura. Base 2.3, un PR. Solo la hoja que se abre al tocar la card de Salud financiera del Panel (`FinancialScoreDetailSheet`). No cambies cómo se calcula la nota.

## Problema
Hoy muestra el anillo con la nota, «¡Vas increíble!», un párrafo que explica los pesos y tres filas de texto (Presupuestos 40 %, Ritmo 25 %, Compromisos 35 %). Jürgen: «pésimo, nada de valor añadido, puro texto que nadie leerá».

## Lo que quiere
- Algo visual y accionable: alertas vigentes (presupuestos por excederse o excedidos, pagos que vienen y si el saldo los cubre), presupuestos con su barra de avance, días seguidos registrando (racha visual, tipo calendario o llamita), y qué hacer para subir la nota, cada cosa con toque que lleva a su vista.
- La explicación de los pesos queda breve y secundaria (por ejemplo en un «¿Cómo se calcula?» plegado), no como bloque principal.
- Estados sin datos útiles (sin presupuestos: invitar a crear uno) en vez de «Aún no cuenta».
- Reúsa datos que ya calcula el Panel (`PanelViewModel`, `ScoreRingView`) sin modificar esos archivos (no están en tu toca); si hace falta algo nuevo, ponlo en la carpeta `SaludFinanciera/`.

## Cómo entregar
- Propón 2 o 3 variantes en maquetas, elige la recomendada e impleméntala. Lo menor, con la opción recomendada, anotado en «Decidido sin consultar».
- Tests de la lógica nueva en `YalaTests/SaludFinancieraDetalle/` y prueba de UI en `YalaUITests/SaludFinancieraDetalle/`.
- Capturas antes y después (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad).
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después lado a lado y las variantes.
- Commits y PR sin firma de IA. Toca solo lo declarado. Textos nuevos en `SaludFinancieraDetalle.strings` de cada `.lproj`, nunca en `Localizable.strings`. Nunca un botón debajo del otro.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto).
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0

Decisiones tomadas antes de escribir código (modo semi; nada de esto es vital, así que va con la recomendada):

- **Alcance:** solo la hoja de la nota TOTAL (la que abre la tarjeta del Panel, y el «?» de la tarjeta grande de Estadísticas, que es la misma hoja). Las hojas de cada parte (Presupuestos, Ritmo, Compromisos) no cambian.
- **Variante:** A, «lista de acciones» (alertas → presupuestos → próximos pagos → racha → para subir tu nota → «¿Cómo se calcula?» plegado). B (rejilla de mosaicos) y C (lista de tareas) quedan en el artifact.
- **Datos:** la hoja sigue recibiendo la nota del Panel (no se recalcula). Lo nuevo (barras de presupuesto, pagos, racha) lo lee un cargador propio en `SaludFinanciera/` con las mismas piezas del Panel y de Planificación: `BudgetPeriodInterval.current` + `BudgetsViewModel.calculateSpending` + `BudgetStatusCounter`, `MonthEndBalanceLogic` («Al 30 tendrías») para la cobertura y `ScheduledPayment.nextDueDate` para los próximos pagos. Movimientos leídos por tramos (como el Panel) para no congelar la hoja con historiales grandes.
- **Racha:** días seguidos con al menos un movimiento propio (sin ajustes), contando desde hoy o desde ayer si hoy aún no hay; tira de los últimos 14 días.
- **Toques:** presupuesto → ese presupuesto; pago → ese pago; cuenta en rojo → su ficha en el Panel; racha → Nuevo registro; «para subir» → la vista de esa parte. Cierra la hoja y navega, como el botón de antes.
- **Tamaño de la hoja:** la total abre grande (tiene más contenido); se puede bajar a media altura.
- **Textos:** nuevos en `SaludFinancieraDetalle.strings` de los 16 idiomas; se reusan los de `Localizable` que ya existen (titulares, pesos).
- **Fuera de `toca`:** `qa/coverage-index.json` (lo exige el gate al tocar `Yala/`).
