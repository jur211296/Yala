# Auditoría UX 2.2 · decidido por Jürgen · 07 · Yala IA: un solo nombre, temas, nueva conversación, límites, tarjetas de registro, personalización y paywall

Base y PR: **2.2** (no 2.1). `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. El PR va contra **2.2**.

## Contexto
Jürgen respondió el 18-oct (18:41–21:18 Lima, sesión «preguntas-auditoria-ux-2-2») todas las cards de la auditoría UX 2.2 que esperaban decisión. Resumen completo: `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md`. Esta sesión implementa las de abajo, que están en «ready to launch» asignadas a frank, con la decisión en la nota de cada card.
Fuentes: la card (nota = decisión; contexto con capturas), el informe del lote en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-14-yala-ia/informe.md`, `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-16-ajustes/informe.md`, el HTML `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (opciones A/B/C/D y variantes) y los «Criterios UX/UI permanentes de Jürgen» del brief madre `~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md` (léelos: sin degradados, etc.). Las variantes elegidas (p. ej. «L17-2-B.png») están en `capturas/` de esa misma carpeta del lote.

## Cards de esta sesión (10)
- **L14-1** · `tablero-ux-2-2-l14-1-la-misma-funcion-tiene-siet-nq0e`
  UX 2.2 · L14-1 · La misma función tiene siete nombres según la pantalla
  Decisión de Jürgen: opción B (recomendada). «Yala IA» en todas partes, VoiceOver incluido.
- **L14-6** · `tablero-ux-2-2-l14-6-temas-repite-las-mismas-tre-unct`
  UX 2.2 · L14-6 · «Temas» repite las mismas tres sugerencias del saludo
  Decisión de Jürgen: opción B (recomendada). «Temas» por áreas con 2-3 ejemplos de los datos del usuario.
- **L14-7** · `tablero-ux-2-2-l14-7-reiniciar-contexto-de-conve-sgpy`
  UX 2.2 · L14-7 · «Reiniciar contexto de conversación» es jerga y borra la conversación entera sin preguntar
  Decisión de Jürgen: opción C (recomendada). «Nueva conversación» sin preguntar, con aviso «Conversación borrada · Deshacer».
- **L14-8** · `tablero-ux-2-2-l14-8-no-se-sabe-que-hay-un-limit-xyyz`
  UX 2.2 · L14-8 · No se sabe que hay un límite de preguntas hasta las últimas diez, ni cuándo se renueva
  Decisión de Jürgen: opción B (recomendada). Con el tope, la caja se apaga y dice que se renuevan a medianoche.
- **L14-9** · `tablero-ux-2-2-l14-9-la-tarjeta-de-registro-no-d-y9vp`
  UX 2.2 · L14-9 · La tarjeta de registro no dice si es gasto o ingreso, y con varios hay que guardar uno por uno
  Decisión de Jürgen: opción D (recomendada). Importe con signo y «Gasto/Ingreso» delante, más «Guardar los N» cuando hay varios completos.
- **L14-10** · `tablero-ux-2-2-l14-10-personalizar-ia-son-dos-me-nxuy`
  UX 2.2 · L14-10 · «Personalizar IA» son dos menús sin explicación, y en Ajustes no está el tono
  Decisión de Jürgen: opción C (recomendada). Hoja con las tarjetas de la presentación y nota nueva; fila «Tono de Yala IA» en Personalización y renombrar «Personalizar resumen de IA».
- **L14-11** · `tablero-ux-2-2-l14-11-privacidad-ia-usa-nombres-qwqf`
  UX 2.2 · L14-11 · Privacidad IA usa nombres internos, y deja aceptar el permiso de una función que no puedes usar
  Decisión de Jürgen: opción D (recomendada). Filas con lo que hacen y su línea, diálogo con el nombre de la función, y candado Pro en Yala IA para quien no lo tiene.
- **L14-12** · `tablero-ux-2-2-l14-12-un-usuario-pro-no-puede-oc-wd7k`
  UX 2.2 · L14-12 · Un usuario Pro no puede ocultar el botón de Yala IA
  Decisión de Jürgen: opción B (recomendada). El interruptor también para Pro, con el nombre «Yala IA».
- **L14-13** · `tablero-ux-2-2-l14-13-el-paywall-de-yala-ia-no-d-vvjd`
  UX 2.2 · L14-13 · El paywall de Yala IA no dice qué hace
  Decisión de Jürgen: opción C (recomendada). Reusar la demo animada del paso 1 de la presentación encima del botón.
- **L16-8** · `tablero-ux-2-2-l16-8-personalizar-resumen-de-ia-0sgg`
  UX 2.2 · L16-8 · «Personalizar resumen de IA» controla Estadísticas › Resumen, y casi nada es IA
  Decisión de Jürgen: opción B (recomendada). Línea «Lo ves en Estadísticas › Resumen» y marca de IA solo en Observaciones. Título: el de L14-10 C («Qué sale en el resumen»), salvo que Jürgen diga otra cosa.

## Avisos de esta sesión
- **L16-8**: el título de la hoja es el de L14-10 C («Qué sale en el resumen»), no el «Qué ver en Resumen» de su opción B.
- L14-1 «Yala IA» en todas partes, VoiceOver incluido; L11-8 (sesión 01) ya dejó «Resumen con IA» para la función de Estadísticas: no la pises.
- No cambies cuota, modelo, proveedor ni el flag de `chat.explore`. Yala IA con Grupos como contenedor aparte tiene su sesión más adelante (j): no la hagas aquí.

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

## Nota de Frank (20-oct 05:30)
- El PR #568 («Yala IA responde mejor: saldos del Panel, meses anteriores, «¿puedo gastar?» y más rápida») ya está mergeado en 2.2: cambió el ruteo, los prompts y el contexto de Yala IA. Parte de eso y no lo deshagas; si una card de este lote choca con lo que hizo, gana lo del #568 y lo anotas en el PR.
- Quedaron en espera decisión a nombre de `jurgen` tres preguntas de esa revisión (coste del contexto nuevo, micrófono del chat con el permiso de voz y spike de IA en el iPhone). No las decidas ni las implementes aquí; si un ítem de este lote depende de alguna, para solo ese ítem y anótalo en su card.

## Paso 0 (Frank, 2026-10-20)

Base: rama reseteada sobre `origin/2.2` (bb2e66a8c, #568 incluido). PR contra 2.2. Ficheros (nota, no pregunta): ChatSheetView, ChatTopicsSheet, AIPersonalizationSheet (+ vista compartida con el paso 3 de la presentación), YalaAIOnboardingView, ChatTransactionDraftCard, ChatAttachmentsView, ChatAssistantViewModel, AIPrivacySettingsView, PersonalizationSettingsView, SmartInsightsSettingsView, UpgradePromptSheet, FABStackView, un Logic nuevo de Temas, un L10n nuevo del lote, los 16 Localizable.strings, tests y coverage-index.

Decidido por la sesión (lo que la card no fija):
- **L14-1.** «Yala IA» (el `chat.assistantName` de cada idioma) sustituye a: «Pregúntale a Yala» (VoiceOver del botón flotante y el interruptor de Personalización), «Asistente de chat» (paywall), «Asistente financiero» (título del aviso de permiso; su texto legal no se toca: está fijado contra el anexo de docs/ai-cloud-vs-private-2026-10.md), «Asistente Pro» y «el Asistente» (Privacidad), «Tu asistente financiero» y «Toca IA» (tip del Panel), «Asistente financiero con IA» (bienvenida de Pro), «el asistente» (error sin conexión) y «asistente IA» (tarjeta del Welcome). No se tocan las notas de «Novedades» de versiones pasadas ni «Resumen con IA» (L11-8).
- **L14-6.** Los Temas se arman EN LOCAL con los datos del usuario (sin llamada nueva al modelo ni cambio de prompt): Gastos (siempre), Presupuestos (si hay activos), Pagos planificados (si hay activos) y Apuntar (siempre), 2-3 ejemplos cada una. Tocar un ejemplo de Apuntar lo escribe en la caja y abre el teclado, no lo envía: enviarlo apuntaría un gasto inventado.
- **L14-7.** «Nueva conversación» con el icono de redactar; el aviso es el mismo «· Deshacer» de la Bandeja (5 s). Deshacer devuelve la conversación si no se ha escrito nada nuevo; al cerrar el chat el aviso se va.
- **L14-8.** Con el tope, la caja enseña «Vuelve mañana: tus preguntas se renuevan a medianoche» en lugar del campo, y la línea de encima se quita para no repetir «vuelve mañana». Medido: la caja la apaga el contador del teléfono, que se renueva a medianoche local, así que la frase es cierta.
- **L14-6 (después).** Apuntar usa las subcategorías más apuntadas del mes, no las de más importe.
- **L14-9.** «Gasto»/«Ingreso» va delante del importe, en la misma línea, y el importe lleva el signo como en Registros (gasto en negativo, ingreso sin signo). «Guardar los N» va al pie de las tarjetas, solo con 2+ registros pendientes y completos; guarda uno tras otro por el mismo camino que «Guardar».
- **L14-10.** La hoja reusa el paso «Hazla a tu manera» de la presentación (L14-3: opciones rellenas y ejemplo combinado), extraído a una vista compartida. Título de la hoja = nombre de la fila nueva, «Tono de Yala IA». Nota: «Se aplica a Yala IA y al Resumen con IA de Estadísticas». Medido: el tono solo lo leen el chat, el Resumen con IA y Tendencias; el Panel no (la nota vieja decía «Hero del Panel» y la propuesta «saludo del Panel»). Nombre de L11-8, no «resumen inteligente».
- **L14-11.** Cada función en su bloque con su línea en el pie (el DS pide la ayuda en el pie, no en la fila). Sin Pro, la fila de Yala IA lleva la marca PRO y encenderla abre la hoja de Pro en vez del permiso; si el permiso ya estaba dado, se puede apagar igual.
- **L14-13.** La demo del paso 1 va en el sitio del icono de la hoja de Pro (arriba), como la vista previa de temas e iconos de L16-11: «encima del botón» se decidió cuando la hoja no tenía los planes entre medias.
- **L16-8.** Título y fila: «Qué sale en el resumen». Línea arriba con el camino armado de los títulos reales («Estadísticas › Resumen»). Marca de IA (destellos + «IA», la de Flujo de caja) solo en Observaciones.
