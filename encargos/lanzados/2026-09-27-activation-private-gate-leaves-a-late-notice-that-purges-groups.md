# Activar Yala completo sin poder mirar iCloud deja un aviso cuyo borrado se lleva los grupos

## Contexto
Cola A autónoma Yala (riesgo real: borrado inesperado / pérdida de grupos). Acaba de mergear a 2.1 el PR #279 (`private-gate-back-from-found-keeps-a-resumed-arm`): volver desde «Encontramos datos» tras un corte ya no deja un borrado que la nube termina a ciegas. Residual medium aparcado a propósito en ese encargo (y en el del #278): `tickets/backlog/activation-private-gate-leaves-a-late-notice-that-purges-groups.md`.

Síntoma: estoy en solo-grupos y activo Yala completo → privado sin red (o sin iCloud). La app me deja seguir, termino la activación y conservo mis grupos. Días después, con iCloud funcionando, aparece «Encontramos datos tuyos en iCloud». Si elijo borrarlos, el borrado se lleva también mis grupos: justo lo que la activación existía para conservar.

Medido en el ticket: la puerta privada de la activación sale por `unverifiedExit: .proceedWatchingTheMirror` (`FullModeActivationView.swift`), así que `continueWithoutValidating` escribe el testigo del espejo tardío (`markPrivateChoseWithoutICloud`). `completeFullActivation` retira arm / «a medias» / neutro solo-grupos, pero no ese testigo. Tras la activación la sesión es privada: `runLateICloudMirrorCheck` sondea y presenta `.corpus`, cuyo borrado es `performICloudCorpusWipe(.handover)` (dominio de Grupos incluido). La puerta de «Restaurar → Empezar desde cero» lo evitó a propósito con `.returnWithoutClaimingAWipe`; la privada no.

Hora Lima ~10:25 domingo (diurno). Norma Jürgen 22-sep / 24-sep: tú eliges la opción robusta / good-practice (la Recommended del AskUserQuestion) y sigues sin preguntar a Jürgen por producto/techos/copy. Solo para si hace falta su device, secretos o acceso. De 06:00–21:00 Lima sí puedes AskUserQuestion de producto/acceso real; para elecciones de producto Frank/Claude elige robusto/Recommended sin preguntar a Jürgen salvo device/secretos/demasiado consecuente.

MODO AUTÓNOMO — override explícito: la regla del repo «wait for approval if >3 files» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo. Implementa hasta gate/PR/merge/`/cerrar-total` sin pedir continuar.

## Que se pide
Cierra el ticket `activation-private-gate-leaves-a-late-notice-that-purges-groups`:
1. Ningún aviso que vea quien activó Yala completo ofrece un borrado que purgue sus grupos.
2. La validación de iCloud que no se pudo hacer al activar sigue ocurriendo cuando se pueda (no tirar la validación aplazada por completo).
3. Decisión robusta entre las del ticket: (a) el aviso tardío de quien activó borra con otro alcance (`.importedRows`, sin purgar Grupos), o (b) la activación no deja el testigo y valida de otra forma. Elige la Recommended / good-practice y documenta por qué.
4. Tests que fijen el alcance del wipe del aviso post-activación y que los grupos sobrevivan.
5. Board al día: ticket a qa o done según criterio del repo; hallazgos nuevos → ticket propio en backlog antes de cerrar; actualiza `docs/TICKETS.md`.
6. Cierra con `/cerrar-total` (worktree de `lanzar-sesion`).

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- No paralelizar otro modelo semántico ni otro encargo Cola A
- No inventar alcance: el residual nuevo `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud` es otro ticket; no lo metas en este PR salvo que el mismo cambio lo cubra de verdad y lo documentes
- Device-QA opcional: no bloquees el merge esperando iPhone

## Como se sabe que esta bien
- Criterios de aceptación del ticket en verde (tests + lectura del camino activación → testigo → aviso tardío → wipe)
- PR mergeado a 2.1
- Board y `docs/TICKETS.md` coherentes
- `/cerrar-total` limpio

## Paso 0

Decisiones tomadas (MODO AUTÓNOMO, auto-contestadas con la opción robusta):

1. **Opción (a)**: el aviso tardío de quien activó Yala completo borra con `.importedRows` (zona + filas
   personales; preferencias y grupos intactos). La (b) pierde la validación aplazada o la bloquea (ADR §9: no
   poder preguntar a iCloud jamás bloquea). El copy del aviso («tus registros, tus cuentas y tus presupuestos»)
   ya describe `.importedRows`: no nombra los grupos.
2. **El alcance lo decide un hecho de la SESIÓN, no del testigo**: `PrivateSessionMark` apunta «nació de
   Activar Yala completo» en `completeFullActivation`, ANTES del eje (kill-safe), y muere con el eje (`clear`,
   `set(false)`). Atarlo al testigo no bastaba: «Terminar de borrar» del Welcome (`.leaveForLateNotice`) usa
   el mismo aviso sin testigo y tiene que seguir en `.handover`.
3. **Un solo punto de borrado tardío** (`performLateICloudWipe`) para los tres caminos: el aviso, «Terminar de
   borrar» y la reanudación del arranque. Con grupos conservados pide la convergencia del bridge (misma receta
   que «Restaurar → Empezar desde cero») y re-mide las señales en vez de bajarlas a `false`.
4. **Tras el borrado, onboarding personal** (`hasCompletedOnboarding = false`, como hoy): la activación ya dejó
   `hasShownWelcomeChooser = true`, así que abre el onboarding y no el Welcome.
5. **Asumido — parque**: la key es nueva y está AUSENTE en quien activó con un build anterior (TestFlight, 3
   testers). Ausente ⇒ `.handover`, el comportamiento de hoy; se prefiere a que un Welcome antiguo deje de sellar
   el dominio de otra persona. Se dice en el PR.
6. Fuera: `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud` (otro ticket). Copy sin tocar.
