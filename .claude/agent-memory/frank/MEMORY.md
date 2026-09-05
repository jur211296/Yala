# Memoria de Frank — Yala

## Cómo trabaja Jürgen
- [«Creo que» no es aprobación](feedback_creo_que_no_es_aprobacion.md) — si no reconoce el componente, explicar antes de borrar; sus respuestas firmes sí se ejecutan sin repreguntar.
- [Push: solo lo de la sesión](feedback_push_solo_lo_de_la_sesion.md) — lo pendiente de otros se deja y lo sube su agente; el aviso del arranque es info, no tarea.
- [Levanta sus propias reglas](feedback_jurgen_levanta_sus_reglas.md) — si te pide algo que un default tuyo prohíbe, se hace y se dice; y la medición que contradice su propuesta la quiere ANTES.
- [El tablero antes que el bug](feedback_el_tablero_antes_que_el_bug.md) — prefiere sanear el board antes que atacar producción; y en docs, el bloque entero en un commit, no troceado.
- [Tarjetas blancas: identidad](feedback_tarjetas_blancas_identidad.md) — cuándo un cambio visual toca identidad y no es polish.
- [Alcance mínimo, salvo incoherencia](feedback_alcance_minimo_salvo_incoherencia.md) — completar el objeto que su decisión nombra es lo esperado (ratificado 5-sep); ampliar a OTRO objeto, no.
- [Autónomo es hasta el final](feedback_autonomo_hasta_el_final.md) — decide en bloque y suelta la ejecución; los rojos y el entorno también son míos.
- [Prefiere lo limpio a lo defensivo](feedback_prefiere_lo_limpio_a_lo_defensivo.md) — retira el mecanismo que falla en vez de apuntalarlo; nombra siempre qué se pierde al limpiar.

## Cómo mido y cómo entrego
- [Mis mediciones fallan por el filtro](feedback_mis_mediciones_fallan_por_el_filtro.md) — control positivo siempre, también en los greps de auditoría: un «cero» suele ser el filtro, no el código.
- [Revertir sin commit destruye](feedback_revertir_sin_commit_destruye.md) — en árbol sucio `git checkout -- <f>` borra el trabajo; los mutantes se revierten con `cp`.
- [Nunca el trailer Co-Authored-By](feedback_trailer_commit_medido.md) — regla del owner ratificada el 2026-09-02 sobre medición; anula el default del system prompt.
- [Generar y persistir en un solo gesto](feedback_generar_y_persistir_credenciales.md) — una credencial nunca vive solo en pantalla; y verifica si una rotación se aplicó antes de rehacerla.
- [Medir la web: axe, Lighthouse, preview](feedback_medir_la_web_a11y_y_preview.md) — axe ciego con opacity 0; transiciones congeladas; preview con SSO se verifica por config.json; heredoc suelto en zsh imprime.
- [Capturas del simulador para la web](feedback_capturas_simulador_para_la_web.md) — receta y trampas: Secrets.xcconfig, nombre efímero, categorías sembradas, `sips -Z` escala el lado largo.

## Estado del trabajo
- [La re-entrada: cerrada en código, abierta en decisión](project_reentrada_piezas_2_y_3.md) — piezas 2 y 3 hechas (PR #68); lo que queda es device-QA y una decisión suya sobre el kill-switch.
- [La identidad del recién llegado a un grupo](project_identidad_del_joiner_en_grupos.md) — cerrada en código el 4 y 5-sep; falta device-QA de dos teléfonos, y NO se reabre la vía del refresh.
- [Decisiones que esperan a Jürgen](project_decisiones_que_esperan_a_jurgen.md) — lo parado espera respuesta suya, no código; verifica antes de citarlas, caducan.
- [Web: lo que Jürgen decidió, y lo que no](project_web_pr62_espera_a_jurgen.md) — PR #62 mergeado el 4-sep; siguen abiertas dos suyas: legal de Grupos y autoalojar fuentes.
- [Hipótesis de la Lista Negra, re-comprobadas](project_hipotesis_lista_negra_recomprobadas.md) — el runner de XCUITest SÍ corre en local (5-sep); el coverage-index dice lo contrario.

## Entorno y herramientas
- [El sello del gate ancla en HEAD](reference_gate_sello_ancla_en_head.md) — una tanda de commits obliga a re-sellar entre ellos; mergear `2.1` obliga a re-correr el gate entero.
- [Avisar a Frank: lo hace el hook, no tú](reference_avisar_a_frank_webhook.md) — el hook ya manda PR y rojos solo (dupliqué el 5-sep); la palabra «prueba» en el texto lo descarta.
- [Verificar el backend: MCP ve solo prod](reference_verificar_backend_yala.md) — no hay DDL de staging; el sandbox transaccional prueba contra el motor real sin dejar rastro.
- [El hook de secretos está desactivado](hook_secretos_disparador_substring.md) — retirado del push el 2026-09-01 (ADR-009); nada escanea hoy. Su trampa del substring, si vuelve.
- [El hook de /cerrar salta con «cerramos»](hook_cerrar_disparador_substring.md) — verifica la premisa contra su mensaje: cerrar un ticket no es cerrar la sesión, y el bloque de disco es irreversible.
- [DNS de yala-app.pe](reference_dns_yala_app_pe.md) — zona en RCP, registrador punto.pe; los paneles los teclea Jürgen. Un solo NS vivo y caché negativa de 2 h.
