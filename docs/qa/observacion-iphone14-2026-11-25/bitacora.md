# Observación en vivo del iPhone 14 — 25-nov-2026

Yala Dev 2.3 (10) en el iPhone 14 de pruebas (iOS 27.2.1), base dev limpia. Solo mirada: nadie toca el teléfono salvo Jürgen.
Horas en Lima (UTC−5).

## Cómo se mide

- **Pantalla**: un vigía lee el árbol de accesibilidad cada ~2 s por Device MCP y guarda captura cuando la pantalla cambia
  (o cada 30 s). Precisión de una marca de pantalla: **± 2 s** (aprox., de captura).
- **Telemetría**: eventos de la app en Analytics Engine (`yala_metrics_staging` para Yala Dev), por instalación. Hora de
  llegada al servidor: **precisa al segundo** si hay red.
- **Log del sistema**: no disponible en vivo. `log collect` desde el Mac pide root y `devicectl --console` exige relanzar
  la app, que está prohibido. Queda como hueco declarado.

## Marcas de tiempo

| Hora | Qué |
|---|---|
| 17:10 | Arranca la sesión. El espejo lo tenía la Mini sin uso; se recupera para la Max. |
| 17:11 | Vigía en marcha: Jürgen en la Bienvenida de Yala Dev. |
| 17:12:55 | Toca «Entrar con Google». |
| 17:13:11 | «Vamos a crear tu cuenta» (el correo no tenía cuenta: base dev limpia, como se esperaba). |
| 17:13:15 | Cuenta creada. Empieza el chat: nombre, moneda, «Solo gastos». |
| 17:13:40 | Panel con Primeros pasos, 2 de 7: «Cuenta» ya marcada. |
| 17:16:33 | Abre Ajustes → Tu cuenta de Yala. |
| 17:16:42 | Elimina la cuenta: «Eliminando tu cuenta… Mantén Yala abierta». |
| 17:16:48 | De vuelta en la Bienvenida. |
| 17:19:55 | Entra con Apple (cuenta test@yala-app.pe). |
| 17:20:04 | Cuenta creada con Apple. |
| 17:20:12 | El chat guarda el nombre «Jur» (lo escribió así Jürgen: correcto). |
| 17:20:16 | Panel: Primeros pasos 1 de 7, «Crea tu primera cuenta» pendiente (correcto con «Gastos e ingresos»). |
| 17:28:50 | Empieza el paso 1 (Gastos e ingresos): intro «Antes de empezar», 3 partes. |
| 17:33:16 | Paso 1: «Crear mi primera cuenta» → preguntas («¿Cuál creamos primero?», parte 1 de 5). |
| 17:33:27 | Añade dólares a la cuenta «Ahorros» (6 partes). |
| 17:33:31 | Usa «No lo sé, ayúdame a calcularlo»: S/ 5000.00. |
| 17:33:37 | Pregunta «¿Y en dólares?» (parte 5 de 6). |
| 17:33:47 | Panel: saldo S/ 5000.00, «Tus finanzas» con «Ahorros ≈ S/ 5000.00», Primeros pasos 2 de 7. |
| 17:34:16 | Paso 2: intro «Cuatro maneras de apuntar». |
| 17:34:51 | Primer gasto guardado: S/ 20.00, Supermercados y tiendas. |
| 17:35:16 | Omite Voz, Foto y Yala IA. |
| 17:35:20 | «¿Borramos los de prueba?» (1 registro). |
| 17:35:25 | Aviso de la Bandeja: «Lo que Yala apunta solo». |
| 17:35:33 | Panel en S/ 5000.00: correcto, el gasto de prueba se borró (en el store solo queda el saldo inicial). |
| 17:37:44 | Paso 3 (presupuesto): intro «Un tope para lo que gastas». |
| 17:38:02 | Presupuesto por categorías (el flujo pasa de 7 a 9 partes). |
| 17:38:25 | Permiso de notificaciones de iOS al aceptar los avisos del 75 % y 100 %. |
| 17:38:31 | Presupuesto creado: «Mascotas y animales», S/ 25.00 semanal. |
| 17:38:35 | Panel con el aviso «Tus presupuestos viven en Más». |
| 17:43:43 | Paso 4: preguntas del primer pago planificado (sin intro visible). |
| 17:44:10 | Pago planificado creado: «Películas y series», ≈ S/ 20.00, el 20 de diciembre. |
| 17:44:14 | Aviso «Tus pagos planificados viven en Más». |
| 17:44:18 | Panel: Primeros pasos 5 de 7 (Grupos). |
| 17:48:14 | Paso 5 (Grupos): intro «Comparte gastos sin perderles el rastro». |
| 17:48:25 | Termina la intro de Grupos: mazo en 6 de 7. |
| 17:48:35 | Paso 6: guía «Todas tus gráficas» en Más. |
| 17:48:42 | «Entendido» del paso 6: se queda en Más. |
| 17:49:33 | Paso 7: historias «Anota sin abrir Yala» (Widget, Apple Pay, Compartir…). |
| 17:49:47 | Última historia del paso 7 («Tu IA», con «Terminar»). |
| 17:49:51 | Panel: «¡Primeros pasos completos!», «Dejaste para después: Inicio», confeti y oferta Pro debajo. |
| 17:50:49 | Abre Yala Pro desde la oferta del Panel: sin precios (Yala Dev). |
| 17:51:23 | Ajustes → «¿Cerrar tu sesión en este dispositivo?» |
| 17:51:30 | De vuelta en la Bienvenida tras cerrar sesión. |
| 17:51:40 | Entra con Google (cuenta borrada a las 17:16): aviso correcto «Este dispositivo ya ha usado otra cuenta», con Apple o crear con Google. |
| 17:51:52 | «Ya tienes una cuenta» (test@yala-app.pe). |
| 17:51:58 | Cargando sus datos: 28 % «Conectando con tu cuenta…». |
| 17:52:03 | Panel: S/ 5000.00, «Ahorros», presupuesto «Mascotas y animales»; Pagos planificados vacío (mismo fallo de antes). |
| 17:52:44 | Ajustes → «Cargar datos de prueba». |
| 17:53:03 | Abre Registros. |
| 17:53:09 | Grupos → «Nuevo grupo»: «Tu primer grupo, en tres pasos». |
| 17:53:11 | Vuelve a salir la intro de Grupos. |
| 17:54:19 | Ajustes → «¿Eliminar tu cuenta de Yala?» (cuenta de Apple, test@yala-app.pe). |
| 17:54:26 | «Eliminando tu cuenta…». |
| 17:54:32 | Bienvenida tras eliminar la cuenta de Apple. |
| 17:54:34 | Entra otra vez con Google. |
| 17:54:45 | Cuenta nueva con Google (jur211296). |
| 17:54:56 | Panel: Primeros pasos 1 de 7. |
| 17:55:00 | Paso 1 directo a preguntas, sin intro (ya vista en este teléfono). |
| 17:55:02 | De «¿Cuál creamos primero?» (parte 1) a «¿Cómo se llama?» (parte 3) en 2 s. |
| 17:56:33 | Paso 6 de nuevo: esta vez se ve bien, según Jürgen. |
| ≈17:19 | Jürgen decide: con «Solo gastos» el paso 1 se hace de cero. (hora aproximada del mensaje en el chat) |
| ≈17:34 | Revisión de crashes del iPhone: ninguno desde las 17:10 (el último aviso de memoria es de las 16:37, antes de la sesión). (hora aproximada del mensaje en el chat) |
| ≈17:52 | Jürgen confirma que el paso 4 tuvo intro y parte 4: la falsa alarma se retira. (hora aproximada del mensaje en el chat) |

## Mediciones

| Hora | Medida | Valor | Fuente |
|---|---|---|---|
| 17:12:55 | Tocar «Entrar con Google» → aviso del sistema para abrir Google | ~2.0 s | Captura (± 2 s) |
| 17:13:05 | Confirmar en Google → «Vamos a crear tu cuenta» (pantalla «Verificando tu cuenta…» en medio) | ~4.0 s | Captura: «Verificando» visto de 17:13:07 a 17:13:09, la siguiente a las 17:13:11 (entre 3 y 6 s) |
| 17:13:13 | «Crear mi cuenta» → «Hemos creado tu cuenta» | ~2.0 s | Captura (± 2 s) |
| 17:13:38 | «Entrar a Yala» → Panel con Primeros pasos | ~2.0 s | Captura (± 2 s): último chat 17:13:36, Panel 17:13:40 |
| 17:16:42 | Eliminar mi cuenta: «Eliminando tu cuenta…» → Bienvenida | ~5.0 s | Captura: «Eliminando» de 17:16:42 a 17:16:46, Bienvenida a las 17:16:48 (entre 4 y 8 s, toque de confirmar entre 17:16:40 y 17:16:42) |
| 17:19:58 | Confirmar en Apple → «Vamos a crear tu cuenta» («Verificando tu cuenta…» en medio) | ~3.0 s | Captura: hoja de Apple hasta 17:19:57, «Verificando» a las 17:19:59, la siguiente a las 17:20:02 (entre 2 y 4 s) |
| 17:20:14 | Fin del chat → Panel con Primeros pasos (Apple, «Gastos e ingresos») | ~2.0 s | Captura (± 2 s): chat completo 17:20:14, Panel 17:20:16 |
| 17:33:45 | «Ver mi Yala» tras crear la cuenta → Panel con saldo y la cuenta | ~2.0 s | Captura (± 2 s): «¡Lista!» 17:33:45, Panel 17:33:47 |
| 17:34:47 | Guardar el primer gasto (S/ 20.00) → «Gasto guardado» | ~2.0 s | Captura (± 2 s): formulario 17:34:47, confirmación 17:34:51 con el toque entre medias |
| 17:38:31 | «¡Listo!» del presupuesto → Panel | ~3.0 s | Captura (± 2 s): «¡Listo!» 17:38:31, Panel 17:38:35 con el toque entre medias |
| 17:49:47 | Última historia del paso 7 → Panel con «¡Primeros pasos completos!» | ~3.0 s | Captura (± 2 s): historia 6 a las 17:49:47, Panel a las 17:49:51 |
| 17:51:25 | Cerrar sesión: «Cerrando sesión…» → Bienvenida | ~4.0 s | Captura: «Cerrando» a las 17:51:25, Bienvenida a las 17:51:30 (entre 2 y 6 s) |
| 17:51:38 | Confirmar en Google → «Este dispositivo ya ha usado otra cuenta» | ~2.0 s | Captura (± 2 s): Google 17:51:38, aviso 17:51:40 |
| 17:51:46 | Confirmar en Apple → «Ya tienes una cuenta» | ~4.0 s | Captura: hoja de Apple 17:51:46, transición 17:51:50, aviso 17:51:52 (entre 2 y 6 s) |
| 17:51:56 | Cargar sus datos (barra 28 % → 80 %) → Panel con saldo, cuenta y presupuesto | ~6.0 s | Captura: 28 % a las 17:51:58, 80 % a las 17:52:00, Panel a las 17:52:03; con el toque entre 17:51:52 y 17:51:58, entre 5 y 11 s |
| 17:52:44 | Cargar datos de prueba → Panel con el saldo nuevo (S/ 78,760.05) | ~2.0 s | Captura (± 2 s): Ajustes 17:52:44, Panel 17:52:46 |
| 17:54:26 | Eliminar mi cuenta (con datos de prueba): «Eliminando tu cuenta…» → Bienvenida | ~5.0 s | Captura: «Eliminando» 17:54:26, Bienvenida 17:54:32 (entre 4 y 8 s, igual que la primera vez sin datos) |

## Hallazgos

### 17:12:59 — La hoja de Google sale en inglés

- **Qué pasó:** «Choose an account», «Sign in to Yala», «You'll share this info about you». El resto de la app va en español.
- **Evidencia:** Captura 17:12:59 y 17:13:05
- **Causa probable:** Google pinta su hoja en el idioma del sistema del iPhone, no en el de la app. No es de Yala.
- **Captura:** `capturas/171259.jpg`

### 17:13:05 — «Verificando tu cuenta…» tarda entre 3 y 6 s

- **Qué pasó:** Después de confirmar en Google, la pantalla de verificación se queda varios segundos antes de «Vamos a crear tu cuenta».
- **Evidencia:** Capturas 17:13:07 y 17:13:09 con «Verificando tu cuenta…»; 17:13:11 ya en «Vamos a crear tu cuenta»
- **Causa probable:** Comparado con Apple (17:19:59): Apple tardó entre 2 y 4 s, Google entre 3 y 6 s. La diferencia cabe en el margen de ± 2 s; el tramo común es la consulta al servidor de si el correo ya tiene cuenta.
- **Captura:** `capturas/171309.jpg`

### 17:33:25 — Al añadir una segunda moneda, la hoja dice «Moneda principal»

- **Qué pasó:** En el paso 1, con soles ya elegidos, «+ Añadir moneda» abre un selector titulado «Moneda principal», aunque lo que se elige es la segunda moneda de la cuenta (dólares). Además los nombres salen con mayúscula inicial en cada palabra («Sol Peruano», «Dólar Estadounidense»), mientras la tarjeta dice «sol peruano».
- **Evidencia:** Captura 17:33:25: título «Moneda principal», filas «Sol Peruano, PEN» y «Dólar Estadounidense, USD».
- **Causa probable:** El selector del paso 1 reutiliza el título de Ajustes («settings.preferredCurrency»). Debería decir algo como «Otra moneda» o «Moneda de la cuenta» cuando se añade.
- **Dónde:** Yala/App/Views/Onboarding/PrimerosPasos/FirstAccountFlowView.swift (FirstAccountCurrencyPicker)
- **Captura:** `capturas/173325.jpg`

### 17:33:47 — «Presupuesto» sale en letra más chica que los otros pasos

- **Qué pasó:** En la fila de pasos (Cuenta, Registrar, Presupuesto, Pagos…), «Presupuesto» se encoge para caber y queda visiblemente más pequeño que sus vecinos. Pasa igual con «Solo gastos» y con «Gastos e ingresos».
- **Evidencia:** Capturas 17:13:40 y 17:33:47.
- **Causa probable:** La etiqueta reduce su tamaño para entrar en el ancho fijo de la columna (texto que se escala al mínimo). Opciones: una palabra más corta («Plan»), dos líneas o columnas más anchas.
- **Dónde:** Yala/App/Views/Panel/SetupDeckProgress.swift (fila de pasos del mazo)
- **Captura:** `capturas/173347.jpg`

### 17:43:25 — El nombre del presupuesto sale cortado en el Panel: «Mascotas y anima…»

- **Qué pasó:** En Planificación → Presupuestos, la fila del presupuesto recién creado corta el nombre a «Mascotas y anima…», con espacio libre a la derecha del widget.
- **Evidencia:** Captura 17:43:25 (Panel con Planificación).
- **Causa probable:** La fila del widget pequeño de Presupuestos limita el nombre a una línea en media columna. Opciones: dos líneas o el widget a lo ancho cuando hay un solo presupuesto.
- **Dónde:** Yala/App/Views/Panel/BudgetsWidget.swift · BudgetWidgetRow.swift
- **Captura:** `capturas/174325_p.jpg`

### 17:48:16 — La intro de Grupos dice «paso 2 de 3» dentro del paso 5 de Primeros pasos

- **Qué pasó:** Arriba se lee «Grupos · paso 1/2/3 de 3» mientras las rayitas ya marcan la parte. Las intros de los pasos 1 a 4 dicen «Antes de empezar». Llamar «paso» a las partes de la intro choca con «paso 5 de 7» de Primeros pasos.
- **Evidencia:** Capturas 17:48:14 y 17:48:16.
- **Causa probable:** Texto propio de la intro de Grupos. Propuesta: «Antes de empezar» como en las demás, o «Grupos» sin contador.
- **Dónde:** Intro de Grupos de Primeros pasos (Yala/App/Views/Onboarding/PrimerosPasos/)
- **Captura:** `capturas/174816.jpg`

### 17:49:51 — Tras ver las 6 historias del paso 7, «Inicio» queda «para después»

- **Qué pasó:** Jürgen pasó las seis historias de «Anota sin abrir Yala» (17:49:33 a 17:49:47) y el cierre dice «Dejaste para después: Inicio», con el paso 7 punteado. Sobre el botón «Cerrar» caen piezas del confeti. Además, con 5 de 7 pasos para después, el título sigue diciendo «¡Primeros pasos completos!», que se lee raro cuando solo se hicieron dos.
- **Evidencia:** Captura 17:49:51. Se repite a las 17:57:07 (captura): de nuevo «Tutorial · 6 de 6 · Tu IA · Terminar» a las 17:57:04 y al Panel con «Inicio» para después.
- **Causa probable:** Medido en el código: el paso 7 queda hecho solo si al menos una de sus maneras (Widget, Apple Pay, Compartir, Correo, Siri, Tu IA) se marcó como hecha («Listo», «Ya lo configuré», «Entendido»). Desde que el paso 7 son historias, pasarlas con toques no marca ninguna; al llegar al final con «Terminar» sale «terminado sin ninguna hecha» y el paso se marca como omitido. Arreglo: ver todas las historias hasta «Terminar» cuenta como hecho.
- **Dónde:** Yala/App/Logic/HomeScreenTutorialLogic.swift (resolution: .finished(anyDone) → .skipped si ninguna) · Yala/App/Views/Panel/PrimerosPasosHomeScreenPresentation.swift (afterTutorial)
- **Captura:** `capturas/174951.jpg`

### 17:50:49 — El paywall de Yala Pro dice «No pudimos cargar los precios. Revisa tu conexión.» con Wi-Fi bien

- **Qué pasó:** Al abrir Yala Pro desde la oferta del Panel, la hoja no muestra precios y culpa a la conexión. El iPhone tenía Wi-Fi y red móvil llenas.
- **Evidencia:** Captura 17:50:49.
- **Causa probable:** Esperado en Yala Dev: los productos de Pro están dados de alta para la app de producción, y la compilación de desarrollo no los recibe (la tienda devuelve la lista vacía, sin error). Para probar compras hace falta TestFlight. Lo que sí es mejorable es el texto: con la lista vacía culpa a la conexión aunque no sea eso; un texto neutro («Ahora no podemos mostrar los precios. Inténtalo en un rato.») vale para los dos casos.
- **Dónde:** Yala/App/Services/StoreKitManager.swift (loadProducts) · Yala/App/Views/Subscription/ProPurchaseComponents.swift:224
- **Captura:** `capturas/175049.jpg`


## Reportes de Jürgen

### 17:13:40 — «Solo gastos»: el paso 1 tiene que hacerse de cero (decisión de Jürgen, 17:19)

- **Qué pasó:** Jürgen eligió «Solo gastos» y Primeros pasos arranca en 2 de 7, con «Cuenta» hecha. Debajo dice «Tus gastos van a «Gastos Soles», que Yala crea sola.». Jürgen pregunta: si el paso 1 ya está, ¿no debería verse ya la tarjeta de la cuenta, como pasa con «Ingresos y gastos» al terminar el paso 1?
- **Evidencia:** Captura 17:13:40: «Primeros pasos · 2 de 7», «Hechos: 1».
- **Causa probable:** Hecho a propósito (Panel progresivo, decisión del 19-nov): con «Solo gastos» la tarjeta de la cuenta y el saldo grande esperan a que se haga u omita el paso 2, «Aprender a registrar», para que al entrar solo se vea el mazo, igual que con «Ingresos y gastos». Resultado: el paso 1 dice «hecho» y su tarjeta no está. Si se quiere coherente, hay dos salidas: mostrar la cuenta ya, o no dar el paso 1 por hecho hasta registrar. Decisión de producto. DECISIÓN de Jürgen: se recula; con «Solo gastos» el paso 1 no sale hecho y la persona crea su cuenta de cero, como con «Ingresos y gastos». Toca: el alta (que hoy crea sola «Gastos Soles»), el paso 1 que la da por hecha, la línea «Tus gastos van a…» y la compuerta del Panel.
- **Dónde:** Yala/App/Logic/SetupDeckLogic.swift (PrimerosPasosPanelGate.make: showsAccounts = expensesOnly ? recordStepResolved : accountStepResolved)
- **Captura:** `capturas/171340.jpg`

### 17:22 — Idea: Primeros pasos centrado mientras se está en el paso 1

- **Qué pasó:** En la llegada, el Panel solo muestra el mazo de Primeros pasos, arriba, con el resto de la pantalla vacía. Jürgen propone centrarlo verticalmente; cree que se vería mejor.
- **Evidencia:** Capturas 17:13:40 (Solo gastos) y 17:20:18 (Gastos e ingresos): mazo arriba, dos tercios de pantalla vacíos.
- **Causa probable:** No es fallo: es diseño. Jürgen lo acota al paso 1: mientras no hay cuenta, el mazo es lo único del Panel y va centrado; al terminar el paso 1 aparecen más elementos y el mazo vuelve arriba. Con la decisión de las 17:19, esto vale igual para «Solo gastos». Va como mejora con 2 o 3 maquetas para que elija.
- **Dónde:** Yala/App/Views/Panel/PanelView.swift (setupDeckSlot, isQuietArrival)
- **Captura:** `capturas/171340.jpg`

### 17:29 — Las intros de los pasos solo responden como historias si tocas sobre el contenido

- **Qué pasó:** En «Antes de empezar» del paso 1: tocar a la izquierda no vuelve, a la derecha no avanza y mantener el dedo no pausa. Solo avanza sola cada ~3 s (visto 17:28:50 → 17:28:52 → 17:28:56).
- **Evidencia:** Probado con Device MCP a las 17:31 (con permiso de Jürgen), captura justo después de cada toque: sobre el contenido, derecha avanza (1→2) e izquierda vuelve (2→1); en la zona vacía de abajo (y≈620 pt), ni derecha avanza (se queda en 1) ni izquierda vuelve (se queda en 2). Mantener el dedo 6 s sobre el contenido sí pausa. Las rayitas de arriba también llevan a cada parte.
- **Causa probable:** Medido: la zona que escucha los toques es solo el bloque de contenido (título, texto y ejemplos), no la pantalla entera. En las tres partes ese bloque ocupa la mitad de arriba; la mitad de abajo, hasta el botón, no responde, y es justo donde cae el dedo. El arreglo sería que toda la zona entre las rayitas y el botón escuche (contentShape a pantalla completa, fuera del ScrollView o con el marco estirado). CRITERIO de Jürgen: toda la zona desde las rayitas hasta antes del botón responde al gesto (izquierda vuelve, derecha avanza, mantener pausa), en cualquier punto, haya contenido o no. Vale para todas las intros de los pasos y las historias del paso 7.
- **Dónde:** Yala/App/Views/Onboarding/PrimerosPasos/TutorialStoryPage.swift (onTapGesture + onLongPressGesture sobre content(part), dentro del ScrollView)
- **Captura:** `capturas/172852.jpg`

### 17:34:43 — La guía del primer registro se salta el paso 3, «Tu cuenta ya está puesta»

- **Qué pasó:** En «Aprender a registrar», la guía del formulario pasó de «2 de 5» (categoría) a «4 de 5» (nombre) sin mostrar el 3.
- **Evidencia:** Capturas 17:34:37 («2 de 5 · ¿En qué ha sido?») y 17:34:43 («4 de 5 · Un nombre, si quieres»). Store de Yala Dev copiado del iPhone (solo lectura) a las 17:40: la tabla de cuentas tiene 2 filas, «Ahorros» (PEN) y «Ahorros · USD», la segunda hija de la primera.
- **Causa probable:** Medido: la guía se salta el paso 3 si hay más de una cuenta, y el formulario cuenta TODAS las filas de cuenta sin filtro. Una cuenta con soles y dólares se guarda como dos filas (la principal y su hija por moneda), así que «Ahorros» cuenta como 2 y la guía cree que hay varias. Debería contar solo cuentas principales (sin cuenta madre), no archivadas y no de sistema. Revisar el mismo conteo en otros sitios que usen accounts.count.
- **Dónde:** Yala/App/Views/Transactions/NewTransactionView.swift:620 (hasSingleAccount: viewModel.accounts.count <= 1) · NewTransactionViewModel.loadData (FetchDescriptor<Account> sin filtro) · NewRecordTutorialGuide.step
- **Captura:** `capturas/173443.jpg`

### 17:38:35 — El aviso «Tus presupuestos viven en Más» apunta a una barra plegada: «Más» no se ve

- **Qué pasó:** Al volver al Panel tras crear el presupuesto, el aviso señala la pestaña «Más», pero la barra de abajo está encogida (solo el botón del Panel y la lupa). La flecha apunta a un hueco vacío.
- **Evidencia:** Captura 17:38:35: barra encogida, globo con flecha hacia donde estaría «Más».
- **Causa probable:** Medido en el código: la barra se encoge al desplazarse hacia abajo y solo se despliega al cambiar de pestaña. El aviso de lugar que apunta a una pestaña no la despliega. Criterio de Jürgen: mientras se ve un aviso que señala una pestaña, la barra va desplegada. Mismo caso: los avisos de Más tras el paso 4 (Pagos planificados) y el paso 6 (Estadísticas), y el de Grupos.
- **Dónde:** Yala/App/Tips/PlaceGuide.swift (target .moreTab) · Yala/App/Tips/PlaceGuideOverlay.swift · Yala/App/Views/Shared/TabBarArrivesExpandedModifier.swift (tabBarMinimizeBehavior)
- **Captura:** `capturas/173835.jpg`

### 17:44:23 — El pago planificado recién creado no aparece en el widget del Panel

- **Qué pasó:** Jürgen: todo el paso 4 bien, pero el widget de Pagos planificados del Panel NO muestra «Películas y series» (20 de diciembre). La ficha del widget dice «Sin pagos próximos» y «Pagos planificados de este mes: S/ 0.00». Jürgen confirma además que vio la intro y la parte 4 del paso: no hubo saltos ahí.
- **Evidencia:** Captura 17:44:23. Se repite tras cerrar sesión y volver a entrar (captura 17:52:03): el pago sigue sin salir.
- **Causa probable:** Medido en el código: el widget solo calcula fechas del mes en curso (paymentDatesInMonth con displayMonth = noviembre). Un pago cuyo primer vencimiento cae el mes que viene no entra en la lista ni en el total, y el widget pequeño, con total 0, muestra el vacío. Pasa siempre que alguien crea un pago después de su fecha de este mes. Arreglo: «próximos» debe incluir el siguiente vencimiento aunque caiga en otro mes (o mostrarlo en el vacío: «El próximo: 20 dic»). Jürgen: «puede ser confuso para el usuario que acaba de crear su pago y no lo ve». Opciones en la card: (1, recomendada) la lista de próximos enseña los siguientes vencimientos aunque sean del mes que viene, y el «este mes» sigue en S/ 0; (2) el vacío explica «Nada este mes. El próximo: Películas y series, 20 dic». Jürgen se inclina por la opción 1 («opción 1 creo»): la card va con la 1 y la sesión que la haga enseña capturas antes de cerrar.
- **Dónde:** Yala/App/ViewModels/PanelViewModel.swift (~3883: paymentDatesInMonth(month: displayMonth); upcomingPayments) · Yala/App/Views/Panel/ScheduledPaymentsWidget.swift:65 (vacío si monthlyTotal == 0)
- **Captura:** `capturas/174423.jpg`

### 17:48:29 — «Grupos ya lo conoces: lo viste al entrar» tras salir de la intro

- **Qué pasó:** Jürgen salió de la intro de Grupos y, al volver a tocar el paso, salió «Grupos ya lo conoces: lo viste al entrar. Seguimos con el paso 6.». No lo vio «al entrar»: lo acababa de ver desde Primeros pasos.
- **Evidencia:** Árbol de pantalla 17:48:25 («Primeros pasos · 6 de 7») y 17:48:29 (aviso). Jürgen confirma que salió él.
- **Causa probable:** Salir de la intro marca Grupos como visto y el paso 5 como omitido; al tocarlo de nuevo entra por «ya visto», lo da por hecho y usa un texto pensado para quien vio Grupos en la bienvenida. Arreglo: texto neutro («Grupos ya lo viste. Seguimos con el paso 6.») o reabrir la intro si viene de Primeros pasos.
- **Dónde:** Yala/App/Views/Panel/PanelView.swift (startGroupsStep) · PrimerosPasosPlanningPresentations.swift (afterGroups) · texto pasos23.groups.alreadySeen

### 17:48:35 — Paso 6: la guía de Estadísticas no señala nada y al terminar deja a la persona tirada en Más

- **Qué pasó:** Jürgen: «el chip de estadísticas no sentí que mostró nada» y «mira dónde me dejó, tirado». La guía «Paso 6 de 7 · Todas tus gráficas» oscurece toda la pantalla y su globo tapa Distribución y Planificación; las tarjetas de Estadísticas (Resumen, Tendencias, Distribución) se ven tan apagadas como el resto, sin foco. Además «Más» se abrió ya desplazado, sin el título «Estadísticas» a la vista. Tras «Entendido» se queda en Más, sin volver al Panel ni decir cuál es el paso 7.
- **Evidencia:** Capturas 17:48:35 (mal) y 17:56:33 (bien). En la buena, Más está arriba del todo, las tres tarjetas de Estadísticas salen enmarcadas y el globo queda encima. En la mala, Más venía desplazado de una visita anterior (17:44:51, Planificación), las tarjetas quedaban medio tapadas arriba, sin marco, y el globo caía en medio. Tras «Entendido» se queda en Más las dos veces (17:48:42 y 17:56:50).
- **Causa probable:** Medido comparando las dos pasadas: el foco falla cuando Más ya estaba desplazado. La guía abre la pestaña pero no la sube arriba, así que lo que debe enmarcar queda fuera de la vista y el globo se coloca en el centro. Arreglo: al abrir la guía del paso 6, subir Más arriba del todo antes de enmarcar; y al «Entendido», volver al Panel con el mazo en el paso 7 (sigue pendiente aunque el foco salga bien).
- **Dónde:** Yala/App/Views/Panel/PanelView.swift (startChartsStepGuide) · Yala/App/Tips/PlaceGuide.swift (chartsStep, moreItems insights/trends/categories) · PlaceGuideOverlay.swift
- **Captura:** `capturas/174835.jpg`

### 17:49:51 — Idea: la oferta Pro tras Primeros pasos debe anunciar el mes gratis y llamar más la atención

- **Qué pasó:** Jürgen: la tarjeta «Lleva tus finanzas al siguiente nivel · Desbloquea voz, resumen con IA y cuentas ilimitadas · Pasarme a Pro» es donde debería ir el gancho. Debería decir que hay un mes gratis, en el texto o en el botón, y ser más llamativa; quizá una ventana con confeti al terminar Primeros pasos.
- **Evidencia:** Captura 17:49:51 (tarjeta debajo de «¡Primeros pasos completos!»).
- **Causa probable:** Medido: las dos suscripciones de Pro tienen un mes gratis de prueba (configuración de StoreKit: oferta de introducción gratis, 1 mes) y la app ya sabe si la persona tiene derecho a ella. La tarjeta usa un texto genérico (proBanner.title) que no la nombra, aunque ya existen textos como «Prueba Yala Pro gratis 1 mes» y «Empezar prueba gratis». Propuesta: con derecho a prueba, título «Prueba Yala Pro gratis 1 mes» y botón «Empezar mes gratis»; sin derecho, el texto de hoy. La ventana con confeti es una decisión de diseño: 2 o 3 maquetas para que Jürgen elija.
- **Dónde:** Tarjeta de oferta Pro del Panel (proBanner.*) · StoreKitManager.isIntroOfferEligible
- **Captura:** `capturas/174951.jpg`

### 17:53:11 — La intro de Grupos vuelve a salir tras cerrar sesión, aunque ya se aceptó en Primeros pasos

- **Qué pasó:** Jürgen: «ya lo había aceptado, en los primeros pasos». Tras cerrar sesión y volver a entrar con la misma cuenta, «Nuevo grupo» le enseña otra vez toda la intro de Grupos.
- **Evidencia:** Capturas 17:48:14 (intro desde Primeros pasos) y 17:53:11 (la misma, desde Grupos). Contraste: a las 17:55:00, con la cuenta nueva de Google tras eliminar la de Apple, el paso 1 fue directo a las preguntas sin su intro «Antes de empezar»; esa marca sí sobrevivió. Dos intros que se guardan distinto.
- **Causa probable:** Deducido de lo que se vio: a las 17:48:29 la app dijo «Grupos ya lo conoces», así que la marca de «intro vista» estaba puesta. A las 17:53, tras cerrar sesión (17:51) y volver a entrar, ya no estaba: cerrar sesión borra esa marca, que vive solo en el dispositivo y no viaja con la cuenta. Arreglo: que la marca sobreviva a cerrar sesión o vaya con la cuenta (como las preferencias que se sincronizan).
- **Dónde:** Yala/App/Services/AppPreferences.swift:559 (hasShownGroupsOnboarding, synced: false) · limpieza de cerrar sesión (CloudSignOutFlowLogic / borrado de preferencias)
- **Captura:** `capturas/175311.jpg`

### 17:55:55 — «Ahora no» al final de Grupos en Primeros pasos deja el paso «para después»; debe contar como hecho

- **Qué pasó:** Jürgen: si en la última parte de Grupos («Tu primer grupo · ¿Qué quieres hacer?») elige «Ahora no», ya vio y aceptó la intro y siguió, así que el paso 5 debe quedar hecho, no «para después».
- **Evidencia:** Recorrido 17:55:51-17:55:57 (intro, «¿Qué quieres hacer?», vuelta al Panel).
- **Causa probable:** Hoy es a propósito: al salir con «Ahora no» el paso 5 se marca como omitido y solo se da por hecho cuando existe un grupo (para que un formulario cancelado no lo deje hecho). DECISIÓN de Jürgen: ver y aceptar la intro basta; «Ahora no» cuenta como hecho.
- **Dónde:** Yala/App/Logic/PrimerosPasosPlanningLogic.swift (GroupsTutorialLogic.advancesDeck / marksOnboardingSeen) · PrimerosPasosPlanningPresentations.swift (afterGroups: markSkipped(.groups))

## Cards creadas (tablero de Yala, versión 2.3)

- `tablero-primeros-pasos-solo-gastos-el-paso-1-se-9j3x` — Primeros pasos «Solo gastos»: el paso 1 se hace de cero, sin cuenta creada sola
- `tablero-intros-y-historias-de-primeros-pasos-el-nmjh` — Intros y historias de Primeros pasos: el gesto vale en toda la zona entre las barras y el botón
- `tablero-guia-del-primer-registro-se-salta-tu-cue-tug9` — Guía del primer registro se salta «Tu cuenta ya está puesta» con una cuenta de dos monedas
- `tablero-aviso-viven-en-mas-apunta-a-la-barra-de-yyen` — Aviso «viven en Más» apunta a la barra de pestañas plegada: mientras se ve, la barra va desplegada
- `tablero-widget-de-pagos-planificados-mostrar-el-6y6h` — Widget de Pagos planificados: mostrar el próximo vencimiento aunque caiga el mes que viene
- `tablero-paso-6-la-guia-de-graficas-no-enfoca-si-eg91` — Paso 6: la guía de gráficas no enfoca si Más viene desplazado, y al terminar deja a la persona en Más
- `tablero-paso-7-ver-todas-las-historias-hasta-ter-cyga` — Paso 7: ver todas las historias hasta «Terminar» no cuenta como hecho
- `tablero-grupos-en-primeros-pasos-ahora-no-tras-a-72s8` — Grupos en Primeros pasos: «Ahora no» tras aceptar la intro cuenta como hecho, y el aviso «lo viste al entrar»
- `tablero-la-intro-de-grupos-vuelve-a-salir-tras-c-2xfy` — La intro de Grupos vuelve a salir tras cerrar sesión aunque ya se aceptó
- `tablero-oferta-pro-tras-primeros-pasos-anunciar-dbwh` — Oferta Pro tras Primeros pasos: anunciar el mes gratis y hacerla más llamativa
- `tablero-primeros-pasos-centrado-en-la-pantalla-m-v9tl` — Primeros pasos centrado en la pantalla mientras se está en el paso 1
- `tablero-pulido-de-textos-de-primeros-pasos-y-del-s6y3` — Pulido de textos de Primeros pasos y del paywall visto en el iPhone 14

## Lotes propuestos (sin encolar)

### Lote 1 · Que cada paso de Primeros pasos cuente bien

Primero: son fallos de lógica que hacen mentir al mazo (pasos hechos que salen «para después» y al revés) y un pago que «desaparece». Tocan la lógica del mazo y el Panel, sin diseño nuevo.

- «Solo gastos»: el paso 1 se hace de cero
- Guía del primer registro se salta «Tu cuenta ya está puesta»
- Widget de Pagos planificados: el próximo aunque sea el mes que viene
- Paso 7: ver las historias hasta «Terminar» cuenta como hecho
- Grupos: «Ahora no» tras aceptar cuenta como hecho

### Lote 2 · Guías y avisos que señalan donde deben

Segundo: todo es la capa de guías (historias, avisos de lugar, foco del paso 6) y sus marcas de «ya visto». Se prueba en el mismo recorrido del iPhone.

- Gesto de historias en toda la zona
- Aviso «viven en Más» con la barra plegada
- Paso 6: foco con Más desplazado y vuelta al Panel
- Intro de Grupos que vuelve tras cerrar sesión
- Pulido de textos de Primeros pasos y del paywall

### Lote 3 · Diseño con maquetas (con Jürgen)

Tercero y aparte: piden 2-3 maquetas y su elección antes de construir. Es más chico que lo habitual a propósito: no conviene mezclar decisiones de diseño con arreglos.

- Oferta Pro: anunciar el mes gratis y llamar más
- Primeros pasos centrado mientras se está en el paso 1

Página viva: https://claude.ai/artifact/WURtsKhAZqZ83dhddeVmvi
