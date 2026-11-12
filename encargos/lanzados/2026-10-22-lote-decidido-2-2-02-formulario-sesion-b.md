# Lote decidido 2.2 · 02 · Formulario de registro · SESIÓN B (textos y visual, 14 cards)

Esta sesión hace **solo la Sesión B** del brief de abajo (las 14 cards de «Sesión B · textos y visual»). La Sesión A ya está hecha y **mergeada en 2.2 (PR #600)**: la fila de favoritos, la línea viva sobre «Guardar» y el aviso tras guardar ya existen en origin/2.2; píntalos, no los rehagas. No toques las cards de la Sesión A. Rama: `encargo/…-sesion-b`, PR contra **2.2**.

---

# Auditoría UX 2.2 · decidido por Jürgen · 02 · El formulario de registro (apuntar a mano)

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1. Antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

> El número 02 coincide con `lote-decidido-2-2-02-alineacion-visual-grupos-y-flujo-de-caja.md`. Son lotes distintos: este es el **lote 2 de la auditoría** (el formulario).

## Contexto
Es la pantalla más usada de Yala y un hito de 2.2 (ROADMAP: «La auditoría UX cerrada, incluido el formulario de registro»). Jürgen eligió la opción de cada card el 14-oct. El 21-oct (sesión «decidir-lote-2-2-02-formulario-registro») se cerraron los detalles que esas opciones dejaban abiertos, y entraron tres cards de backlog que tocan el mismo código. La decisión completa y el «hecha cuando» de cada card están en su **nota** («Decisión final 21-oct…»). Mandan sobre este brief si algo difiere.

Fuentes:
- La card: la nota es la decisión y el contexto trae el problema.
- El informe del lote: `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-2-apuntar-a-mano/informe.md`, con opciones A/B/C, y sus maquetas en `capturas/*PROPUESTA*`. La maqueta de L2-15 trae un texto falso («te avisamos antes»); manda la nota.
- `docs/ux/mapa-de-flujos-2.2.md` § Lote 2 (ficheros y entradas).
- Los «Criterios UX/UI permanentes de Jürgen» de `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md`: sin degradados, sin glow, el glass se queda pero se jerarquiza, y adaptar sin transformar.

## Dos sesiones, en serie (no en paralelo)
Las dos tocan `NewTransactionView.swift` y `NewTransactionViewModel.swift`. Lanzar **A primero** y **B cuando A esté mergeada**, porque B pinta componentes que crea A (la fila de favoritos, la línea viva, el aviso tras guardar). Si van a la vez, chocan en cada hunk.

### Sesión A · flujo y datos (11 cards)
- **L2-1** · `tablero-ux-2-2-l2-1-la-cuenta-nunca-viene-puesta-g856`: la cuenta viene puesta (filtro de una → última usada si cabe en el filtro → la única → vacía).
- **L2-2** · `tablero-ux-2-2-l2-2-guardar-apagado-no-dice-que-v6bp`: línea viva sobre «Guardar» con lo que falta y borde en los chips que faltan. La guía ya está corregida.
- **L2-4** · `tablero-ux-2-2-l2-4-deslizar-hacia-abajo-cierra-opg0`: con datos, el gesto no cierra y la X pregunta «¿Descartar este registro?».
- **L2-5** · `tablero-ux-2-2-l2-5-una-pantalla-entera-de-listo-o7ae`: «¡Listo!» completo solo con menos de 3 registros. Después, el formulario se cierra y sale un aviso de 5 s con Editar · Deshacer.
- **L2-6** · `tablero-ux-2-2-l2-6-con-una-sola-cuenta-la-trans-w4de`: «Para pasar dinero necesitas otra cuenta» y «Crear otra cuenta», que vuelve con el destino puesto.
- **L2-7** · `tablero-ux-2-2-l2-7-elegir-ayer-cuesta-tres-toqu-k48q`: Hoy / Ayer / Anteayer, un toque cierra la hoja, y la nota del gris con enlace a Pagos planificados en hoja encima.
- **L2-13** · `tablero-ux-2-2-l2-13-favoritos-la-misma-estrella-torr`: se llaman «Favoritos», hay una fila de chips arriba que rellena con un toque y desaparece la ★ de la barra.
- **L2-14** · `tablero-ux-2-2-l2-14-un-favorito-guardado-desde-ax7s`: el favorito de transferencia guarda origen y destino. **Cambio de esquema** (ver avisos).
- **L2-15** · `tablero-ux-2-2-l2-15-recurrente-abre-un-formular-2fy8`: hoja corta «Hacer recurrente» con semana, mes y año más «Más opciones…»; se arregla el día de la semana que se quedaba en lunes.
- **Favorito/recurrente en dólares** · `tablero-desde-un-movimiento-en-dolares-de-una-cu-4k2q`: guardan la divisa del importe, sin convertir.
- **Cuentas filtradas** · `tablero-con-varias-cuentas-filtradas-el-panel-cu-uipg`: la precarga sale de la regla de L2-1 y el subtítulo del panorama cuenta lo que suma.

### Sesión B · textos y visual (14 cards)
- **L2-3** · `tablero-ux-2-2-l2-3-subcategoria-en-el-chip-cate-9711`: «Categoría» donde se elige y buscador por nombre y grupo, sin tildes.
- **L2-8** · `tablero-ux-2-2-l2-8-usa-cuenta-categoria-etiquet-qgfc`: el ejemplo en el campo y una pista llana que rota entre ! # @ y desaparece tras 6 aperturas o al usar un atajo.
- **L2-9** · `tablero-ux-2-2-l2-9-necesidad-discrecionales-nat-cjyz`: completar los ejemplos y la línea del para qué, con las mismas keys que L11-6.
- **L2-10** · `tablero-ux-2-2-l2-10-las-etiquetas-quedan-fuera-u1bg`: chips en dos filas y etiqueta nueva solo con el nombre.
- **L2-11** · `tablero-ux-2-2-l2-11-al-apuntar-en-dolares-no-ve-3kas`: equivalencia y «Tipo de cambio de hoy» editable también al crear.
- **L2-12** · `tablero-ux-2-2-l2-12-calcular-no-dice-que-calcul-x65w`: «Mi parte», Iguales la 1.ª vez y luego recuerda el modo, y un chip con el total.
- **L2-16** · `tablero-ui-2-2-l2-16-el-monto-no-dice-que-es-ni-voeo`: placeholder gris, símbolo siempre y la pregunta según el tipo.
- **L2-17** · `tablero-ui-2-2-l2-17-calcular-mi-parte-da-un-num-q9qh`: «Te toca pagar», la fórmula y la barra de reparto.
- **L2-18** · `tablero-ui-2-2-l2-18-el-tipo-de-cambio-se-puede-hf2w`: cápsula con lápiz, respeta símbolo o código y sin ceros de relleno.
- **L2-19** · `tablero-ui-2-2-l2-19-lo-que-eliges-solo-cambia-d-k5yy`: lo elegido va relleno, en chips y en filas de hojas.
- **L2-20** · `tablero-ui-2-2-l2-20-todo-pesa-igual-calcular-fa-d5b6`: un color por acción y «Guardar» relleno de acento al estar listo.
- **L2-21** · `tablero-ui-2-2-l2-21-elegir-no-se-siente-el-chip-4ues`: rebote y relleno animado; «Guardar» crece con vibración ligera. Respeta «Reducir movimiento».
- **L2-22** · `tablero-ui-2-2-l2-22-las-hojas-a-media-altura-de-pefr`: material grueso en las hojas a media altura.
- **Orden de etiquetas** · `tablero-las-etiquetas-de-un-registro-cambian-de-z3by`: orden estable en TagDisplayResolver.

## Avisos
- **Sin brillo ni glow en ningún sitio** (Jürgen, L2-19/20/21). Las maquetas de L2-20 y L2-21 llevan brillo: no se copia.
- **Cambio de esquema (L2-14):** `FavoritePayment` necesita la cuenta destino. Va en la ventana de cambio de esquema de 2.2, la de las tarjetas (ROADMAP hito 3). Prueba la migración con un store que ya tenga favoritos. El despliegue a CloudKit Production es de Jürgen: crea una card asignada a `jurgen` con los pasos y no lo despliegues tú. Ojo con `Cloudkit Schemas/yala_dev-*.ckdb` del árbol principal (ver Reglas).
- **Reutiliza lo que ya existe**, medido el 21-oct:
  - `LastUsedAccountStore` (la última cuenta, L2-1).
  - `transactionsSavedCount` (contador, L2-5).
  - `DraftDiscardUndoNotice` (aviso con Deshacer, L2-5).
  - `lastSplitType` (L2-12).
  - `Tag.nextAvailableColor` (L2-10).
  - `AppPreferences.currencyDisplayFormat` (símbolo o código, L2-11 y L2-18).
  - `SelectorSheetSizing` (L2-22).
- **L2-11 se apoya en la tarjeta multidivisa, entrega 3** (PR #549, en QA). No la rehagas.
- **L2-15:** un pago planificado no crea registros. Deja un borrador en la Bandeja y avisa el día. El texto de la hoja dice exactamente eso.
- **L2-5:** el aviso tras guardar se ve sobre la pantalla de origen. Pruébalo desde Panel, Registros y Estadísticas.

## Cómo mover las cards
- Al empezar cada una: `tablero mover <id> --a "in progress" --agente frank`. `--nota` en `tablero editar` reemplaza la nota entera: copia la que ya está (decisión del 14-oct y la del 21-oct) y añade debajo lo tuyo.
- Al cerrar, las que queden hechas y mergeadas sin nada que probar en el teléfono van a `done` (`--agente frank`). Las que pidan iPhone (vibración de L2-21, aviso de L2-5) van a `in qa`, asignadas a `jurgen`, con un guion corto en la nota.
- Todo ticket nuevo lleva su card.

## La UI sigue la decisión al pie de la letra
- Implementa exactamente lo que dice la nota de cada card. No inventes UI ni «mejores» la opción elegida. Lo que la decisión no fija y el sistema de diseño ya resuelve (márgenes, tipografía, componentes) se toma de lo que ya hay en la app.
- Si al implementar aparece algo de verdad sin decidir (dos caminos que cambian lo que ve el usuario y ninguno sale de la decisión), NO elijas tú. Deja 2–3 propuestas con capturas y tu recomendación en la nota de esa card, muévela a «espera decisión» asignada a `jurgen` con `--pregunta` y sigue con las demás. Solo se para ese ítem.
- Todo texto nuevo o cambiado va en los **16 idiomas**, y `/l10n-check` tiene que salir limpio.

## Reglas
- **Sin esperar el CI de ningún PR** (tampoco el tuyo): `git fetch origin && git rebase origin/2.2` justo antes de abrir el PR.
- Pipeline serial en la Mini:
  - Limpia y compila con `xcodebuild -jobs 2`, sin simulador encendido.
  - Enciende 1 simulador, corre los tests y apágalo. Un simulador a la vez.
  - Mira `df -h /` antes de compilar.
  - Usa los simuladores iOS 27.0, y al cerrar apaga y borra (erase) el que usaste.
- Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.
- En `~/Yala` (árbol principal) no toques, commitees ni descartes `Cloudkit Schemas/yala_dev-*.ckdb`, `Yala.xcscheme` ni `encargos/pendientes/`.
- Nada de salud ni de clínicas. No toques tmux `salud--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*` ni otros `Yala--` vivos.
- Nada de despliegues a producción: ni CloudKit Production, ni Worker o gateway, ni Supabase, ni web. Si algo hace falta, déjalo listo con los pasos en una card a `jurgen` y sigue.
- **Review adversarial** en la sesión A, sobre el Deshacer de L2-5 (borra un registro y mueve saldos) y la migración de L2-14. En la sesión B no hace falta: es copy y visual.
- Prueba la sesión tú mismo con **/barrido-qa** en el simulador: tests de lo que cambie, flujos tocados de punta a punta y VoiceOver en lo nuevo. Hay cambio visible, así que van capturas de antes y después en `capturas/` del worktree, copiadas también a `~/Claude/entregas/<sesión>/capturas/`, con sus rutas en el resumen de cierre.
- Cierra solo con **/cerrar-total** (merge incluido). No esperes a nadie.

## Cómo se sabe que está bien
- Cada card hecha tal como dice su nota. Si algo no estaba decidido, sus propuestas quedan en la card a `jurgen` y solo ese ítem se para.
- Textos en los 16 idiomas.
- Tests en verde (`/gate`, `YalaTests`) y /barrido-qa pasado.
- Capturas de antes y después.
- Cards movidas.
- PR mergeado en 2.2, que explica en lenguaje de usuario qué verá la persona.
- En la sesión A, además: la migración de favoritos probada y la card de despliegue de esquema creada para `jurgen`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR. Lo que la nota de cada
> card fija no se repite aquí: aquí va solo lo que la nota deja abierto y yo cerré.

**D1 · L2-3, ¿qué claves pasan a «Categoría»?** → Las de los sitios donde se elige un solo nivel: `transaction.subcategory`
(chip, hoja, edición masiva, favoritos, gasto de grupo, Bandeja), `validation.selectSubcategory`, `scheduled.editor.subcategory`,
`scheduled.select.subcategory`, las de asignar de la Bandeja, las del borrador del chat, `groups.bridge.assignFromInbox`,
`records.l8.changeSubcategoryTitle`, `bulkEdit.cannotEditTransferSubcategory` y el criterio de duplicados (va con la misma
clave del chip). Se cambia el VALOR en los 16 idiomas, no la clave. Siguen con «Subcategoría»: exportación, agrupar
informes, filtros de búsqueda, Ajustes › Categorías, widgets y tutoriales (dos niveles, o no es una pantalla de elegir).
Por qué: es la regla de la nota. Alternativa descartada: claves nuevas por sitio (duplica sin ganar nada).

**D2 · L2-3, texto del buscador** → `.searchable` nativo con el «Buscar» que ya existe. Por qué: la maqueta decía
«comida, taxi, luz…» y «comida» no encuentra nada sin sinónimos (la nota los deja fuera): el ejemplo prometería algo falso.

**D3 · L2-8, qué cuenta como «una apertura» y «usar un atajo»** → Una apertura = un formulario nuevo que aparece
(no al volver de una hoja encima, no al editar un registro guardado). Usar un atajo = elegir una sugerencia de ! # @.
El contador vive en `UserDefaults` y se borra con «Vaciar datos» como los demás contadores.

**D4 · L2-9, «discrecionales» y «naturaleza»** → Las dos palabras salen de toda pantalla en los 16 idiomas: los textos
de necesidad (`need.*.desc`, las mismas claves que usa L11-6) y los cuatro que aún decían «naturaleza» (selector de
icono, filtro bloqueado de Tendencias, filtro de presupuesto y tutoriales) pasan a «necesidad».

**D5 · L2-10, nombre repetido de una etiqueta ARCHIVADA** → Se elige y se reactiva. Por qué: la persona la pide; ponerle
una etiqueta oculta al registro la dejaría invisible en Ajustes. Alternativa descartada: crear un duplicado.

**D6 · L2-11, la fecha de la tasa** → Si el registro no es de hoy, «del 19 oct» es la fecha del registro: el converter
busca la tasa de ese día (con sus escalones). Y la tasa editada a mano SE USA al guardar: el importe convertido sale de
monto × tasa, marcado exacto. Sin tocarla, el guardado sigue convirtiendo como hoy. Por qué: una tasa editable que no se
guarda sería un control falso. Alternativa descartada: enseñarla editable y seguir convirtiendo con la del servicio.

**D7 · L2-11 y L2-18, un solo componente** → `ExchangeRateCapsule`, cápsula con lápiz que al tocarla se edita en sitio.
En un gasto en otra divisa el rótulo va DENTRO, como dice la nota («Tipo de cambio de hoy: 1 US$ = S/ 3.55 ✎», o «del 19
oct»); en la transferencia va encima («Tipo de cambio de hoy · tócalo si tu banco usó otro», como la maqueta). En
transferencias de otro día el rótulo dice la fecha, no «de hoy».

**D8 · L2-17, la barra** → Tú frente a los demás con los montos de la nota; sin porcentaje (la maqueta lo traía, la nota no).

**D9 · L2-19, contraste AA** → El relleno elegido es el color de la cuenta/categoría/necesidad/etiqueta oscurecido lo justo
para que el blanco encima dé ≥ 4,5:1 (helper puro con test). Las etiquetas, con su propio color.

**D10 · L2-20, qué colores** → Tres tokens nuevos en el sistema de diseño con el tono de la maqueta y blanco encima
≥ 4,5:1: «Mi parte» turquesa, «Favorito» naranja, «Recurrente» violeta. «Guardar» listo: el acento del tema, sin el 50 %
de opacidad que le ponía el formulario.

**D11 · L2-22, las cuatro hojas** → `SelectorSheetSizing` da `.thickMaterial` a media altura; la hoja de necesidad pasa a
usar `SelectorSheetSizing` (antes iba con su propio detent).

**D12 · Capturas con un conductor XCUITest que no se commitea** (`ZZCapturasSesionBConductor`), antes y después, claro y
oscuro. iPhone SE y 17 Pro Max para el XCUITest de L2-10: se crean en iOS 27.0 para la corrida y se borran al cerrar.

**D13 · «Guardar» fuera del scroll** → Sin teclado, el botón y la línea de lo que falta van en un `safeAreaInset`
inferior; con el teclado puesto vuelven dentro del scroll, como siempre.
Por qué: con lo que añade esta sesión (pregunta, pista, equivalencia, chips en dos filas) un gasto en dólares con
favoritos dejaba «Guardar» bajo el borde del 17 Pro y su toque se perdía (lo cazó `QuickActionsFavoritesUITests`). Es
la regla de `swiftui-ds.md` para botones de salida; cuando todo cabe se ve igual. Medido y descartado: fijo también con
teclado tapa los chips de cuenta y categoría justo después de escribir el monto (con fondo, ni se pueden tocar).

**D14 · Poco alto (iPhone SE)** → Con el formulario por debajo de 650 pt de alto (sin contar el teclado), el aire entre bloques del
formulario baja de `xxl` a `md`. Por qué: la card L2-10 pide «Etiquetas» a la vista sin deslizar también en el SE, y con
la pregunta del monto, la pista y la segunda fila de chips la segunda fila quedaba bajo el borde. En un iPhone normal no
cambia nada. Alternativa descartada: quitar o encoger algo de lo decidido.

## Resultado (2026-10-23, Frank)

Las 14 cards hechas como dice su nota; ninguna quedó sin decidir. L2-21 va a QA de Jürgen (vibración y pulso en el
iPhone); las otras 13, a done con el PR en cola de auto-merge.

- Gate: `Yala` y `Yala Dev` compilan sin avisos nuevos en lo tocado (ninguna expresión del formulario pasa de 200 ms de
  tipado); `YalaTests` entero, 11.257 tests en verde; XCUITest del formulario en verde (34 casos, centinela 0), y
  `TransactionFormDecided02BUITests` también en iPhone SE y 17 Pro Max.
- Capturas antes/después (Liquid Glass, Claro, Oscuro, código de moneda, SE, Pro Max) y GIF del movimiento con y sin
  «Reducir movimiento»: `~/Claude/entregas/Yala-2026-10-22-lote-decidido-2-2-02-formulario-sesion-b/`.
- Encontrado y no tocado: escribiendo en el campo nuevo de la hoja de etiquetas, XCUITest a veces no ve la app en reposo
  («App animations complete notification not received», 2 de 5 corridas, el caso pasa igual). Ticket
  `tag-sheet-new-name-field-never-idles-in-xcuitest`.
