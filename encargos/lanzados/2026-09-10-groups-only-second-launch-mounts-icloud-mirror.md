# Paso 5: solo-grupos no debe adjuntar iCloud al reabrir (y se retira la puerta «datos ajenos»)

## Contexto
Cola autónoma del rediseño de sesiones. Acaba de cerrar el **paso 4** (`welcome-private-fresh-start-skips-icloud-check`, PR #133 mergeado a 2.1; ticket en `tickets/qa/` — device-QA iPhone pendiente, punto BLOQUEANTE: sonda CloudKit).

Ticket: `groups-only-second-launch-mounts-icloud-mirror` (high, backlog).
Quién arranca: sesión limpia, sin nuestra conversación.

Síntoma medido: «Vengo por un grupo» → alta → reabrir ⇒ el store personal monta espejo de iCloud y baja datos ajenos. También: si el store ya tenía espejo/datos, la puerta «datos ajenos» bloqueaba al dueño — **esa puerta se retira aquí**.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Solo parar ante decisión/acceso real. Secrets.xcconfig ya va por `.claude/worktree-enlaces`. UI tests CI advisory.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo que vas a reclasificar, build a reintentar, ni ruido de CI advisory.

## Que se pide
1. Leer el ticket entero + decisiones de Jürgen (2026-09-09) + ADR §2-3 + docblock de `CloudSyncFlags.armNeutralMount`.
2. Alta solo-grupos (crear e invitación) deja neutro **duradero** en todos los arranques hasta «Activar Yala completo»; no caduca con `hasShownWelcomeChooser` en este caso.
3. Si al elegir grupos el store ya lleva espejo/datos: vuelta al neutro (espera export pendiente antes de borrar local; avisa sin confirmar; cancela restore en curso si aplica); iCloud intacto; sin pantalla de bloqueo «datos ajenos».
4. Unit tests del mount; review adversarial; `/gate` verde; PR a `2.1`; board + `docs/TICKETS.md`; device-QA CloudKit queda en `qa/`.
5. `/cerrar-total` al terminar (worktree).

## Que NO hay que tocar
- marketing/ (Lola).
- Paso 4 ya mergeado (salvo consumo mínimo de su validación al pasar a privado).
- Pasos 6–13 salvo lo mínimo que este mount exija.
- clinicas / datos de salud.

## Como se sabe que esta bien
Criterios de aceptación del ticket; PR mergeado a 2.1; board/`TICKETS.md` al día; `/cerrar-total`.

## Paso 0 — decisiones

Dos las contestó **Jürgen en vivo** (2026-09-10) porque eran suyas y el propio ticket las anticipaba;
el resto las resolví yo contra el árbol y se discuten en el PR. Detalle largo con coordenadas en el
ticket (`tickets/…/groups-only-second-launch-mounts-icloud-mirror.md`, sección «Paso 0»).

### Contestadas por Jürgen

- **D3 · La mitad 2 (estado B: el store ya lleva espejo) NO se implementa aquí.** Se entrega la mitad 1
  y el estado B sale a ticket propio. Motivo medido: el desmontaje en caliente que pedía el ticket lo
  rechaza `PersonalSwapReleaseLogic.mountAdmitsSwap` por diseño cuando el mount de salida lleva mirror
  (spike R3: CloudKit siguió emitiendo eventos 10 s DESPUÉS del release), y —peor— `wipeAllUserData`
  borra por filas sobre un store con mirror, así que **los deletes se exportarían a iCloud** y
  destruirían el corpus que el criterio de aceptación promete conservar. «Esperar al export» no existe
  en el repo. Era el punto que el ticket marcaba como «avisa y espera».
- **D5 · Sin migración para el parque instalado.** El arreglo cubre a quien haga el alta a partir de
  ahora. Armar la marca retroactivamente a todo `.groupInvite` alcanzaría a quien restauró de iCloud con
  ese modo heredado por iKV y le apagaría el espejo. Quien ya está afectado se cura al reinstalar.

### Resueltas en autónomo (bypass)

- **D1 · Marca propia `groupsOnlyNeutralMount`, sin término de caducidad**, en vez de reusar
  `armNeutralMount` o derivar de `onboardingMode`. Las dos alternativas están descartadas por medición:
  derivar del modo destruye un restore legítimo; reusar la marca vieja la deja inerte para quien tocó
  «privado» antes de volver a Grupos (`onSelectPrivateAccount` marca el chooser en el acto).
- **D2 · Se arma en las dos ALTAS, no en las dos puertas.** `writePreferences` (organizador) y
  `performSilentSetup` (invitación). `performJoinOnlySetup` —invitado que ya tiene onboarding— NO arma:
  es el caso «privada + grupos asociados» del ADR §2, que sí quiere su espejo.
- **D2-bis · Se levanta en dos sitios**, y el segundo es el anti-bucle que sustituye a la caducidad:
  `FullModeActivationView` y `onNeedsMirrorRelaunch`.
- **D4 · La puerta «datos ajenos» NO se retira todavía.** Sin la vuelta al neutro de D3, retirarla deja
  al usuario creando un grupo encima de datos ajenos — peor que el bloqueo. Se va con D3.
- **D6 · El parámetro nuevo de `shouldMountNeutralDurable` va SIN valor por defecto**, siguiendo la
  convención declarada del área (`freshInstall` y `neutralDurable` ya lo hacen): en la tabla de mounts un
  descuido cuesta un store montado del revés, así que el compilador obliga a cada llamador a pronunciarse.
