# Lote · XCUITest de selectores y neto del flujo / widget en cero
toca: XCUITest selectores Nuevo registro, XCUITest barra iPad, neto mes flujo de caja widget Saldo

Rama base: origin/2.3 (y el arreglo del XCUITest de 2.2 si aplica cherry o rama que toque). Un solo PR, un solo cierre. Máquina: la libre. Si la prueba va mejor en el celular que en el simulador, usa el iPhone 14 conectado por DeviceMCP. Si corres en la Max y otra sesión de otro proyecto ya usa un simulador, puedes abrir un segundo (tope 2 en la Max) o usar el iPhone 14 conectado por DeviceMCP. En la Mini el tope de simuladores es 1. Cierre autónomo. Termina con `/cerrar-total`. Commits y PR sin firma de IA.

## Contexto
Tres arreglos de tests / cifras:
1. El XCUITest de los selectores de Nuevo registro cae: el chip de Etiquetas queda tapado (tablero-el-xcuitest-de-los-selectores-de-nuevo-r-ditx, v2.2)
2. Los XCUITest que comprueban la barra de pestañas del iPhone siguen fallando en iPad (tablero-los-xcuitest-que-comprueban-la-barra-de-8o89)
3. El neto del mes del flujo de caja y la variación del widget de Saldo ponen signo o flecha a un cero (tablero-el-neto-del-mes-del-flujo-de-caja-y-la-v-dakm)

## Qué se pide
Arreglar los tres; suite verde en lo tocado; cards a `in qa` o done según corresponda.

## Qué NO hay que tocar
marketing/, reescrituras grandes de flujo de caja.

## Cómo se sabe que está bien
Tests verdes en lo tocado; gate verde; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas, salvo D1, que contestó Jürgen. Se discuten en el PR.

**D1 · ¿Dónde va el arreglo del chip de Etiquetas, si el rojo solo existe en 2.2?** → Opción C (Jürgen, por el bot): un PR a 2.2 solo con ese arreglo y otro a 2.3 con lo demás.
Por qué: el cambio que lo trajo («Guardar» sin pisar el formulario) no está en 2.3; arreglarlo allí no arregla nada. Alternativa descartada: todo en 2.3 (2.2 seguiría rojo).

**D2 · ¿Qué cifras entran en «un cero sin signo ni flecha»?** → La cápsula del mes, el rótulo «te sobran/te faltan» del mes y del resumen del plan, la píldora de Saldo y la de Entradas y salidas, y la lectura de VoiceOver de la de Gastos.
Por qué: es el mismo patrón (decidir el signo con `>= 0`/`> 0` sobre una cifra que se pinta redondeada) y la regla es arreglar todas las instancias. Alternativa descartada: solo las dos de la card (dejaría «te faltan S/ 0.00» y la flecha en Entradas y salidas).

**D3 · ¿Con qué se decide «se pinta como cero» en el widget?** → Con el mismo formateador que pinta la cifra (`WidgetAmountSplitter.shownSign`), no con un umbral de 0,5.
Por qué: el umbral fallaba justo en 0,5, que el redondeo al par pinta «0». Alternativa descartada: `CurrencyFormattingHelper.isShownAsZero` (no compila en la extensión).

**D4 · Barra de pestañas en iPad: ¿adaptar o declarar de iPhone, por suite?** → Adaptar donde la prueba vale en los dos (Panel elegido por su entrada, informes por Reportes sin «Más», barra encogida); declarar con `XCTSkip` y motivo solo lo que prueba «Más» o la barra de abajo, y solo en iPad sin «Más» (en iPad vertical, si hay «Más», sigue corriendo). Las medidas de la barra de abajo pasan por `compactTabBar`, que en iPad no existe.
Por qué: es lo que pide «hecho cuando» (`tabBars` solo en el ayudante) sin perder cobertura en iPad. Alternativa descartada: saltar suites enteras por idiom.
