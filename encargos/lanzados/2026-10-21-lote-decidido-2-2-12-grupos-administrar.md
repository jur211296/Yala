# Auditoría UX 2.2 · decidido por Jürgen · 12 · Grupos: administradores, quitar miembros, archivar, eliminar, salir y presupuesto del grupo

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-19-grupos-iii/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (11)
- **L19-3** · `tablero-ux-2-2-l19-3-no-se-puede-hacer-administr-ivwq`
  UX 2.2 · L19-3 · No se puede hacer administrador a nadie en un grupo de la nube
  Decisión de Jürgen: opción B (recomendada). Cambio de rol en el servidor, «Hacer/Quitar como administrador» con confirmación de permisos, y una sola palabra para el rol. Toca backend de Grupos: review adversarial.
- **L19-4** · `tablero-ux-2-2-l19-4-quitar-a-alguien-que-debe-n-fa90`
  UX 2.2 · L19-4 · Quitar a alguien que debe no dice cuánto ni a quién
  Decisión de Jürgen: opción C (recomendada). Aviso con la cifra y el sentido, «Quitar a X» y «Saldar primero».
- **L19-5** · `tablero-ui-2-2-l19-5-archivar-desarchivar-y-elim-p2d3`
  UI 2.2 · L19-5 · Archivar, desarchivar y eliminar salen en rojo, igual de graves
  Decisión de Jürgen: opción B, variante 1 (recomendada): tarjeta «Archivar o eliminar» con dos pesos (L19-5-A.png).
- **L19-6** · `tablero-ui-2-2-l19-6-el-presupuesto-del-grupo-se-0d53`
  UI 2.2 · L19-6 · El presupuesto del grupo se teclea en una alerta, sin decir qué pasa al llegar al tope
  Decisión de Jürgen: opción D, variante 3 (recomendada): hoja con monto grande, qué pasa y vista previa de lo gastado contra la cifra (L19-6-C.png).
- **L19-7** · `tablero-ux-2-2-l19-7-las-opciones-del-grupo-habl-9y48`
  UX 2.2 · L19-7 · Las opciones del grupo hablan en jerga, y el nombre no parece editable
  Decisión de Jürgen: opción C (recomendada). Textos con ejemplo, una palabra para el rol y lápiz junto al nombre.
- **L19-8** · `tablero-ux-2-2-l19-8-archivar-sin-deudas-no-preg-55n8`
  UX 2.2 · L19-8 · Archivar sin deudas no pregunta ni avisa: el grupo desaparece
  Decisión de Jürgen: opción B (recomendada). Aviso «Lo moviste a Archivados · Deshacer».
- **L19-9** · `tablero-ux-2-2-l19-9-un-grupo-archivado-no-lo-di-vow2`
  UX 2.2 · L19-9 · Un grupo archivado no lo dice, y su deuda deja de sumar
  Decisión de Jürgen: opción B (recomendada). Aviso «Grupo archivado · Desarchivar» en el detalle y línea bajo el total con la deuda de los archivados.
- **L19-10** · `tablero-ux-2-2-l19-10-eliminar-bloqueado-no-dice-5jaf`
  UX 2.2 · L19-10 · «Eliminar» bloqueado no dice qué saldo lo bloquea, y a veces son dos céntimos
  Decisión de Jürgen: opción C (recomendada). Nombrar quién debe y cuánto con «Ver los saldos» y no contar el residuo de redondeo como deuda. Cálculo financiero: review adversarial.
- **L19-11** · `tablero-ux-2-2-l19-11-salir-o-eliminar-no-dicen-0fz1`
  UX 2.2 · L19-11 · Salir o eliminar no dicen qué pasa con tu dinero
  Decisión de Jürgen: opción C (recomendada). Avisos con la cifra y el efecto, y «Saldar primero» al salir con deuda.
- **L19-13** · `tablero-ux-2-2-l19-13-los-grupos-que-no-se-pudie-ufkf`
  UX 2.2 · L19-13 · Los grupos que no se pudieron dejar dicen «Eres administrador y hay otros miembros»
  Decisión de Jürgen: opción C (recomendada). Texto con el motivo real y un botón por grupo que abre sus ajustes; ajustar el texto si L19-3 (cambio de administrador) aterriza.
- **L19-14** · `tablero-ux-2-2-l19-14-desasociar-la-cuenta-de-gr-fdqr`
  UX 2.2 · L19-14 · Desasociar la cuenta de grupos se explica con jerga y dos salidas difíciles
  Decisión de Jürgen: opción C (recomendada). Texto nuevo y dos salidas con su efecto y su cifra.

## Avisos de esta sesión
- **Alineación visual pendiente.** Las cards «Grupos tiene que sentirse la misma app» (`tablero-grupos-tiene-que-sentirse-la-misma-app-a-k2up`) y «Flujo de caja tiene que sentirse la misma app» (`tablero-flujo-de-caja-tiene-que-sentirse-la-mism-e7by`) son propuestas visuales que se preparan en la sesión lote-decidido-2-2-02. Antes de empezar, mira con `tablero ver` en qué estado están. Si Jürgen ya eligió (nota con su decisión), aplica lo elegido a las pantallas que toques en esta sesión. Si siguen en «espera decisión», implementa las cards de abajo con los componentes, filas, tarjetas y cabeceras que ya usan Registros y Estadísticas (sin estilo nuevo propio) y no hagas el rediseño general: eso queda para cuando Jürgen elija.
- **L19-3** toca el backend de Grupos (cambio de rol en el servidor) y **L19-10** el cálculo de deudas (residuo de redondeo): review adversarial antes del PR de los dos (quién puede cambiar roles, el último administrador no se queda sin sucesor, el residuo no esconde una deuda real).
- Backend: migración y función en local/staging; nada en producción. Si hace falta desplegar algo a producción, déjalo listo en una card a `jurgen` en «ready to launch» y sigue.
- L19-13: ajusta el texto según aterrice L19-3 en esta misma sesión.
- L19-5 y L19-6 tienen variante elegida con captura en ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-19-grupos-iii/capturas/.

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
> Base: `origin/2.2` (rama re-creada sobre ella antes del primer commit).

**D1 · Alineación visual («Una sola Yala», decidida el 19-oct: todas las recomendadas).** → Se aplica a las dos hojas que esta sesión reescribe: **Ajustes del grupo y Miembros pasan a la lista agrupada** (`YalaSettingsList`, como «Ajustes de Grupos»), con el saldo de cada persona a la derecha en Miembros. La lista de grupos y el detalle solo reciben lo de L19-8/L19-9 (aviso, banner, línea bajo el total).
Por qué: el lienzo pide montar primero las piezas comunes (cifra de arriba, fila, color de montos) que comparten los lotes 12 y 13; hacerlas a medias aquí rompe ese orden. Alternativa descartada: rediseñar ya lista y detalle (es el trabajo de la card de alineación, no de las L19).

**D2 · L19-3, quién cambia roles en el servidor.** → RPC nuevo `set_member_role(p_group_id, p_member_key, p_role)`: lo llama cualquier administrador activo; el objetivo tiene que estar activo; **quien creó el grupo no se puede quitar como administrador** (y por eso el grupo nunca se queda sin uno); hacer administrador exige que la persona tenga cuenta (`user_id` no nulo: un hueco de un grupo migrado sin reclamar no puede administrar); idempotente si ya tiene ese rol; sin aviso push (los demás lo ven al sincronizar). Migración y banco en local; staging y producción, card a Jürgen.
Por qué: es la regla que ya aplica el camino local (`changeRole`: el dueño no se degrada, el último administrador no se quita). Alternativa descartada: que solo el creador cambie roles (la decisión B dice «Hacer/Quitar como administrador» sin acotarlo, y el creador ya tiene la protección).

**D3 · L19-3, «una sola palabra para el rol».** → «administrador» en todas partes: la insignia pasa de «Admin» a «Administrador»; «organizador» desaparece de Ajustes del grupo. Donde la regla es del creador (moneda única), el texto dice «quien creó el grupo».

**D4 · L19-10, qué es residuo de redondeo.** → Cuenta como deuda lo que aparece en las deudas de persona a persona, simplificadas (la misma fuente que «Están a mano» y Saldos); el saldo neto que no se lo debe nadie a nadie no bloquea. Lo usan el bloqueo de eliminar, el aviso de archivar, el de salir, el de quitar a alguien y `softDelete`. Falla cerrado ante un importe no finito.
Por qué: el caso medido (Beto, $ 0.02) es el descuadre entre el importe de un gasto y sus repartos, que nunca llega a las deudas. Alternativa descartada: **una tolerancia de céntimos por persona, que fue la primera versión y tumbó la review adversarial**: escondía una deuda real pequeña (una liquidación corta de 0.02 que Saldos sí enseña) y no perdonaba un residuo mayor (tres gastos de 10.00 a 3.33 dejan 0.03).

**D5 · L19-10/L19-5, el texto del bloqueo.** → «Desaparece para todos y no se puede deshacer. Beto debe $ 30.00 y Carla debe S/ 20.00. Cuando las cuentas queden en cero podrás eliminarlo.» + «Ver los saldos» (lleva a la pestaña Saldos del grupo). Con heredero, se conserva la frase de «Transferir y salir».

**D6 · L19-4 y L19-11, «Saldar primero».** → Si la deuda es entre tú y esa persona (o, al salir, tienes una sola deuda), abre «Saldar» con esa deuda; si no, lleva a Saldos. La cifra sale de las deudas que ya enseña el grupo (respeta «simplificar» y «moneda única»).

**D7 · L19-14, la cifra en los botones.** → La cifra va en el mensaje del diálogo, no en el texto del botón (un `confirmationDialog` con etiquetas que cambian es la familia del bug de alertas medido el 06-sep). Cuenta los gastos que pagaste (pata real) que se quedarían, con el total por divisa.

**D8 · L19-13 tras L19-3.** → Texto decidido (B) para los dos motivos de «nadie puede quedarse al frente»: «Lo creaste tú y nadie más puede quedarse al frente todavía. Ábrelo para archivarlo o eliminarlo.» y un botón por grupo que abre sus ajustes. Con L19-3, el heredero sigue siendo el administrador más antiguo y, si no hay, el miembro con cuenta más antiguo: el texto no cambia.

**D9 · L19-7, textos con ejemplo.** → Claves nuevas para Ajustes del grupo (no se tocan las del formulario de crear grupo, que son de L12-9).

**D10 · L19-6.** → Hoja con detents grandes, monto con la divisa del grupo, vista previa con lo gastado (`GroupBudgetLogic.progress`, `≈` si hubo conversión) y las dos frases de qué pasa. «Quitar presupuesto» se queda en su fila.

**D11 · L19-4, el botón «Quitar a X».** → El nombre va en el título del diálogo («¿Quitar a Ana del grupo?») y el botón dice «Quitar del grupo». Por qué: un texto de botón que depende del estado es la familia del bug medido el 06-sep en alertas (rompía flujos ajenos); el título dinámico está probado que no.

**D12 · L19-5, el texto de archivar (medido).** → La maqueta decía «Lo quitas de tu lista». Medido: `is_archived` viaja al servidor y archiva el grupo **para todos** (`GroupEntityEmissionMap`, `GroupsSyncClient.applyGroupMeta`). El texto dice lo que pasa: «Pasa a Archivados para todo el grupo. Los gastos y las deudas se guardan y puedes recuperarlo cuando quieras.»

**D13 · L19-3 tras la review de servidor.** → Quien sale o es expulsado deja de ser administrador (`remove_member` y `leave_group` ponen `role = 'member'`): sin eso, al volver a entrar y ser aprobado recuperaba el rol sin que nadie lo decidiera. El conteo del «último administrador» solo cuenta a quien tiene cuenta. Los tres rechazos del servidor tienen texto propio.

## Resultado

Cerrado por Frank el 2026-10-21. Las 11 cards implementadas tal cual la decisión; ninguna quedó en «espera decisión».

- **Done (10):** L19-4, L19-5, L19-6, L19-7, L19-8, L19-9, L19-10, L19-11, L19-13, L19-14 — XCUITest del flujo real
  (`GroupsLote19DecididoUITests`) o capturas antes/después en el simulador. Detalle en `docs/qa/tanda-qa-jurgen-2.2-lote19-grupos.md`.
- **In QA para Jürgen (1):** L19-3 en un grupo de la nube: necesita desplegar `g22_01` y el Worker (card
  `tablero-desplegar-cambiar-el-rol-de-un-miembro-g-pbcq`, ticket `groups-set-member-role-deploy`) y dos teléfonos.
- **Review adversarial** (L19-3 servidor y cliente, L19-10 cálculo): tumbó la tolerancia de céntimos (D4), encontró que el
  rol sobrevivía a salir del grupo, que el «último administrador» contaba huecos, que confirmar un cambio de rol podía
  aplicar el contrario si el pull llegaba con el diálogo abierto, y que el aviso de quitar/salir decidía por el saldo neto
  y enseñaba las deudas de dos en dos. Todo arreglado y con test.
- **Pruebas:** `YalaTests` entera en verde (11 047), 56 XCUITest de Grupos con el centinela limpio, banco SQL 80/80 con
  8 mutantes muertos, 2 mutantes de la regla del residuo muertos, gateway `npm test` en verde, `/l10n-check` limpio.
- **Encontrado y no tocado:** «Salir de todos mis grupos» y borrar la cuenta siguen contando el residuo (ticket
  `groups-own-debt-checks-still-count-rounding-residue`); en el canal de la nube, `removeMember` valida el último admin
  después del RPC (inalcanzable hoy: quien expulsa es admin); el rediseño de lista y detalle sigue en la card de alineación.
