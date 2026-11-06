# Memoria de Frank — Yala

> **Límite: el índice se lee hasta ~24 KB.** Aquí solo va «Cómo trabaja Jürgen» y un puntero por tema; cada entrada
> nueva va a su subíndice. Si este fichero pasa de 20 KB, poda o mueve antes de añadir.

## Subíndices — ábrelos cuando el tema toque
- [Cómo mido y cómo entrego](indice_medir_y_entregar.md) — 76 entradas: tests, gate, CI, QA, telemetría, mutantes. Antes de medir o preparar QA.
- [Simulador y capturas](indice_simulador_y_capturas.md) — 85 entradas: axe, XCUITest conductor, iPad y Duo, capturas, vídeo, antes/después.
- [Lecciones de código y de copy](indice_lecciones_de_codigo.md) — 122 entradas: gates que fallan abiertos, techos, reintentos, herencias de moldes y de copy. Antes de diseñar un arreglo y en la review.
- [Estado del trabajo](indice_estado_del_trabajo.md) — 93 entradas de proyecto, con fecha: qué espera cada frente. Mide antes de actuar.
- [Entorno y herramientas](indice_entorno.md) — 20 entradas: máquina, hooks, accesos, disco.

## Cómo trabaja Jürgen
- [QA en Yala Dev antes que prod](feedback_qa_en_yala_dev_antes_que_prod.md) — TestFlight solo para lo que exige producción (App Store, attest enforce, StoreKit).
- [Sesión de rediseño](feedback_sesion_de_rediseno.md) — si el QA se vuelve producto, se sigue: acta en docs/sessions.
- [Diseña en lienzo antes de construir](feedback_disena_en_lienzo_antes_de_construir.md) — cita vaga de UI: 3-4 propuestas, elige él; el alcance crece.
- [«Creo que» no es aprobación](feedback_creo_que_no_es_aprobacion.md) — si no reconoce el componente, explicar antes de borrar.
- [Push: solo lo de la sesión](feedback_push_solo_lo_de_la_sesion.md) — lo pendiente de otros se deja y lo sube su agente.
- [Levanta sus propias reglas](feedback_jurgen_levanta_sus_reglas.md) — si te pide algo que un default tuyo prohíbe, se hace…
- [El test se para antes del último gesto](feedback_el_test_que_se_para_antes_del_ultimo_gesto.md) — recorre hasta la confirmación final y sal por Cancelar; B5 vivió semanas.
- [El tablero antes que el bug](feedback_el_tablero_antes_que_el_bug.md) — prefiere sanear el board antes que atacar producción.
- [El cierre incluye TICKETS.md y ticket por hallazgo](feedback_cierre_board_tickets_y_hallazgos.md) — mandato 6-sep: índice…
- [Tarjetas blancas: identidad](feedback_tarjetas_blancas_identidad.md) — cuándo un cambio visual toca identidad y no es polish.
- [Alcance mínimo, salvo incoherencia](feedback_alcance_minimo_salvo_incoherencia.md) — completar el objeto que su decisión n…
- [Autónomo es hasta el final](feedback_autonomo_hasta_el_final.md) — decide en bloque y suelta la ejecución; de día pregunto…
- [Prefiere lo limpio a lo defensivo](feedback_prefiere_lo_limpio_a_lo_defensivo.md) — retira el mecanismo que falla en vez d…
- [Cuándo la app pregunta al usuario](feedback_cuando_la_app_pregunta_al_usuario.md) — pregunta si la decisión mueve DATOS su…
- [Un límite de plataforma se explica en la pregunta](feedback_un_limite_de_plataforma_se_explica_en_la_pregunta.md) — preguntó por qu…
- [Credencial pendiente: se aparca y se mide](feedback_credencial_pendiente_se_aparca.md) — pídela una vez; al llegar, mide a qué alcanza antes de usarla.
- [El carril espera a Cola A](feedback_carril_espera_a_cola_a.md) — nada al simulador con Cola A viva; al acabar, validar que limpió.
- [Elige la propuesta completa aunque apriete](feedback_elige_la_propuesta_completa_aunque_aprieta.md) — por producto y, en finanzas, por la regla del dominio.
- [Gasto a la medida del tráfico](feedback_gasto_a_la_medida_del_trafico.md) — plan mínimo que funcione; estima el gasto y avisa antes.
- [Verificar prod del gateway: token acuñado](feedback_verificar_prod_del_gateway_con_token_acunado.md) — staging con Yala Dev de Jürgen; prod con token 15 min, preguntando.
- [UI compleja: capturas antes de cerrar](feedback_ui_compleja_capturas_antes_de_cerrar.md) — aprueba sobre el simulador, no el lienzo; pide aire.
- [El atasco se prueba con segundos y el mismo cambio](feedback_el_atasco_se_prueba_con_segundos_y_el_mismo_cambio.md) — backoff de segundos + mismo fallo antes de abrir una salida que pierde datos.
- [No esperes el CI ajeno](feedback_no_esperar_ci_ajeno.md) — ni antes del gate: sigue y rebasa una vez antes de tu PR.
- [El rerun no recoge el arreglo de la base](feedback_rerun_no_recoge_el_arreglo_de_la_base.md) — reusa el merge original: hace falta update-branch.
- [Simulador ajeno parado: se pregunta](feedback_simulador_ajeno_parado_se_pregunta.md) — si su sesión espera a Jürgen, aprobó usarlo sin apagarlo.
- [Los contenedores del simulador también hacen cola](feedback_contenedores_del_simulador_tambien_hacen_cola.md) — limpiar Preferences/tmp con sim TOMADO pisó a la bienvenida; va con sim-lock.
- [Auditoría UX por lotes: propone, no implementa](feedback_auditoria_ux_lote_propone_no_implementa.md) — solo bugs claros con card; informe.md + HTML acumulado + card por mejora.
- [Auditoría UI: el glass se queda, se jerarquiza](feedback_auditoria_ui_glass_se_queda_jerarquiza.md) — rellenos sólidos, sin degradados ni brillos; instruir; adaptar; solo el lote.
- [Capturas en el chat antes de preguntar](feedback_capturas_en_el_chat_antes_de_preguntar.md) — SendUserFile o artifact antes de la pregunta; la ruta no sirve.
- [El guion se adapta al estado del teléfono](feedback_el_guion_se_adapta_al_estado_del_telefono.md) — QA guiado: re-deriva cada paso de lo que dejaron las pruebas previas; nunca literal.
- [QA sin accesibilidad](feedback_qa_sin_accesibilidad.md) — en su QA manual no se piden pasos de texto grande ni VoiceOver: se dan por buenos.
- [Barrido: filtro doble, mínimo QA](feedback_barrido_filtro_doble_minimo_qa.md) — 24-oct: al iPhone solo lo grave Y no validable en sim/tests; vistos buenos uno por mensaje.
- [Lo que llega en vivo se encola](feedback_alcance_que_llega_en_vivo_se_encola.md) — decisión grande a mitad de lote: a su card lista para lanzar; «widget» = ¿inicio o Panel?
- [Planificar con él es iterar](feedback_planificar_con_el_es_iterar.md) — acepta lo recomendado y vuelve con ideas; re-pregunta «¿bueno?».
- [Tablero: una tanda a la vez](feedback_tablero_una_tanda_a_la_vez.md) — dos tandas se pisan (409); ajustes en pasada final.
- [Encargo sin simulador y el gate](feedback_encargo_sin_simulador_y_el_gate.md) — el gate lo necesita: se pregunta; aprobó usarlo solo para el gate, en cola.
- [Revisión por dispositivo sin saltar](feedback_revision_por_dispositivo_sin_saltar.md) — Duo entero primero; lo del iPhone se apunta y va al final.
- [«Eliminar cuenta» es borrar todo](feedback_eliminar_cuenta_es_borrar_todo.md) — al preguntar qué borra un gesto, di antes dónde vive cada dato.
- [Límite del plan: la persona elige](feedback_limite_del_plan_la_persona_elige.md) — alta masiva sobre el límite Free: elegir qué entra, o pedir Pro; nunca saltarlo.
- [La condición del encargo puede no ser suya](feedback_la_condicion_del_encargo_puede_no_ser_suya.md) — «sin tapar el +» era de Tim; confirma lo que multiplica alcance.
- [Una sesión de Yala por máquina](feedback_una_sesion_yala_por_maquina.md) — 5-nov: otra viva en el sim ⇒ pausa sin tocar sim ni CI de UI; retoma al aviso.
- [Gate en disco local, no ExtDev](feedback_gate_en_disco_local_no_extdev.md) — ExtDev se cuelga en Resolve Package Graph; 3 min y matar.
- [Adjuntos de XCTest en el simulador](reference_adjuntos_de_xctest_en_el_simulador.md) — 16 GB en tmp/Attachments del daemon; y workspaces de XcodeBuildMCP huérfanos.
- [Contar el store del iPhone](reference_contar_el_store_del_iphone_con_devicectl.md) — devicectl desde el App Group (no la app) + sqlite3: qué filas sube.
- [iPhone 14 libre para pruebas](feedback_iphone_14_libre_para_pruebas.md) — siempre en Device MCP; úsalo si sale más rápido o fiel que el simulador.
- [Borrar en disco lo hace el bot](feedback_borrar_en_disco_lo_hace_el_bot.md) — sandbox niega `rm` y falta espacio: pide al bot de Frank la ruta exacta, solo lo tuyo.
