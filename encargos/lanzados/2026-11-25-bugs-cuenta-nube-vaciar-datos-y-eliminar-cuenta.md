# Bugs de cuenta nube: Vaciar datos y Eliminar cuenta
---
toca: Yala/App/Views/Settings/UserDataResetView.swift,Yala/App/Views/Settings/UsageModeSettingsView.swift,Yala/App/Views/Profile/ProfileView.swift,Yala/App/Views/Profile/YalaAccountView.swift,Yala/App/Views/Panel/PanelView.swift,Yala/App/Views/Panel/Sections/PanelHeroSection.swift,Yala/App/ViewModels/PanelViewModel.swift,Yala/App/Logic/DestructiveScopeLogic.swift,Yala/App/Logic/RemoteWipeCutLogic.swift,Yala/App/Logic/RemoteWipeGraceLogic.swift,Yala/App/Logic/FreshStartAlertRoutingLogic.swift,Yala/App/Logic/SyncSignInBannerLogic.swift,Yala/App/Logic/SyncStatusSectionLogic.swift,Yala/App/Logic/CloudSignOutFlowLogic.swift,Yala/App/Logic/AccountEntryLandingLogic.swift,Yala/App/Logic/YalaAccountLogic.swift,Yala/App/Logic/AccountDeletionDebtLogic.swift,Yala/App/Logic/AccountRemovalLogic.swift,Yala/App/Models/SessionState.swift,Yala/App/Services/UsageModeService.swift,Yala/App/Services/SyncOutboxMirror.swift,Yala/App/Services/GroupsOutboxMirror.swift,Yala/App/Services/AppPreferences.swift,Yala/App/AppBootstrapper.swift,Yala/App/ContentView.swift,Yala/App/UITestHooks.swift,YalaTests/BugsCuentaNube/,YalaUITests/BugsCuentaNube/,gateway/src/sync/account.ts,gateway/test/account.delete.test.ts,docs/qa/bugs-cuenta-nube-2026-11-25/,capturas/,tickets/backlog/2026-11-25-bugs-cuenta-nube-vaciar-datos-y-eliminar-cuenta.md,tickets/done/2026-11-25-bugs-cuenta-nube-vaciar-datos-y-eliminar-cuenta.md
esfuerzo: high
cierre: cierra-sola
---

## Contexto
Jürgen probó Yala Dev (2.3, build 9) el 25-nov a las 7:04 y 7:05 (hora de Lima) y reportó dos bugs. Los bugs que reporta él van delante de las mejoras. Sus capturas están en la Mini, en `~/Claude/flota/compartido/yala/bug-cuenta-nube-2026-11-25/`:
- `1-panel-banner-iniciar-sesion.png`: el Panel con el banner «Inicia sesión para subir 7,383 cambios / Lo que ves aquí puede no estar al día con tu cuenta» y el botón Iniciar sesión.
- `2-donde-viven-tus-datos.png`: «Dónde viven tus datos» dice «En tu cuenta de Yala» (modo nube) y, en Sincronización, «Inicia sesión para subir 7,383 cambios».
- `3-esqueleto-pegado.png`: el esqueleto del Panel, que se queda muchísimo tiempo.
- `4-ajustes-sin-eliminar-cuenta.png`: Ajustes › Tu cuenta solo muestra «Tu IA» y «Cerrar sesión».

**Bug A (sus palabras, resumidas):** «Estoy dentro de una cuenta modo nube pero dice que debo iniciar sesión. ¿Cómo es eso posible? Si la sesión estuviera cerrada, ¿no debería estar en el Welcome? Las dos pantallas son DESPUÉS de "Vaciar datos". Me salió "Empezaste de cero", pero el esqueleto se quedó MUCHÍSIMO tiempo, incluso cerrando por completo la app. Si vacié los datos, ¿por qué aparece que hay datos y que debo iniciar sesión?»

**Bug B:** «No veo la opción para eliminar mi cuenta.» Apple la exige en las apps con cuenta (App Store 5.1.1(v)).

Pistas que ya están en el repo (verifícalas, no las des por hechas):
- PR #688 (29-oct) definió que «Vaciar datos» deja al usuario en el Panel con su cuenta y que «Eliminar cuenta» lo borra todo. Los PR #659, #964 y #1074 tocaron «Empezar de cero», «Cerrar sesión» y «Eliminar mi cuenta».
- En `ProfileView.swift`, la fila «Eliminar mi cuenta» depende de `deleteAccountRowHasSession`. Es probable que el bug B sea consecuencia del A: el teléfono queda en modo nube **sin sesión válida**, así que la fila se oculta, y la cuenta queda sin ninguna forma de borrarse. Confírmalo o descártalo.
- En el tablero ya está la card «Tras «Empezar desde cero», el teléfono puede quedar en modo nube sin sesión y pedir a la persona nueva entrar en una cuenta ajena» (v2.5). Si la causa es la misma, ciérrala con este PR y anótalo.
- El gateway ya tiene `/account/delete` en `gateway/src/sync/account.ts`.

## Que se pide
1. **Reproducir** en el iPhone 14 por DeviceMCP, o en el simulador de la Mini. Un simulador a la vez: el segundo solo se permite en la Max. Usa una cuenta nube de prueba con datos, pulsa «Vaciar datos», mide cuánto dura el esqueleto, cierra la app por completo y vuelve a abrir. Anota el estado de sesión, el modo de uso y cuántos cambios hay en la cola de salida (outbox de sync y de grupos). Deja capturas de antes.
2. **Bug A, la causa y su arreglo:**
   - «Vaciar datos» tiene que vaciar también la cola de cambios por subir (las outbox de sync y de grupos) y dejar coherente el estado de modo nube y de sesión. No pueden quedar 7.383 cambios pendientes de datos que ya se borraron.
   - Sin una sesión válida, la app no se queda en modo nube. Revisa el ADR y el diseño vigente (DECISIONS.md, solo los ADR de Vaciar datos, modo de uso y sesión) para decidir si va al Welcome o queda en modo local limpio, y cita el ADR en el cierre. Si Vaciar datos mantiene la sesión por diseño, la sesión tiene que seguir siendo válida después y el banner no debe salir.
   - El esqueleto del Panel no puede quedarse pegado, ni recién vaciado ni al reabrir. Busca qué espera (una carga, un flag o un recálculo que no termina) y corrígelo.
3. **Bug B:** averigua si «Eliminar cuenta» existía para la cuenta nube y se perdió (git log/blame de ProfileView y YalaAccountView), o si nunca estuvo. Tiene que verse para toda cuenta nube, incluido el estado roto del bug A, con su flujo completo: una confirmación clara de qué se borra, llamar al gateway (`/account/delete`) para borrar la cuenta y los datos asociados, limpiar los datos locales y terminar en el Welcome. Si el endpoint del gateway necesita cambios, hazlos en `gateway/src/sync/account.ts` con su prueba. **No despliegues nada a producción** (ni gateway ni Supabase ni D1): deja los pasos exactos para Dan en el cierre.
4. Escribe las pruebas de la lógica en `YalaTests/BugsCuentaNube/` y, si hace falta UI, en `YalaUITests/BugsCuentaNube/`. Crea el ticket en `tickets/backlog/2026-11-25-bugs-cuenta-nube-vaciar-datos-y-eliminar-cuenta.md` y muévelo a `tickets/done/` al terminar.
5. Usa los textos que ya existen («Eliminar mi cuenta» y otros). No toques `Yala/Resources`. Si un texto nuevo es inevitable, explícalo en el cierre.
6. Haz un PR a `2.3` sin firma de IA, déjalo en auto-merge y cierra sin esperar el CI. En el cierre van «Saltado o asumido sin preguntar» y «Decidido sin consultar».
7. Entrega un artifact visual de Claude con el antes y el después de los dos bugs (capturas del iPhone 14: esqueleto, banner, Dónde viven tus datos, Ajustes › Tu cuenta con «Eliminar cuenta» y su confirmación), la causa en lenguaje llano y los pasos para Dan, si los hay. Deja `capturas/antes.png` y `capturas/despues.png` en el worktree.

Pruebas de interfaz:
  - Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final.
  - Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue.
  - Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo.
  - Ninguna espera de más de 3 min sin escribir avance (qué corre, cuánto lleva); nada de bucles de 10 min ni comandos que se pasen del límite y queden en segundo plano a ciegas.
  - Antes de compilar en iOS mira la carga: si otra sesión compila con xcodebuild en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso, no en paralelo.

Pipeline serial de la Mini: limpiar, compilar con `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, correr las pruebas y apagarlo. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de una sesión viva.

## Que NO hay que tocar
- Ni `Yala/`, ni `YalaTests/`, ni `tickets/` enteros, ni `Yala/Resources`. Solo lo que está en `toca`.
- Lo de las sesiones vivas: la subida de la build 9 en la Mini (`Yala.xcodeproj/project.pbxproj`, `Cloudkit Schemas/`, `docs/qa/testflight-2-3-9/`, `docs/guias/novedades-2-3/`) y el análisis de las tandas de UI en la Max (`docs/analisis/ci-ui-rojo-2026-11-25/`).
- Nada de despliegues a producción, ni de cambios en el esquema de CloudKit de Producción.

## Como se sabe que esta bien
- En el iPhone 14: después de «Vaciar datos» no hay cambios pendientes ni banner de «Inicia sesión», el esqueleto se va en pocos segundos (también al reabrir), y la app queda en un estado coherente según el ADR (Welcome o local limpio, o nube con sesión válida).
- En Ajustes › Tu cuenta aparece «Eliminar cuenta» en toda cuenta nube. El flujo borra la cuenta en el gateway (en dev/staging) y deja la app en el Welcome.
- Las pruebas nuevas pasan, el PR a 2.3 está en auto-merge, y el artifact tiene el antes y el después y, si hace falta, los pasos para Dan.

## Paso 0 (Frank, 2026-11-25)

Título del lote (ampliado por Jürgen): «Bugs de cuenta: Vaciar datos, Eliminar cuenta y primeros pasos en solo gastos».

**Medido antes de decidir** (iPhone 14 con Yala Dev 2.3 (9), cuenta jur211296 en staging, y copia del store y las
preferencias del iPhone 18 de Jürgen):
- Tras «Recargar datos de prueba» + «Vaciar datos» quedan 7.166 cambios en la cola personal: 3.148 filas con alta y baja
  (nunca llegaron al servidor) y 1.099 bajas de tipos de cambio. El motor sube TODA la cola antes de bajar nada, en
  trozos de 50 con el token pedido una vez (≈300 ms por cambio ⇒ media hora). La espera del Panel depende de esa
  primera bajada: esqueleto de 62 s al reabrir (techo de 60 s), con la sesión válida.
- Un token que caduca a mitad de esa subida devuelve 401 ⇒ el motor se para «hasta iniciar sesión» ⇒ banner
  «Inicia sesión para subir N cambios» (inferido por código; el JWT de staging dura 1 h).
- Bug C: en el iPhone 18 falta `onboarding23.freshInstall` y `tabBarDefaults23.migrated` está puesta: el mazo exige
  esa marca, que solo se decide en el primer arranque con código 2.3. Cualquier teléfono que tuviera Yala antes de 2.3
  no ve Primeros pasos nunca, en ningún modo.

**Decisiones:**
1. «Vaciar datos» conserva cuenta y sesión (decisión «Sesiones — dos ejes» del 2026-09-09, punto 6, y S27i del
   2026-10-29). No se manda al Welcome ni a local: se arregla lo que rompe la sesión y lo que tapa el Panel.
2. La cola NO se tira entera: en la nube esas bajas son el «también se borran de tu cuenta» que promete la hoja. Se
   compacta: una fila cuya última operación pendiente es una baja deja de mandar sus altas anteriores.
3. Subida: token y attest se piden por trozo (no uno para toda la subida).
4. Hasta la primera bajada del proceso, el ciclo sube como mucho dos trozos y baja; el resto va en el ciclo siguiente.
5. La espera del Panel no espera a un motor que está esperando a que se inicie sesión.
6. Eliminar cuenta: visible para toda cuenta en la nube (sesión o modo nube). Sin sesión, al confirmar se pide entrar
   con la misma cuenta (la puerta de «Iniciar sesión») y luego se borra por el servidor.
7. Bug C: el alta de 2.3 apunta la marca de instalación nueva al terminar (solo `.freshInstall`, no las re-entradas).
8. Ficheros fuera de `toca` que hacen falta: `SyncPushClient.swift`, `CloudSyncRuntime.swift`,
   `CloudSyncEngine.swift`, `AccountDeletionService.swift`, `TabBarDefaultsMigration.swift`. Ninguna otra sesión los toca.
9. Gateway: `/account/delete` sirve tal cual; no se toca ni se despliega nada.
