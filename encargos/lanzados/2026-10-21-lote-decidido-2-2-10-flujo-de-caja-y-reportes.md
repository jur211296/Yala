# Auditoría UX 2.2 · decidido por Jürgen · 10 · Flujo de caja y Reportes: comparativa, desglose, crear el plan, líneas y gráficas

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-18-reportes/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (13)
- **L18-1** · `tablero-ux-2-2-l18-1-reportes-queda-al-fondo-de-4848`
  UX 2.2 · L18-1 · Reportes queda al fondo de «Más» y sus dos tarjetas no dicen para qué sirven
  Decisión de Jürgen: opción B (recomendada). Subtítulos con la pregunta que contesta cada tarjeta.
- **L18-2** · `tablero-ux-2-2-l18-2-la-comparativa-abre-en-todo-2do2`
  UX 2.2 · L18-2 · La Comparativa abre en «Todo el tiempo», donde no hay nada que comparar
  Decisión de Jürgen: opción C (recomendada). En «Todo el tiempo», tarjeta «Para comparar, elige un mes o un año» con «Este mes» y «Mes pasado».
- **L18-3** · `tablero-ui-2-2-l18-3-la-tabla-no-dice-que-es-cad-aam5`
  UI 2.2 · L18-3 · La tabla no dice qué es cada número, y «P-1» y «A-1» son jerga
  Decisión de Jürgen: opción D, variante 3 (recomendada): frase arriba, chips en palabras, «en setiembre» bajo cada monto, «Te quedó» y cabeceras de columna (L18-3-C.png).
- **L18-4** · `tablero-ux-2-2-l18-4-el-desglose-habla-en-jerga-e4hz`
  UX 2.2 · L18-4 · El desglose habla en jerga: «Profundizar», «Tipo», «Naturaleza», «Flujo neto»
  Decisión de Jürgen: opción C (recomendada). Palabras de la app, gastos sin signo, ejemplo del resultado en la hoja en vez del nivel fijo con candado, y VoiceOver sin «Aumento» cuando no cambia.
- **L18-5** · `tablero-ui-2-2-l18-5-crear-el-plan-pide-revisar-dfry`
  UI 2.2 · L18-5 · Crear el plan pide revisar 29 líneas y empieza con S/ 0 teniendo S/ 83,666
  Decisión de Jürgen: opción C, variante 2 (recomendada): saldo real arriba, lista partida en fijos a la vista y variables plegados (L18-5-B.png).
- **L18-6** · `tablero-ux-2-2-l18-6-tres-explicaciones-apiladas-2386`
  UX 2.2 · L18-6 · Tres explicaciones apiladas al entrar, y la primera dice «hasta fin de mes»
  Decisión de Jürgen: opción C (recomendada). Una explicación por pantalla: aviso corregido en la de crear y tour de 3 pasos solo al crear el plan.
- **L18-7** · `tablero-ux-2-2-l18-7-una-vez-creado-el-plan-una-lci6`
  UX 2.2 · L18-7 · Una vez creado el plan, una línea no se puede cambiar ni borrar a la vista
  Decisión de Jürgen: opción B (recomendada). «Cómo se calcula · Cambiar» y «Eliminar línea» en el detalle; el método deja de pintarse como enlace.
- **L18-8** · `tablero-ux-2-2-l18-8-este-mes-y-futuros-cambia-t-qp67`
  UX 2.2 · L18-8 · «Este mes y futuros» cambia también los meses pasados y el actual
  Decisión de Jürgen: opción A (recomendada). La línea guarda desde qué mes vale el monto nuevo; campo nuevo con despliegue al esquema de iCloud (dev + prod) antes del build. Toca SwiftData/CloudKit: review adversarial.
- **L18-9** · `tablero-ux-2-2-l18-9-ajustar-un-monto-el-campo-n-0hgm`
  UX 2.2 · L18-9 · Ajustar un monto: el campo no dice qué es y el teclado tapa «Guardar»
  Decisión de Jürgen: opción C (recomendada). Rótulo «Monto para <mes>», «Guardar» en barra sobre el teclado y la pregunta con el mes.
- **L18-10** · `tablero-ux-2-2-l18-10-cambiar-el-saldo-inicial-u-z6f6`
  UX 2.2 · L18-10 · Cambiar el saldo inicial: un lápiz que parece «prohibido» y una hoja sin divisa
  Decisión de Jürgen: opción C (recomendada). Fila «Empezaste con S/ X · Cambiar», hoja con divisa y «Usar este monto» con el saldo de las cuentas, y el plan nace con ese saldo (L18-5).
- **L18-11** · `tablero-ui-2-2-l18-11-la-tira-de-meses-y-el-resu-hdd9`
  UI 2.2 · L18-11 · La tira de meses y el resumen no dicen qué es cada número
  Decisión de Jürgen: opción C, variante 2 (recomendada): un número por cápsula y el resumen en frases (L18-11-B.png).
- **L18-12** · `tablero-ux-2-2-l18-12-las-graficas-no-dicen-de-q-ikfd`
  UX 2.2 · L18-12 · Las gráficas no dicen de qué período son y sus cifras no casan con el detalle del mes
  Decisión de Jürgen: opción B (recomendada). Cada gráfica dice su período y usa las mismas cifras que el detalle del mes, o explica la diferencia.
- **L18-13** · `tablero-ux-2-2-l18-13-agregar-linea-ofrece-tres-345i`
  UX 2.2 · L18-13 · «Agregar línea» ofrece tres caminos sin decir cuál conviene
  Decisión de Jürgen: opción B (recomendada). Ejemplo por camino y número con significado («S/ 10,900 en 6 meses»).

## Avisos de esta sesión
- **Alineación visual pendiente.** Las cards «Grupos tiene que sentirse la misma app» (`tablero-grupos-tiene-que-sentirse-la-misma-app-a-k2up`) y «Flujo de caja tiene que sentirse la misma app» (`tablero-flujo-de-caja-tiene-que-sentirse-la-mism-e7by`) son propuestas visuales que se preparan en la sesión lote-decidido-2-2-02. Antes de empezar, mira con `tablero ver` en qué estado están. Si Jürgen ya eligió (nota con su decisión), aplica lo elegido a las pantallas que toques en esta sesión. Si siguen en «espera decisión», implementa las cards de abajo con los componentes, filas, tarjetas y cabeceras que ya usan Registros y Estadísticas (sin estilo nuevo propio) y no hagas el rediseño general: eso queda para cuando Jürgen elija.
- **L18-8** cambia el modelo: la línea guarda desde qué mes vale el monto nuevo (campo nuevo en SwiftData/CloudKit). Review adversarial antes del PR (meses pasados intactos, migración de líneas existentes, sync entre dos dispositivos con versiones distintas). Despliega el campo al esquema de **desarrollo** de iCloud y comprueba el build. El despliegue a **producción** del esquema no lo hagas: déjalo listo con los pasos en una card a `lola` (copia a `jurgen`) en «ready to launch», como en las entregas de la tarjeta con varias divisas. No toques los `.ckdb` sin commitear de ~/Yala.
- L18-5 y L18-10: el plan nace con el saldo real de las cuentas; hazlas juntas.
- L18-3, L18-5 y L18-11 tienen variante elegida con captura en ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-18-reportes/capturas/.

## Cómo mover las cards
- Al empezar con cada una: `tablero mover <id> --a "in progress" --agente frank`. No uses `--nota` en `tablero editar` salvo para AÑADIR: `--nota` reemplaza la nota entera, así que copia la decisión de Jürgen que ya está y añade debajo lo tuyo.
- Al cerrar: a `done` (`--agente frank`) las que queden hechas y mergeadas sin nada que probar en el teléfono; a `in qa` asignadas a `jurgen` con un guion corto de iPhone en la nota si hay algo que él deba probar en el teléfono.
- Todo ticket nuevo lleva su card.

## La UI sigue la decisión al pie de la letra
- Implementa exactamente lo que dice la decisión de cada card (y la variante con captura si la hay). No inventes UI ni «mejores» la opción elegida. Los detalles que la decisión no fija y que el sistema de diseño ya resuelve (márgenes, tipografía, componentes existentes) se toman de lo que ya hay en la app.
- Si al implementar aparece algo de verdad sin decidir (dos caminos que cambian lo que ve el usuario y ninguno sale de la decisión), NO elijas tú: deja 2–3 propuestas con capturas o mock y tu recomendación en la nota de esa card, muévela a «espera decisión» asignada a `jurgen` con `--pregunta`, y sigue con las demás. Solo se para ese ítem, no la sesión.
- Ningún texto de la app escribe «OpenAI»: se dice «un servicio de IA» (con enlace a la política de privacidad, que es el único sitio que nombra al proveedor).
- Todo texto nuevo o cambiado, en los **16 idiomas**, y `/l10n-check` limpio.

## Reglas
- **Sin esperar el CI de ningún PR** (tampoco el tuyo): `git fetch origin && git rebase origin/2.2` justo antes de abrir el PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. 1 simulador a la vez. Mira `df -h /` antes de compilar. Usa los simuladores iOS 27.0. Al cerrar, apaga y borra (erase) el simulador que usaste.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- En `~/Yala` (árbol principal) no toques, commitees ni descartes `Cloudkit Schemas/yala_dev-*.ckdb`, `Yala.xcscheme` ni `encargos/pendientes/`.
- Nada de salud ni de clínicas. No toques tmux `salud--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*`, `Yala--qa-guiado-2-1-tf17` ni otros `Yala--` vivos.
- Nada de despliegues a producción (Worker/gateway, Supabase, CloudKit Production, web). Si algo hace falta, déjalo listo con los pasos en una card a `jurgen` (o a `lola` si es CloudKit) y sigue.
- No cambies cuota, modelo ni proveedor de IA, precios ni productos de StoreKit.
- Prueba la sesión tú misma con **/barrido-qa** en el simulador (tests de lo que cambie, flujos tocados de punta a punta, VoiceOver en lo nuevo). Hay cambio visible: capturas de antes y después en `capturas/` del worktree, copiadas también a `~/Claude/entregas/<sesión>/capturas/`, con sus rutas en el resumen de cierre.
- Cierra sola con **/cerrar-total** (merge incluido). No esperes a nadie.

## Cómo se sabe que está bien
Cada card hecha tal como la decidió Jürgen (o, si algo no estaba decidido, con sus propuestas en la card a `jurgen` y solo ese ítem parado), textos en los 16 idiomas, tests en verde (`/gate`, `YalaTests`), /barrido-qa pasado, capturas de antes y después, cards movidas, y PR mergeado en 2.2 explicando en lenguaje de usuario qué verá la persona.

## Paso 0

Resuelto por Frank el 2026-10-21 (02:30 Lima, sin nadie delante: auto-contestado). Lo medido, lo decidido y lo asumido.

**Rama y base.** `encargo/2026-10-21-lote-decidido-2-2-10-flujo-de-caja-y-reportes` recreada sobre `origin/2.2` (`git log origin/2.2..HEAD` vacío). PR contra `2.2`.

**Alineación visual.** La card «Flujo de caja tiene que sentirse la misma app» ya tiene decisión (19-oct 06:04: todas las recomendadas del lienzo «Una sola Yala» + lo «sin pregunta»), y el lienzo pone su implementación en esta sesión. Medido: la sesión de Grupos que montaría las piezas comunes no existe todavía en `2.2`. ⇒ Se aplica a las pantallas de Flujo de caja que toca este lote (todas): 2A (cada línea con la fila de Presupuestos), 5A (la tira se queda, mes elegido relleno en el acento), 6A (gráficas en su hoja con tarjetas de Tendencias) y lo «sin pregunta» (color de montos, títulos de sección sin mayúsculas, icono de 40, hojas con cabecera y fondo de la app, «Gastos · Ingresos» con el selector de «Nuevo registro», avisos con el aviso de la app). Se reutilizan piezas existentes (`BudgetRemainingFigure`, `BudgetSpentLine`, `BudgetProgressBar`, `HeroHeader`, `CollapsibleSectionHeader`, `TransactionTypeSelectorView`); no se crea estilo nuevo. Grupos no se toca.

**Cruces entre decisiones, y cómo se resuelven (sin elegir UI nueva):**
- L18-11 C2 dice «Este mes te sobran S/ X» como cifra principal; el lienzo pide la cifra grande del mes con las frases de C2 debajo. ⇒ `HeroHeader` con el rótulo y la cifra de C2 y las otras dos frases debajo. Desaparece el pie «Disponible / Acumulado» con «?» y lápiz (C2 lo sustituye).
- L18-5 C2 parte la lista en «se repiten / cambian»; el lienzo titula «Lo que entra / Lo que sale». ⇒ «Lo que entra» con los ingresos, «Lo que sale» con los gastos que se repiten a la vista y debajo la fila plegada «Gastos que cambian · N». Regla de «se repite»: viene de un pago planificado, o tuvo actividad en ≥ 5 de los 6 meses con montos parecidos (variación ≤ 25 % sobre su media). Asumido.
- L18-3 D3 pide chips «Con el mes anterior / Con octubre de 2025»; L11-4 cambió en Estadísticas los chips P-1/A-1 por una frase-menú compartida. ⇒ La Comparativa sigue la variante elegida al pie de la letra (frase arriba + dos chips); Estadísticas conserva su frase-menú. Anotado en «Encontrado».
- L18-7 B: el informe preguntaba si vuelve la hoja retirada en marzo o se rehace en el detalle; la recomendación decía «sin traer de vuelta la hoja que se retiró». ⇒ «Cambiar» abre el selector de método que ya usa la pantalla de crear el plan (`CashFlowMethodPickerSheet`), adaptado a una línea existente. `CashFlowLineConfigSheet` sigue sin entrada.
- L18-13 B pone de ejemplo «S/ 10,900 en 6 meses», pero 10,900 era el promedio mensual. ⇒ La cifra dice lo que es: el total de los 6 meses con «en 6 meses», convertido a la divisa del plan.

**L18-8 (modelo).** Campo nuevo `CashFlowLine.amountChangesRaw: String?`: los cambios «desde este mes» de una línea (`yyyy-MM=monto`, separados por coma). Un mes usa, por orden: su ajuste de un solo mes, el último cambio cuyo mes es ≤ ese mes, y si no, el método de la línea. Así un cambio desde noviembre no toca setiembre ni octubre, y un segundo cambio desde febrero no borra el de noviembre a enero. Cambiar el método de la línea («Cómo se calcula · Cambiar») borra los cambios: el método nuevo vale para todos los meses, como hasta hoy. «Solo noviembre» sigue siendo un ajuste de un mes.
- iCloud: `CD_amountChangesRaw` STRING en los cuatro `.ckdb`. Sin token de `cktool` en esta máquina (medido): el despliegue a Development y a Production queda en una card a Lola (copia a Jürgen) con los pasos A-E de `docs/cloudkit-schema-diff-2.1.md`, como en la tarjeta con varias divisas.
- Modo Nube: columna `cashflow_lines.amount_changes_raw` con `since: 3` (manifest v3), DDL preparado en `qa/cloud/`, y la subida de versión se generaliza para reemitir también las líneas cuyo cambio no subió. DDL y Worker de producción: card a Jürgen. Nada se despliega a producción.
- Una versión anterior de la app ignora el campo: ve el método de la línea en los meses siguientes (no corrompe nada). Review adversarial antes del PR (meses pasados intactos, migración de líneas existentes —nacen sin cambios—, dos dispositivos con versiones distintas, los dos canales).

**L18-5 + L18-10.** El plan nace con el saldo de las cuentas que suman (misma regla que el «en N cuentas» del Panel: `PanelTotalAccountsLogic.countableAccounts`), convertido a la divisa del plan. «Cambiar el monto» y la fila «Empezaste con S/ X · Cambiar» abren la misma hoja: cabecera de la app, cifra grande con la divisa, «Usar este monto» con el saldo de hoy, y la fecha del saldo como hasta ahora.

**L18-6.** Fuera la guía de 4 pasos de crear el plan; se queda una sola explicación (el aviso, con el texto corregido «Mira mes a mes si lo que ganas cubre lo que gastas»). La guía de 3 pasos del plan sale solo justo después de crearlo, una vez.

**L18-1, L18-2, L18-4, L18-9, L18-12.** Tal cual las decisiones. L18-12: medido que «Gastos por revisar» promedia los meses pasados y el actual mientras el detalle es de un mes; cada gráfica dice su período y esa explica que es un promedio por mes.

**Fuera de alcance:** el chip «IA» sin Pro (L18-12 C, no elegido), mover Reportes en «Más» (L18-1 C), Grupos. Ningún texto nombra a un proveedor de IA. Textos nuevos en los 16 idiomas.

## Resultado

Cerrado por Frank el 2026-10-21. Las 13 cards implementadas tal cual la decisión; ninguna quedó en «espera decisión».

**Decidido durante la implementación (sin cambiar lo que pedía la decisión):**
- L18-3: con tres columnas separadas los nombres de las subcategorías se cortaban; se aplicó el texto de la decisión
  («en setiembre» bajo cada monto) y la cabecera nombra el período y «Cambio». Los nombres largos usan dos líneas.
- L18-8: la review adversarial (dos lentes) cazó cuatro cosas y se arreglaron antes del PR: «Cambiar» guardado sin
  cambios borraba los cambios «desde este mes», el selector redondeaba el monto fijo a entero, «monto fijo» sin cifra
  dejaba la línea en 0, y la subida de nivel del Modo Nube no se pedía si la v3 llegaba al actualizar la app (ahora se
  compara con el último nivel declarado; mutante verificado).
- Pulido medido en las capturas: meses con mayúscula a media frase («Monto para Octubre») por el formato suelto del
  mes, el estimado de la gráfica diaria pisando la etiqueta del eje, «Te falta recibir S/ 0.00» en un ingreso cobrado
  entero (ahora «Recibido»), «Usar este monto» cuando ya estaba puesto, y «Cambiar» suelto en VoiceOver.

**Verificado:** `/gate` (Yala y Yala Dev sin warnings nuevos; 10.966 tests de unidad; 95 XCUITest de las áreas
tocadas con el centinela a 0; el flaky conocido del carrusel por tarjeta, 3/3 verde aislado), `/l10n-check` limpio,
capturas de antes y después en `~/Claude/entregas/Yala--lote-decidido-2-2-10-flujo-de-caja-y-reportes/capturas/`.

**Queda fuera de esta sesión (cards):** desplegar `CD_amountChangesRaw` a CloudKit Development y Production (Lola,
antes de cualquier TestFlight de 2.2), aplicar el DDL g21_01 y desplegar el Worker v3 (Jürgen, después de g18_01), y
el device-QA con dos iPhone de L18-8.

**Tickets nuevos:** `cashflow-amount-changes-from-two-phones-overwrite-each-other`,
`comparative-and-statistics-pick-the-comparison-with-different-controls`. Movidos: `cashflow-this-and-future-adjustment-rewrites-past-months`
(a `qa`) y `cash-flow-plan-asks-the-starting-balance-the-account-already-has` (a `done`).
