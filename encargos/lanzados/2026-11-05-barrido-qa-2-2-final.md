Yala
# Barrido de QA final de la 2.2 antes de la subida a App Store
toca: pantallas 2.2 (iPhone, iPad, Duo), docs/qa/, tickets nuevos de bug 2.2 si salen

Rama base: origin/2.2. Un solo PR contra 2.2, un solo cierre. Máquina: **Max** (pedido Jürgen 5-nov 14:00). Usa simulador; pipeline serial (1 sim).

## Contexto
Último barrido de QA de la 2.2 antes de App Store. Todos los lotes anteriores de 2.2 ya mergeados. Encargo que estaba en espera; Jürgen pidió lanzarlo ya en la Max.

## Qué se pide
1. Recorre todas las pantallas de la 2.2 en iPhone, iPad y Duo, en modo claro y oscuro y con el texto al máximo, siguiendo la lista de los barridos A, B y C (docs/qa/).
2. Arregla en este mismo PR lo que sea chico.
3. Lo grande: card de bug en 2.2, prioridad alta, cierre autónomo.
4. Termina con una lista corta de lo que Jürgen tiene que probar en su iPhone.

## Hecha cuando
- Barrido A/B/C recorrido en los tres form factors × claro/oscuro × texto máximo.
- Bugs chicos en el PR; grandes en tablero 2.2 high.
- Lista de QA para Jürgen en el cierre.
- Card(s) de barrido en in qa o done según aplique.
- `/cerrar-total` con «Saltado o asumido sin preguntar».

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Qué son «los barridos A, B y C»** → A = barrido del 30-oct, B = barrido del 3-nov, C = barrido C del 3-nov (`docs/qa/tanda-qa-jurgen-2.2-barrido-*`). Su lista de pantallas 2.2 (Panel y «Tus finanzas», Registros, Estadísticas, Planificación, Pagos planificados, Grupos y su cabecera, Nuevo registro, voz y hoja de varios registros, Yala IA, Bandeja, Categorías, Perfil y Cuentas, Más y Flujo de caja, oferta Pro, Bienvenida) es la que se recorre. Además se drena lo que entró en «in qa» desde el barrido C (PR #766 en adelante).
Por qué: son los únicos tres barridos de 2.2 con esa letra en `docs/qa/`. Alternativa descartada: recorrer la app entera pantalla por pantalla de Ajustes (decenas de subpantallas sin cambios en 2.2).

**D2 · Matriz de variantes** (confirmada por Jürgen vía el bot, 5-nov: opción A) → por aparato, tres corridas: claro con texto normal, oscuro con texto normal y oscuro con el texto al máximo (AX5). «Oscuro» es el tema por defecto de la app (Liquid Glass, siempre oscuro); «claro» es el tema Claro.
Por qué: el layout con AX5 no cambia con el tema; lo que cambia con el tema es el color, y eso se ve con el texto normal. Alternativa descartada: AX5 también en claro (duplica capturas sin un fallo nuevo que buscar).

**D3 · Aparatos** → iPhone 17 Pro, iPad Pro 13" (M5) y iPhone Duo (cerrado = pantalla exterior; abierto = interior si Device Hub responde en la Max). Para el texto al máximo en iPhone se añade el más pequeño (iPhone 17e), como manda el pase de estrés.
Por qué: los tres form factors del encargo, más la regla del pase de estrés. Alternativa descartada: los 13 simuladores instalados.

**D4 · Cómo se conduce** → un XCUITest conductor temporal (`ZZBarridoFinalCapturasUITests`) que no se commitea: en la Max no está `axe`. Semilla `ficha` con `-uitest-seed-marketing`, Pro.
Por qué: un conductor XCUITest es lo que ya funcionó en barridos previos y no depende de herramientas que faltan. Alternativa descartada: instalar `axe` (dependencia nueva en la Max sin pedirla).

**D5 · Qué es «chico»** → se arregla en este PR lo que cabe en pocas líneas de UI sin cambiar diseño ni lógica (un `lineLimit`, un `minimumScaleFactor`, un `fixedSize`, un texto sin traducir). Lo que pide decidir diseño, toca lógica o más de ~2 ficheros → card de bug en 2.2, prioridad alta, cierre autónomo.
Por qué: el encargo pide arreglar lo chico sin abrir rediseños antes de App Store. Alternativa descartada: arreglar todo en el PR (riesgo de regresión el día de la subida).

**D6 · Cards en «in qa»** → se aplica el filtro doble de `/barrido-qa` a las cards de versión 2.2 que entraron después del barrido C; las de 2.3, las de Lola y las de marketing/App Store Connect no se tocan.
Por qué: el alcance del encargo es la 2.2 antes de App Store. Alternativa descartada: barrer también 2.3.

**D7 · Choque con la sesión que registra decisiones (también toca `tickets/`)** (Jürgen vía el bot, 5-nov) → los movimientos de tickets van en este PR; el merge de la otra sesión se espera solo al integrar (un rebase antes de abrir el PR), sin parar el recorrido.

**D8 · El Panel del iPad que no carga al abrir Yala** (Jürgen vía el bot, 5-nov) → primero B (card aparte); tras medir que la 2.1 publicada NO lo tiene (regresión de 2.2), **A: el arreglo entra en este PR**, con sus tests y la verificación en el iPad.

**D9 · Duo abierto en la Max** (Jürgen vía el bot, 5-nov: opción 1) → Jürgen da a Terminal Grabación de pantalla y Accesibilidad en la Max, y el Duo abierto se recorre ahí con Device Hub.
