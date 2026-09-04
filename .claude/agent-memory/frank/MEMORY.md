# Memoria de Frank — Yala

## Cómo trabaja Jürgen
- [«Creo que» no es aprobación](feedback_creo_que_no_es_aprobacion.md) — si no reconoce el componente, explicar antes de borrar; sus respuestas firmes sí se ejecutan sin repreguntar.
- [Push: solo lo de la sesión](feedback_push_solo_lo_de_la_sesion.md) — lo pendiente de otros se deja y lo sube su agente; el aviso del arranque es info, no tarea.
- [Levanta sus propias reglas](feedback_jurgen_levanta_sus_reglas.md) — si te pide algo que un default tuyo prohíbe, se hace y se dice; y la medición que contradice su propuesta la quiere ANTES.
- [El tablero antes que el bug](feedback_el_tablero_antes_que_el_bug.md) — prefiere sanear el board antes que atacar producción; y en docs, el bloque entero en un commit, no troceado.
- [Tarjetas blancas: identidad](feedback_tarjetas_blancas_identidad.md) — cuándo un cambio visual toca identidad y no es polish.

## Cómo mido y cómo entrego
- [Mis mediciones fallan por el filtro](feedback_mis_mediciones_fallan_por_el_filtro.md) — control positivo siempre; un numerador sin denominador no es proporción; `-only-testing` por método corre cero tests y dice SUCCEEDED.
- [Nunca el trailer Co-Authored-By](feedback_trailer_commit_medido.md) — regla del owner ratificada el 2026-09-02 sobre medición; anula el default del system prompt.
- [Generar y persistir en un solo gesto](feedback_generar_y_persistir_credenciales.md) — una credencial nunca vive solo en pantalla; y verifica si una rotación se aplicó antes de rehacerla.
- [Medir la web: axe, Lighthouse, preview](feedback_medir_la_web_a11y_y_preview.md) — axe ciego con opacity 0; transiciones congeladas; preview con SSO se verifica por config.json; heredoc suelto en zsh imprime.

## Estado del trabajo
- [Decisiones que esperan a Jürgen](project_decisiones_que_esperan_a_jurgen.md) — lo parado espera respuesta suya, no código; verifica antes de citarlas, caducan.
- [Web PR #62 espera a Jürgen](project_web_pr62_espera_a_jurgen.md) — revisión web 2026-09-03: mergear, y 4 decisiones (legal Grupos, fuentes, tono acento, tema sistema).

## Entorno y herramientas
- [El hook de secretos está desactivado](hook_secretos_disparador_substring.md) — retirado del push el 2026-09-01 (ADR-009); nada escanea hoy. Su trampa del substring, si vuelve.
- [El hook de /cerrar salta con «cerramos»](hook_cerrar_disparador_substring.md) — verifica la premisa contra su mensaje: cerrar un ticket no es cerrar la sesión, y el bloque de disco es irreversible.
