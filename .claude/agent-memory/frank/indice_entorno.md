---
name: indice-entorno
description: Subíndice: máquina, hooks, accesos (backend, DNS, Sentry), disco y rarezas del entorno.
metadata:
  type: reference
---

# Entorno y herramientas

Subíndice de `MEMORY.md` (2026-11-05).

- [Girar y estrechar el iPad sin Simulator.app](reference_girar_simulador_sin_simulator_app.md) — estrechar y ensanchar con XCUIApplication+Window; sin erase.
- [`removeObject` sin efecto = es el simulador](feedback_simulador_preferencias_fuera_del_contenedor.md) — `simctl erase` va…
- [El sello del gate ancla en HEAD](reference_gate_sello_ancla_en_head.md) — una tanda de commits obliga a re-sellar entre el…
- [Avisar a Frank: lo hace el hook, no tú](reference_avisar_a_frank_webhook.md) — el hook manda PR y rojos solo; «prueba» en…
- [El aviso de cierre necesita el cwd del repo](reference_aviso_cierre_necesita_cwd.md) — tras retirar el worktree va a Dan y…
- [Un campo Codable nuevo apaga los widgets](feedback_campo_codable_nuevo_apaga_el_widget.md) — el DTO del App Group está DUP…
- [El acceso al backend se MIDE cada sesión](reference_verificar_backend_yala.md) — el 10-sep estaba invertido; `execute_sql` y…
- [Runbook de DDL en staging](reference_runbook_staging_ddl.md) — las tres migraciones en un solo sitio; su «falta la…
- [`git` bloqueado por la licencia de Xcode](reference_git_bloqueado_por_licencia_de_xcode.md) — tras actualizar Xcode; el bi…
- [El hook de secretos está desactivado](hook_secretos_disparador_substring.md) — retirado del push el 2026-09-01 (ADR-009).
- [El hook de /cerrar salta con «cerramos»](hook_cerrar_disparador_substring.md) — verifica la premisa contra su mensaje.
- [DNS de yala-app.pe](reference_dns_yala_app_pe.md) — el correo autentica desde el 8-sep; qué leer en la cabecera además de…
- [El disco: los GB están DENTRO del simulador](reference_disco_cache_simulador.md) — cachés regenerables del device; tras mu…
- [Adelantar un paso vuelve normal el caso «imposible»](feedback_adelantar_un_paso_vuelve_normal_el_caso_imposible.md) — consent antes de la sesión: el sin-sello lo heredaba otro.
- [Yala Dev es Debug-Dev](reference_yala_dev_es_debug_dev.md) — `configuration Debug` (MCP o `xcodebuild -configuration`) compila producción sin DEV_BUILD.
- [El negativo previo corre contra el arreglo](feedback_el_negativo_previo_corre_contra_el_arreglo.md) — seam de reloj: N por encima de la navegación, o con el arreglo cae el «aún no está».
- [reference-capturas-en-claro-y-oscuro-con-el-tema](reference_capturas_en_claro_y_oscuro_con_el_tema.md) — Para capturas claro/oscuro de Yala, `simctl ui appearance` no sirve (el tema de fábrica fuerza oscuro); se fija `userThe…
- [reference-skills-pulido-ui](reference_skills_pulido_ui.md) — Dos skills globales de pulido de UI (better-ui, emil-design-eng) instaladas el 2026-09-15; son de web, pero sus reglas d…
- [reference-ui-flujo-por-pasos](reference_ui_flujo_por_pasos.md) — Referencia de UI que Jürgen señaló el 2026-09-15 para todo lo que en Yala requiera pasos — captura en docs/design/refere…
- [reference-ui-onboarding-login](reference_ui_onboarding_login.md) — Referencia de UI que Jürgen señaló el 2026-09-15 para el onboarding de Yala — pantalla de entrada con Google, correo y «…
- [El centinela no vigila un `timeout`](feedback_el_centinela_no_vigila_un_timeout.md) — pgrep casa con el envoltorio y sale 2; lanza sin `timeout` y pasa `$!`.
- [Device MCP Free: un espejo](reference_device_mcp_free_un_espejo.md) — otro dispositivo espejado ⇒ simulador con axe + simctl.
- [Campo de CloudKit en Development: lo añade Dan](feedback_campo_cloudkit_development_lo_anade_dan.md) — sin token de cktool; pedir al bot Frank → Dan; `preguntar-bot --help` envía.
- [Secretos de staging en la Mini](reference_secretos_de_staging_en_la_mini.md) — desde la Max por ssh mini; dos wrangler (personal y Yala) desde el 16-nov; Turnstile no.
- [Playwright en la Mini](reference_playwright_en_la_mini.md) — capturas de staging con A/B: la descarga de Chromium se atasca; copiar el de la Max (1243 + playwright 1.63.0).
- [Desplegar el gateway desde la Mini](reference_desplegar_el_gateway_desde_la_mini.md) — prod no corre la cabeza de 2.3: base verificada byte a byte + solo tu parche.
- [TestFlight del iPhone 14](reference_testflight_del_iphone_14_es_externo.md) — cuenta test, interna desde el 15-nov; el admin@ de la ficha es el contacto; sin invitar por API.
- [Suelta el turno antes del paso 5](feedback_suelta_el_turno_antes_del_paso_5.md) — el sleep de QA bloquea sim-lock-test; rm -rf $VAR y ${(f)} los rechaza el chequeo de Bash.
- [Limpiar staging = sus cuentas](feedback_limpiar_staging_es_sus_cuentas.md) — sus 3 de Google con todo; los 4 sintéticos i5 de los goldens se quedan.
- [Artifact público con Chrome](reference_artifact_publico_lo_frena_el_clasificador.md) — 16-nov la Mini lo denegó; 17-nov la Max pasó con find + clic por ref.
- [Yala web con sesión, de noche en la Max](reference_web_con_sesion_de_noche_en_la_max.md) — iPhone 14 reflejado y Chrome sin extensión; staging con Playwright en la Mini sí.
- [Consola del iPhone con Core Data llena el disco](reference_consola_del_iphone_con_core_data_llena_el_disco.md) — grep --line-buffered sin cut; parar la consola cierra la app; sin rm, clean + mv a ExtDev.
- [zsh: `$REF:ruta` es un modificador](feedback_zsh_modificador_tras_variable.md) — `:q`, `:h`, `:t` tras `$VAR` rompen `git show $B:qa/…`; usa `"${B}:ruta"`.
- [Artifact público: en la Max pasó](reference_artifact_publico_paso_en_la_max.md) — 17-nov, find + clic por ref; si se deniega, la nota del clasificador.
- [Girar el simulador y capturarlo](reference_girar_el_simulador_y_capturarlo.md) — XCUITest + XCUIScreen; app.screenshot() sale descuadrada girado.
- [Disco de la Mini con simulador y build de iPhone](reference_disco_de_la_mini_con_simulador_y_build_de_iphone.md) — DD propia 7,8 GB, SE creado 4,5 GB, iphoneos 2 GB: qué borrar y cuándo.
- [iPhone bloqueado: pídelo en el chat](feedback_iphone_bloqueado_se_pide_en_el_chat.md) — 17-nov rechazó request_human_action; contestó «desbloqueado».
- [Gate con la DerivedData de XcodeBuildMCP](reference_gate_con_la_derived_data_de_xcodebuildmcp.md) — disco justo: `-derivedDataPath` a la subcarpeta con hash, no al padre (duplica 6 GB).
- [Disco justo: esquema Yala a ExtDev con paquetes locales](reference_disco_justo_esquema_yala_a_extdev_con_paquetes_locales.md) — `-clonedSourcePackagesDirPath` local evita el cuelgue; Yala Dev en local.
- [Artifact público: a veces sí, a veces no](reference_artifacts_no_se_pueden_hacer_publicos.md) — el 19-nov salió desactivado y luego pasó; siempre un intento entero.
- [Desplegar el Worker sin arrastrar shared-core](reference_desplegar_el_gateway_desde_la_mini.md) — 20-nov: el wrangler de `~/.wrangler` es la cuenta personal; el de Yala, `~/Library/Preferences/.wrangler` con token renovado.
- [Dos Chrome conectados frenan el artifact público](reference_dos_chrome_conectados_frena_el_artifact_publico.md) — 20-nov: hay que elegir navegador; sin Jürgen delante, queda privado y se anota.
