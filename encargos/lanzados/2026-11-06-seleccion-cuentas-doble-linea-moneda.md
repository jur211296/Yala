# Selección de cuentas: la fila principal de una cuenta de doble línea no mezcle monedas
toca: AccountSelectorSheet, AccountSelectorViewModel, ImportAccountPickerSheet

Rama base: origin/2.2. Un solo PR contra 2.2, un solo cierre. Máquina: la libre (máx. 1 Yala por máquina). Si la prueba va mejor en el celular que en el simulador, usa el iPhone 14 conectado por DeviceMCP. Cierre autónomo. Termina con `/cerrar-total`.

Card: «Selección de cuentas: la fila principal de una cuenta de doble línea no mezcle monedas». Prioridad alta, versión 2.2.

## Contexto
El 6 de noviembre Jürgen vio en la hoja «Cuenta» (selector al registrar o elegir cuenta) que las cuentas de doble línea se leen mal. Ejemplo con Sapphire: la fila principal dice «PEN · USD» en la misma línea (como si fuera de las dos monedas a la vez) y debajo aparece «Sapphire · USD». Lo mismo se ve en «BCP Débito» con «PEN · USD».

Quiere que cada fila diga solo su moneda, y que esa moneda también aparezca en el nombre de la principal:

Sapphire · PEN
PEN
     Sapphire · USD
     USD

## Qué se pide
En la selección de cuentas (la hoja titulada «Cuenta» y cualquier otro selector igual):
- La fila de la línea principal muestra una sola moneda (la de esa línea), no «PEN · USD».
- Esa moneda también va en el nombre: «Sapphire · PEN», no solo «Sapphire».
- La fila de la otra línea queda como ahora en espíritu: «Sapphire · USD» con subtítulo «USD».
- Aplica a todas las cuentas de doble línea, no solo a Sapphire (p. ej. BCP Débito).
- Prueba el cambio en pantalla (iPhone 14 por DeviceMCP si conviene; si no, simulador) con al menos una cuenta de doble línea y una de una sola moneda (Sip, Starbucks) para no romper esas.
- Deja la card en `in qa` con una nota corta de qué cambió.

## Qué NO hay que tocar
marketing/. No rediseñes el selector entero ni cambies cómo se elige o guarda la cuenta. No toques el editor de saldos iniciales de doble línea salvo que el mismo texto del selector viva ahí y quede inconsistente: en ese caso alinéalo. Si una decisión de producto no está clara, `preguntar-bot` con opciones; no saltes ni asumas.

## Cómo se sabe que está bien
Cada fila muestra una sola moneda, también en el nombre de la principal, como en el ejemplo de Jürgen. Gate verde. `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: la línea ya se llama «Sapphire · USD» porque ese es su nombre guardado
(`AccountCardLogic.lineName`); la principal se llama «Sapphire» y la hoja le ponía de subtítulo todas las
divisas de la tarjeta (`AccountSelectorRow.cardCurrencies`). Reproducido en el simulador con la semilla
`tarjeta-dos-lineas`: «Visa QA / PEN · USD».

**D1 · ¿El «· PEN» se guarda en el nombre de la cuenta o solo se muestra?** → Solo se muestra en el selector.
Por qué: el encargo prohíbe cambiar cómo se guarda la cuenta, y renombrarla movería el Panel, Ajustes y el orden guardado por nombre. Alternativa descartada: renombrar la principal (toca datos de usuario).

**D2 · ¿Cuándo lleva la principal su divisa en el nombre?** → Cuando tiene alguna línea viva, aunque esa línea no salga en la hoja (divisa fija, o la línea es el origen de la transferencia).
Por qué: así la misma cuenta se llama igual en todas las hojas de elegir cuenta. Alternativa descartada: solo cuando la línea se ve debajo (la misma tarjeta cambiaría de nombre según el formulario).

**D3 · Un nombre que ya acaba en su divisa («X · PEN»)** → No se repite («X · PEN · PEN» no).
Por qué: barato y evita un nombre feo. Se reutiliza la detección de nombres automáticos que ya existe.

**D4 · ¿Qué otros selectores entran?** → La hoja «Cuenta» (todos los formularios que la abren) y la hoja de elegir cuenta al importar. Fuera: el menú de cuenta de los pagos programados y los filtros de Registros y presupuestos.
Por qué: el de importar es el único otro con la misma fila nombre + moneda; el menú de programados solo pinta nombres, y los filtros enseñan la tarjeta entera (ahí «la tarjeta» sí abarca sus dos divisas). Lo de fuera va en «Encontrado».

**D5 · Editor de saldos iniciales de doble línea** → No se toca.
Por qué: no usa el texto «PEN · USD» del selector (medido: `AccountLineBalanceEditor` solo nombra la divisa de la línea).

**D6 · Identificador de accesibilidad de la fila** → Sigue con el nombre guardado (`account_selector_row_Visa QA`).
Por qué: decenas de XCUITest eligen la cuenta por él; la etiqueta que lee VoiceOver sí dice el nombre nuevo.
