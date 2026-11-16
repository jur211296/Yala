# CI 2.2 · Recuperar las nueve tandas UI: compatibilidad Xcode/runtime y detectar cero tests
card: tablero-ci-2-2-recuperar-las-nueve-tandas-ui-com-0gz2
toca: .github/workflows/,qa/
esfuerzo: high

Base: origin/2.2 en jur211296/Yala. Un solo PR, cierre autónomo (cierra-sola), termina con `/cerrar-total`. Al lanzar: --permission-mode bypassPermissions, sin segunda Yala/marketing por máquina. Commits y PR sin firma de IA. No implementar cambios funcionales de app ni tocar marketing/auth/producción. Descripción corta en español por comando Bash.

## Contexto y diagnóstico por verificar
Jürgen autorizó «Encola» el 7-nov11:06 Lima. Fuente: https://github.com/jur211296/Yala/actions/runs/42383702440 — QA programada 7-nov09:53 Lima, commit f0571f6. Reporte inicial: las 9 tandas UI no ejecutaron pruebas: Failed to load test bundle YalaUITests; AppIntentsTesting.framework de Xcode27.1 busca símbolo de AppIntentsServices ausente en runtime iOS27.2. Mismo commit pasó UI el 6-nov21:51 Lima. Hipótesis de diferencia de runner, NO causa ya demostrada. No confundir con tarjeta tablero-ci-las-tandas-de-ui-del-qa-programado-no-de19 (timeout de compilación25min, ya en QA).

## Trabajo acotado (un incidente, no inventar tareas)
1. Comparar logs reales del run afectado y el anterior que sí ejecutó tests en mismo commit. Registrar versiones/build exactos de Xcode, SDK, runtime, imagen del runner y selección de simulador; comprobar discrepancia antes de fijar solución.
2. Estabilizar selección compatible Xcode/runtime y añadir preflight claro del entorno. Elegir alineación respaldada por versiones disponibles, no asumir que basta subir/bajar versión. No cambiar código funcional, excluir suites, saltar tests ni aflojar assertions para taparlo.
3. Detectar/reportar explícitamente fallo de carga y ejecuciones de cero tests con conteos reales/resultado xcresult. Mantener política UI advisory: no convertir todo UI en gate obligatorio ni volver verde silencioso un paquete que no cargó. Revisar la comprobación existente antes de duplicarla.
4. Rerun real: demostrar al menos que carga YalaUITests y se ejecutan tests (>0); ideal las9tandas con conteos por tanda y links/logs. Una edición YAML o build local no prueba resolución. Si no hay runner/acceso o ejecución disponible, registrar validación pendiente y limitación concreta; no declarar resuelto.
5. Evaluar propagación mínima a2.3 según política vigente, con evidencia y sin merge masivo no aprobado. Evitar duplicar PRs/cards/cola; leer actualizados al arrancar.

## Pruebas y limpieza
Simuladores permitidos: Mini máximo1; Max máximo2 o iPhone14 mediante DeviceMCP si realmente aplica. No tocar dispositivo real ni recursos de sesiones ajenas. Si compilas local: limpiar solo propios/huérfanos cerrados, build xcodebuild -jobs2 sin sim booteado, luego boot/test y apagar/borrar solo propios. Quitar DerivedData propio y caches de worktrees inexistentes al cerrar; no caches de sesiones vivas.
Justo antes del gate: git fetch y un solo rebase sobre origin/2.2; CI previo fallido no justifica espera bloqueante. Dudas materiales siguen playbook habitual (ya terminó ventana autónoma hasta11:00).

## Terminado verificable
PR acotado de CI a2.2 con diagnóstico comparativo, entorno seleccionado, preflight y detector de0tests, evidencia de rerun con paquete cargado y tests reales (ideal9tandas). Si faltó validación, declararlo expresamente y no marcar como resuelto. Card actualizada con evidencias y `/cerrar-total`.
FIN

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** El run del mismo commit del 6-nov 21:51 Lima (push, 42331289595) NO corrió UI: sus tandas salieron `skipped`. La comparación válida es contra los programados. Tanda 1 de cada run: con la imagen `xcode-27-arm64` **20261026.0314.1** (Xcode 27.1 27A9275 + runtime iOS **27.0**) la UI ejecutó tests hasta el 4-nov; con la **20261104.0337.1** (mismo Xcode, trae Xcode 27.2 final y un runtime iOS **27.2** completo) `ci-simulador.sh` elige el 27.2 y el paquete no carga desde el programado del 5-nov (runs 42064641786, 42071149226, 42247422332, 42383702440). El 27.0 sigue en la imagen nueva. El job de unit también cayó en 27.2 y pasó (12 721 + 97 tests).

**D1 · ¿Qué pareja Xcode/runtime?** → Xcode 27.1 (sin cambios) + runtime que no pase del SDK: hoy el 27.0.
Por qué: es la pareja que corrió la UI entera hasta el 4-nov y el compilador sigue siendo el de la release. Alternativa descartada: subir el CI a Xcode 27.2 + runtime 27.2 — cambia el compilador de los unit que bloquean el merge y se separa de la release; decisión de Jürgen, no de un incidente.

**D2 · ¿Dónde se fija?** → En el orden de `ci-simulador.sh` (casa con SDK → más nuevo que no pase del SDK → solo si no hay otro, el menos nuevo de los posteriores, con aviso), para los dos jobs; modo estricto (`SIM_HASTA_SDK=si`) solo en el job `ui`, que descarta los posteriores y falla con motivo.
Por qué: el fallo es del criterio «el más nuevo», no de una versión; fijar «27.0» a mano se rompe en la próxima imagen. El job de unit queda tolerante porque allí un runtime posterior sí corre. Alternativa descartada: estricto en todos — dejaría los PR sin CI el día que la imagen pierda el 27.0.

**D3 · ¿Preflight?** → Dentro de `ci-simulador.sh`: una línea «Entorno» (imagen, Xcode, SDK, runtime con build, veredicto de compatibilidad) en el log, en el resumen del paso y en `runtime=`.
Por qué: el paso ya existe en los tres jobs; un paso nuevo duplicaría la lectura de `simctl`.

**D4 · ¿Cómo se detecta cero tests en la UI?** → Script nuevo `ci-ui-conteo.sh` que lee el `.xcresult` (`xcresulttool … summary`) y el log; la tanda escribe `ui_N=sin_tests` y su job sale en rojo SOLO si el paquete no cargó o no corrió ningún test. Los rojos de test siguen advisory. El aviso gana una rama propia: «la UI no ejecutó ningún test».
Por qué: el detector existente (`ci-reintentar-rojos.sh`) es de unit y reintenta; la UI no lo usa y no se debe reintentar un paquete que no carga. Alternativa descartada: reutilizar `ci-reintentar-rojos.sh` en la UI — cambia la política de reintentos de UI, fuera de alcance.

**D5 · ¿Validación?** → `workflow_dispatch` de `qa.yml` sobre la rama del PR, con las nueve tandas; se registran conteos por tanda. Si no termina antes del cierre, se declara pendiente con su link.

**D6 · ¿Propagación a 2.3?** → Se evalúa con evidencia (si existe la rama y comparte `ci-simulador.sh`), sin abrir PR a 2.3 en este encargo.
Por qué: el encargo pide un solo PR a 2.2 y prohíbe merges masivos no aprobados.
