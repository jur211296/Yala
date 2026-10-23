# Cuatro arreglos de 2.1 que quedan del QA guiado del 19-oct: «Activar la nube» parada por App Attest, la espera a que iCloud termine, unirse por enlace en una instalación nueva y «Mira lo nuevo» tras actualizar

## Contexto
Son las cuatro cards de 2.1 que quedan de las halladas por Jürgen en el QA guiado del 19-oct (sesión `Yala--qa-guiado-2-1-tf17`, iPhone de QA e iPad, TestFlight 18 contra producción). Mientras 2.1 esté en QA, sus correcciones van primero. Las otras cuatro ya van en el PR #564 (asociación de Grupos, borrado de iCloud, grupos sin relanzar, música tras la voz) y la de iCloud Drive apagado en el #562; el QA guiado espera un TestFlight 19 con todas. Las cuatro cierran solas. Lee cada card entera con `tablero ver <id>` antes de empezar: el contexto (MEDIDO / INFERIDO), el siguiente paso y el criterio de hecho están ahí. Lo INFERIDO es una hipótesis: verifícala antes de arreglar.

1. `tablero-activar-la-nube-se-queda-en-60-sin-subir-axgf` (high) · «Activar la nube» se queda en ~60 % sin subir nada hasta cerrar y abrir Yala (App Attest en producción). Medido: 401 `yala_attest_required` en producción; `CloudMigrationController.makeExecutor` pide el attest con `try?`, y la migración, la vuelta y el adopt usan clientes sin la puerta de attest. Se pide que pidan o renueven la sesión de App Attest ante ese 401 y reintenten, con el mismo trato que el motor de sync. La card `vv0k` (2.2, primera foto fallida) podría tener la misma causa: si es así, dilo en el PR y en esa card, sin arreglarla aquí.
2. `tablero-activar-la-nube-con-6-movimientos-espera-ppxk` (medium) · Con 6 movimientos, «Activar la nube» espera más de 5 min a que iCloud «termine de sincronizar» y solo sigue al volver a la app; además «Cancelar la activación» está desactivado mientras espera. Medido: pre-espera de quiescencia con tope de 300 s, luego aparcado y solo reintentan foreground o boot. Hipótesis: el barrido de duplicados de Account re-exporta y re-importa en bucle. Se pide medir por qué el import no se asienta con un corpus mínimo, reintentar en primer plano tras el tope, decir en pantalla qué espera y dejar una salida mientras espera. Va junto con la 1: es el mismo flujo.
3. `tablero-unirse-por-enlace-en-una-instalacion-nue-t2q8` (medium) · Unirse por enlace en una instalación nueva bloquea por los datos privados del propio iCloud. Confirmado en pantalla: el primer arranque por enlace monta el espejo de iCloud y baja los datos privados del Apple ID, y la unión además espera ~8 min por `importNotQuiescent`. Se pide alinear la puerta de invitación con la del Welcome (montaje neutro antes de decidir), con test de la decisión por las dos puertas.
4. `tablero-al-actualizar-desde-la-2-0-4-mira-lo-nue-n2xn` (medium) · Al actualizar desde la 2.0.4, «Mira lo nuevo en Yala» no sale en el primer arranque sino en el segundo, y no pasa siempre (en el iPad sí salió). Se pide reproducir con Yala Dev en simulador (build de v2.0.4 desde su tag, onboarding privado, 2.1 encima con consola) y arreglar la rama que no encola o descarta `.presentWhatsNew`. Si no se reproduce en simulador tras un intento serio, deja lo medido y la hipótesis en la card, con un guion de device-QA para Jürgen, y sigue con las demás.

## Qué se pide
- Arreglar las cuatro, cada una con su test de la decisión (lógica pura donde se pueda) y su control: el caso en que el comportamiento viejo sí era el correcto. Para la 1, test del 401 en el executor; para la 2, test del reintento tras el tope.
- Ticket en `tickets/qa/` por card (o actualizar el que exista), índice de QA y `docs/TICKETS.md` al día.
- Cada card en `in qa` a nombre de `jurgen` con un guion corto de device-QA en `siguientePaso` (D · E2 activar la nube recién instalado en TestFlight; activar la nube con un iCloud que traiga cuentas duplicadas; D · E1 paso 3 unirse por enlace tras reinstalar; ly22 paso 3 actualizar desde la 2.0.4). Si alguna no necesita su iPhone, a `done`.
- Si al verificar una hipótesis descubres que la card ya está resuelta en 2.1 o en 2.2 (mira en especial el PR #560 de 2.2, «activar la nube, iCloud y reabrir Yala»), no la dupliques: dilo en el PR y en la card.

## Qué NO hay que tocar
- No tocar los iPhone ni el iPad de Jürgen: los usa el QA guiado. Todo en simulador.
- Nada de 2.2. Si tocas archivos que cambiaron en 2.2 o en el PR #564 (nube, iCloud, `StorageSettingsView`, `CloudMigrationController`, `UITestHooks`), anota en el PR qué habrá que mirar al traer 2.1 a 2.2.
- No rediseñar los flujos de migración, vuelta a iCloud, unión por enlace ni novedades más allá de lo necesario para cada arreglo. Si alguno pide una decisión de diseño o de texto que no está en la card, deja la propuesta en la card a nombre de `jurgen` en espera de decisión y sigue con las demás.
- No pedir OK a Jürgen: cierra sola con /cerrar-total.

## Dependencias
La sesión arranca ya sobre `origin/2.1`, sin esperar CI ni merge de ningún PR anterior (el #564 está en cola de merge a 2.1). Justo antes de abrir el PR: `git fetch` y un solo rebase sobre `origin/2.1`; el build y el simulador van una vez después de ese rebase. PR contra 2.1. No esperes el CI para cerrar: el PR entra cuando el CI sale en verde.

## Mini (pipeline serial, sin preguntar)
1) Limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees ya cerrados. 2) Build con `xcodebuild -jobs 2` sin simulador encendido. 3) Bootear un solo simulador (antes, `xcrun simctl list devices booted`). 4) Tests. 5) Apagar y borrar ese simulador. Prohibido solapar build, simulador y UITests. La Mini anda con ~21 GB libres: no dejes builds viejos (la de v2.0.4 incluida) al terminar.
Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de un worktree vivo (el del QA guiado y el del roadmap). Si un borrado falla, dilo en el cierre.

## Cómo se sabe que está bien
- Se cumple el `hechaCuando` de cada una de las cuatro cards, con tests nuevos en verde y su control.
- `/gate` en verde en lo tocado; capturas de antes y después en `capturas/` para lo que se vea en pantalla (progreso de «Activar la nube», qué espera, unirse por enlace, «Mira lo nuevo»).
- PR a 2.1 abierto y en cola de merge; cards movidas como se pide arriba.
- En el resumen de cierre, indica qué pruebas debe repetir la sesión del QA guiado.
- CIERRE: cierra sola, /cerrar-total sin esperar a Jürgen.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir (card axgf).** Telemetría de producción (`yala_metrics`, 19-oct): el iPhone que migraba es la instalación `79a1ba45` (`cloudConsentAccepted migration` 22:13:05). El `cloudSyncAttestRequired prefs-pull` de las 22:17:20 que cita la card es de OTRA instalación, `5fc8fa9f` (el iPad, que esa tarde hacía la unión a «QA unión» y un adopt). El iPhone no emitió ningún `cloudSyncAttestRequired` (push/pull/merkle) ni `cloudSnapshotUploadWaiting` antes de reabrir, y el spool de métricas es kill-tolerante (`UserDefaults`), así que no se perdió. ⇒ el push del snapshot nunca salió en ese proceso: la pasada se quedó dentro de un `await` sin observar nada (barra en `uploadingSnapshot`, «Retomar» apagado por `isWorking`). En ese tramo, el único `await` sin techo es el token de App Attest (`AppAttestClient.currentSessionToken`: single-flight sin límite; `DCAppAttestService` y `Transaction.currentEntitlements` no traen timeout). La premisa de la card («401 `yala_attest_required` en producción») es FALSA para ese iPhone; la hipótesis «se colgó el refresh del attest» queda INFERIDA.

**D1 · ¿Qué se arregla en la card 1, si el 401 no llegó a ocurrir?** → Las dos cosas: (a) un techo de 90 s a la espera de un refresh de attest en vuelo, pasado el cual se abandona y el siguiente llamador empieza otro; (b) lo que pide la card: ante un 401 `yala_attest_required`, el cliente que lo recibe hace olvidar el token guardado si es el que viajó, y el reintento de siempre pide uno nuevo.
Por qué: (a) es lo que explica lo medido; (b) cierra el otro modo de quedarse con un token rechazado (backlog `attest-session-token-rejected-by-the-gateway-stays-cached`). Alternativa descartada: solo (b) — arreglaría la premisa falsa y dejaría el síntoma.

**D2 · ¿Dónde vive el techo: en el executor de la migración o en `AppAttestClient`?** → En `AppAttestClient`, una sola vez.
Por qué: un techo solo en la migración dejaría colgada la tarea compartida y cada pasada siguiente esperaría su techo para mandar un push sin cabecera; y la IA, los tipos de cambio y Grupos esperan a la misma tarea. Alternativa descartada: timeout por llamador.

**D3 · ¿Cuántos 401 olvidan el token?** → Los ocho sitios que leen `yala_attest_required` (push, pull, merkle, prefs ×2, Grupos sync ×2, membresía), con el token que viajó.
Por qué: «todas las instancias del patrón». El reintento lo pone la cadencia que ya tiene cada llamador: no se añade un bucle dentro del cliente (el de fuera multiplicaría el de dentro).

**D4 · ¿El executor de la migración sigue con `try?`?** → No: un proveedor propio que deja rastro (`CloudSyncBreadcrumb`) del fallo y devuelve `nil`. Contrato «cabecera o nada» intacto.

**D5 · Card vv0k (2.2, primera foto).** → No se toca. Su forma es otra (falla AL INSTANTE, no se cuelga); se anota en el PR y en la card la pista común (el token guardado lleva el tier y podía ser de antes de la compra).

**D6 · Cards 2-4.** → Se deciden tras medir (subagentes de lectura + telemetría); se anotan aquí abajo antes de escribir su código.

**Hechos medidos (card ppxk).** El bucle 75 → 55 % es la verificación de la ida: cuatro `cloudSyncMerkleDivergence accounts` (22:22, 22:44, 22:55, 23:15) y cada desajuste vuelve a `uploadingSnapshot`. La espera de más de 5 min es la pre-espera de quiescencia (`awaitImportQuiescenceForResume`, 300 s): `isImportQuiescent` exige 8 s sin un import terminado, y no los tuvo. La afirmación «tras el tope nadie reintenta con la app delante» es FALSA en Almacenamiento: su bucle de 1 s re-kickea cada 30 s, pero lo hace con `await`, así que la pantalla deja de refrescarse mientras espera. «Cancelar» está apagado por `isWorking` durante toda la pre-espera. No hay un barrido que BORRE cuentas: el `Account|boot-cleanup` lo emiten un recuento de solo lectura y `repairCollapsedIdentityUUIDs`, que regenera `Account.shortcutID` (el sync_id) y en `.icloud` no se difiere con la ida en vuelo. Por qué el import no se asienta con 6 movimientos no se puede medir en simulador (sin CloudKit).

**D7 · Card ppxk: ¿qué se arregla sin poder medir el import?** → Cuatro cosas: (a) la reparación de identidades se difiere en `.icloud` con la ida en vuelo (mismo predicado que en `.cloud`), que quita una causa de la divergencia de `accounts`; (b) «Cancelar la activación» se puede tocar durante la pre-espera y la corta; (c) el bucle de Almacenamiento no espera al re-kick, así que la pantalla sigue al día; (d) canario `cloudMigrationImportNotSettled` al vencer el tope, con qué tenía a iCloud sin asentarse.
Por qué: lo medible se arregla y lo inferido se instrumenta. Alternativa descartada: quitar la quiescencia de la pre-espera (protege del SIGTRAP del contexto compartido; no se toca sin medir).

**D8 · Card ppxk: ¿texto nuevo para «qué espera»?** → No. La pantalla ya decía «Esperando a que iCloud termine de sincronizar…» (Jürgen lo vio); lo que fallaba era que no se refrescaba y no había salida. Un texto nuevo sería una decisión de copy que la card no toma.

**Hechos medidos (card t2q8).** Telemetría del iPad (`5fc8fa9f`): primer arranque 21:33 (descarte de la key de attest = instalación nueva), consentimientos `adopt` 21:35, y el espejo exportando a las 21:39:26 en un proceso posterior de la MISMA instalación. El primer proceso por enlace monta NEUTRO (la hipótesis de la card es falsa para él); el neutro de instalación nueva dura un proceso, y el siguiente adjunta el espejo. Y el primer bloqueo («datos de otra cuenta») sale de que la hoja de Grupos arranca el canal al firmar, el canal baja los grupos de la cuenta completa y el guard cuenta `SplitGroup`.

**D9 · Card t2q8** → (a) al entrar por un enlace con el montaje neutro y nada elegido, se arma el neutro durable del cierre de sesión (`armNeutralMountIfUnarmed`, caduca con `hasShownWelcomeChooser`); (b) con una cuenta completa, la hoja de Grupos no arranca el canal antes del guard.
Por qué: son las dos causas medidas. Alternativa descartada: que el guard cuente solo datos personales (cambiaría la puerta del Welcome, que no falla).

**D10 · Card n2xn** → Primero reproducir en simulador (2.0.4 desde su tag, onboarding privado, 2.1 encima con consola). La hipótesis de la card (la marca de sesión en el splash) es falsa: con la marca ausente, `hasPrivateSession()` vale `true`. Si no se reproduce, se deja lo medido y un guion de device-QA en la card.

**Hechos medidos (card n2xn).** Reproducido en simulador (iPhone 17 Pro, iOS 27.0) con el build de `v2.0.4` y la 2.1 encima: la 2.0.4 deja `needsPostOnboardingTrial` sin consumir tras «Restaurar» con destino directo a la app, y la 2.1 ponía la oferta antes que Novedades. Control sin oferta: Novedades a la primera.

**D11 · Card n2xn** → Novedades antes que la oferta pendiente, una hoja por arranque; la oferta sale en el siguiente. Por qué: cumple el `hechaCuando` sin apilar dos hojas. Alternativa descartada: encolar las dos en el mismo arranque.

**D12 · Lo que cambió la review adversarial (tres lentes)** → (a) alto: el neutro que arma el enlace se retira al adoptar una cuenta completa (`retireNeutralMountOnChoice` en `onAdoptStarted`), o «Volver a iCloud» habría montado sin espejo; (b) «Cancelar» no se puede tocar dos veces durante su propia espera (`isCancellingMigration`); (c) el diferido de la reparación empieza en `assigningIdentity`, no antes; (d) el paso del refresh del canario es por tarea, y el rastro del executor dice el motivo real. Quedan con ticket: el canal de Grupos que el arranque o el primer plano aún pueden arrancar antes del guard, y las otras dos salidas apagadas durante la pre-espera.

**D13 · Gate: once XCUITest tapados por la oferta de prueba** → `-uitest-reset` ahora baja también en memoria la oferta pendiente (salvo con el seam nuevo). Era una contaminación entre tests, no un fallo del producto: aislados pasaban y la debug description mostraba la oferta encima del avatar.
