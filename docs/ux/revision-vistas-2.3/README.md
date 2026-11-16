# Revisión por vistas 2.3 · Índice

Índice de la revisión de UX por vistas de Yala 2.3: qué zonas se revisaron, dónde abrir cada una, sus problemas
principales y lo que queda por decidir. **No añade conclusiones propias**: los problemas y las recomendaciones salen de la
`ficha.md` de cada zona, que manda si algo no cuadra, y las decisiones ya tomadas salen de
`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md` (la discusión de Jürgen del 9-nov-2026). Ninguna zona
cambia la app; cada una deja problemas priorizados, alternativas maquetadas y una recomendación.

> **Índice actualizado el 14-nov-2026.** Las **11 zonas están revisadas**. Sus fichas entraron en `2.3` el 7-nov
> (Panel, Registros, Nuevo registro y las zonas 34 a 38) y el 9-nov (zonas 39, 40 y 41). Las decisiones que Jürgen tomó
> el 9-nov sobre esas revisiones ya están marcadas abajo como «Decidido»; el resumen final separa lo decidido de lo que
> sigue pendiente.

El reparto de zonas sale del mapa de cobertura fijo del 6-nov-2026 (`~/Claude/flota/cobertura-vistas-yala-2.3.md`, en la
Mini), hecho desde las vistas de `Yala/**/Views/` en `origin/2.3`.

**Cómo leer los códigos.** `PN-1`… son los problemas del Panel. En el resto de zonas, el número es el problema de la ficha
y la letra con número (`B1`, `F2`, `T1`…) es una de sus alternativas maquetadas. Cada decisión lleva su explicación al lado.

## Estado

| Zona | Estado | Abrir | Respaldo para el móvil |
|---|---|---|---|
| 30 · Panel | Revisada | [`30-panel/index.html`](30-panel/index.html) | [`revision-panel.pdf`](30-panel/revision-panel.pdf) |
| 31 · Registros, filtros, calendario y búsqueda | Revisada | [`31-registros/index.html`](31-registros/index.html) | [`revision-registros.pdf`](31-registros/revision-registros.pdf) |
| 32 · Nuevo registro, favoritos, voz y foto | Revisada | [`32-nuevo-registro/index.html`](32-nuevo-registro/index.html) | [`revision-nuevo-registro.pdf`](32-nuevo-registro/revision-nuevo-registro.pdf) |
| 34 · Planificación | Revisada | [`34-planificacion/index.html`](34-planificacion/index.html) | [`revision-planificacion.pdf`](34-planificacion/revision-planificacion.pdf) |
| 35 · Estadísticas | Revisada | [`35-estadisticas/index.html`](35-estadisticas/index.html) | [`revision-estadisticas.pdf`](35-estadisticas/revision-estadisticas.pdf) |
| 36 · Reportes y Flujo de caja | Revisada | [`36-reportes-flujo/index.html`](36-reportes-flujo/index.html) | [`revision-reportes-flujo.pdf`](36-reportes-flujo/revision-reportes-flujo.pdf) |
| 37 · Grupos en el uso diario | Revisada | [`37-grupos/index.html`](37-grupos/index.html) | [`revision-grupos.pdf`](37-grupos/revision-grupos.pdf) |
| 38 · Bandeja, Yala IA, correo del banco, Apple Pay y Siri | Revisada | [`38-bandeja-ia/index.html`](38-bandeja-ia/index.html) | [`revision-bandeja-ia.pdf`](38-bandeja-ia/revision-bandeja-ia.pdf) |
| 39 · Cuentas, tarjetas, categorías, etiquetas y divisas | Revisada | [`39-cuentas-categorias/index.html`](39-cuentas-categorias/index.html) | [`revision-cuentas-categorias.pdf`](39-cuentas-categorias/revision-cuentas-categorias.pdf) |
| 40 · Perfil, Más, Ajustes, Pro y ayuda | Revisada | [`40-perfil-ajustes/index.html`](40-perfil-ajustes/index.html) | [`revision-perfil-ajustes.pdf`](40-perfil-ajustes/revision-perfil-ajustes.pdf) |
| 41 · Dónde viven tus datos | Revisada | [`41-nube-almacenamiento/index.html`](41-nube-almacenamiento/index.html) | [`revision-nube-almacenamiento.pdf`](41-nube-almacenamiento/revision-nube-almacenamiento.pdf) |

Cada `index.html` enlaza sus páginas y lleva las capturas al lado, en `capturas/`. El PDF de cada zona trae lo mismo en un
solo archivo.

En cada lista de decisiones, tres etiquetas: **Decidido** (Jürgen ya eligió, con su número en `decisiones-discusion.md`),
**Va sin decisión** (la consolidación de noviembre lo clasificó como cambio necesario, o ya estaba en 2.2) y
**Pendiente** (nadie lo ha decidido).

---

## 30 · Panel

Ficha: [`30-panel/ficha.md`](30-panel/ficha.md).

**Vistas cubiertas.** PanelView, HeroMonthView, AccountsCarouselView, AccountCardView, FinancialScoreView, ScoreRingView,
TrendChartView, WidgetInfoChipView (hojas de ayuda) y PanelSectionsConfigView. Casos: mes típico, mes recién empezado,
montos ocultos, varias divisas, cargando, texto grande (AX3 y máximo) e iPad. 38 capturas del simulador con datos
ficticios. «Sin conexión» va documentado desde el código, sin verlo en pantalla.

**Problemas principales.**

| | Problema | Recomendada |
|---|---|---|
| PN-1 · alta | «Balance» (entró − salió) se lee como lo que tienes; el total de las cuentas no está a la vista | B: total en «Tus finanzas» |
| PN-2 · alta | La nota de salud da 99-100 con pocos datos y no ve un presupuesto pasado ni una cuenta en rojo | A + B: sin nota hasta tener datos, y decir lo que no ve |
| PN-6 · alta | Con texto grande la cifra principal es lo más pequeño de la pantalla; acciones y títulos cortados | A + B: la cifra escala y el hero se reordena |
| PN-3 · media | El día 1 del mes: nota 96, gráfica de un punto, −100 % | A + B: «Día 1 de 31» y ventana de 30 días |
| PN-4 · media | La gráfica exagera la caída; «+10.3 %» no dice contra qué, «PEN» y «x̄», eje «nov 24» = año | A + B: etiquetas claras, inicio y fin a la vista |
| PN-5 · media | Cuentas de una en una, sin total ni aviso de rojo; plegar oculta la nota; hueco en el iPad | C en iPhone + D en iPad |
| PN-7 · media | Con montos ocultos, la ayuda «?» de la gráfica dice el saldo exacto | A: la ayuda usa la máscara |
| PN-8 · baja | Configurar Panel: iconos sin texto, «Restablecer» sin aviso, dos sitios para lo mismo | A: botones con texto y confirmación |
| PN-9 · baja | Sin conexión la tasa cae a una tabla y el «≈» no lo dice (no validado en pantalla) | A: la conversión dice la fecha de la tasa |

**Decisiones para Jürgen.**

1. PN-1, ¿dónde vive «lo que tienes» y se renombra «Balance»? **Decidido** (decisión 8): opción C, con maqueta primero. La
   cifra grande pasa a «Tienes hoy»; debajo, el mes en curso en presente («Te queda S/ X»). «Balance» y «Disponible»
   desaparecen de la app; el detalle final se cierra con la maqueta en la mano.
2. PN-2, ¿cuántas partes hacen falta para enseñar una nota? **Decidido** (decisión 9): A con dos de tres partes, más B
   (una línea con lo que la nota no ve). Se descartan reabrir la escala (C) y los pesos (D).
3. PN-2, propuestas para mejorar la nota de salud (variables nuevas, cálculo, visibilidad). **Pendiente:** la sesión que lo
   implemente las propone y Jürgen las decide (decisión 9).
4. PN-6, ¿la cifra del hero escala con el texto y se reordena en tamaños de accesibilidad? **Va sin decisión:** la
   consolidación la clasificó como necesaria (lote P). Cambiar las píldoras (parte B) quedó fuera por ser de producto.
5. PN-3, el día 1 del mes. **Decidido** (decisión 10): se elige una opción nueva, E, y no la recomendada. El período manda
   siempre; los días 1 y 2 sale «Día N de 31 · Ver últimos 30 días · Ver <mes anterior>» y los porcentajes esperan al día 3.
6. PN-4, la gráfica de saldo. **Decidido** (decisión 11): A + B. El eje no arranca en cero (C descartada).
7. PN-5, las cuentas. **Decidido** (decisión 12): solo D, cuentas en cuadrícula en el iPad. No se tocan el carrusel del
   iPhone ni la salud al plegar.
8. PN-7, la ayuda «?» con montos ocultos. **Va sin decisión:** necesaria (lote P).
9. PN-9, sin conexión. **Decidido** (decisión 13): no va, se deja como está.
---

## 31 · Registros, filtros, calendario y búsqueda

Ficha: [`31-registros/ficha.md`](31-registros/ficha.md).

**Vistas cubiertas.** RecordsStandaloneView, RecordRowView, RecordDateSectionView, RecordsCalendarView, RecordsFiltersView
+ FilterChipView, GlobalSearchView, el menú contextual y la edición en lote, con texto grande (AX3) e iPad.
TransactionSnippetView (la respuesta de Siri) va reconstruida del código: Siri no se puede conducir en el simulador.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Buscar desaparece justo en Registros y no entiende importes | Alta | B1 · campo de búsqueda dentro de Registros, con importe |
| 2 | Filtrar por cuenta y categoría pide 7 toques, dentro de «···» | Alta | F2 · chips rápidos encima de la lista |
| 3 | Con la lista vacía, el filtro culpable queda fuera de pantalla | Alta | L1 · banda «Filtrando por…» con «Quitar todo» |
| 4 | En «Todo el tiempo», la lista no dice el año ni deja saltar a un mes (9 deslizamientos hasta hace 3 semanas) | Media-alta | T2 · separador de mes fijo que lleva a otro mes (+ T1, año y total del día) |
| 5 | «Seleccionar todo» marca 2.334 registros y el lote no se puede deshacer | Alta | E1 · «Deshacer» también en lote (+ el texto de E2) |
| 6 | Al tocar un día del calendario, lo que cambia queda fuera de la pantalla | Media | C2 · el calendario se pliega a la semana |

Lo barato, según la ficha: B3, F1 + F3, L3, T1 y E2 son cambios de texto o de sitio y no cierran la puerta a lo anterior.

**Decisiones para Jürgen.**

1. Buscar. **Decidido** (decisión 14): B1. Campo «Buscar en Registros» arriba de la lista, busca también por importe y
   respeta período y filtros. No se añade texto que explique la diferencia con la pestaña Buscar.
2. Filtrar. **Decidido** (decisión 15): F2 + F3. Chips rápidos sobre la lista (Cuenta, Categoría, Fecha, Más filtros) y una hoja
   de categorías con buscador, filas enteras tocables y resumen de lo elegido.
3. Lista vacía y filtros. **Decidido** (decisión 16): L1 integrada con F2 + L3, con «Quitar todo» y la X de 44 pt. Los filtros
   siguen siendo de la sesión: L4 no se elige.
4. Separador de mes y año. **Decidido** (decisión 17): T1 + T2. El año solo sale cuando el día no es del año actual.
5. ¿Registros sigue abriendo en «Todo el tiempo»? **Pendiente:** `decisiones-discusion.md` no lo menciona.
6. «Deshacer» en lote. **Decidido** (decisión 18): E1 + E2, con los textos que dicen cuánto es («Seleccionar los 2.334»).
   Pide medir cuánto cuesta guardar el «antes» de miles de registros y review adversarial, porque toca sync.
7. Calendario. **Decidido** (decisión 19): C2, el mes se pliega a la semana del día elegido. C3 (moneda en la celda) no, porque
   reabre lo decidido en 2.2.

Los hallazgos secundarios de Registros (decisiones 60 a 61, 66 a 67 y 73 a 79: VoiceOver, iPad, grafías, selector de lista
vacía, estado de carga) también van; no se repiten aquí.

---

## 32 · Nuevo registro: gasto, ingreso, transferencia, favoritos, voz y foto

Ficha: [`32-nuevo-registro/ficha.md`](32-nuevo-registro/ficha.md).

**Vistas cubiertas.** NewTransactionView, TransactionTypeSelectorView, TransferAmountInputView, TransactionSuccessView,
FavoritesListView + FavoriteRowView + FavoriteEditorView, VoiceRecordingView e ImageSelectionView (recibo), con texto
grande (AX3) e iPad. TransactionAmountInputView no tiene captura: no se usa en ninguna parte (código muerto). La pantalla
«Sin conexión» de voz y foto va reconstruida del código; la cámara no existe en el simulador.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Con el teclado abierto, lo que falta y «Guardar» quedan debajo: el café cuesta 6 toques + 4 teclas | Alta | G1 · barra sobre el teclado con lo que falta y «Guardar» |
| 2 | Para un café hay que adivinar la categoría: sin recientes al empezar y «café» no encuentra nada | Alta | C2 · las 3 categorías más usadas a la vista (+ C3, palabras en el buscador) |
| 3 | Con texto grande, la zona fija de «Guardar» se monta sobre el formulario; 2.2 ya lo arregló y 2.3 no lo tiene | Alta | Z2 · el botón dice lo que falta, sobre Z1 · traer el arreglo de 2.2 |
| 4 | El importe escrito en soles pasa a dólares al elegir la cuenta, sin aviso | Media-alta | M1 · decirlo con palabras (+ M4, la cuenta en soles primero) |
| 5 | Cuando voz o foto fallan, «a mano» empieza de cero; el muro de Pro promete «a mano» sin botón | Media-alta | V1 · «Apuntarlo a mano» trae lo entendido (+ V3, el botón del muro) |
| 6 | Transferencia entre monedas: dos importes sin nombre y las cuentas lejos | Media-alta | T1 · cada importe con su cuenta (+ T2, «¿cuánto llegó?») |
| 7 | Repetir un favorito no es «un toque»: rellena 12.00 y hay que borrarlo; solo vive en el formulario | Media | F1 · el importe del favorito viene seleccionado (+ F2, favoritos en el Panel) |

Lo barato, según la ficha: Z1, V3, F4, M1 y C3. La ficha avisa además de que `origin/2.3` no tiene seis arreglos de 2.2
que tocan esta zona; la revisión es de 2.3 tal como está.

**Decisiones para Jürgen.**

1. Barra sobre el teclado. **Decidido** (decisión 20): G1, que se construye después del merge de 2.2. ¿El formulario abre con
   el teclado en el importe? Sin respuesta: queda como está («No abrir»).
2. Categorías frecuentes. **Decidido** (decisión 21): C2 + C3. Fila con las 3 más usadas más «Más…»; las de arranque son
   Restaurantes, Supermercados y Taxis y apps. El buscador entiende «café», «uber», «menú» en los 16 idiomas.
3. ¿Cuándo se integra 2.2 en 2.3? **Decidido** (decisión 1): A, encolado. Termina la corrección de 2.2, TestFlight, merge de
   2.2 en 2.3, y después todo lo de esta discusión. Con eso llega el arreglo de la zona fija (Z1).
4. ¿El botón dice lo que falta (Z2, reabre L2-2)? **Pendiente.**
5. Aviso al cambiar de moneda (M1). **Va sin decisión:** necesaria (lote F). La hoja de cuentas con la moneda principal
   primero (M4) queda **pendiente**.
6. Botón «Apuntarlo a mano» en el muro de Pro (V3). **Va sin decisión:** necesaria (lote F). Que precargue lo entendido (V1)
   queda **pendiente**.
7. Transferencia con cada importe junto a su cuenta (T1 mínimo). **Va sin decisión:** necesaria (lote F). «¿Cuánto llegó?»
   (T2) queda **pendiente**.
8. Favoritos. **Decidido** (decisión 22): F1 + F4. El favorito abre con el importe seleccionado y el teclado abierto, y los
   textos dejan de prometer «un toque». Favoritos en el Panel (F2): no por ahora.

Los hallazgos secundarios de Nuevo registro (decisiones 62 a 65, 68 a 72 y 80 a 83: VoiceOver, texto grande, iPad,
favoritos, código muerto) también van; no se repiten aquí.

---

## 34 · Planificación: presupuestos y pagos planificados

Ficha: [`34-planificacion/ficha.md`](34-planificacion/ficha.md).

**Vistas cubiertas.** PlanningView, BudgetsListView + BudgetRowView, BudgetDetailView, BudgetEditorView, BudgetChartsView,
ScheduledPaymentsView + ScheduledPaymentsListView + ScheduledPaymentRowView, ScheduledPaymentDetailView y
ScheduledPaymentEditorView. Casos: al 30 %, 90 % y 118 %, mes cerrado, plan gratis, vacía, pagos vencidos, pagados y saltados,
calendario, texto grande (AX3) e iPad. El caso: «Comidas fuera» al 90 %, «Salidas con amigos» al 118 % y un Alquiler vencido
(datos ficticios). Sin conexión no cambia estas vistas (datos del teléfono); sin indicador de carga ni mensaje de error, que
van como hallazgos secundarios.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Al 90 % dice a la vez «Te quedan», «En el límite» y «Hoy te pasaste»; cinco piezas con cuatro umbrales | Alta | S1 · un estado, una palabra, un color |
| 2 | Al pasarse, la app anima pero no ayuda (ni en qué se fue ni cómo ajustar) | Alta | X2 · «Ver los gastos» y «Ajustar el límite» |
| 3 | Editar lo que cuenta un presupuesto: dos puertas, «Delivery +3» y 7 toques | Alta | E2 · cambiarlo desde el detalle (+ texto de E4) |
| 4 | Un pago vencido se confunde con los próximos; pagarlo pide 4 toques | Alta | V1 · sección «Vencidos» con «Ya lo pagué» |
| 5 | Apuntar un pago no se deshace, «Ya no está pagado» deja el gasto, saltar se anuncia como pagado | Alta | D1 + D2 + D3 |
| 6 | Calendario de pagos: cifras de 6-9 pt sin moneda, celdas mudas, día elegido fuera de vista | Media | C2 · se pliega a la semana (+ C4) |

Lo barato, según la ficha: S4, X4, E4, D3 y C4. **Bug encontrado, sin tocar:** tras «Saltar este mes», el detalle dice
«Noviembre de 2026 ya está pagado» (`ScheduledPaymentDetailView.swift:202-210` y `:251-258`).

**Decisiones para Jürgen.**

1. Umbrales únicos y estado del presupuesto. **Decidido** (decisión 23): S1 más el cupo diario como guía neutra. Un estado, una
   palabra, un color y los mismos umbrales en barra, palabra, sección e historial: 80 % «En el límite», 100 % exacto «Llegaste
   al límite», más de 100 % «Te pasaste». El cupo es una línea neutra, sin rosa ni alerta; con el mes agotado no sale.
2. ¿Botones «Ver los gastos» y «Ajustar el límite» al pasarse (X2)? ¿Un límite nuevo vale desde este mes o reescribe el
   historial? **Pendiente.**
3. ¿«Qué cuenta» se edita desde el detalle, guardando al cerrar con «Deshacer» (E2)? ¿Se quita «Subcategorías» de Filtros?
   **Pendiente.**
4. ¿Sección «Vencidos» propia, arriba, con «Ya lo pagué» en la fila (V1)? **Pendiente.**
5. Apuntar un pago. **Decidido** (decisión 24): D1 + D2. Aviso «Apuntaste S/ X en <cuenta> · Deshacer» que borra el registro
   creado, y «Ya no está pagado» pregunta si borrar el gasto, dejarlo suelto o cancelar. El texto «ya está pagado» tras
   saltar (D3) **va sin decisión**: necesaria (lote 4).
6. ¿Calendario que se pliega a la semana (C2)? **Pendiente** para Planificación. En Registros ya se decidió C2 (decisión 19).

---

## 35 · Estadísticas

Ficha: [`35-estadisticas/ficha.md`](35-estadisticas/ficha.md).

**Vistas cubiertas.** StatisticsView, DetailContainerView, InsightsTabView (Resumen), TrendsTabView (Tendencias),
PeriodComparisonChartView, CategoriesTabView (Distribución), SankeyChartView y RecordsTabView (Registros). Casos: este mes,
mes pasado, entrar a una categoría y volver, primera semana, vacío, diez años (11.696 registros), Free, texto grande (AX3) e
iPad Pro 13. 58 capturas del simulador con datos ficticios. VoiceOver medido en el árbol de accesibilidad, sin encenderlo.
«Sin conexión» y «error» solo afectan a la IA y van documentados desde el código.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | «¿En qué se me fue la plata?» no tiene respuesta en un sitio: abre en «Balance»; Distribución enseña «Saldo de cuentas»; el total frente a octubre está en Gráficas o al fondo | Alta | A1 · la cifra de Distribución es lo gastado y su comparación (+ A2, tarjeta en Resumen) |
| 2 | Tocar una categoría no la abre: pone «Solo X» + «Gasto»; la cifra no cambia; volver es una X de 19 pt | Alta | B1 · abre el detalle de la categoría y «atrás» vuelve |
| 3 | Con texto grande se cortan importes, la cuadrícula de Resumen y las pestañas | Alta | D1 + D2 · filas apiladas y cuadrícula a una columna |
| 4 | «Balance», «Saldo» y «Saldo de cuentas»: tres cifras distintas, nombres casi iguales; VoiceOver dice otro | Media-alta | C1 · un nombre por cifra que diga qué suma (con PN-1 del Panel) |
| 5 | VoiceOver lee las gráficas como recuentos («7 puntos»), sin valores | Media-alta | V1 + V2 · etiqueta con la conclusión y descripción de gráficas de iOS |
| 6 | Con una semana de datos afirma de más: «los jueves son tu día más caro», «N/A», «este Este mes» | Media | F2 (+ F1) · textos honestos y mínimo de datos por tarjeta |
| 7 | Con diez años, ~2 s congelada al entrar y al cambiar de pestaña; ejes en años ilegibles; Sankey a dos deslizamientos | Media | G1 (medir antes) + G2 · respuesta al toque y gráficas por mes/año |

Eficiencia, medido (Debug, simulador, semilla «pesado»): entrar a Estadísticas 509-516 ms con «Este mes» y 1.731-2.253 ms con
«Todo el tiempo»; cambiar a Tendencias tarda ~2 s. Lo demás son hipótesis leídas en el código, con la forma de medirlas.

**Decisiones para Jürgen.**

1. ¿La cifra grande de Distribución pasa a ser lo gastado con su comparación (A1)? ¿Tarjeta «En qué se fue tu dinero» en
   Resumen (A2)? **Pendiente.**
2. Tocar una categoría. **Decidido** (decisión 25): B1. Abre el detalle (gastado y comparación, subcategorías, últimos
   registros, «Ver en Registros»), «atrás» vuelve y no se toca ningún filtro. Reabre a propósito lo decidido el 25-26 de
   octubre. ¿La X de los filtros sube a 44 pt? **Pendiente:** no consta.
3. Texto grande: filas apiladas (D1) y «Tus cifras» a una columna (D2). **Va sin decisión:** necesaria (lote 5).
4. Nombres de las tres cifras. **Decidido** (decisión 8, la del Panel): vocabulario único en toda la app. «Tienes/Saldo» es lo
   de las cuentas, «Te queda» es entró − salió, y «Balance» y «Disponible» desaparecen.
5. VoiceOver. **Decidido** (decisión 26): V1 + V2 («lo que recomiendes»). Se valida con tests y el árbol de accesibilidad,
   no en el QA de Jürgen.
6. Pocos datos. **Decidido** (decisión 27): F2 + F1 + F4. El día de la semana espera 4 semanas de datos y dice cuándo estará;
   «Nueva» sustituye a «N/A»; «este Este mes» va en el lote 7.
7. Rendimiento con diez años. **Decidido** (decisión 28): G1 (medir antes con Instruments en el iPhone 14 de pruebas, Release)
   + G2 + G3. La pestaña responde al toque con esqueleto, las gráficas van por mes y año, y el Sankey del iPhone empieza en
   las categorías.
8. Decidido además (no estaba en la ficha como pregunta): la comparación de Tendencias cambiaba en silencio. **Decidido**
   (decisión 29): A, Tendencias lleva el mismo selector y todas las pestañas cortan hasta hoy.
9. Ancho en el iPad. **Decidido** (decisión 7): C, el ancho legible que ya existe (700 pt); dos columnas, más adelante.

---

## 36 · Reportes y Flujo de caja/proyectado

Ficha: [`36-reportes-flujo/ficha.md`](36-reportes-flujo/ficha.md).

**Vistas cubiertas.** FinancialReportView, PivotRowView, NetFlowSummaryView, CashFlowSetupView, CashFlowTableView,
CashFlowMonthDetailView (con sus hojas de línea y de Gráficas) y «Ver proyectado» en Tendencias, Panel y en los widgets Gasto
y Saldo, **después** de la mejora del flujo de caja. Casos: con datos, vacío, primera semana y Free; guías, desglose por
categoría y meses futuros; Solo gastos y montos ocultos; texto grande (AX3) e iPad Pro 13. «Sin conexión» y «error» van
documentados desde el código: la zona calcula en el teléfono y solo el chip «IA» de Gráficas usa la red.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | «¿Llego a fin de mes?» tiene cinco cifras distintas (S/ 69,390.71, 396.18, 86,771.48, 587.18 y 2,893.08); ninguna dice de qué es ni hasta cuándo | Alta | B (rótulos con métrica y fecha), y A cuando se reabra la cabecera del mes |
| 2 | Lo real y lo estimado se pintan igual y se nombran de siete formas; no hay «≈» en el flujo de caja | Alta | B + A (palabras fijas y barra de dos tonos) |
| 3 | El plan vive en Más › Reportes; armarlo pide revisar 18 líneas en 5 desplazamientos; los chips flotan sobre el contenido | Media-alta | A + D (resumen y «Crear» arriba, líneas plegadas; chips con fondo) |
| 4 | Leer un mes es recorrer 25 tarjetas iguales; la única que se pasó está en el puesto 20 | Media | A + C (agrupar por «te pasaste / falta / cubierto», y barras del mes) |
| 5 | Con AX3 desaparecen los nombres de fila de la Comparativa y se cortan los importes; «No-viem-bre» | Media | A + B (filas que se apilan; frases para VoiceOver) |
| 6 | La Comparativa dice «Noviembre» cuando compara el 1–7; mezcla «=+0%», «N/A», «−100%» | Media | A + B (tramo exacto; abrir desglosada por categoría) |
| 7 | En la primera semana el armado no tiene ingresos y dice «Te faltan al mes S/ 2,573» | Media | A (preguntar el ingreso que falta) |

Eficiencia, medido (Debug, simulador, semilla de 730 días con plan): abrir Flujo de caja 201-330 ms; el plan no es lento. Las
hipótesis leídas en el código (la Comparativa se recalcula con el plan a la vista; el detalle de una línea recorre todo el
historial varias veces) van con la forma de medirlas. **Fuera de esta revisión (cálculo):** sin plan, «Estimado con tu ritmo
de gasto» vuelve a contar el sueldo que ya entró; necesita su propia card con review adversarial.

**Decisiones para Jürgen.**

1. ¿Llego a fin de mes? **Decidido** (decisión 30): A, con maqueta junto a la del Panel. Una sola cifra, «Al 30 de noviembre
   tendrías S/ X», igual en el Panel y en el flujo de caja, con su cuenta (hoy · entra · sale). Reabre a propósito la
   cabecera del mes del lote 18 de 2.2.
2. Real y estimado. **Decidido** (decisión 31): A + B. Barra de dos tonos (gastado sólido, lo que falta rayado), «Real» y
   «Estimado» como únicas palabras y «Pago programado» pasa a «pago planificado». «≈» sigue significando solo «convertido».
3. ¿Resumen y «Crear mi plan» arriba con las líneas plegadas (A)? ¿Flujo de caja se muda a Planificación (C)? **Pendiente.**
4. ¿Líneas agrupadas por lo que piden (A) y las barras del mes (C)? **Pendiente.**
5. Texto grande: filas apiladas (A) y frases para VoiceOver (B). **Va sin decisión:** necesaria (lote 5).
6. Comparativa. **Decidido** (decisión 32): A + B. Rótulos con el tramo exacto («1–7 nov.» frente a «1–7 oct.»), «igual» y
   «nuevo» en vez de «=+0%» y «N/A», y abre desglosada por categoría.
7. Primera semana sin ingresos. **Decidido** (decisión 33): A, el armado pregunta «¿Cuánto recibes al mes?», con «Aún no lo
   sé».
8. ¿Se abre la card del ritmo que vuelve a contar el sueldo? **Pendiente:** no consta.
9. Decididas además (no estaban en la ficha como pregunta): Free ve el flujo de caja avanzado. **Decidido** (decisión 2): A,
   gratis a propósito; se borra el bloqueo que no actúa y sus textos de Pro. El widget. **Decidido** (decisión 34): A, el
   punteado con color propio y una cifra corta «Estimado S/ X al 31 dic». Gráficas. **Decidido** (decisión 35): A, el rótulo
   dice el período («En promedio, últimos 4 meses…»). Ancho en el iPad. **Decidido** (decisión 7): C, ancho legible.

---

## 37 · Grupos en el uso diario

Ficha: [`37-grupos/ficha.md`](37-grupos/ficha.md).

**Vistas cubiertas.** GroupsContainerView, GroupCardView, GroupDetailView, GroupRecordsView, GroupBalancesView,
GroupStatsView, GroupMembersView, GroupSettingsView, GroupsGlobalSettingsView, GroupFormView, GroupExpenseComposerView,
GroupExpenseFormView, GroupExpenseSuccessView, GroupSplitSelectorView, GroupTwoPersonSplitView, GroupReceiptSplitView,
MemberPickerView, SettlementFormView y GroupOpeningBalanceFormView. Caso de un viaje de 4 personas. 72 capturas del
simulador con datos ficticios, incluidas texto grande (AX3) e iPad; la cuarta persona se añadió a la semilla solo en local.
`GroupSplitSelectorView` no está en el camino de Grupos (solo lo usa el editor de pagos planificados). «Cargando», «error» y
«sin conexión» no se ven en el simulador: el detalle no tiene estado de error (un fallo se ve como «Sin gastos»), leído en el
código. Fuera de alcance: invitación, consentimiento y entrada a Grupos.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | «¿Cuánto debo y a quién?» tiene cuatro respuestas: «Tú no le debes nada a nadie» encima de «Tú pagas a Ana S/ 40.00»; «Debes S/ 0.00»; 7 pagos para 4 personas; «Beto paga a Tú» | Alta | A1 · «Menos pagos entre ustedes» encendido por defecto en grupos de 3+ (+ el texto de A4) |
| 2 | Partir desigual cuesta 11 toques; borrar y escribir 150 dejó «1,100.00»; se puede guardar un reparto que suma 399,99 | Alta | B2 · escribe solo lo distinto y el resto se reparte solo (+ B1) |
| 3 | Saldar: solo quien debe o cobra puede apuntarlo; pagar de más se acepta sin aviso; al guardar no se confirma nada | Media-alta | C2 + C3 · «Todo / Una parte» con lo que queda, y aviso con «Deshacer» |
| 4 | Con soles y dólares cada deuda son dos y las cruzadas no se compensan | Media-alta | D1 · chip «Todo en S/ ≈» en Saldos (+ D4) |
| 5 | Con texto grande se corta lo que hay que leer para decidir; VoiceOver lee el importe como «0.00» | Alta | E1 + E4 · filas con texto grande y etiquetas de VoiceOver (E2 ya, barato) |
| 6 | La X o deslizar tiran el gasto a medias sin preguntar; cambiar de grupo también | Media | F1 · preguntar antes de descartar (+ F3) |
| 7 | En el iPad el detalle se estira de lado a lado y el reparto se ve fila a fila con el teclado | Media | H1 + H3 · ancho legible y «Nuevo gasto» a tamaño de página |

Eficiencia, medido (Debug, simulador, semilla del viaje): abrir Grupos tarda 178 ms de mediana (150-346). Lo demás son
hipótesis leídas en el código, con la forma de medirlas; falta una semilla con un grupo grande.

**Decisiones para Jürgen.**

1. «Menos pagos entre ustedes». **Decidido** (decisión 36): A1, solo en grupos nuevos de 3+, con una línea al pie que dice que
   Yala juntó las deudas. Los grupos existentes no cambian. Las frases «no le debes nada a nadie» y «Beto paga a Tú» (A4) **van
   sin decisión**: necesarias (lote 6).
2. ¿Reparto «escribe solo lo distinto» (B2)? ¿Seleccionar el importe al tocarlo en toda la app (B1)? **Pendiente.** El
   «1,100.00» y el reparto que suma 399,99 **van sin decisión**: necesarios (lotes 1 y 2).
3. Saldar. **Decidido** (decisión 37): C1 + C2 + C3 («lo que recomiendes»). Cualquiera apunta cualquier pago y queda «Falta
   que <quien recibe> lo confirme» (reabre L13-1); «Todo» o «Una parte», con aviso si se paga de más; aviso con el saldo
   nuevo y «Deshacer». Toca datos compartidos: review adversarial.
4. Soles y dólares. **Decidido** (decisión 38): no va. Las monedas van siempre separadas, como en Splitwise; solo se juntan
   en el hero de la lista de Grupos.
5. Texto grande y VoiceOver (E1, E4). **Va sin decisión:** necesaria (lote 6). Que la cifra crezca con el texto (E3) queda
   **pendiente**, junto con PN-6 del Panel.
6. Descartar un gasto a medias. **Decidido** (decisión 39): F1 + F3. Pregunta antes de descartar, también en «Apuntar pago» y
   «Saldo inicial»; cambiar de grupo conserva lo escrito.
7. iPad. **Decidido** (decisión 7): ancho legible (H1). Gastos y Saldos lado a lado (H2), más adelante. «Nuevo gasto» a
   tamaño de página (H3): **pendiente**, no consta.
8. Vocabulario de saldar y nombres del puente (L13-5 y L13-14 de 2.2). **Decidido** (decisión 40): «Saldos» (pantalla),
   «Saldar» (acción y botón), «Pago» (lo registrado) y un solo nombre para el puente, «Reflejar en tus cuentas».
9. Decidido además (no estaba en la ficha como pregunta): apagar «deudas en una moneda» no cambia la moneda del grupo.
   **Decidido** (decisión 3): A, la moneda se conserva.

---

## 38 · Bandeja, Yala IA, correo del banco, Apple Pay y Siri

Ficha: [`38-bandeja-ia/ficha.md`](38-bandeja-ia/ficha.md).

**Vistas cubiertas.** InboxView, InboxDraftRowView, InboxApproveSuccessView, InboxBulkApproveSuccessView,
GroupDraftLinkCandidatesView, ChatSheetView, ChatAttachmentsView, BankEmailForwardingView, ApplePayAutomationGuideView y
SiriShortcutsView. Caso de Lucía: 8 borradores (uno dudoso y uno de grupo), una pregunta a Yala IA y configurar el correo del
banco y Apple Pay; también sin conexión y sin Pro. 57 capturas del simulador con datos ficticios, incluidas texto grande (AX3)
e iPad. Siri por voz y Apple Pay real no se conducen en el simulador: se revisan sus pantallas y sus borradores. El modo
avión de verdad sigue el mismo camino según el código, sin medir en un iPhone.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Lo que se apunta solo vive en tres sitios; con iCloud la fila del correo no existe; ninguna pantalla dice si funciona | Alta | A2 · una pantalla «Lo que se apunta solo» con el estado de cada entrada (+ A4) |
| 2 | Revisar 8: la selección lleva a «Editar» que guarda, deslizar a la derecha guarda sin pista, y el dudoso y la cena quedan mezclados por fecha | Alta | B1 · «Necesitan algo» arriba y «Listos» con su botón; «Deshacer» en vez de la alerta (+ B4) |
| 3 | El dudoso enseña «55 %» sin explicar; «Posible duplicado» sale tras 4 pasos y no dice cuál; el lote y deslizar guardan sin mirar duplicados | Alta | C1 · nombrar el posible duplicado, con «Es el mismo / Es otro» (+ C3, el lote no lo guarda) |
| 4 | El gasto de grupo pide «Elige la cuenta» y «Finalizar» cuando la respuesta es «¿Ya lo apuntaste?» | Media-alta | D1 · la pregunta primero, con el reparto en una línea |
| 5 | Yala IA sin servidor dice «no disponible… en unos minutos» y apaga la caja; sin Pro y sin conexión, muro sin precios y botón apagado | Media-alta | F1 · decir «sin conexión» al abrir y ofrecer apuntar a mano (+ F3) |
| 6 | Correo del banco: cinco pasos y nunca se sabe si funcionó; sin conexión todo apagado | Media-alta | E1 · estado vivo «Funcionando / Aún no llega» (+ E4) |
| 7 | Con texto grande se parten los botones que deciden; el pie de las guías tapa ¼ de pantalla; «Bandeja de En…» | Media | G1 · apilar las barras de botones (+ G2 y G3, baratos) |

Eficiencia, medido (Debug, simulador, 8-10 borradores): abrir la Bandeja tarda 162 ms de mediana (155-589); las cuatro lentas
son la primera tras arrancar. Hipótesis leídas en el código: cada pintado recorre la lista unas diez veces y la lista lee como
mucho los 500 borradores más recientes. **Hallazgo secundario de severidad alta:** la pantalla de Siri dice «Requiere Yala Pro»
aunque «Anota un gasto en Yala» funciona sin Pro en el teléfono con el modelo de Apple listo (`SiriShortcutsView.swift:106,121`
frente a `SiriOnDeviceEntry.swift:30-33`).

**Decisiones para Jürgen.**

1. ¿Una pantalla «Lo que se apunta solo» en Ajustes (A2) o conectar desde la Bandeja (A1)? ¿Apple Pay sale de Tutoriales? ¿Con
   iCloud la fila del correo se enseña explicando por qué? ¿Se pinta ya el último aviso del banco? **Pendiente.**
2. Revisar 8. **Decidido** (decisión 41): B1 + B4. «Necesitan algo» arriba y «Listos» con «Guardar los 6» en su cabecera;
   «Editar» de la selección pasa a «Acciones» y «Finalizar» a «Guardar»; «Deshacer» en vez de la alerta del lote y deslizar
   con pista visible.
3. ¿Se busca el duplicado al llegar el borrador y se nombra (C1)? **Pendiente.** Que el lote y deslizar no guarden
   posibles duplicados (C3) **va sin decisión**: necesario (lote 3). ¿Se guarda el texto del aviso del banco (C2)?
   **Pendiente:** la decisión 44 descarta guardar los correos sin leer porque rompería la promesa de no guardar el texto,
   pero no nombra C2.
4. ¿La hoja del gasto de grupo abre con «¿Ya lo apuntaste?» (D1)? **Pendiente.** «Finalizar» pasa a «Guardar»: **Decidido**
   (decisión 41, B4).
5. Yala IA sin conexión. **Decidido** (decisión 42): F1 + F3. Sin conexión, el chat lo dice al abrir y ofrece apuntar a mano.
   Sin Pro y sin conexión, el muro ofrece lo gratis (apuntar a mano; Siri en teléfonos con modelo propio).
6. ¿Estado vivo del correo (E1) y fila visible con iCloud (E4)? ¿Elegir banco primero (E2)? **Pendiente.** Avisos que
   «llegaron sin leerse» al pasar a Pro: **Decidido** (decisión 44): A. El texto dice «3 correos llegaron con la prueba agotada
   y no se leyeron. Con Pro se leen los próximos».
7. Texto grande: G1 + G2 + G3. **Va sin decisión:** necesaria (lote 5). «Bandeja de Entrada» pasa a «Bandeja». **Decidido**
   (decisión 43): en toda la app y en los 16 idiomas. ¿Qué patrón tiene la Bandeja en el iPad (hoy, hoja centrada de ~400 pt)?
   **Pendiente.**
8. ¿Se corrige ya «Requiere Yala Pro» en la pantalla de Siri para teléfonos con el modelo de Apple? **Pendiente:** no consta.

---

## 39 · Cuentas, tarjetas, categorías, etiquetas y divisas

Ficha: [`39-cuentas-categorias/ficha.md`](39-cuentas-categorias/ficha.md).

**Vistas cubiertas.** AccountFormView, AdjustmentModeSelectorView (solo en el modo «Solo anotar mis gastos»; leída en el
código), AccountsSettingsListView, CategoriesSettingsListView, CategoryDetailView, SubcategoryDetailView,
SubcategoryNeedSelectorView, TagsSettingsListView, TagFormView y CurrencySettingsView. Caso de Lucía: ajustar el saldo de una
cuenta, archivar una Visa vieja sin perder lo gastado, ordenar y renombrar categorías, crear una etiqueta y añadir el euro.
Capturas del simulador con las semillas de la app: vacío, con datos, editar, crear, eliminar, archivar, cambiar de moneda,
texto grande (AX3) e iPad. «Sin conexión» no se pudo poner en el simulador: lo de tipos de cambio se documenta desde el código.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Archivar una tarjeta aparta también lo que se gastó con ella (y su deuda deja de restar); el interruptor está al fondo de cinco pantallas | Alta | A1 · hacer ya la opción A del 8-oct (archivar conserva el historial), con botón y hoja, avisando si la tarjeta aún debe |
| 2 | Las categorías no se pueden ordenar; Ajustes (A-Z) y el selector al registrar no coinciden | Alta | B1 · «Reordenar» como en Cuentas, y ese orden manda al registrar; «Ingresos» aparte |
| 8 | Con texto grande (AX3), Cuentas pierde los nombres de las cuentas y Etiquetas su última fila | Alta | H1 + H2 · la fila se apila y las listas miden solas su alto |
| 3 | Crear una categoría pide una subcategoría solo tras tocar Guardar: 12 toques y una alerta | Media-alta | C1 · nombre y subcategorías en la misma pantalla, con «Sin dividir» |
| 4 | Al ajustar el saldo, el teclado tapa «¿Cómo lo corregimos?» y la opción preelegida puede reescribir todos los meses | Media | D2 · «Listo» en el teclado y «registro de ajuste» siempre preelegido (+ D4) |
| 5 | Con número de cuenta, la lista enseña el número (casi completo) en vez del nombre | Media-alta | E1 · rediseño de la lista aprobado el 3-oct (nombre y «•••• 0019») (+ E2) |
| 6 | «Monedas secundarias» parece tocar las cuentas, viene con USD y EUR elegidas y solo caben dos | Media | F1 · «Tipos de cambio que sigues» (+ F3, no tapar la pantalla) |
| 7 | «No lo uses al registrar» se dice de cuatro formas; Etiquetas enseña «#5E5CE6», corta a 20 sin avisar y su X no pregunta | Media | G1 · «Usar al registrar» en Etiquetas y subcategorías (+ G3) |

Eficiencia, medido (Debug, simulador): abrir Ajustes › Cuentas tarda 32 ms sin registros, 113 ms con dos años y 447 ms con
diez. Crece con los registros porque la lista los lee todos para calcular saldos, en el hilo principal. **Lo que ya estaba
decidido** (según la ficha): archivar conserva el historial (8-oct, opción A), la lista de Cuentas con el nombre y el número
enmascarado y la ficha corta del formulario (3-oct).

**Decisiones para Jürgen.**

1. Archivar. **Decidido** (decisión 6): A, se adelanta de 2.4 a 2.3 como lote propio. Archivar saca del saldo y del carrusel
   y conserva el historial; cálculo financiero, con review adversarial. ¿Avisar si la tarjeta aún debe? ¿Deslizar en la
   lista como atajo (A2)? **Pendiente:** no constan.
2. ¿Categorías gana «Reordenar» y ese orden manda en selector, filtros e informes (B1)? ¿«Ingresos» en su sección? ¿Fila
   «Frecuentes»? **Pendiente** el orden. La fila de frecuentes ya es **Decidido** (decisión 21, zona 32).
3. ¿Nueva categoría con sus subcategorías en una pantalla (C1), con «Sin dividir»? **Pendiente.**
4. Ajustar el saldo. **Decidido** (decisión 5): D2. «Registro de ajuste» siempre preelegido (las dos opciones siguen), teclado
   con «Listo» y «Al guardar, queda en…» junto al botón. D4 (un solo nombre para el saldo de partida) no se pidió.
5. Número de cuenta. **Decidido** (decisión 4): se elimina el campo, no el rediseño E1 de la ficha. Desaparece del formulario y
   de la lista, los números guardados se borran en el teléfono y en las dos nubes, y la nube de Yala deja de emitirlos. Toca
   sync: review adversarial.
6. Monedas secundarias. **Decidido** en parte (decisión 46): B. USD y EUR dejan de venir elegidas; sin secundarias, la pantalla
   y el widget enseñan las monedas de tus cuentas. «Tipos de cambio que sigues» (F1) y no tapar la pantalla (F3): **Pendiente**,
   no constan.
7. «Usar al registrar». **Decidido** (decisión 45): G1 + G3. «Usar al registrar» en Categorías, Subcategorías y Etiquetas;
   Cuentas mantiene «Archivar». Etiquetas: color con nombre, aviso cerca de 20 caracteres y la X pregunta si hay cambios.
8. Texto grande (H1, H2). **Va sin decisión:** necesaria (lote 5); lo de los nombres de Cuentas ya estaba en 2.2.
9. Decidido además (no estaba en la ficha como pregunta): ancho en el iPad. **Decidido** (decisión 7): C, ancho legible.

---

## 40 · Perfil, Más, Ajustes generales, Pro y ayuda

Ficha: [`40-perfil-ajustes/ficha.md`](40-perfil-ajustes/ficha.md).

**Vistas cubiertas.** ProfileView, PersonalDetailsView, YalaAccountView, MoreView, PersonalizationSettingsView,
ThemeSettingsView, AppIconSettingsView, TabBarConfigView, NotificationsSettingsView, PermissionsSettingsView,
SmartInsightsSettingsView, AIPrivacySettingsView, BudgetsFavoritesSettingsView, UsageModeSettingsView,
FaceIDProtectionGuideView, SubscriptionView + SubscriptionSuccessView, FAQView, TutorialsListView + TutorialDetailView +
TutorialCompletionView, ExportRecordsView, GroupsExportView y UserDataResetView. Caso de Andrea: cinco ajustes de los que se
cambian una vez, entender qué le da Pro antes de pagar, exportar gastos a su contador y escribir a soporte. Capturas del
simulador: gratis, Pro anual, Pro en prueba, sin precios, comprado, con cuenta de Yala, Solo grupos, sin registros, texto
grande (AX3) e iPad. Sin capturar, documentado desde el código: Notificaciones con el permiso denegado, la hoja de exportar de
Solo grupos y «Escríbenos» sin una cuenta en Mail.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Ajustes son 31 filas en siete bloques y cuatro pantallas, sin buscador; solo uno de los cinco ajustes del caso se hace en menos de tres toques | Alta | A2 · reordenar por intención con el valor a la vista; A1 (buscador) después |
| 2 | «Presupuestos» de Ajustes no abre tus presupuestos, «Pagos planificados» cierra Ajustes y salta de pestaña, y «Favoritos» se cruza con los presupuestos favoritos | Alta | B1 · cada fila con el nombre de lo que abre; lo del Panel, a Configurar Panel |
| 3 | Yala Pro enseña primero el precio; «Qué incluye» está dos pantallas abajo y el límite gratis solo se le dice a quien ya paga | Alta | C1 · tabla «Gratis o Pro» antes de los precios (+ C4) |
| 4 | Exportar abre en «Todo» (2.342 registros), sin «Mes pasado» y sin filtro de gastos o ingresos; sin registros, la fila sale gris sin decir por qué | Media-alta | D1 · «Mes pasado» y «Qué registros» a la vista (+ D4) |
| 5 | La ayuda vive al fondo (cuarta pantalla), las 15 preguntas no se buscan ni llevan al sitio, y «Escríbenos» depende de la app Mail | Media | E1 · una sola «Ayuda» arriba con buscador y «Escríbenos» fijo (+ E2) |
| 6 | «Cómo usas Yala» (Completo / Solo grupos) y «Modo de uso» (Solo gastos) son dos cosas casi homónimas en dos sitios | Media | F1 · «Solo gastos» se muda a «Cómo usas Yala» como interruptor |
| 7 | Con texto grande (AX3), los títulos de Ajustes se parten por sílabas, los iconos no crecen y la lista pasa de 4 a 8 pantallas | Media | G1 · sin icono con texto de accesibilidad (+ G3) |

Eficiencia, medido (Debug, simulador): abrir Ajustes desde el Panel tarda 130 ms sin registros, 345 ms con dos años y ~1.020 ms
con diez. **Lo que ya estaba decidido** (según la ficha, de la auditoría 2.2): el nombre «Ajustes» del avatar, «Quitar mis datos
de este dispositivo» al final, Vaciar datos con su frase, la fila de Pro con su estado y «Hacerlo ahora» en los tutoriales.

**Decisiones para Jürgen.**

1. ¿Se reordena Ajustes por intención (A2)? ¿Tema, Idioma y Formato de cantidades salen de Personalización a su fila?
   ¿Buscador (A1) ahora o después? **Pendiente.**
2. Filas que no abren lo que dicen. **Decidido** (decisión 47): B1. «Presupuestos» pasa a «Presupuestos en el Panel» dentro de
   Configurar Panel, «Pagos planificados» sale de Ajustes y «Favoritos» pasa a «Registros favoritos».
3. ¿Tabla «Gratis o Pro» antes de los precios (C1)? ¿Tu plan en una tarjeta arriba de Ajustes (C4)? **Pendiente.**
4. ¿«Mes pasado» y «Qué registros» en Exportar (D1)? ¿Las transferencias cuentan en «Solo gastos»? **Pendiente.** El motivo de la
   fila apagada (D4) **va sin decisión**: necesario (lote 10).
5. ¿Una «Ayuda» arriba con buscador (E1)? ¿«Ir a…» en las respuestas (E2)? **Pendiente.** Probar antes «Escríbenos» en el
   iPhone 14 sin cuenta de Mail (E3).
6. «Cómo usas Yala» y «Modo de uso». **Decidido** (decisión 48): F1. «Solo gastos» se muda a «Cómo usas Yala» como interruptor
   bajo «Yala completo», con su aviso; Personalización deja de tener «Modo de uso».
7. Texto grande. Los títulos de una palabra (G3) **van sin decisión**: necesarios (lote 5). ¿Filas sin icono con texto de
   accesibilidad (G1)? **Pendiente.**
8. Rendimiento de Ajustes. **Decidido** (decisión 50): A. La medición se suma a la card «La app se traba en Perfil (App Hang)»,
   y se puede medir en la misma sesión que Estadísticas.
9. Decidido además: las dos filas sobre dónde están los datos se resuelven con la zona 41. **Decidido** (decisión 49, con
   la decisión 54): una fila «Tus datos».

---

## 41 · Dónde viven tus datos: nube, iCloud y cierre de sesión

Ficha: [`41-nube-almacenamiento/ficha.md`](41-nube-almacenamiento/ficha.md).

**Vistas cubiertas.** StorageSettingsView (con la hoja «Antes de activar la nube»), iCloudSyncSettingsView, CloudConsentView,
CloudProgressStepsView, StorageSignInChooserView, StorageMigrationBlockedView, ReturnToFullYalaView, SignOutRelaunchView y
GroupBatchLeaveView. CloudSyncDebugView queda fuera: solo existe en Yala Dev. Es una revisión de comprensión (textos,
jerarquía y pasos), con el caso de Lucía: 1.537 registros en su iCloud, activar la nube para el iPad del trabajo, volver a
iCloud y quitar sus datos del iPhone que va a vender. Capturas del simulador con las semillas y ganchos de la app; ningún
botón que mueve datos se pulsó contra una cuenta real. Sin captura, leídos del código: la tarjeta de «reabre Yala», la espera
de otro dispositivo, iCloud al día o con fallo, y la nube sin conexión.

**Problemas principales.**

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Nueve nombres y seis verbos para dos sitios; «cuenta de Yala» es a la vez la de Grupos y la de los datos | Alta | T1 · dos nombres fijos, «En tu iCloud» y «En tu cuenta de Yala», con «Pasar a» / «Volver a» |
| 2 | Al activar la nube, «no hay cifrado de extremo a extremo» y «tus fotos de recibos no viajan» quedan plegados en «Ver los detalles» | Alta | H1 · los tres puntos a la vista, una línea cada uno, con la cifra de fotos |
| 3 | Volver a iCloud promete «sin perder nada» y «en pausa por si vuelves», pero volver a la nube con esa cuenta no se puede | Alta | V2 · una hoja con fases (qué pasa, qué hacer con lo que ya hay, confirmar) |
| 7 | Con iCloud apagado, un estado dice que se sincroniza por iCloud y otro que no; dos filas para la misma pregunta | Media-alta | S1 · una fila «Tus datos» con el estado real (y S2 ya, por separado) |
| 4 | «Desasociar» es el botón más llamativo, encima de la acción; los bloqueos mandan a buscarlo sin enlace | Media-alta | G1 · la cuenta en una fila con «Cambiar de cuenta», y el bloqueo ofrece esa salida |
| 5 | 43 textos de fallo (hasta 394 caracteres) con un solo botón, «Reintentar» | Media | E1 · qué pasó · dónde están tus datos · qué hacer, con su botón |
| 6 | La subida no dice cuánto falta; «Ya casi está» dice «Sesión cerrada» tras «Quitar mis datos» | Media | R1 · cifras con unidad y plazo; «Ya casi está» que dice lo hecho y dónde quedan |
| 8 | Con texto grande, el estado se aprieta en media columna y el pie fijo de la hoja de activar ocupa casi la mitad | Media | X1 · estado apilado y botones dentro del desplazamiento |

Eficiencia, medido (Debug, simulador): en reposo la app gasta 6,5 % de CPU con Ajustes abierto y 8,4 % con «Dónde viven tus
datos»; la pantalla suma poco, y el consumo en reposo es de otra zona, por medir en Release. **Lo que ya estaba decidido**
(según la ficha): L20-11, L20-17, la opción B del 22-oct, L20-18, el paso 10 y L19-15.

**Decisiones para Jürgen.** Las marcadas **(datos)** tocan seguridad o pérdida de datos y van también a la tarjeta del tablero
«Decidir: cinco puntos de datos de la revisión de la nube».

1. **(datos)** Estado con iCloud apagado. **Decidido** (decisión 54): S2 ya, como arreglo propio y primero («Solo en este
   iPhone · iCloud no está activo», con botón a Ajustes), y S1, una fila «Tus datos» con sitio y estado real.
2. **(datos)** Cifrado y fotos. **Decidido** (decisión 52): H1. La hoja de Ajustes enseña los tres puntos a la vista, con la
   cifra de fotos y «Exportar una copia antes»; «Ver los detalles» se va. Un solo consentimiento para todas las entradas (H2):
   no se elige, la bienvenida no cambia.
3. **(datos)** Volver a iCloud. **Decidido** (decisión 53): V2, una hoja con fases que retira «en pausa por si vuelves» y dice
   que volver a la nube con esa cuenta hoy no se puede. Poder volver a la nube con la misma cuenta (V4) va a su propia card:
   **Pendiente.**
4. **(datos)** Cuenta y «Cambiar de cuenta». **Decidido** (decisión 55): G1. La cuenta en una fila bajo el estado y el bloqueo
   ofrece esa salida, que abre la hoja de consecuencias y no se salta nunca. Adelantar G3: **Pendiente**, no consta.
5. **(datos)** «Activar sin borrar» cancela un borrado de iCloud pedido. **Decidido** (decisión 57): A. Hoja con fases que dice
   que el borrado no terminó, con tres opciones: conservar los datos de iCloud, terminar de borrarlos primero, o ahora no.
6. Nombres. **Decidido** (decisión 51): T1, con la bienvenida. Dos nombres fijos, «En tu iCloud» y «En tu cuenta de Yala»;
   ~60 textos en 16 idiomas.
7. ¿Plantilla de tres partes con el botón que arregla (E1), o solo el segundo botón (E2) por ahora? **Pendiente.**
8. Subida y «Ya casi está». **Decidido** (decisión 56): R1. «650 de 1.537 registros · quedan unos minutos»; «Ya casi está» dice
   lo que hizo la persona y dónde quedan sus datos. El aviso al salir a mitad (R2): no por ahora.
9. Texto grande: estado apilado y botones dentro del desplazamiento (X1). **Va sin decisión:** necesaria (lote 11).
10. Decididas además (no estaban en la ficha como pregunta): «Sí, cancelar» no dice qué cancela. **Decidido** (decisión 58): A,
    botones que nombran el resultado. «Desasociar» sin explicar la diferencia. **Decidido** (decisión 59): A, cada opción con su
    consecuencia bajo el botón; el texto final espera a verificar en el código qué hace cada opción con los gastos pagados.

---

## Resumen de decisiones

Los números son los de la tabla de `docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`. Los códigos `B1`, `F2`…
son alternativas de cada ficha. **Va sin decisión** (cambios necesarios de la consolidación) no se repite aquí.

### Lo que Jürgen ya decidió (9-nov-2026)

**Transversales**
- Decisión 1 · Cuándo entra 2.2 en 2.3 (A, encolado): termina la corrección de 2.2, TestFlight, merge de 2.2 en 2.3 y, después, todo lo de esta discusión.
- Decisión 7 · Ancho en el iPad en Estadísticas, Reportes, Grupos y Cuentas (C): ancho legible de 700 pt ahora; dos columnas más adelante, vista por vista.

**30 · Panel**
- Decisión 8 · PN-1 «Balance» se lee como lo que tienes (C, con maqueta primero): cifra grande «Tienes hoy», debajo «Te queda S/ X» y vocabulario único en toda la app.
- Decisión 9 · PN-2 nota de salud (A con dos de tres partes + B): sin nota hasta tener datos y una línea con lo que la nota no ve.
- Decisión 10 · PN-3 día 1 del mes (E, nueva): el período manda; días 1 y 2 con atajos y porcentajes desde el día 3.
- Decisión 11 · PN-4 gráfica de saldo (A + B): dice contra qué compara, inicio → hoy; el eje no arranca en cero.
- Decisión 12 · PN-5 cuentas (solo D): cuadrícula en el iPad.
- Decisión 13 · PN-9 sin conexión (no va): se deja como está.

**31 · Registros**
- Decisión 14 · Buscar (B1): campo dentro de Registros, también por importe.
- Decisión 15 · Filtrar (F2 + F3): chips rápidos y hoja de categorías con buscador.
- Decisión 16 · Lista vacía (L1 + F2 + L3): banda «Quitar todo»; los filtros siguen siendo de la sesión.
- Decisión 17 · «Todo el tiempo» (T1 + T2): separador de mes fijo y año en la cabecera del día.
- Decisión 18 · «Seleccionar todo» (E1 + E2): «Deshacer» en lote y textos que dicen cuánto es.
- Decisión 19 · Calendario (C2): el mes se pliega a la semana del día elegido.
- Decisiones 60 a 79 · hallazgos secundarios de Registros (VoiceOver, iPad, grafías, carga).

**32 · Nuevo registro**
- Decisión 20 · Teclado (G1): barra con lo que falta y «Guardar», después del merge de 2.2.
- Decisión 21 · Categoría del café (C2 + C3): 3 categorías frecuentes y buscador con palabras del día a día.
- Decisión 22 · Favoritos (F1 + F4): importe seleccionado y teclado abierto; textos sin «un toque».
- Decisiones 62 a 72 y 80 a 83 · hallazgos secundarios de Nuevo registro.

**34 · Planificación**
- Decisión 23 · Estado del presupuesto (S1 + cupo diario neutro): un estado, una palabra, un color, umbrales 80 % y 100 %.
- Decisión 24 · Apuntar un pago (D1 + D2): «Deshacer» y «Ya no está pagado» pregunta qué hacer con el gasto.

**35 · Estadísticas**
- Decisión 25 · Tocar una categoría (B1): abre su detalle y no filtra.
- Decisión 26 · VoiceOver en las gráficas (V1 + V2): etiqueta con cifras y descripción de gráficas de iOS.
- Decisión 27 · Pocos datos (F2 + F1 + F4): textos honestos y 4 semanas para el día de la semana.
- Decisión 28 · Diez años de datos (G1 + G2 + G3): medir antes, esqueleto y gráficas por mes y año.
- Decisión 29 · Comparación en Tendencias (A): mismo selector y corte hasta hoy.
- Decisión 8 · Tres nombres para tres cifras: vocabulario único («Tienes», «Te queda»).

**36 · Reportes y Flujo de caja**
- Decisión 30 · «¿Llego a fin de mes?» (A, con maqueta): una sola cifra «Al 30 de noviembre tendrías S/ X».
- Decisión 31 · Real y estimado (A + B): barra de dos tonos y palabras fijas.
- Decisión 32 · Comparativa (A + B): tramo exacto y abierta por categoría.
- Decisión 33 · Primera semana sin ingresos (A): el armado pregunta cuánto recibes.
- Decisión 2 · Free ve el flujo de caja avanzado (A): gratis a propósito.
- Decisión 34 · Widget (A): punteado con color propio y «Estimado S/ X al 31 dic».
- Decisión 35 · Gráficas (A): el rótulo dice el período.

**37 · Grupos**
- Decisión 36 · «Menos pagos» (A1): encendido en grupos nuevos de 3+.
- Decisión 37 · Saldar (C1 + C2 + C3): cualquiera apunta, «Todo / Una parte» y aviso con «Deshacer».
- Decisión 38 · Soles y dólares (no va): las monedas van siempre separadas.
- Decisión 39 · Descartar a medias (F1 + F3): pregunta antes; conserva lo escrito al cambiar de grupo.
- Decisión 40 · Vocabulario de saldar y del puente: «Saldos», «Saldar», «Pago» y «Reflejar en tus cuentas».
- Decisión 3 · Apagar «deudas en una moneda» (A): la moneda del grupo se conserva.

**38 · Bandeja e IA**
- Decisión 41 · Revisar 8 (B1 + B4): «Necesitan algo» y «Listos», «Guardar», «Deshacer» y deslizar con pista.
- Decisión 42 · Yala IA sin conexión (F1 + F3): lo dice al abrir y ofrece apuntar a mano.
- Decisión 43 · Un solo nombre, «Bandeja», en toda la app.
- Decisión 44 · Correos «sin leerse» al pasar a Pro (A): el texto lo dice; no se guardan.

**39 · Cuentas y categorías**
- Decisión 6 · Archivar conserva el historial (A): se adelanta a 2.3.
- Decisión 5 · Ajustar el saldo (D2): «registro de ajuste» siempre preelegido, teclado con «Listo».
- Decisión 4 · Número de cuenta: se elimina el campo y se borran los guardados.
- Decisión 45 · «Usar al registrar» (G1 + G3): un solo texto y arreglos de Etiquetas.
- Decisión 46 · USD y EUR elegidas sin pedirlo (B): se enseñan las monedas de tus cuentas.

**40 · Perfil y Ajustes**
- Decisión 47 · Filas que no abren lo que dicen (B1): «Presupuestos en el Panel», «Registros favoritos».
- Decisión 48 · «Cómo usas Yala» y «Modo de uso» (F1): «Solo gastos» pasa a ser un interruptor.
- Decisión 50 · Ajustes tarda ~1 s con diez años (A): se suma a la card de «App Hang».
- Decisión 49 · Dos filas sobre dónde están los datos: se resuelve con la zona 41 (decisión 54).

**41 · Dónde viven tus datos**
- Decisión 51 · Nombres (T1): «En tu iCloud» y «En tu cuenta de Yala», con la bienvenida.
- Decisión 52 · Cifrado y fotos (H1): a la vista en la hoja.
- Decisión 53 · Volver a iCloud (V2): hoja con fases; V4 a su card.
- Decisión 54 · Estado con iCloud apagado (S2 + S1): arreglo propio y una fila «Tus datos».
- Decisión 55 · «Desasociar» (G1): la cuenta en una fila con «Cambiar de cuenta».
- Decisión 56 · Subida y «Ya casi está» (R1): cifras con plazo y lo hecho.
- Decisión 57 · «Activar sin borrar» (A): hoja con fases.
- Decisión 58 · «Sí, cancelar» (A): botones que nombran el resultado.
- Decisión 59 · «Desasociar», las dos opciones (A): cada una con su consecuencia.

### Lo que sigue pendiente

- **30 · Panel:** propuestas para mejorar la nota de salud (las trae la sesión que la implemente).
- **31 · Registros:** si Registros sigue abriendo en «Todo el tiempo».
- **32 · Nuevo registro:** Z2 (el botón dice lo que falta), M4 (cuenta en soles primero), V1 (precargar lo entendido) y T2 («¿cuánto llegó?»).
- **34 · Planificación:** X2 (botones al pasarse), E2 (editar qué cuenta desde el detalle), V1 (sección «Vencidos») y C2 (calendario plegado a la semana).
- **35 · Estadísticas:** A1 + A2 (qué responde «¿En qué se me fue?») y la X de los filtros a 44 pt.
- **36 · Reportes y Flujo:** plan arriba y su ubicación (problema 3), líneas agrupadas y barras del mes (problema 4), y la card del ritmo que recuenta el sueldo.
- **37 · Grupos:** B2 («escribe solo lo distinto»), B1 (seleccionar el importe al tocarlo), E3 (la cifra crece con el texto) y H3 («Nuevo gasto» a tamaño de página en el iPad).
- **38 · Bandeja e IA:** A1/A2 (pantalla «Lo que se apunta solo»), C1 (nombrar el duplicado), C2 (guardar el texto del aviso), D1 (hoja de grupo con «¿Ya lo apuntaste?»), E1/E2/E4 (estado vivo del correo), patrón de la Bandeja en el iPad y «Requiere Yala Pro» en Siri.
- **39 · Cuentas y categorías:** aviso de deuda y deslizar al archivar, B1 (reordenar categorías), C1 (crear categoría en una pantalla), F1 y F3 (tipos de cambio que sigues, sin tapar la pantalla).
- **40 · Perfil y Ajustes:** A2 (reordenar por intención), C1 y C4 (tabla «Gratis o Pro»), D1 (exportar «Mes pasado»), E1/E2 (ayuda con buscador) y G1 (filas sin icono).
- **41 · Dónde viven tus datos:** V4 (volver a la nube con la misma cuenta, en su card), G3 y E1/E2 (textos de fallo con su botón).

**Fuera de la serie, a propósito** (según el mapa): Onboarding y alta (Welcome, invitación, consentimiento de Grupos,
entrada a Grupos), que cubre la guía visual del usuario nuevo; los componentes compartidos se miran dentro de la zona que
los usa; SplashScreenView y WidgetNoDataInviteView entran en Panel solo si salen en su caso. El mapa no tiene zona 33.
