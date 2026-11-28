Yala
# CI de la 2.3 en rojo (tandas de interfaz 1, 8, 9 y 12): corregir, esperar el verde y subir la build 12 a TestFlight
---
toca: YalaUITests/Flows/BulkEditUITests.swift,YalaUITests/AsistentePagoCompartido/AsistentePagoCompartidoUITests.swift,YalaUITests/Flows/Bienvenida23BaseUITests.swift,YalaUITests/Flows/GroupsOnboardingCloseUITests.swift,YalaUITests/WelcomeTrasCuentaLista/WelcomeTrasCuentaListaUITests.swift,YalaUITests/AsistentePagoPlanificado/AsistentePagoPlanificadoUITests.swift,YalaUITests/Flows/CustomTabBarUITests.swift,YalaUITests/Flows/StatisticsHeroLikePanelUITests.swift,YalaUITests/CIRojo23Build12/,YalaTests/CIRojo23Build12/,Yala.xcodeproj/project.pbxproj,Cloudkit Schemas/,docs/qa/testflight-2-3-12/,docs/guias/novedades-2-3/,tickets/backlog/2026-11-27-ci-ui-rojo-y-testflight-2-3-build-12.md,tickets/done/2026-11-27-ci-ui-rojo-y-testflight-2-3-build-12.md
modelo: opus
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: si
depende: Yala/barrido-qa-2-3-build-12
---

Decisión de Jürgen (27-nov, Lima; t2012u): «Mete al final de la cola una sesión que revise esto, lo solucione, lo espere que pase y suba el TestFlight. Antes de eso mete un barrido qa». Va después del barrido de QA de la build 12, para llevar sus arreglos.

## Contexto
- Card del tablero de Yala 2.3: «CI 2.3 UI en rojo (tandas 1, 8, 9 y 12) + espera verde y subida a TestFlight». Al terminar, muévela a «done» con nota del PR y el número de build.
- Run de referencia: https://github.com/jur211296/Yala/actions/runs/45932539245 (QA manual sobre `2.3`, 26-nov 22:09 Lima). El run sale «success» porque los rojos se reintentan y van al informe de cuarentena (`qa/scripts/ci-reintentar-rojos.sh`), pero estas pruebas fallaron en sus 3 intentos:
  - **Tanda 1** (edición masiva de cuenta): `BulkEditUITests.test_bulkEditAccount_isPendingUntilApply_andThenTheRecordsChange` (línea 203). Además `AsistentePagoCompartidoUITests.test_asistente_preguntaSiEsCompartido_yCreaElPagoDelGrupo` falló una vez (inestable: revísalo).
  - **Tanda 8** (bienvenida 2.3 en instalación nueva y cerrar con X el onboarding de grupos): `Bienvenida23BaseUITests.test_freshInstall_hasTheNewTabs_andTheDeckIsTheOnlyAction` y `GroupsOnboardingCloseUITests.test_closingWithX_postponesOnce_andTheSecondXMarksItSeen` (esperan `TabBar` y no aparece).
  - **Tanda 9** (bienvenida tras tener cuenta lista con iCloud privado / cuenta nueva): `WelcomeTrasCuentaListaUITests.test_iCloudPrivado_cuentaNueva_entraYNoVuelveALaBienvenida`. Además `AsistentePagoPlanificadoUITests.test_cerrarConRespuestas_preguntaAntes` falló una vez.
  - **Tanda 12**: las cinco de `CustomTabBarUITests` (`test_backFromGroupsOnly_thenCustomized_opensTheirScreens`, `test_customizedBar_groupsAndRecords_openTheirScreens`, `test_customizedBar_recordsThenGroups_openTheirScreens`, `test_customizedTwice_opensTheirScreens`, `test_recordsOpenedFromMoreFirst_thenCustomized_opensTheirScreens`) y el cuelgue en el hero de distribución de Estadísticas (`StatisticsHeroLikePanelUITests`, p. ej. `test_distributionHeroFollowsANewRecord`).
- Receta de subida: el encargo «Subir a TestFlight la build 11 de 2.3…», `docs/qa/testflight-2-3-11/`, `docs/qa/testflight-2-3-10/` y sus tickets.

## Qué se pide
1. **Revisa el estado actual.** Lee el run de referencia y compáralo con el último run de QA de `2.3` (`gh run list --branch 2.3`) y su informe de cuarentena: qué de lo de arriba sigue en rojo hoy, qué ya se arregló y qué rojo nuevo apareció. Reprodúcelo en local con `-only-testing` por clase.
2. **Corrige todo lo que siga fallando**, primero entendiendo la causa: si la prueba quedó vieja frente a un cambio de producto intencional (por ejemplo la barra de pestañas o la bienvenida 2.3), actualiza la prueba al comportamiento correcto; si es un bug de la app, arréglalo en el código. El cuelgue del hero de Estadísticas es bug de la app salvo prueba en contra. Un arreglo de app fuera de `toca:` solo si el archivo no está en el `toca` de otra sesión viva o pendiente, anotado en «Saltado o asumido sin preguntar» con su prueba en `YalaTests/CIRojo23Build12/` o `YalaUITests/CIRojo23Build12/`. Abre el PR de arreglos contra `2.3` con auto-merge.
3. **Espera a que todo entre y el CI pase en verde.** Comprueba: que tu PR y los de los lotes y el barrido están mergeados en 2.3; que no hay PR de app abiertos contra 2.3 (`gh pr list --base 2.3 --state open`); que no hay otra sesión de Yala viva ni encargo de Yala de app pendiente en la cola (`python3 ~/.claude/scripts/coordinador.py estado` y `mirar`). Un PR o encargo que toca solo `Web/`, `mcp/`, `docs/` o marketing no se espera. Luego lanza o espera el QA de `2.3` sobre el último commit y espera a que termine **completo** (tarda horas: no cortes por el tope corto de espera; revisa cada 10 minutos escribiendo avance). Exige que las tandas 1, 8, 9 y 12 salgan sin rojos ni en el informe de cuarentena. Si algo vuelve a salir rojo, arréglalo antes de subir y repite. Si un PR ya sin sesión está trabado por conflicto, arréglalo tú para que entre. Si algo no puede entrar por una causa que no puedes resolver, `BLOQUEANTE:` con link y motivo; no subas sin eso.
4. Sube el número de build al siguiente después del 11 (lo normal es 12; confirma en App Store Connect cuál es el último). La versión sigue en 2.3.
5. Antes de archivar, comprueba con `cktool` que los esquemas de Producción de iCloud tienen todos los campos del modelo de hoy. Si falta alguno, no lo des de alta tú: es `BLOQUEANTE:` para Jürgen (el alta en Producción la hace Dan con su OK).
6. Archiva y sube con firma en la nube con la clave `.p8` de App Store Connect, como la build 11. dSYM a Sentry y distribución al grupo interno, con el iPhone 14 de Jürgen como tester interno. No envíes a revisión de App Store. Si fallan credenciales o firma, no las inventes: `BLOQUEANTE:`.
7. Notas de prueba en español neutro latinoamericano, en lenguaje de usuario y sin ids ni nombres de ramas, en `docs/qa/testflight-2-3-12/`, con lo nuevo desde la build 11 y la lista de prueba que dejó el barrido.
8. **Pon al día la guía de novedades 2.3** siguiendo `docs/guias/novedades-2-3/README.md`: suma lo mergeado desde la última actualización, mueve a «listo» lo que llega en la build 12, saca capturas nuevas de lo que cambió y conserva los ids existentes para no perder las notas de Jürgen. Publica sobre la misma URL si se puede y deja el link en el README.
- Esta vez **no** se limpia la base de desarrollo ni se reinstala Yala Dev: Jürgen no lo pidió.
- **Dispositivos:** en la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Apaga y limpia los que enciendas. **iPhone 14** («iPhone de JURGEN», UDID `00008110-001A35A6267A401E`) por DeviceMCP con candado ADR-132 (hook `candado_dispositivo.py`): si está ocupado por otra sesión, **no reintentes en bucle**; sigue con el simulador u otra parte y vuelve a probar una sola vez más tarde; si sigue ocupado, anótalo en «Saltado o asumido sin preguntar». Antes comprueba con `xcrun devicectl device info lockState --device 00008110-001A35A6267A401E` que no esté bloqueado. No borres datos del iPhone salvo «Vaciar datos» o «Eliminar cuenta» dentro de Yala Dev cuando el encargo lo diga.
- Al arrancar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen (nunca las de un worktree vivo). No uses `-derivedDataPath /tmp/claude-*`.
- Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. Si una prueba falla 2 veces por timeout, anótala como inestable y sigue. Ninguna espera de más de 3 min sin escribir avance.
- Build iOS en pipeline serial: limpiar, `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, probar y apagarlo. Antes de compilar mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.

## Qué NO hay que tocar
- Solo lo de `toca:` más los arreglos de app anotados: pruebas de las tandas 1, 8, 9 y 12, número de build, esquemas `.ckdb` si cambian, docs de esta subida, guía de novedades y ticket por archivo. Nunca `Yala/`, `YalaTests/` ni `YalaUITests/` enteros.
- Nada de producción salvo la subida a TestFlight: ni Supabase, ni CloudKit de producción, ni D1, KV o Workers. No despliegues gateway, web ni conector.

## Cómo entregar
- Un PR de arreglos y otro (o el mismo) con el cambio de build y la guía al día, contra 2.3, sin firma de IA en commits ni PR, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Entrega final: artifact visual de Claude con qué estaba en rojo y cómo se arregló, el run verde final, número de build, qué incluye, link de TestFlight o App Store Connect, notas de prueba y link de la guía de novedades (ADR-130 de casa); no Markdown, PDF ni documento de puro texto. Enlázalo en «Qué salió».
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin mergear ni subir lo incompleto. Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada», y el link del artifact. `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones (Frank, 27-nov 16:50 Lima, modo semi, Max)

| # | Decisión | Por qué |
|---|---|---|
| 1 | Se parte de `origin/2.3` al día (1ef2fdadf). El barrido de la build 12 (su PR con auto-merge) aún no entró: el código de arreglos se hace ya y la build espera a que entre. | `depende:` declara el barrido; el código no choca con su diff (tickets/docs/salud). |
| 2 | Diagnóstico por el log del run de referencia antes de tocar nada; reproducción local por clase con `-only-testing`. | Prueba vieja vs. bug de app se decide por la causa, no por el síntoma. |
| 3 | Prueba vieja frente a cambio intencional ⇒ se actualiza la prueba. Bug de la app ⇒ arreglo mínimo en la app con su prueba. | Encargo. |
| 4 | Un PR con los arreglos y, tras el QA verde, otro con build 12 + notas + guía. | Separar lo que necesita CI de lo que va después del verde. |
| 5 | El QA completo de `2.3` se lanza a mano (`workflow_dispatch`) sobre el último commit cuando todo haya entrado. | Los push y la nocturna no corren la interfaz. |
| 6 | Sin limpiar la base de desarrollo ni reinstalar Yala Dev. | Encargo. |
