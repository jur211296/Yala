# Cuatro arreglos de 2.1 del QA del TestFlight 19: iCloud privado que se pasa de sus 25 s, «Rechazar» en grupos de la nube, unirse por enlace tras la bienvenida o un relanzamiento, y la bienvenida que sale 10-15 s antes de la invitación

## Contexto
Son las cuatro cards de 2.1 que salieron del QA guiado del TestFlight 19 (20-oct, sesión `Yala--qa-guiado-2-1-tf17`, iPhone de QA e iPad, Yala Dev desde ad6781f8a contra staging). Jürgen pidió que todo lo de 2.1 que salga del QA vaya junto en una sola sesión, y que vaya antes de los lotes de 2.2. Jürgen da 2.1 por casi cerrada: esto es lo último antes del envío. Las cuatro cierran solas. Lee cada card entera con `tablero ver <id>` antes de empezar: el contexto (MEDIDO / INFERIDO), el siguiente paso y el criterio de hecho están ahí. Lo INFERIDO es una hipótesis: verifícala antes de arreglar.

1. `tablero-no-pudimos-conectarnos-a-icloud-al-elegi-blqa` (high) · «No pudimos conectarnos a iCloud» al elegir iCloud privado: la revisión se pasa de su plazo TOTAL de 25 s con un iCloud con mucho historial (`ICloudPersonalCorpusProbe.measureFromCloudKit`, desenlace silencioso `scanDeadline`; `recordZoneChanges` desde token nil recorre también las páginas de borrados). Decisión de Jürgen: 2.1. Se pide plazo SIN avance (como el #564) en vez de total, o cortar en cuanto se sepa la respuesta, y un texto que no culpe a la conexión cuando fue el plazo. Mismo patrón que el ticket `reverse-prior-icloud-scan-has-a-fixed-deadline`.
2. `tablero-en-un-grupo-de-la-nube-rechazar-una-soli-840m` (medium) · En un grupo de la nube, «Rechazar» una solicitud de unión falla siempre: `GroupService.rejectMember` lanza `.backendActionUnavailable` para los grupos del canal backend y el rechazo nunca llega al servidor. Decisión de Jürgen: A, implementar el rechazo en el backend en 2.1 (RPC + cliente, simétrico a aprobar), y que el solicitante lo vea. Migración nueva solo aditiva; aplicarla en staging, NO en producción: deja el paso de producción en una card a `jurgen` con el comando exacto.
3. `tablero-unirse-por-enlace-en-una-instalacion-nue-t2q8` (medium, vuelve del QA) · El PR #566 arregló la entrada por el enlace directo, pero siguen fallando dos caminos: (a) bienvenida › «Vengo por un grupo › Tengo una invitación» con una cuenta completa que pide «Abre Yala otra vez»: al reabrir se monta el espejo de iCloud y sale «Antes de unirte, este teléfono queda en blanco»; (b) relanzamiento a mitad del flujo (en «Conectando con tu grupo…» cerrar Yala y reabrir el enlace) → mismo «queda en blanco». El neutro duradero del #566 no se arma o no sobrevive en esos dos caminos. Test de la decisión por las tres puertas (enlace directo, bienvenida › invitación, relanzamiento a mitad).
4. `tablero-al-abrir-un-enlace-de-invitacion-en-una-z81w` (medium) · Al abrir un enlace en una instalación nueva, la bienvenida normal sale 10-15 s interactiva antes de «Conecta tu cuenta». Decisión de Jürgen: desde el primer instante una pantalla «Abriendo tu invitación…» sin botones hasta «Conecta tu cuenta», y no esperar a la importación de iCloud para encaminar. Ver el grupo antes de pedir cuenta NO va aquí (es L12-17, 2.2). Va junto con la 3: es la misma puerta de entrada.

## Qué se pide
- Arreglar las cuatro, cada una con su test de la decisión (lógica pura donde se pueda) y su control: el caso en que el comportamiento viejo sí era el correcto.
- Textos nuevos en los 16 idiomas.
- Ticket en `tickets/qa/` por card (o actualizar el que exista), índice de QA y `docs/TICKETS.md` al día.
- Cada card en `in qa` a nombre de `jurgen` con un guion corto de device-QA en `siguientePaso` (iCloud privado con el contenedor de Yala Dev de test@ en el iPhone de QA; rechazar una solicitud en «QA unión 19»; las tres puertas de unirse en el iPad tras reinstalar sin abrir; abrir un enlace en instalación nueva y cronometrar). Si alguna no necesita su iPhone, a `done`.
- Si al verificar descubres que una card ya está resuelta en 2.1 o en 2.2, no la dupliques: dilo en el PR y en la card.

## Qué NO hay que tocar
- No tocar los iPhone ni el iPad de Jürgen: los usa el QA guiado. Todo en simulador y staging.
- Nada de 2.2. Si tocas archivos que cambiaron en 2.2 (grupos, nube, iCloud, bienvenida, `GroupService`), anota en el PR qué habrá que mirar al traer 2.1 a 2.2.
- No rediseñar la bienvenida, la unión ni la revisión de iCloud más allá de lo necesario. Si algo pide una decisión de diseño o de texto que no está en la card, deja la propuesta en la card a nombre de `jurgen` en espera de decisión y sigue con las demás.
- Nada en producción (ni migraciones ni deploy del gateway): queda en card a `jurgen`.
- No pedir OK a Jürgen: cierra sola con /cerrar-total.

## Dependencias
La sesión arranca ya sobre `origin/2.1`, sin esperar CI ni merge de ningún PR anterior (en cola a 2.1 están el #572, #573 y #575, de marketing). Justo antes de abrir el PR: `git fetch` y un solo rebase sobre `origin/2.1`; el build y el simulador van una vez después de ese rebase. PR contra 2.1. No esperes el CI para cerrar: el PR entra cuando el CI sale en verde.

## Mini (pipeline serial, sin preguntar)
1) Limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees ya cerrados. 2) Build con `xcodebuild -jobs 2` sin simulador encendido. 3) Bootear un solo simulador (antes, `xcrun simctl list devices booted`). 4) Tests. 5) Apagar y borrar ese simulador. Prohibido solapar build, simulador y UITests. La Mini anda con ~23 GB libres: no dejes builds viejos al terminar.
Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de un worktree vivo (el del QA guiado y el del roadmap). Si un borrado falla, dilo en el cierre.

## Cómo se sabe que está bien
- Se cumple el `hechaCuando` de cada una de las cuatro cards, con tests nuevos en verde y su control.
- `/barrido-qa` y `/gate` en verde en lo tocado; capturas de antes y después en `capturas/` para lo que se vea en pantalla (aviso de iCloud privado, rechazar, «Abriendo tu invitación…», las puertas de unirse).
- PR a 2.1 abierto y en cola de merge; cards movidas como se pide arriba.
- En el resumen de cierre, indica qué pruebas debe repetir la sesión del QA guiado y si hace falta un TestFlight 20.
- CIERRE: cierra sola, /cerrar-total sin esperar a Jürgen.

## Paso 0

Medido antes de decidir (worktree sobre `origin/2.1` @ 31c82a351). Lo INFERIDO va marcado.

### 1 · iCloud privado que se pasa de sus 25 s (blqa)
- **Medido:** `measureFromCloudKit` y `findAdoptRelevantRecord` cortan con un plazo TOTAL de 25 s (`scanDeadline`), mirado solo entre páginas. La revisión de la vuelta a iCloud (`scanForeignCorpus`) tiene el mismo molde con 60 s (ticket `reverse-prior-icloud-scan-has-a-fixed-deadline`).
- **Inferido, sin medir:** que la zona devuelva muchas páginas de borrados. El simulador no tiene CloudKit; queda instrumentado (páginas, registros, borrados en el rastro DEBUG) para el device-QA.
- **Decisión:** plazo SIN avance, el molde del #564. Avanzar es que llegue una página, traiga lo que traiga. Un solo recorrido puro (`ICloudZoneScan`) para las tres revisiones: la de la puerta, la del adopt y la de la vuelta (25 s / 25 s / 60 s sin avance). «Cortar en cuanto se sepa la respuesta» no aplica: la pantalla enseña cifras. La pantalla «Revisando…» ya tiene «Volver», así que una revisión larga no deja a nadie sin salida.
- **Texto:** cuando el motivo es el plazo (`scanStalled`), título y cuerpo propios que no hablan de la conexión, en la puerta y en su variante «no borramos nada». El texto de la vuelta a iCloud no cambia (queda en su ticket).

### 2 · «Rechazar» en grupos de la nube (840m)
- **Medido (premisa de la card falsa):** el servidor YA rechaza. `remove_member` deja `rejected` a un `pendingApproval` (`supabase-groups-staging.ddl`, §5), `g13_02` deja al rechazado leer su fila (aplicada en producción el 2026-09-03), el Worker le manda el aviso neutro y la app pinta «no te aceptaron» (`GroupDetailView`). Lo que falta es solo el cliente: `GroupService.rejectMember` lanza `.backendActionUnavailable`.
- **Decisión:** el cliente rechaza con `remove_member`, servidor primero y luego `.rejected` en local, como aprobar. **Sin migración ni deploy del gateway**: funciona en producción con el build. Asumido: no se crea un RPC `reject_member` aparte (pediría migración y deploy en los dos entornos y esta sesión no tiene acceso a staging).
- **Residual aceptado, con ticket:** con el estado local viejo (aprobado desde otro dispositivo del mismo admin), «Rechazar» expulsaría a quien ya está dentro. En el canal backend hay un solo admin por grupo (no existe RPC de cambio de rol), así que solo pasa con el mismo admin en dos aparatos.

### 3 · Unirse por enlace tras la bienvenida o un relanzamiento (t2q8)
- **(a) Medido:** «Tengo una invitación» sale del Welcome por `leaveWelcome(to: .inviteRecovery)`, y `WelcomeMirrorRelaunchLogic.requiresMirror(.inviteRecovery)` es `true` (razón de la era CKShare, que ya no existe). En una instalación nueva eso pide reabrir, marca el chooser y el arranque siguiente monta el espejo: baja el iCloud del aparato y la puerta del invitado pide dejar el teléfono en blanco. El enlace directo no pasa por ahí.
- **(a) Decisión:** `.inviteRecovery` deja de pedir el espejo (como `.groupsInvite`), y elegir «Tengo una invitación» no marca el chooser (como «Crear mi primer grupo»). Así `persistIntent` arma el neutro duradero igual que por el enlace.
- **(b) Inferido del código (sin device):** tras el CTA de la hoja, el alta del invitado siembra categorías y el canal baja sus grupos; al relanzar, el montaje SÍ es neutro (dos marcas armadas), pero la puerta cuenta esas filas como de otra persona (`hasExistingData`).
- **(b) Decisión:** dos testigos de «esto es de quien está delante». La puerta gana un término `inviteConfirmedOnThisDevice` (la persona ya dijo que sí a ESTA invitación aquí, después de que la puerta la dejara pasar) que apaga solo el término del corpus, nunca el del espejo. Y el sign-in del invitado apunta la marca de grupos de quien entra (`LateNoticeKeptGroupsMark`, la de `onEnterGroupsOnly`) para el relanzamiento entre firmar y el CTA.
- **Tests:** las tres puertas como secuencia de escrituras + montaje + puerta, con su control (espejo montado, datos de otra persona sin confirmar).

### 4 · La bienvenida que sale 10-15 s antes de la invitación (z81w)
- **Medido:** los 10-15 s son `forceFetchAndWait(timeout: 15)` de `awaitPersonalStoreReady`, que el reconciler espera antes de encaminar; en un montaje neutro no hay import que esperar.
- **Decisión:** (i) el reconciler del arranque no espera al import cuando este proceso no montó espejo, el modo es `.icloud` y hubo un enlace en este arranque; (ii) «Abriendo tu invitación…», sin botones, dentro del cover del Welcome mientras haya un enlace abierto en este arranque sin onboarding hecho, hasta que la cadena del invitado releve al Welcome, el enlace falle, el join salga directo o venza un techo de 20 s (vuelve el Welcome normal: no hay camino muerto).
- **Residual:** la selección de idioma (solo con idioma del sistema no soportado) no se cubre.

### Comunes
- Textos nuevos en los 16 idiomas. Tickets en `tickets/qa/` y cards a `jurgen` en `qa` con su guion. Ninguna se cierra sin su iPhone o iPad.
- Al traer a 2.2: `GroupService`, `ICloudPersonalCorpusProbe`, `WelcomeFlowContainer`, `ContentView`, `AppBootstrapper`, `GroupBackendInviteEntryHandler` (anotado en el PR).

## Resultado

- **blqa**: las tres revisiones de iCloud pasan por `ICloudZoneScan` con plazo sin avance; texto propio cuando vence («iCloud tardó demasiado en responder»), 16 idiomas. Rastro `ICloudScan[…] pages= records= deletions=` para el device-QA.
- **840m**: «Rechazar» va por `remove_member` (el servidor ya rechazaba; sin migración ni deploy). Nada queda para producción.
- **t2q8**: (a) «Tengo una invitación» ya no pide el espejo ni marca el chooser; (b) la marca del alta sobre un store limpio y la de grupos al firmar. Test de las tres puertas con sus controles.
- **z81w**: «Abriendo tu invitación…» sin botones (sustituye al Hero y los selectores; tapa los pasos con trabajo en vuelo) con techo de 20 s desde que se ve, y el reconciler del arranque encamina sin esperar al import con un enlace y sin espejo.
- Review adversarial con dos lentes: cambió la página tardía del adopt, la zona borrada como respuesta, las validaciones locales antes de rechazar, el techo desde que se ve, el fin de la apertura cuando no hay nada que abrir y la marca de grupos solo con el canal arrancando.
- Gate: `Yala` y `Yala Dev` sin warnings nuevos; 10022 unit tests en 1019 suites; 43 XCUITest de las áreas tocadas (centinela 0); dos mutantes caen; índice de QA OK.
- Pase de estrés: solo hay un iPhone instalado (17 Pro). AX5 en alemán: la pantalla de apertura cabe; los avisos de la puerta privada se cortan, también los de antes (`private-gate-notices-overflow-at-the-largest-text-size`, backlog).
- Capturas: `/Users/jur/Claude/worktrees/_capturas/2026-10-20-qa-2-1-icloud-privado-rechazar-y-enlace/`.
