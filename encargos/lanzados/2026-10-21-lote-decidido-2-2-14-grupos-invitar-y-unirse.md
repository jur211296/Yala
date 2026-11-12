# Auditoría UX 2.2 · decidido por Jürgen · 14 · Grupos: invitar, la web de invitación, unirse, aprobar solicitudes y avisos

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-12-grupos/informe.md`, `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-19-grupos-iii/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (11)
- **L12-8** · `tablero-ux-2-2-l12-8-el-permiso-de-avisos-de-gru-d4ad`
  UX 2.2 · L12-8 · El permiso de avisos de grupo se pide en una alerta suelta, en cuanto aparece el primer grupo
  Decisión de Jürgen: opción B (recomendada). Permiso dentro de «‘X’ está listo» (L12-10) o «¡Todo listo!» (L12-18), con su línea de por qué.
- **L12-14** · `tablero-ux-2-2-l12-14-el-enlace-se-manda-solo-si-x468`
  UX 2.2 · L12-14 · El enlace se manda solo, sin un texto que diga qué es ni qué hacer
  Decisión de Jürgen: opción B (recomendada). Compartir mensaje con el enlace y la instrucción de volver a tocarlo tras instalar.
- **L12-15** · `tablero-ux-2-2-l12-15-la-web-de-invitacion-no-di-aw34`
  UX 2.2 · L12-15 · La web de invitación no dice qué hacer tras instalar ni quién invita, y «Abrir en Yala» falla sin la app
  Decisión de Jürgen: opción B (recomendada). «Lucía te invita» en la tarjeta, dos pasos numerados y «Abrir en Yala» como segundo botón.
- **L12-16** · `tablero-ux-2-2-l12-16-pega-tu-enlace-no-tiene-bo-0xrh`
  UX 2.2 · L12-16 · «Pega tu enlace» no tiene botón de pegar y rechaza el mensaje de WhatsApp entero
  Decisión de Jürgen: opción B (recomendada). Botón «Pegar» del sistema y extraer el enlace de Yala de cualquier texto pegado.
- **L12-17** · `tablero-ux-2-2-l12-17-se-pide-cuenta-y-consentim-046l`
  UX 2.2 · L12-17 · Se pide cuenta y consentimiento antes de enseñar a qué grupo te unes
  Decisión de Jürgen: opción B (recomendada). Primera pantalla = tarjeta del grupo (nombre, quién invita, miembros) con «Unirme»; después cuenta y consentimiento.
- **L12-18** · `tablero-ux-2-2-l12-18-todo-listo-no-dice-a-que-g-7xnd`
  UX 2.2 · L12-18 · «¡Todo listo!» no dice a qué grupo entraste ni qué hacer ahora
  Decisión de Jürgen: opción B (recomendada). «Ya estás en «X»», miembros, «Apuntar un gasto» y «Ver el grupo»; aquí se pide el permiso de avisos (L12-8).
- **L12-19** · `tablero-ux-2-2-l12-19-mientras-se-conecta-la-pes-ibn0`
  UX 2.2 · L12-19 · Mientras se conecta, la pestaña dice «Sin grupos · Crea un grupo» debajo de «Conectando con tu grupo…»
  Decisión de Jürgen: opción B (recomendada). Estado propio «Tu grupo está en camino» con el chip y sin ofrecer crear.
- **L12-20** · `tablero-ux-2-2-l12-20-al-que-espera-aprobacion-s-ywm1`
  UX 2.2 · L12-20 · Al que espera aprobación se le pide volver a mirar y no se le avisa; y hay dos textos para lo mismo
  Decisión de Jürgen: opción B (recomendada). Aviso al ser aprobado y los dos textos → «Te avisaremos cuando te aprueben».
- **L12-21** · `tablero-ux-2-2-l12-21-jerga-y-frases-raras-en-lo-i2fw`
  UX 2.2 · L12-21 · Jerga y frases raras en los avisos: «Pídele al admin que regenere uno», «se sincronizan con un iCloud»
  Decisión de Jürgen: opción B (recomendada). «Pídele a quien te invitó un enlace nuevo» y «…con una cuenta de iCloud…».
- **L19-1** · `tablero-ui-2-2-l19-1-una-solicitud-para-unirse-e-giwy`
  UI 2.2 · L19-1 · Una solicitud para unirse es un punto rojo, y se acepta con dos iconos sin texto
  Decisión de Jürgen: opción D, variante 3 (recomendada): aviso «X quiere unirse · Revisar» dentro del grupo y tarjeta «Quieren unirse» en Miembros con «Aceptar»/«Rechazar» y la consecuencia (L19-1-C.png).
- **L19-2** · `tablero-ux-2-2-l19-2-carla-entra-con-saldo-inici-vywm`
  UX 2.2 · L19-2 · «¿Carla entra con saldo inicial?» es jerga, y casi nadie lo necesita
  Decisión de Jürgen: opción B (recomendada). «¿Carla ya tenía cuentas pendientes con el grupo?» con «Sí, apuntarlo» / «No, empieza en cero».

## Avisos de esta sesión
- **Alineación visual pendiente.** Las cards «Grupos tiene que sentirse la misma app» (`tablero-grupos-tiene-que-sentirse-la-misma-app-a-k2up`) y «Flujo de caja tiene que sentirse la misma app» (`tablero-flujo-de-caja-tiene-que-sentirse-la-mism-e7by`) son propuestas visuales que se preparan en la sesión lote-decidido-2-2-02. Antes de empezar, mira con `tablero ver` en qué estado están. Si Jürgen ya eligió (nota con su decisión), aplica lo elegido a las pantallas que toques en esta sesión. Si siguen en «espera decisión», implementa las cards de abajo con los componentes, filas, tarjetas y cabeceras que ya usan Registros y Estadísticas (sin estilo nuevo propio) y no hagas el rediseño general: eso queda para cuando Jürgen elija.
- **L12-15** toca la web de invitación en `Web/`, no solo la app: build de la web en local y capturas; no despliegues a producción (si hace falta, card a `jurgen`).
- L12-8 pide el permiso de avisos dentro de «‘X’ está listo» (L12-10, ya en 2.2) o «¡Todo listo!» (L12-18): hazlas juntas.
- L12-20 añade un aviso al ser aprobado: si necesita backend/push nuevo en producción, déjalo listo y en card a `jurgen`.
- L19-1 tiene variante elegida (L19-1-C.png en ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-19-grupos-iii/capturas/).

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

**Ficheros que se tocan (nota, no pregunta):** `GroupsContainerView` (alerta suelta fuera, estado «en camino»), `GroupCreatedInviteSheet`, `GroupInviteOnboardingView` (tarjeta del grupo primero, «Ya estás en «X»», solicitud enviada), `GroupsBackendInviteModifier`/`ContentView` (la tarjeta antes de la cuenta), `GroupBackendInviteEntryHandler` + `GroupBackendInviteEntryLogic` (paso nuevo), `PendingJoinStore` (marca de «dijo Unirme en la tarjeta»), `InviteLinkService.BrandedMetadata` (quién invita), `GroupMembersView`/`GroupMemberRow`/`GroupDetailView` (solicitudes), `GroupsSyncClient`/`GroupNotificationService` (aviso al ser aprobado), `InviteRecoveryView` (Pegar), `GroupsEmptyStepsCard`, `SceneNavigation`, `Web/src/pages/invite.astro` + `Web/src/i18n/translations.ts`, lógica pura nueva con sus tests, `L10n` del lote y los 16 `Localizable.strings`.

**D1 · Rediseño «Una sola Yala» (decidido el 19-oct).** → No se aplica aquí: sus seis piezas (pastilla Te deben/Debes, fila de Presupuestos, cifra de Gastos y Saldos, cápsula de Estadísticas, tira de meses, gráficas) no viven en las pantallas de esta sesión, y su card sigue en «ready to launch» con sesión propia. Lo nuevo usa piezas que ya existen (tarjeta de cristal de los estados vacíos, `YalaPrimaryButton`, la tarjeta índigo de invitar, rosa de marca para lo que pide atención). Sin degradados ni blanco sólido.

**D2 · L12-8, dónde va el permiso.** → Una tarjeta «Avisos del grupo» con la línea de por qué («Te avisamos cuando alguien apunte un gasto o te pague») y «Activar avisos», dentro de «“X” está listo» y de «Ya estás en «X»». Sale solo si los avisos de grupo no están ya activos con permiso del sistema; con permiso negado, «Abrir Ajustes». La alerta suelta de la lista se retira. **Asumido:** la misma tarjeta va también en «Solicitud enviada», porque L12-20 promete «Te avisaremos cuando te aprueben» y sin permiso esa frase sería falsa (completa lo que nombra la decisión, no añade una pantalla).

**D3 · L12-14, el mensaje.** → «Lucía te invita a «Depa Miraflores» en Yala para dividir los gastos. Toca el enlace para entrar; si no tienes Yala, descárgala y vuelve a tocarlo.» + el enlace en la línea siguiente, en las tres salidas de compartir (hoja «está listo», Miembros, fila de invitar del detalle). Sin nombre en el perfil: «Te invitan a «X» en Yala…».

**D4 · L12-15, la web.** → «Lucía te invita» en la tarjeta, pasos «1 · Descarga Yala» y «2 · Vuelve aquí y toca «Abrir en Yala»», «Descargar en App Store» primero y «Abrir en Yala» como segundo botón, en los 6 idiomas de la web. **Asumido:** «Abrir en Yala» lleva también nombre, icono, color, miembros y quién invita (hoy solo lleva `s`): sin eso la tarjeta del grupo de L12-17 saldría genérica justo para quien llega por la web. Sin despliegue: card a `jurgen`.

**D5 · L12-16.** → `PasteButton` del sistema junto al campo (no pide permiso del portapapeles) y extracción del primer enlace de Yala de cualquier texto, pegado o escrito; el campo se queda con el enlace limpio.

**D6 · L12-17, el orden.** → Sin cuenta o sin consentimiento, la primera pantalla de la invitación es la tarjeta del grupo (icono, nombre, «Lucía te invita», miembros) con el campo de nombre y «Unirme»; ese toque apunta en la invitación que dijo que sí a la tarjeta y sigue a cuenta y consentimiento; al volver, la unión arranca sola con el nombre que escribió (sin repetir «Unirme»). Con cuenta y consentimiento, la misma tarjeta une directamente. La puerta del teléfono con datos de otra persona va DESPUÉS de la tarjeta. «Unirme» en la tarjeta NO sella la confirmación del join (la sigue sellando el toque que une), para que el alta del invitado nuevo siga corriendo donde corre hoy. Descartado: mover el alta antes de la cuenta (dejaría un alta sin sesión si cancela el inicio de sesión).

**D7 · L12-18.** → «Ya estás en «X»», «Con Ana y Beto» (miembros activos del grupo; si aún no bajaron, los del enlace), «Apuntar un gasto» (abre el formulario de gasto con ese grupo) y «Ver el grupo», más la tarjeta de avisos (D2).

**D8 · L12-19.** → Con la lista vacía y una unión en curso (conectando, esperando aprobación o error que se puede reintentar), la tarjeta de cristal dice «Tu grupo está en camino» + «Aparecerá aquí en cuanto esté listo.», sin pasos y sin botón de crear; el chip sigue arriba. Invitación caducada o rechazada sin remedio: el estado vacío de siempre.

**D9 · L12-20.** → Medido: el servidor YA manda un aviso al aprobado (`approve_member` → audiencia `member`, texto genérico «Novedades sobre tu membresía en un grupo», con eco silencioso). No hace falta backend nuevo: la app, al bajar su propio miembro de «pendiente» a «activo», avisa «Ya estás en «X»» (aviso local, con los avisos de grupo activos). Los dos textos acaban en «Te avisaremos cuando te aprueben.».

**D10 · L12-21.** → Exactamente las dos frases: «Pídele a quien te invitó un enlace nuevo.» y «…con una cuenta de iCloud…».

**D11 · L19-1 (variante 3, L19-1-C).** → Dentro del grupo, para quien puede aprobar: tarjeta rosa «Carla quiere unirse · Acepta su solicitud para que vea y apunte gastos.» con «Revisar» (abre Miembros); con varias, «N personas quieren unirse». En Miembros, sección «Quieren unirse (N)» arriba con una tarjeta por persona: nombre, «Abrió tu enlace de invitación hoy/ayer/el 12 oct», «Si aceptas, verá los gastos del grupo y podrá apuntar los suyos. Si rechazas, no verá nada.», «Aceptar» (rosa, relleno) y «Rechazar». Las confirmaciones de aceptar/rechazar que ya existen se quedan. El punto del botón de Miembros se queda (sale en la variante). Neutro de género en las frases que la maqueta dice con «la».

**D12 · L19-2.** → Título «¿Carla ya tenía cuentas pendientes con el grupo?», texto «Si antes de unirse ya debía algo, o le debían, apúntalo para que los saldos cuadren.», «Sí, apuntarlo» / «No, empieza en cero». es-AR con voseo.

**D13 · Review adversarial.** → Sí para D6 y D9 (flujo de invitación y sync de Grupos, donde un fallo deja a alguien fuera del grupo o con dos uniones). Lentes: presentaciones que se pisan en el ancla de `ContentView`, uniones dobles o perdidas tras matar la app, avisos duplicados o a la persona equivocada.

**D14 · QA en iPhone.** → El aviso real al ser aprobado (D9) y el enlace por WhatsApp con la web (D3-D4) necesitan teléfono y web desplegada: esas cards van a `in qa` para Jürgen con guion. El resto se prueba en el simulador.

**D15 · Lo que encontró la review adversarial (3 lentes) y qué se hizo.** → Arreglado: la unión automática al volver de cuenta y consentimiento podía arrancar días después sin un toque (la marca de la tarjeta vivía 7 días) → solo une sola si el «Unirme» de la tarjeta fue hace menos de 30 min; si no, vuelve la tarjeta con «Unirme» y «Más tarde». Una vuelta a primer plano con la tarjeta delante dejaba otra petición en cola y la tarjeta salía dos veces → el drenado de `ContentView` y la propia hoja siguen la cadena si la tarjeta ya se aceptó. «Ya estás en «X»» salía además del aviso genérico del servidor → al publicarlo se retira el genérico entregado. Con el permiso de iOS negado, «Abrir Ajustes» no encendía el aviso de grupos de Yala → lo enciende y la tarjeta vuelve a medir al volver. «Apuntar un gasto» pedía el formulario con la hoja aún cerrándose y podía decidir con la caché de miembros vieja → se aplica en el `onDismiss` del cover y la pestaña recarga antes de decidir. Fuera, con su ticket y card: quien llega a su primer grupo por otro camino ya no ve la pregunta de avisos (`groups-notifications-permission-skipped-when-the-group-arrives-another-way`, decisión de Jürgen) y la puerta del teléfono con datos olvida el «Unirme» de la tarjeta (`invite-neutral-gate-forgets-the-group-card-answer`).

**D16 · L19-2 en el simulador.** → Aceptar una solicitud en un grupo de la nube pide el servidor, así que la pregunta de cuentas pendientes se abre con el seam `-uitest-opening-balance-prompt`. El botón «Pegar» de L12-16 es el control del sistema y no acepta toques sintéticos: su toque va al guion de iPhone; el XCUITest cubre la extracción del enlace escribiendo el mensaje entero.

## Resultado

- Las 11 cards hechas como las decidió Jürgen (L19-1 con la variante 3, el resto opción B). Cuatro se cierran en el
  barrido (L12-19, L12-21, L19-1, L19-2); siete van a `in qa` para Jürgen con el guion
  `docs/qa/tanda-qa-jurgen-2.2-lote14-grupos-invitar.md` (cuenta real, dos dispositivos, push o la web publicada).
- La web de invitación (L12-15) está en `Web/` y compila; **sin desplegar**: card a Jürgen «Publicar la web de
  invitación» con los pasos.
- L12-20 sin backend nuevo: el servidor ya avisaba al aprobado con un texto genérico; la app lo sustituye por «Ya estás
  en «X»».
- Textos nuevos y cambiados en los 16 idiomas (script idempotente; paridad en verde) y la web en sus 6.
- Tests: `YalaTests` completo (11 053) y XCUITest de las 63 suites de las áreas tocadas (252 casos, centinela limpio);
  nuevos `UXAudit22Decidido14Tests` (lógica, el manejador con la tarjeta delante y cableado) y
  `UXAudit22Decidido14UITests` (7 flujos), más tres casos en `GroupsSyncClientTests`. Dos mutantes muertos (quitar la
  tarjeta de `drive`, quitar el apunte de la aprobación). De paso, `GroupsSmokeUITests` vuelve a verde: el lote 13
  escondió la moneda única tras «Más opciones» y no lo había actualizado.
- Review adversarial con tres lentes: cinco arreglos (D15) y dos tickets con card.
- Capturas antes/después: `/Users/jur/Claude/entregas/Yala--lote-decidido-2-2-14-grupos-invitar-y-unirse/capturas/`
  (copia en `~/Claude/worktrees/_capturas/2026-10-21-lote-decidido-2-2-14-grupos-invitar-y-unirse/`).
