# El servidor ya no da el relevo de una activación que pasó el cutover; B adopta la cuenta completa

## Contexto
Sale del cierre de #238 (`leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile`, mergeado a 2.1). Medido en producción: `claim_account` da `created` a un claim de migración con lease vencido sin mirar `migrated_at`. Tras el cutover la cuenta ya está verificada; dar el relevo hace que B vuelva a subir su corpus entero encima (trabajo inútil). El cliente A ya no sube residual (#238); falta cortar el grant en servidor y que B salga sin callejón.

Ticket: `tickets/progress/claim-grants-a-takeover-after-the-leader-passed-the-cutover.md` (ya en in-progress).

## Decisión de producto (ya tomada — no preguntes)
Con `migrated_at` puesto y lease vencido, B recibe **adopt / `existing_stable`**, no espera como seguidor (`claiming_in_progress`) ni un nuevo relevo (`created`).
Motivo: la cuenta ya está completa; esperar deja a B atrapado si A no vuelve (teléfono perdido); adoptar cierra el callejón. El reverse_claim sobre un forward abandonado sigue siendo por diseño y no se toca.

## Que se pide
1. En `claim_account`, con claim de migración y `migrated_at` ya puesto: no devolver `created`/relevo. Devolver el camino de cuenta estable / adopt (`existing_stable` o el equivalente canónico del banco g16_03).
2. Ampliar el banco de escenarios de g16_03 (sandbox transaccional en producción; receta en memoria Frank `verificar-backend-yala`).
3. Cliente de B: tratar esa respuesta sin callejón (flujo adopt, sin re-subir corpus de migración encima de la cuenta completa).
4. No romper: relevo legítimo antes del cutover; reverse_claim de vuelta a iCloud tras cutover abandonado (por diseño).

## Que NO hay que tocar
- marketing/, Web/
- El comportamiento de #238 en el cliente A post-cutover (espera / une / recupera)
- reverse_claim legítimo post-cutover
- No pedir OK a Jürgen por producto: decisión adopt ya fijada arriba. Solo AskUserQuestion si hace falta su device/secretos/acceso real (horario diurno Lima).

## Como se sabe que esta bien
- Criterios del ticket cumplidos (decisión implementada, g16_03 ampliado, cliente B sin callejón).
- Gate verde; mutantes del área muertos; review de lentes.
- Ticket a `qa` con guion device-QA si aplica, o `done` si no hace falta QA manual; `docs/TICKETS.md` al día.
- PR mergeado a `2.1` y `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante acceso/secretos reales de Jürgen. La regla del repo «espera aprobación si >3 files» / «¿Sigo?» tras el plan queda suspendida en este encargo: implementa hasta cerrar.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de acceso de Jürgen (no de producto: eso ya está decidido);
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo que vas a reclasificar, build a reintentar, ni ruido de CI advisory.

## Paso 0 (resuelto por la sesión, sin nadie delante)

**Medido antes de decidir** (producción, lectura, 2026-09-24): `claim_account` md5 `c96106b7…` (g16_03) da `created` con
`migration_in_progress` + líder ajeno + lease > 60 min y `p_migration`, sin mirar `migrated_at`. En `migration_progress`
(md5 `14fc5e2c…`) solo el `cutover` del líder estampa `migrated_at`, y solo `reverse_claim` cambia de líder con la
migración en curso (y la cierra: `mip=false`). ⇒ con `migrated_at` puesto y `mip=true`, el líder registrado es el que hizo
el cutover. En el cliente, `existing_stable` ya lleva a B al adopt por las tres puertas que conducen la migración: el poll
del seguidor (`leaderCompleted`), `driveClaim` con `adoptIfExisting`, y el Welcome/alta (`routeReturningUser`). Ninguna
lee `profile.migration_in_progress`, y el Worker no bloquea el push por `mip`.

1. **Rama nueva** → migración `g16_04`, no editar g16_03 (ya aplicada): con `mip`, líder ajeno, lease vencido (no nulo) y
   `migrated_at` puesto, `existing_stable` con su `profile`. El líder NO cambia, así que A, al volver, sigue liderando y
   cierra con su `complete`.
2. **También sin `migration`** → sí. *Asumido*: hoy un claim sin migración recibe ahí `claiming_in_progress` y el Welcome
   de «Soy nuevo» se queda esperando a un A que puede no volver — el mismo callejón que la decisión cierra. Es completar
   el objeto que la decisión nombra (B recibe `existing_stable`, no espera).
3. **Sello `personal_adopted_at`** → solo con `migration`, la regla de g16_02 (B entra en la cuenta).
4. **Lease vigente con `migrated_at`** → sin cambio (`claiming_in_progress`): A está vivo y cierra en segundos.
5. **Cliente** → sin cambio de lógica: B ya adopta con `existing_stable`. Se corrigen los docblocks y la regla que decían
   que el servidor da el relevo tras el cutover. Las ramas `retaken`/`otherLeads` de #238 quedan para un servidor sin
   g16_04 (no se tocan: el encargo lo prohíbe y son inofensivas).
6. **Goldens del Worker** → el 9 y el 9-bis heredaban el `migrated_at` del golden 6 y fijaban el relevo post-cutover como
   contrato: pasan a `migrated_at: null` (el relevo legítimo antes del cutover) y se añaden los dos casos nuevos.
7. **Aplicación** → banco en sandbox contra producción (vivo, nuevo, mutantes), staging primero, luego producción.
8. **El guion de #238** («B toma el relevo tras el cutover») deja de poder montarse: se anota en su ticket y lo sustituye
   el de este.
9. **Review adversarial** → sí (lease/claim).
