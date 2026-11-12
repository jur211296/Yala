# Auditoría UX 2.2 · decidido por Jürgen · 08 · Widgets, iPad, teclado, botones flotantes y accesos rápidos del icono

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-15-desde-fuera/informe.md`, `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-16-ajustes/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (11)
- **L15-1** · `tablero-ux-2-2-l15-1-los-widgets-se-llaman-disti-s3od`
  UX 2.2 · L15-1 · Los widgets se llaman distinto que lo que abren
  Decisión de Jürgen: opción C (recomendada). Nombres = pantalla que abren y la descripción de la galería dice a dónde lleva; si L11-10 renombra Flujo de Efectivo a «Entradas y salidas», el widget lo sigue.
- **L15-2** · `tablero-ux-2-2-l15-2-sin-datos-los-widgets-ensen-d0k2`
  UX 2.2 · L15-2 · Sin datos, los widgets enseñan ceros o «todo pagado» sin decir por qué
  Decisión de Jürgen: opción C (recomendada). Estados vacíos que invitan, y si lo elegido a mano se borró, el widget vuelve solo a «los más usados».
- **L15-3** · `tablero-ux-2-2-l15-3-widgets-que-ensenan-lo-mism-n2iq`
  UX 2.2 · L15-3 · Widgets que enseñan lo mismo llevan a sitios distintos
  Decisión de Jürgen: opción B (recomendada). Cada widget abre la pantalla que amplía lo que enseña; Balance sigue en el Panel.
- **L15-11** · `tablero-ux-2-2-l15-11-una-ventana-de-yala-se-que-qo1l`
  UX 2.2 · L15-11 · Una ventana de Yala se queda con un indicador de carga sin decir por qué
  Decisión de Jürgen: opción C (recomendada). Texto bajo el indicador y botón «Ir a esa ventana».
- **L15-12** · `tablero-ux-2-2-l15-12-soltar-un-recibo-en-el-ipa-neah`
  UX 2.2 · L15-12 · Soltar un recibo en el iPad con algo abierto no hace nada
  Decisión de Jürgen: opción C (recomendada). Aceptar el archivo y leerlo al cerrarse lo abierto; varios, hasta 10 como tanda.
- **L15-13** · `tablero-ux-2-2-l15-13-atajos-de-teclado-configur-dne1`
  UX 2.2 · L15-13 · Atajos de teclado: «Configuración» en vez de «Ajustes», ⌘K abre Yala IA y no hay deshacer
  Decisión de Jürgen: opción C (recomendada). «Ajustes» en el menú, motivo en «Eliminar» de grupo y ⌘Z deshace el último borrado unos segundos; ⌘K se queda.
- **L15-14** · `tablero-ux-2-2-l15-14-con-el-iphone-girado-o-en-069n`
  UX 2.2 · L15-14 · Con el iPhone girado o en el iPad, los botones flotantes tapan el contenido
  Decisión de Jürgen: opción B (recomendada). Con poco alto, los dos botones en fila abajo a la derecha, sobre la barra.
- **L15-15** · `tablero-ux-2-2-l15-15-no-hay-accesos-rapidos-al-vq9a`
  UX 2.2 · L15-15 · No hay accesos rápidos al mantener pulsado el icono
  Decisión de Jürgen: opción B (recomendada). Accesos rápidos del icono: «Nuevo registro», «Registrar por voz», «Foto o archivo».
- **L16-20** · `tablero-ux-2-2-l16-20-en-el-ipad-la-lista-de-aju-t8lh`
  UX 2.2 · L16-20 · En el iPad, la lista de Ajustes no marca qué ajuste está abierto
  Decisión de Jürgen: opción C (recomendada). Fila abierta rellena (color de L16-9) y sin «‹» en el detalle con la lista al lado.
- **L16-21** · `tablero-ux-2-2-l16-21-el-tamano-de-un-widget-del-9dz2`
  UX 2.2 · L16-21 · El tamaño de un widget del Panel se esconde detrás del «?»
  Decisión de Jürgen: opción B (recomendada). El tamaño también en «Preferencias de widgets».
- `tablero-widgets-extragrandes-en-el-iphone-con-io-5fir`
  Widgets extragrandes en el iPhone con iOS 27
  (pedido de Jürgen) Jürgen, 18-oct en la ronda de decisiones de la auditoría UX 2.2, literal: «También me gustaría aprovechar widget extra large que salió en iOS 27 y no tenemos». Medido en el repo: ya existe UN widget extragrande, «Resumen del mes» (MonthSummaryWidget, solo .systemExtraLarge), pensado para iPad (ticket done ipad-large-and-extra-large-widgets). Ningún otro widget declara el tamaño extragrande. Siguiente paso: Frank: medir con el SDK de iOS 27 que el tamaño extragrande existe en el iPhone y cómo se llama; comprobar si «Resumen del mes» ya aparece en la galería del iPhone; proponer en lienzo qué widgets ganan versión extragrande (con los nombres decididos en L15-1) para que Jürgen elija. Agrupar con el lote 15 (widgets).

## Avisos de esta sesión
- L15-1: si la sesión 01 ya renombró «Flujo de Efectivo» a «Entradas y salidas» (L11-10), el widget lo sigue.
- **Widgets extragrandes** (`tablero-widgets-extragrandes-en-el-iphone-con-io-5fir`) tiene cierre «propuesta-visual»: no la implementes. Mide con el SDK de iOS 27 que el tamaño extragrande existe en el iPhone y cómo se llama, comprueba si «Resumen del mes» ya sale en la galería del iPhone y deja en un lienzo qué widgets ganarían versión extragrande (con los nombres de L15-1), opciones y recomendación. Esa card vuelve a «espera decisión» a `jurgen` con el enlace; el resto de la sesión sí se implementa y se mergea.
- L15-13: ⌘Z deshace el último borrado unos segundos; ⌘K se queda como está.
- Prueba también en el simulador de iPad (L15-11, L15-12, L15-14, L16-20), uno cada vez.

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

Medido el 2026-10-20 sobre `origin/2.2` (rama rebasada; `git log origin/2.2..HEAD` vacío al empezar).

**Lo que ya estaba (medido, no se rehace):**
- **L11-10 ya está en 2.2**: Tendencias llama «Entradas y salidas» a la tarjeta de Flujo de Efectivo (`stats.l11d.trends.inAndOut`). El widget de flujo lo sigue: «Entradas y salidas», y su toque abre esa tarjeta.
- **L16-21 ya está en 2.2**: el tamaño de cada widget vive en «Preferencias de widgets» (`PanelSectionPreferencesSheet.sizePicker`, P20-11) y el «?» ya no lo lleva desde el lote 3 (L3-7, `d558cf1e6`, 17-oct). La captura de la auditoría es del 15-oct, anterior. Se verifica en el simulador y se cierra con captura, sin código.
- **L16-9 ya está en 2.2** (`SelectedOptionFill`): L16-20 reusa ese relleno.

**Decisiones de implementación (defaults sensatos, no cambian lo que decidió Jürgen):**
- **L15-1 · nombres.** Los de la opción B del informe: «Entradas y salidas» (sigue a L11-10), «Categorías en círculo», «Subcategorías en círculo», «Categorías que más gastan», «Subcategorías que más gastan», «Pagos planificados», «Disponible» (también el de bloqueo), «Foto o archivo», «Nuevo registro», «Registrar por voz». Los que ya se llamaban como su pantalla (Gastos, Presupuestos, Últimos registros, Resumen del mes, Presupuesto, Próximo pago) conservan el nombre. Cada descripción de la galería termina diciendo a dónde lleva el toque. Los títulos dentro del widget («Registro rápido», «Flujo de dinero», «Próximos pagos») pasan al mismo nombre. Donde la app ya tiene el término traducido (`panel.hero.availableLabel`, `planning.scheduledPayments`, `shortcut.*`, `stats.l11d.trends.inAndOut`) se copia su traducción para que no diverjan.
- **L15-3 · destinos.** Gastos (inicio y bloqueo) → Estadísticas › Resumen (`statistics/insights`); Entradas y salidas → Tendencias, desplazado a esa tarjeta (`statistics/trends/in-and-out`, destino nuevo); Subcategorías (círculo y lista) → Distribución con la vista de subcategorías (`statistics/categories/subcategories`, destino nuevo); Balance/Disponible sigue en el Panel.
- **L15-2 · estados vacíos.** Sin datos de Yala todavía (no hay snapshot en el App Group): «Abre Yala para ver tu saldo» en Disponible y «Abre Yala para ver tus datos» en el resto de widgets de datos. Sin ningún pago planificado: «Aún no tienes pagos planificados · Toca para crear uno», que abre el editor de pago nuevo; mismo patrón en Presupuestos. Lo elegido a mano que ya no existe: el widget vuelve a automático («los más usados»/«los próximos») en vez de decir que no hay.
- **L15-11 · texto según la causa.** Cerrando sesión en otra ventana: «Cerrando tu sesión en la otra ventana…»; borrando datos: «Borrando tus datos en la otra ventana…»; arrancando: «Yala se está abriendo en la otra ventana…». «Ir a esa ventana» trae al frente la ventana que lanzó el cierre (o la líder); si no hay otra ventana viva, el botón no sale.
- **L15-12 · soltar con algo abierto.** Se acepta y entra por el camino de la foto compartida, que ya espera a que se cierre lo abierto (`RouterConsumerGateLogic`). Varios archivos: hasta 10 como una tanda (`SharedImageBatch`), con el mismo aviso de los que no entran. Solo grupos y los bloqueos críticos del shell (cierre de sesión, borrado, actualización obligatoria) siguen rechazando.
- **L15-13 · ⌘Z.** «Ajustes» en el menú en los 16 idiomas (es: Ajustes; fr: Réglages; pt-PT: Definições — el término que la app ya usa en cada uno). En un registro de grupo, «Eliminar» sale desactivado con el motivo «Se borra desde el grupo» (menú contextual y menú Registro). Borrar un registro desde el menú contextual, ⌫ o el detalle en columna espera unos segundos con el aviso «Eliminaste … · Deshacer» (molde de `ScheduledPaymentPendingDeletion`, L10-15), y ⌘Z deshace el último borrado mientras dura el aviso (también el de un pago planificado). ⌘K no se toca.
- **L15-14 · poco alto.** Con menos de 500 pt de alto disponible, Yala IA y «+» van en fila abajo a la derecha; con más, como siempre.
- **L15-15.** Accesos dinámicos (`UIApplication.shortcutItems`) para que sigan el idioma elegido en la app, con los títulos de los atajos de Siri que ya existen en 16 idiomas; entran por el mismo deep link que los widgets de entrada rápida.
- **L16-20.** Fila abierta con `selectedOptionFill` y sin «‹» en el primer nivel del detalle cuando la lista está al lado.
- **Widgets extragrandes:** propuesta visual (lienzo), no implementación; la card vuelve a `jurgen` con el enlace.
- Review adversarial: sí en el borrado aplazado con ⌘Z (toca borrado de registros y transferencias); el resto es UI/copy.
- **Alcance ampliado por coherencia (L15-1 + L11-10):** el widget de flujo DENTRO del Panel (`cashFlow.title`, su nombre en Preferencias de widgets `widgetType.cashFlow` y el título de su «?» `panel.widgetInfo.cashFlow.title`, que decía «Flujo de caja») pasa también a «Entradas y salidas». La sesión de L11-10 dejó escrito que lo seguía esta; con el de inicio y Tendencias ya renombrados, quedaba como la única pantalla con el nombre viejo. Solo texto.

## Resultado

- **Hecho y en `done`:** L15-1, L15-2, L15-3, L15-13, L15-14, L16-20; L16-21 ya estaba (lote 3). Evidencia en cada card y en `~/Claude/worktrees/_capturas/2026-10-20-lote-decidido-2-2-08-widgets-ipad-y-teclado/`.
- **Hecho y en `in qa` para Jürgen** (lo que el simulador no monta): L15-15 (app cerrada del todo y ventana que viene de 2.1), L15-12 (arrastre entre apps en un iPad), L15-11 (dos ventanas con sesión real). Guion en cada card y en `docs/qa/tanda-qa-jurgen-2.2.md` (montaje E).
- **Widgets extragrandes:** medido (`systemExtraLargePortrait` en el iPhone; ninguno de los 20 widgets de Yala lo ofrecía) y lienzo publicado (https://claude.ai/artifact/A17gM3xCQH96SWVNxakCaR). Jürgen eligió C (los tres) y pidió otra sesión: card en «lista para lanzar».
- **Lo que salió por el camino:** un ⌘Z sumado al del sistema cerraba la app (lo cazó el XCUITest; regla en `swiftui-ds.md`); `typeKey` no llega a un `CommandGroup` condicional (regla en `testing.md`); el «‹» de Ajustes lo pinta cada pantalla, no el sistema. Residual en ticket `record-pending-deletion-still-counts-outside-records`.
