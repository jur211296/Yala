Yala
# Flujo de caja: crear el plan sin saldo inicial manual y con líneas por subcategoría sembradas con tu promedio
---
toca: Yala/App/Views/Reports/CashFlow/CashFlowSetupView.swift,Yala/App/Views/Reports/CashFlow/CashFlowStartingBalanceSheet.swift,Yala/App/Views/Reports/CashFlow/CashFlowAddLineSheet.swift,Yala/App/Logic/CashFlowSetupLogic.swift,Yala/App/Views/Reports/CashFlow/CrearPlan/,Yala/Resources/de.lproj/FlujoCrearPlan.strings,Yala/Resources/en-GB.lproj/FlujoCrearPlan.strings,Yala/Resources/en.lproj/FlujoCrearPlan.strings,Yala/Resources/es-419.lproj/FlujoCrearPlan.strings,Yala/Resources/es-AR.lproj/FlujoCrearPlan.strings,Yala/Resources/es-ES.lproj/FlujoCrearPlan.strings,Yala/Resources/es.lproj/FlujoCrearPlan.strings,Yala/Resources/fr.lproj/FlujoCrearPlan.strings,Yala/Resources/it.lproj/FlujoCrearPlan.strings,Yala/Resources/ja.lproj/FlujoCrearPlan.strings,Yala/Resources/nl.lproj/FlujoCrearPlan.strings,Yala/Resources/pl.lproj/FlujoCrearPlan.strings,Yala/Resources/pt-BR.lproj/FlujoCrearPlan.strings,Yala/Resources/pt-PT.lproj/FlujoCrearPlan.strings,Yala/Resources/pt.lproj/FlujoCrearPlan.strings,Yala/Resources/zh-Hans.lproj/FlujoCrearPlan.strings,YalaTests/FlujoCrearPlan/,YalaUITests/FlujoCrearPlan/,tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md
esfuerzo: medium
cierre: cierra-sola
depende: Yala/flujo-detalle-de-linea
---

Decisiones de Jürgen del 18-nov (06:26 Lima), registradas: aceptó todo lo recomendado del análisis «Flujo de caja: replanteo» (ticket `tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md`, evidencia en `docs/analisis/2026-11-17-flujo-de-caja-replanteo/`):
- P1 modelo A: mes real + lo que falta.
- P2 línea excedida: cuenta lo real y no proyecta más.
- P3 al cambiar un límite, por defecto «desde este mes en adelante».
- P4 el límite es un monto fijo, sembrado con tu promedio al crear.
- P5 se retira el saldo inicial manual: se parte del saldo de tus cuentas.
- P6 lo que no tiene línea en meses futuros: gastos por la mediana de 6 meses; los ingresos no se proyectan.
- AJUSTE OBLIGATORIO: el nivel de detalle siempre llega a SUBCATEGORÍA, que es el id base. La categoría se deriva de sus subcategorías (suma) y se muestra como agrupador, puede ser colapsable. Nunca una línea solo a nivel categoría que pierda el detalle de subcategoría.

Sesión S5 del plan del ticket.

## Qué hacer
- Fuera «¿Con cuánto empiezas?»: se parte del saldo de tus cuentas. Retira o deja inalcanzable la hoja de saldo inicial y migra con cuidado los planes que ya lo tienen (sin perder datos; anota qué hiciste).
- Líneas por subcategoría por defecto, agrupadas bajo su categoría (colapsable), con límites fijos sembrados con el promedio de 6 meses.
- Agregar línea: se elige subcategoría (la categoría sale de ella).
- Actualiza el ticket marcando S5.

## Cómo entregar
- Base 2.3, un PR. Toca solo lo declarado; si algo imprescindible queda fuera, ponlo en una carpeta nueva dentro de lo declarado y anótalo.
- Tests de lo nuevo. Capturas antes y después (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad) cuando haya UI.
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después y lo decidido.
- Commits y PR sin firma de IA. Textos nuevos solo en la tabla de strings declarada de cada `.lproj`, nunca en `Localizable.strings`. Nunca un botón debajo del otro.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto). Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (resueltas en autónomo, bypass, modo nocturno)

Medido antes de decidir: desde S1 el motor del mes no lee `plan.startingBalance` (solo lo escribe
`updateStartingBalance`, que ya nadie llama desde la UI); desde S2 la hoja del saldo inicial ya no se abre desde la
tabla. La única entrada viva es «¿Con cuánto empiezas? · Cambiar» del armado.

1. **Saldo inicial manual (P5).** Fuera la cabecera «¿Con cuánto empiezas?» y su «Cambiar». En su sitio, «Tienes hoy»
   con el saldo de las cuentas (la cifra del Panel), sin edición, y la frase de que el plan parte de ahí.
   `CashFlowStartingBalanceSheet` se queda: es también la hoja de «¿Cuánto recibes al mes?». Como hoja del saldo
   inicial queda inalcanzable.
2. **Migración de los planes que ya tienen saldo inicial:** no se toca nada. El dato se queda guardado tal cual
   (`startingBalance` y `startingBalanceDate`), no se pierde, y nadie lo lee desde S1. Sin migración de esquema. Un plan
   nuevo guarda en ese campo el saldo de hoy, solo como registro.
3. **Líneas por subcategoría (ajuste obligatorio).** Las sugerencias por categoría se retiran cuando la categoría
   tiene subcategorías visibles. Lo anotado en la madre sin subcategoría no lleva línea: en el mes sale en la fila «Sin
   subcategoría» de la tabla (S2) y en los meses futuros entra en «otros» por la mediana (P6). **Excepción:** una
   categoría SIN subcategorías visibles sí lleva línea por categoría, porque no hay detalle que perder (la misma regla
   que ya usa «Agregar a mi plan» desde otros). Un pago planificado conserva su línea.
4. **Agrupado.** En el armado, cada sección agrupa sus líneas bajo la categoría, con cabecera plegable (desplegada al
   abrir) que suma lo elegido. Se conserva la división «lo que se repite a la vista / gastos que cambian plegados» del
   lote 18: un grupo va a la vista si alguna de sus líneas se repite.
5. **Límite fijo sembrado con el promedio (P4).** Al crear, cada línea por promedio (o «el mes pasado») se guarda como
   monto fijo con la cifra calculada. Un pago planificado sigue con su pago. El selector «Cómo se calcula» del armado se
   queda como forma de elegir con qué cifra se siembra.
6. **Agregar línea › Desde mis gastos.** Se elige la subcategoría (la categoría sale de ella; sin subcategorías, la
   categoría). La línea nace con monto fijo sembrado con el método elegido, calculado como el motor: meses completos
   anteriores y con signo. Antes la vista previa ignoraba el método y sumaba magnitudes.
7. **iPad:** en la Mini solo hay un simulador y no hay iPad creado; con 16 GB libres no se crea otro. Capturas de
   iPhone 17 Pro (oscuro, claro, texto grande) y SE. El iPad queda fuera y se dice en el cierre.
8. **Ficheros fuera de lo declarado:** `YalaUITests/Flows/CashFlowPlanUITests.swift` fija la cabecera retirada y se
   actualiza (si no, el gate cae). `CashFlowPlanViewModel` no se toca: el filtrado y el monto fijo se aplican sobre
   `suggestedLines` desde la lógica nueva en `CrearPlan/`.
