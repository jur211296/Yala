# Auditoría UX 2.2 · decidido por Jürgen · 13 · Grupos: crear el primer grupo, educativo, consentimiento y entrar con Apple o Google

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-12-grupos/informe.md`, `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-13-grupos-ii/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (10)
- **L12-1** · `tablero-ux-2-2-l12-1-en-el-grupo-estadisticas-se-qulj`
  UX 2.2 · L12-1 · En el grupo, «Estadísticas» se corta y «Balances» es una palabra prestada
  Decisión de Jürgen: opción B (recomendada). Misma solución que L11-1 (iconos, nombre solo en la elegida) y «Balances» → «Saldos».
- **L12-3** · `tablero-ux-2-2-l12-3-un-ultimo-paso-continuar-no-cx3v`
  UX 2.2 · L12-3 · «Un último paso · Continuar» no dice qué paso es
  Decisión de Jürgen: opción B (recomendada). «Acepta cómo se guardan tus grupos» y «Ver y aceptar».
- **L12-4** · `tablero-ux-2-2-l12-4-el-paso-3-del-educativo-y-e-c42m`
  UX 2.2 · L12-4 · El paso 3 del educativo y el consentimiento cuentan lo mismo: dos pantallas para una sola decisión
  Decisión de Jürgen: opción B (recomendada). El paso 3 del educativo pasa a ser el consentimiento; la hoja aparte solo para quien no vio el educativo o debe re-aceptar.
- **L12-5** · `tablero-ux-2-2-l12-5-el-consentimiento-habla-de-7zoc`
  UX 2.2 · L12-5 · El consentimiento habla de «alias», repite el título y lleva cuatro iconos de información iguales en azul de sistema
  Decisión de Jürgen: opción B (recomendada). «tu nombre», icono propio por punto en índigo de la marca, un solo título (dentro del paso 3 por L12-4 B).
- **L12-6** · `tablero-ux-2-2-l12-6-puedes-cambiar-este-comport-wjjc`
  UX 2.2 · L12-6 · «Puedes cambiar este comportamiento en Ajustes de Grupos» no dice qué comportamiento
  Decisión de Jürgen: opción B (recomendada). La frase pasa al paso 2, pegada a la nota del registro personal.
- **L12-7** · `tablero-ux-2-2-l12-7-iniciar-sesion-con-apple-y-t4gw`
  UX 2.2 · L12-7 · «Iniciar sesión con Apple» y «Crear cuenta con Google»: dos verbos para lo mismo, y el título dos veces
  Decisión de Jürgen: opción B (recomendada). «Continuar con Apple/Google», línea «Si ya tienes cuenta, entras; si no, se crea» y un solo título.
- **L12-9** · `tablero-ux-2-2-l12-9-el-formulario-habla-como-un-zilq`
  UX 2.2 · L12-9 · El formulario habla como un contador: «Simplificar deudas», «Moneda única para deudas», «División predeterminada»
  Decisión de Jürgen: opción B (recomendada). Ejemplo en el nombre y las tres opciones plegadas en «Más opciones» con palabras de persona.
- **L12-11** · `tablero-ux-2-2-l12-11-si-para-crear-hubo-que-ini-y2hy`
  UX 2.2 · L12-11 · Si para crear hubo que iniciar sesión y aceptar, al terminar no vuelve al formulario
  Decisión de Jürgen: opción B (recomendada). Recordar la intención de crear y abrir el formulario al aceptar.
- **L12-12** · `tablero-ux-2-2-l12-12-crear-mi-primer-grupo-desd-mhtg`
  UX 2.2 · L12-12 · «Crear mi primer grupo» desde la bienvenida son 9 pantallas (10 sin cuenta) y «Crear mi grupo» abre otro formulario
  Decisión de Jürgen: opción B (recomendada). Saltar pasos 1 y 2 del educativo en esta rama, nombre dentro del formulario y obligatorio (~6 pantallas).
- **L13-8** · `tablero-ux-2-2-l13-8-desde-el-panel-sin-grupos-g-5tex`
  UX 2.2 · L13-8 · Desde el Panel sin grupos, «Grupo» lleva a «¿Cómo funcionan los grupos?» y el formulario aparece después, sin explicarlo
  Decisión de Jürgen: opción B (recomendada). Hoja «Para dividir un gasto, primero crea un grupo» con «Crear grupo»; luego el gasto sigue avisado.

## Avisos de esta sesión
- **Alineación visual pendiente.** Las cards «Grupos tiene que sentirse la misma app» (`tablero-grupos-tiene-que-sentirse-la-misma-app-a-k2up`) y «Flujo de caja tiene que sentirse la misma app» (`tablero-flujo-de-caja-tiene-que-sentirse-la-mism-e7by`) son propuestas visuales que se preparan en la sesión lote-decidido-2-2-02. Antes de empezar, mira con `tablero ver` en qué estado están. Si Jürgen ya eligió (nota con su decisión), aplica lo elegido a las pantallas que toques en esta sesión. Si siguen en «espera decisión», implementa las cards de abajo con los componentes, filas, tarjetas y cabeceras que ya usan Registros y Estadísticas (sin estilo nuevo propio) y no hagas el rediseño general: eso queda para cuando Jürgen elija.
- L12-4, L12-5 y L12-6 tocan el mismo educativo: el paso 3 pasa a ser el consentimiento (L12-4), con «tu nombre» e iconos índigo propios (L12-5), y la frase de Ajustes de Grupos baja al paso 2 (L12-6). Hazlas juntas.
- L12-7: «Continuar con Apple/Google»; si la sesión 04 (L19-17) ya creó esas claves, reutilízalas.
- L12-1 usa la misma solución de L11-1 (ya en 2.2): reutilízala.

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

## Punto extra a revisar (Jürgen 20-oct 08:01, del QA)
Último paso del onboarding de Grupos sin sesión: «Crear mi cuenta» (abre el alta) e «Ir a Grupos» (cierra y deja en Grupos, que muestra de inmediato su propio «Crear mi cuenta») se sienten como el mismo destino. Revisa junto con la card del paso 3 del educativo. Si toca diseño, deja propuestas (p. ej. secundario «Ahora no» o un solo botón) y espera la decisión de Jürgen.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, de día): lo que la decisión de Jürgen no fija se toma del sistema de diseño o del
> comportamiento que ya hay. Lo que cambia lo que ve el usuario y no sale de ninguna decisión, a una card en «espera
> decisión».

- **D1 · Base.** Rama sobre `origin/2.2` (6fa0777c7). El PR #588 (lote 12 decidido, en cola de auto-merge) toca
  `GroupDetailView`, `GroupsContainerView` y los 16 `Localizable.strings`: se rebasa una vez antes de abrir el PR y los
  conflictos se resuelven entonces. Las claves nuevas van en un fichero propio (`L10n+UXAudit22Lote13Decididas.swift`).
- **D2 · Alineación «Una sola Yala».** Está decidida (todas las recomendadas, 19-oct). De lo que toca esta sesión solo
  coincide la fila de pestañas del detalle del grupo, que ya es L12-1 B («chip de Estadísticas»). El resto de la card
  (cifra grande, fila, color de montos, Ajustes como lista) no toca estas pantallas y se queda en su card.
- **D3 · L12-1.** Mismo dibujo que L11-1 en `DetailContainerView` (icono en las tres, nombre solo en la elegida, nombre
  para VoiceOver). «Balances» → «Saldos» en los cuatro españoles (pestaña y título de su pantalla); en los otros 12 ya
  dice «saldo» en su idioma. Las otras frases con «balance» del español (archivar, «Tu balance») no son la pestaña: fuera.
- **D4 · L12-4 + L12-5 + L12-6, juntas.** El paso 3 del educativo enseña los cuatro puntos del consentimiento (un icono
  propio por punto en índigo: nube, persona, candado, salida; «tu nombre» en vez de «tu alias») bajo un solo título, y
  su botón principal es «Aceptar y continuar» cuando hay que aceptar (canal de Grupos encendido y sin consentimiento
  válido). Aceptar registra el consentimiento por el mismo escritor que la hoja (`GroupsConsentRegistrar.register`) y
  después sigue: sin sesión, a la cuenta; con sesión, a Grupos. Sin sesión el consentimiento queda sin sello y lo sella
  `handleSignIn` al entrar (mecanismo que ya existe para el legacy). Con el consentimiento ya válido el paso 3 informa
  y su botón sigue siendo «Ir a Grupos». La hoja aparte se queda para quien no vio el educativo o tiene que volver a
  aceptar (los productores de `.presentGroupsConsent` no cambian). La hoja: un solo título (el de dentro), mismos
  iconos y textos. Sin degradados en el paso 3 (criterio de Jürgen). La frase de Ajustes de Grupos baja al paso 2,
  pegada a la nota del registro personal.
- **D5 · Punto extra (los dos botones del último paso).** Con D4 el principal pasa a «Aceptar y continuar» y el
  secundario «Ir a Grupos» se queda como está (sale sin aceptar). Qué hacer con el secundario cambia lo que ve el usuario
  y no lo fija ninguna decisión: card nueva a `jurgen` en «espera decisión» con tres opciones (dejarlo, «Ahora no», un
  solo botón). Solo se para ese ítem.
- **D6 · L12-7.** Los botones ya dicen «Continuar con Apple/Google» (L19-17, se reutiliza). Falta la línea «Si ya tienes
  cuenta, entras; si no, se crea» bajo los botones y un solo título: se quita el de la barra y queda el de dentro.
- **D7 · L12-9.** Solo el formulario de crear (es su único uso). Ejemplo en el nombre («Ej.: Viaje a Cusco») y las tres
  opciones plegadas en «Más opciones» con los textos de la decisión, en claves nuevas para no tocar los de Ajustes del
  grupo, que el lote 12 (#588, L19-7) ya cambió con otro texto. La diferencia de palabras entre los dos sitios es de
  dos decisiones distintas y se dice en el PR.
- **D8 · L12-11.** La intención de crear vive en `SceneNavigation` (estado de navegación de la ventana). La arma
  `requestCreateGroup` cuando manda a cuenta o consentimiento; la consume la cadena al terminar (cuenta → consentimiento
  si falta → formulario); un cancelar la retira. La de la invitación no cambia.
- **D9 · L12-12.** En la rama «Crear mi primer grupo» el educativo arranca en el paso 3 (ya eligió grupos). El nombre de
  la persona va dentro del formulario («Tu nombre en el grupo»), obligatorio: el formulario de esta rama es una pantalla
  completa propia sobre el Welcome que sustituye a «¿Cómo te llamas?» y que, al tocar Crear, escribe el alta
  (`GroupsOrganizerOnboarding.completeSetup`, su único llamador) y crea el grupo en el mismo gesto. Si el alta ya está
  escrita y crear falla, el formulario dice el error y deja reintentar; cerrarlo deja en Grupos (como hoy al cancelar el
  formulario tras el nombre). `GroupsOrganizerNameView` se retira.
- **D10 · L13-8.** Sin ningún grupo activo, «Grupo» del FAB abre una hoja en la pantalla donde está el FAB («Para
  dividir un gasto, primero crea un grupo» · «Crear grupo»). «Crear grupo» lleva al formulario de Grupos y, al crearlo,
  abre el gasto con el aviso «Ahora apunta el gasto» (sin la hoja de invitar en medio: el gasto es lo que se vino a
  hacer). Cancelar el formulario retira el gasto pendiente: no vuelve a saltar horas después. Con grupos solo pendientes
  de aprobación el comportamiento no cambia (no lo decide L13-8 B): queda anotado.
- **D11 · Review adversarial.** Sí, sobre la cadena del consentimiento (D4, D8, D9): toca el registro legal del
  consentimiento y el alta del organizador. El resto es texto y layout.

## Resultado (2026-10-21)

Las 10 cards implementadas tal como las decidió Jürgen (todas B). Un ítem queda en «espera decisión»: el segundo
botón del último paso del educativo (punto extra, card `tablero-ux-2-2-ultimo-paso-del-educativo-de-grup-ldqu`).

- **L12-1** · pestañas del grupo con icono y nombre solo en la elegida (el dibujo de L11-1); «Balances» → «Saldos».
- **L12-3** · el botón del estado vacío del consentimiento dice «Ver y aceptar».
- **L12-4 + L12-5 + L12-6** · el paso 3 del educativo es el consentimiento («Grupos en la nube», cuatro puntos con
  icono propio en índigo, «tu nombre», «Aceptar y continuar»); aceptar sin sesión sigue directo a la cuenta. La hoja
  aparte se queda para quien no vio el educativo o vuelve a aceptar, con un solo título. La frase de Ajustes de
  Grupos bajó al paso 2. Sin degradado en el paso 3.
- **L12-7** · «Si ya tienes cuenta, entras; si no, se crea.» bajo «Continuar con Apple/Google» (claves de L19-17
  reutilizadas) y un solo título.
- **L12-9** · nombre con ejemplo («Ej.: Viaje a Cusco») y las tres opciones plegadas en «Más opciones».
- **L12-11** · crear sin cuenta o sin consentimiento recuerda la intención y abre el formulario al terminar.
- **L12-12** · «Crear mi primer grupo» arranca el educativo en su paso 3 y el formulario pide «Tu nombre en el grupo»
  (obligatorio); «¿Cómo te llamas?» se retiró. Al crear, Grupos propone invitar (L12-10).
- **L13-8** · sin grupos, «Grupo» del botón + abre «Para dividir un gasto, primero crea un grupo» · «Crear grupo»;
  al crearlo se abre el gasto con «Ahora apunta el gasto»; cancelar no deja nada pendiente.

Review adversarial (3 lentes: consentimiento, navegación, alta). Arreglado: el consentimiento sin sello se retira en
las fronteras de persona y conserva su `path`; se sella también al abrir Grupos con sesión; la hoja de invitar y el
aviso de notificaciones ya no chocan con el formulario de la bienvenida; la intención de crear se busca y se retira en
todas las ventanas; el educativo no se cruza con «Crear grupo»; el alta solo se escribe con el canal encendido; la
«X» del formulario espera a que termine el guardado. Residuales con ticket: ver «Encontrado» del PR.
