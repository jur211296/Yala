Yala
# Flujo de caja: el detalle de línea muestra todos los registros del mes, el límite arriba y lo que falta
---
toca: Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift,Yala/App/Views/Reports/CashFlow/CashFlowCellMiniChart.swift,Yala/App/Views/Reports/CashFlow/CashFlowDetailLineRow.swift,Yala/App/Views/Reports/CashFlow/DetalleLinea/,Yala/Resources/de.lproj/FlujoDetalleLinea.strings,Yala/Resources/en-GB.lproj/FlujoDetalleLinea.strings,Yala/Resources/en.lproj/FlujoDetalleLinea.strings,Yala/Resources/es-419.lproj/FlujoDetalleLinea.strings,Yala/Resources/es-AR.lproj/FlujoDetalleLinea.strings,Yala/Resources/es-ES.lproj/FlujoDetalleLinea.strings,Yala/Resources/es.lproj/FlujoDetalleLinea.strings,Yala/Resources/fr.lproj/FlujoDetalleLinea.strings,Yala/Resources/it.lproj/FlujoDetalleLinea.strings,Yala/Resources/ja.lproj/FlujoDetalleLinea.strings,Yala/Resources/nl.lproj/FlujoDetalleLinea.strings,Yala/Resources/pl.lproj/FlujoDetalleLinea.strings,Yala/Resources/pt-BR.lproj/FlujoDetalleLinea.strings,Yala/Resources/pt-PT.lproj/FlujoDetalleLinea.strings,Yala/Resources/pt.lproj/FlujoDetalleLinea.strings,Yala/Resources/zh-Hans.lproj/FlujoDetalleLinea.strings,YalaTests/FlujoDetalleLinea/,YalaUITests/FlujoDetalleLinea/,tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md
esfuerzo: medium
cierre: cierra-sola
depende: Yala/flujo-cambiar-limite
---

Decisiones de Jürgen del 18-nov (06:26 Lima), registradas: aceptó todo lo recomendado del análisis «Flujo de caja: replanteo» (ticket `tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md`, evidencia en `docs/analisis/2026-11-17-flujo-de-caja-replanteo/`):
- P1 modelo A: mes real + lo que falta.
- P2 línea excedida: cuenta lo real y no proyecta más.
- P3 al cambiar un límite, por defecto «desde este mes en adelante».
- P4 el límite es un monto fijo, sembrado con tu promedio al crear.
- P5 se retira el saldo inicial manual: se parte del saldo de tus cuentas.
- P6 lo que no tiene línea en meses futuros: gastos por la mediana de 6 meses; los ingresos no se proyectan.
- AJUSTE OBLIGATORIO: el nivel de detalle siempre llega a SUBCATEGORÍA, que es el id base. La categoría se deriva de sus subcategorías (suma) y se muestra como agrupador, puede ser colapsable. Nunca una línea solo a nivel categoría que pierda el detalle de subcategoría.

Sesión S3 del plan del ticket.

## Qué hacer
- Todos los registros del mes de esa línea (no solo 5), agrupados por día, con «Ver en Registros».
- El límite arriba con «Cambiar» que abre la hoja de la sesión flujo-cambiar-limite.
- Lo que falta y si sigue al ritmo; 6 meses de real contra límite.
- Si la línea es una subcategoría, se ve a qué categoría pertenece; aviso si hay gasto anotado en la categoría madre.
- 2 o 3 variantes en maquetas, implementa la recomendada. Actualiza el ticket marcando S3.

## Cómo entregar
- Base 2.3, un PR. Toca solo lo declarado; si algo imprescindible queda fuera, ponlo en una carpeta nueva dentro de lo declarado y anótalo.
- Tests de lo nuevo. Capturas antes y después (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad) cuando haya UI.
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después y lo decidido.
- Commits y PR sin firma de IA. Textos nuevos solo en la tabla de strings declarada de cada `.lproj`, nunca en `Localizable.strings`. Nunca un botón debajo del otro.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto). Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas por la sesión (modo semi, sin decisión vital pendiente): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Base** → la rama nace de la de «Cambiar límite» (S4, PR abierto en cola de auto-merge) y se rebasa a `2.3` cuando aterrice.
Por qué: el encargo declara `depende:` y S4 reescribe el mismo fichero (`CashFlowCellDetailSheet.swift`). Alternativa descartada: partir de `2.3` y chocar al mergear.

**D2 · Qué registros salen** → los que el reparto del motor (`FlujoMotorMes.Dueños`) da a ESA línea en ese mes, con el mismo alcance de cuentas que su cifra (las del saldo del Panel), todos, agrupados por día y con el total del día. Lo fechado después de hoy sale con su día marcado «Programado».
Por qué: la lista tiene que sumar lo que dice la línea; filtrar por categoría a mano (lo de antes) contaba lo de una subcategoría con línea propia y lo de los pagos con línea. Alternativa descartada: todos los de la categoría (no cuadra con la cifra).

**D3 · «Ver en Registros»** → pone el filtro de la subcategoría (o de la categoría, si la línea es por categoría) y el período de ese mes, cierra la hoja y abre la pestaña Registros. Solo sale si la línea tiene categoría.
Por qué: es el gesto de Distribución («Solo <categoría>» + Registros), y el período del mes hace que se vea lo mismo. Alternativa descartada: un período de visita que vuelva solo (solo existe para Estadísticas).

**D4 · El límite arriba** → la primera tarjeta dice «Límite de <mes>» con la cifra y «Cambiar» al lado, que abre la hoja de S4 (mismo id `cashflow_adjust_amount`). Sale en todos los meses. Se va el «Ajustar monto» de abajo. Debajo, «Cómo se calcula» como antes.
Por qué: el encargo lo pide arriba; S4 ya admite meses pasados. Alternativa descartada: dejar los dos botones.

**D5 · Lo que falta y el ritmo** → en el mes en curso: «Llevas X de Y», barra, «Te quedan Z» y una frase de ritmo solo en gastos: «Al ritmo de este mes llegarías a ~W» (en rosa si pasa del límite). Excedida (P2): «Te pasaste por Z. No se proyecta más.» Ingresos: «Falta recibir Z», sin ritmo (llegan en bloque). Mes que viene: el límite y lo ya programado (fechado + pagos pendientes). Mes cerrado: real contra límite.
Por qué: P1/P2 del replanteo. Alternativa descartada: ritmo también en ingresos (un sueldo mensual daría ritmos absurdos).

**D6 · 6 meses de real contra límite** → gráfica de barras de los 5 meses cerrados y el que se ve si es el actual o uno pasado (si se ve uno que viene, los 6 que acaban en el actual), con la marca del límite de cada mes. Sale del mismo reparto y del mismo cálculo del límite que el motor (`resolvePlanned`), así que no depende de cuántos meses atrás tenga el plan.
Por qué: el plan guarda 3 meses atrás por defecto; leerlo de la proyección daría 3. Alternativa descartada: ampliar el horizonte del plan (toca el ViewModel y la tabla, fuera de lo declarado).

**D7 · Navegar entre meses** → la tira de ±2 meses se sustituye por «‹ noviembre 2026 ›» en la cabecera de la tarjeta del límite; la gráfica de 6 meses ya enseña la historia.
Por qué: dos tiras de meses repetían lo mismo. Alternativa descartada: conservar la tira.

**D8 · Subcategoría y categoría madre** → la cabecera dice la categoría encima del nombre («Comida» › «Restaurantes»). Si en ese mes hay gasto anotado en la categoría sin subcategoría (`unassignedAmount` del grupo), un aviso: «Hay X en <categoría> sin subcategoría. Cuenta en el mes, no en esta línea.»
Por qué: ajuste obligatorio de Jürgen (subcategoría como id base) y lo pendiente de S1/S2. Alternativa descartada: sumarlo a la línea (rompería el reparto de un solo dueño).

**D9 · La gráfica diaria (`CashFlowCellMiniChart`)** → se retira: el ritmo y los 6 meses la sustituyen, y sumaba magnitudes sin convertir (una devolución sumaba). Se borra el fichero si queda sin uso.
Por qué: variante A de las maquetas (recomendada). Alternativa descartada: arreglarla y dejarla (tres gráficas en una hoja).

**D10 · Variantes** → A «Límite primero» (recomendada), B «Registros primero», C «Pestañas Mes / Historia». Se implementa A.
