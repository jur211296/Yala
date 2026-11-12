# Auditoría UX 2.2 · decidido por Jürgen · 11 · Grupos: gastos, saldar, saldos y el puente a tus cuentas

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-13-grupos-ii/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (11)
- **L13-4** · `tablero-ux-2-2-l13-4-borrar-un-gasto-solo-dice-e-m0ah`
  UX 2.2 · L13-4 · Borrar un gasto solo dice «Eliminar»: no avisa de que desaparece para todos ni de que se borra tu movimiento
  Decisión de Jürgen: opción B (recomendada). «¿Eliminar «X»?» con el mensaje de que se borra para todo el grupo y de tus cuentas.
- **L13-5** · `tablero-ux-2-2-l13-5-cinco-palabras-para-lo-mism-65kb`
  UX 2.2 · L13-5 · Cinco palabras para lo mismo: «Liquidar», «Registrar pago», «Liquidaciones», «saldar», «Salda pagos»
  Decisión de Jürgen: opción B (recomendada). «Saldar» para la acción, «Pagos» para la lista, «Apuntar pago».
- **L13-6** · `tablero-ux-2-2-l13-6-saldos-y-el-resumen-para-co-kvd8`
  UX 2.2 · L13-6 · Saldos y el resumen para compartir dan cifras distintas para la misma deuda
  Decisión de Jürgen: opción B (recomendada). El resumen para compartir sigue la opción «Simplificar deudas» del grupo, igual que Saldos.
- **L13-7** · `tablero-ux-2-2-l13-7-si-registrar-no-registra-de-d89y`
  UX 2.2 · L13-7 · «Sí, registrar» no registra: deja un borrador en la Bandeja y no lo dice
  Decisión de Jürgen: opción B (recomendada). Pedir la cuenta ahí mismo y registrar de verdad; la Bandeja solo si no se elige.
- **L13-9** · `tablero-ux-2-2-l13-9-guardar-se-apaga-sin-decir-23cx`
  UX 2.2 · L13-9 · «Guardar» se apaga sin decir qué falta
  Decisión de Jürgen: opción B (recomendada). «Guardar» siempre activo; al tocar con algo pendiente marca el campo y una línea de qué falta.
- **L13-10** · `tablero-ux-2-2-l13-10-los-saldos-iniciales-estan-adl9`
  UX 2.2 · L13-10 · Los saldos iniciales están al fondo de Miembros y el formulario no explica qué son
  Decisión de Jürgen: opción B (recomendada). Línea de ayuda en el formulario y la entrada también en Saldos.
- **L13-11** · `tablero-ux-2-2-l13-11-al-convertir-un-borrador-e-rvrx`
  UX 2.2 · L13-11 · Al convertir un borrador en gasto de grupo, desaparece sin decir adónde fue
  Decisión de Jürgen: opción B (recomendada). Aviso «Movido a «X»» con «Ver» al volver a la Bandeja y el selector sin preselección.
- **L13-12** · `tablero-ux-2-2-l13-12-las-hojas-para-completar-u-nugm`
  UX 2.2 · L13-12 · Las hojas para completar un borrador de grupo no hablan igual
  Decisión de Jürgen: opción B (recomendada). Mismo verbo en todas, el pago con nombre y el recuadro en una línea.
- **L13-13** · `tablero-ux-2-2-l13-13-quien-ha-hecho-mas-pagos-m-4qu6`
  UX 2.2 · L13-13 · «¿Quién ha hecho más pagos?» mide dinero, no pagos
  Decisión de Jürgen: opción B (recomendada). «¿Quién puso más?» y «lo que te tocaba» bajo «Mi parte».
- **L13-14** · `tablero-ux-2-2-l13-14-activar-y-desactivar-el-pu-vwob`
  UX 2.2 · L13-14 · Activar y desactivar el puente no hablan igual, y borrar de tus cuentas no pide confirmación
  Decisión de Jürgen: opción B (recomendada). «Reflejar en tus cuentas» en las dos hojas, «Eliminar de mis cuentas» en rojo con confirmación de N movimientos y enlace a Ajustes de Grupos.
- **L13-15** · `tablero-ux-2-2-l13-15-no-hay-forma-de-enlazar-un-6fs9`
  UX 2.2 · L13-15 · No hay forma de enlazar un gasto de grupo con un movimiento que ya apuntaste a mano
  Decisión de Jürgen: opción B (recomendada). «¿Ya lo apuntaste?» con movimientos parecidos del día al completar el borrador; elegir uno los enlaza.

## Avisos de esta sesión
- **Alineación visual pendiente.** Las cards «Grupos tiene que sentirse la misma app» (`tablero-grupos-tiene-que-sentirse-la-misma-app-a-k2up`) y «Flujo de caja tiene que sentirse la misma app» (`tablero-flujo-de-caja-tiene-que-sentirse-la-mism-e7by`) son propuestas visuales que se preparan en la sesión lote-decidido-2-2-02. Antes de empezar, mira con `tablero ver` en qué estado están. Si Jürgen ya eligió (nota con su decisión), aplica lo elegido a las pantallas que toques en esta sesión. Si siguen en «espera decisión», implementa las cards de abajo con los componentes, filas, tarjetas y cabeceras que ya usan Registros y Estadísticas (sin estilo nuevo propio) y no hagas el rediseño general: eso queda para cuando Jürgen elija.
- Van primero los que dan cifras o registros mal: **L13-6** (el resumen para compartir sigue «Simplificar deudas» como Saldos) y **L13-7** (registrar de verdad pidiendo la cuenta). Review adversarial antes del PR de L13-6, L13-7 y L13-15 (cálculo de deudas y puente a las cuentas personales: nada duplicado, nada perdido, enlazar no cambia importes).
- L13-5: «Saldar» para la acción, «Pagos» para la lista, «Apuntar pago» en todas las pantallas de Grupos que lo nombren.

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

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Ficheros que se tocan (nota, no pregunta):** `GroupShareableSummaryLogic`, `GroupExpenseFormView`/`GroupExpenseViewModel`, `GroupRecordsView`, `GroupBalancesView`, `GroupDetailView`, `SettlementFormView`, `GroupStatsView`, `GroupOpeningBalanceFormView`, `GroupSettingsView`, `GroupsGlobalSettingsView`, `BridgeActivationSheet`/`BridgeDeactivationSheet`, `GroupPickerSheet`, `InboxView`, las cuatro hojas de borrador de grupo de la Bandeja y su `GroupDraftFinalizationScaffold`, `InboxDraftRowView`, `DraftService` (enlazar), lógica pura nueva y sus tests, `L10n.swift` y los 16 `Localizable.strings`.

**D1 · ¿Se aplica aquí el rediseño «Una sola Yala» (decidido el 19-oct, card `…misma-app-a-k2up`)?** → No el rediseño general (cifra de arriba, fila, chip de pestaña, cápsula de período): esa card sigue en «ready to launch» con su propia sesión. Lo que estas cards CREAN usa piezas que ya existen y la regla «sin pregunta» del color (lo que entra o te deben en el tono de ingreso, lo demás en el color del texto; nada rosa nuevo).
Por qué: el lienzo dice «primero las piezas comunes, después las pantallas»; meterlas a medias aquí las haría dos veces. Alternativa descartada: implementar 1A/3A/4A aquí — duplica la sesión de la card y choca con L12/L19.

**D2 · L13-6, ¿qué cambia además del cálculo?** → El resumen usa `group.simplifyDebts` (el mismo flag que `GroupDetailViewModel.recalculate`), y el texto de ayuda pierde «mínimos» («los pagos para saldar todo»), que ya no sería verdad con el ajuste apagado. Consolidación a una moneda: sin cambios (ya espejaba Saldos).
Por qué: una sola respuesta en toda la app. Descartado: tocar también `SettlementReminderLogic` (ya respeta el flag).

**D3 · L13-7, ¿cómo se «pide la cuenta ahí mismo»?** → «Sí, registrar» crea el borrador de siempre y abre en el acto la hoja de la Bandeja que lo completa (cuenta; y subcategoría si el gasto no la resuelve). Elegir = se registra de verdad por el camino de aprobación ya probado. Cerrar sin elegir = el borrador se queda en la Bandeja y la pantalla de éxito lo dice. Vale igual para el flujo de la Bandeja (convertir) y para «Apuntar pago» (el mismo «Sí, registrar» del pago, con su hoja de pago).
Por qué: no se escribe un segundo camino que cree movimientos; el que hay ya concilia la pata virtual. Descartado: un selector de cuenta suelto en el formulario (duplicaría la lógica del puente).

**D4 · L13-15, ¿qué es un movimiento «parecido» y qué hace enlazar?** → Mismo día, misma divisa y mismo importe (±0,005) que el gasto, en una cuenta real, sin puntero de grupo y que no sea el registro de un pago aprobado. Solo en las hojas de borrador de un gasto que pagaste tú (las que piden cuenta). Tocar uno lo enlaza: el movimiento pasa a ser la pata real del gasto, el puente rehace la virtual y el borrador se va. No cambia ningún importe ni la cuenta, nota o subcategoría; la hora pasa a la del gasto (mismo día), que es lo que el puente ya hace con toda pata real. Pagos: fuera (card nueva si hace falta).
Por qué: «mismo importe» es lo que garantiza que enlazar no cambie importes. Descartado: tolerancia de importe (el puente reescribiría el importe del movimiento).

**D5 · L13-12, textos exactos.** → Títulos: «Elige la cuenta» (gasto y pago), «Elige la subcategoría», «Elige la cuenta y la subcategoría». Recuadro: «Viene del grupo «X».». El pago con nombre: «Pago a Ana · Viaje a Cusco» (o «Pago de Ana · …» si lo recibes), en la hoja y en su fila de la Bandeja, calculado al pintar.
Por qué: un verbo, una línea. Descartado: escribir el nombre en el borrador al crearlo (no arregla los que ya existen).

**D6 · L13-5, alcance.** → Todo texto de Grupos que diga liquidar/liquidación/registrar pago: botón y título del formulario («Apuntar pago»), lista («Pagos»), fila del feed («Pago»), menú y diálogo de borrar un pago, educativo, avisos de borrar grupo y gasto, el aviso de la Bandeja, su chip de origen («Pago de grupo»), el de cambio de importe y el motivo de cambio de divisa de una cuenta. **No** se tocan los nombres de las subcategorías de sistema («Liquidación enviada/recibida»): se reconocen por nombre en el puente.
Por qué: cambiarlas rompería el emparejado por nombre. Descartado: renombrarlas con migración (fuera del encargo).

**D7 · L13-9, alcance y prioridad.** → Solo el formulario de gasto de grupo. «Guardar» activo salvo grupo congelado por migración (eso ya tiene su aviso). Al tocar con algo pendiente: se marca el primero que falta (descripción → importe → reparto → cuenta) y una línea encima del botón dice qué falta; la línea desaparece cuando se arregla.
Descartado: aplicarlo al pago y al saldo inicial sin decisión (van a «Encontrado»).

**D8 · L13-10.** → Línea de ayuda bajo el título del formulario: «Lo que alguien ya debía antes de usar Yala». En Saldos, «Añadir saldo inicial» al final de «Para quedar a mano», solo para quien creó el grupo (el único que puede), abriendo la misma hoja.

**D9 · L13-11.** → El selector de grupo llega sin ninguno marcado. Al guardar el gasto convertido, la Bandeja enseña el aviso de la app («Movido a «X»» · «Ver»); «Ver» cierra la Bandeja y abre el grupo. También cuando solo hay un grupo (no pasa por el selector).

**D10 · L13-13.** → «¿Quién puso más?» y, bajo «Mi parte», «lo que te tocaba».

**D11 · L13-14.** → «Reflejar en tus cuentas» (activar) y «Dejar de reflejar en tus cuentas» (desactivar) como títulos de las hojas, y el mismo nombre en los dos títulos de sección (Ajustes de Grupos y del grupo). «Eliminar de mis cuentas» en rojo; con ella elegida, «Continuar» pregunta «¿Eliminar N movimientos de tus cuentas?» (N = los que se borrarían). «Ajustes de Grupos» del aviso del grupo es un enlace que abre esa hoja.

**D12 · L13-4.** → El mismo diálogo desde el formulario y desde la fila: «¿Eliminar «X»?» + «Se borra para todo el grupo y los saldos se recalculan. Si está en tus cuentas, también se quita de ahí.».

**D13 · Tests que fijan el contrato viejo.** → `GroupsSmokeUITests` (Guardar apagado sin cuenta) y `GroupShareableSummaryLogicTests.paymentsAreAlwaysSimplified` se reescriben al contrato nuevo; tests nuevos para la lógica pura (faltantes, candidatos de enlace, nombre del pago) y el enlace en `DraftService`.

**D14 · Review adversarial** → L13-6, L13-7 y L13-15 antes del PR (lentes: dinero duplicado o perdido, importes que cambian, flujos que abren dos hojas).

**D15 · QA en iPhone** → Ninguna card pide dispositivo: todo se prueba en el simulador. Se cierran a `done`.

**D16 · Lo que encontró la review adversarial (3 lentes) y qué se hizo.** → Arreglado: la hoja de la cuenta tras «Sí, registrar» podía no presentarse con «Guardar»/«Apuntar pago» aún activos (un segundo toque apuntaba el pago dos veces) → ahora el botón queda apagado y se comprueba que la hoja llegó (un reintento; si no, el borrador queda en la Bandeja y el flujo cierra); la ruta de la hoja se fija al abrirla; la marca de «qué falta» se quedaba en «Crear otro gasto»; un movimiento conservado al desasociar podía ofrecerse como candidato (lo dejaba contado cero veces); enlazar cuando el puente no concilia (miembro inactivo, grupo oculto, gasto conservado); la X de la hoja del puente revertía el ajuste con los movimientos ya borrados; pt-PT nombraba «Definições» y el aviso tras saldar decía «liquidar». Fuera, con su ticket: repartos duplicados por el sync (única diferencia que queda entre resumen y Saldos, `group-balance-service-shares-not-deduped`), dos borradores de cuenta del mismo gasto (`two-account-drafts-…`).
Por qué: son daños de dinero o de flujo con un arreglo acotado; los de fuera son anomalías previas con su propio alcance.

**D17 · Un movimiento enlazado (L13-15), ¿sigue al gasto después?** → Sí: desde que se enlaza ES el gasto del grupo en tus cuentas; si alguien corrige el importe del gasto, cambia, y si se borra, se va (el diálogo de borrar ya lo dice, L13-4). Enlazar en sí no cambia nada.
Por qué: es lo que significa «los enlaza»; un movimiento que no siguiera al gasto volvería a contar el gasto aparte. Alternativa descartada: «desenlazar» al borrar (no decidido y abre otro doble conteo).

## Resultado

- Las 11 cards hechas como las decidió Jürgen (todas opción B), sin nada que pedir a su iPhone: van a `done` al quedar el PR en cola.
- Textos nuevos y cambiados en los 16 idiomas (script idempotente; paridad en verde).
- Tests: `YalaTests` completo (11 014) y XCUITest de las 31 suites de las áreas tocadas; nuevos `GroupExpenseLinkDraftTests` (enlace contra el bridge real, mutante verificado) y `UXAudit22Lote13DecididoUITests` (5 flujos).
- Capturas antes/después: `/Users/jur/Claude/entregas/Yala--lote-decidido-2-2-11-grupos-gastos-y-saldar/capturas/` (copia en `~/Claude/worktrees/_capturas/2026-10-21-lote-decidido-2-2-11-grupos-gastos-y-saldar/`).
- Tickets nuevos con card: `two-account-drafts-for-one-group-expense-can-create-two-real-legs`, `settle-and-opening-balance-buttons-turn-off-without-saying-why`, `image-vision-error-still-names-the-ai-provider`.
