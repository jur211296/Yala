# Si cierro Almacenamiento mientras el desasociar espera, el coordinador de cierre queda stranded

## Contexto
Alternancia Cola A ↔ carril adaptativo (una sola sesión Yala a la vez). Acaba de cerrar el turno adaptativo `ipad-real-multiwindow-with-per-scene-state` (PR #324 en cola de auto-merge a 2.1, mergeable_state blocked esperando CI — no lo reabras). Cola A otra vez.

Ticket: `tickets/backlog/detach-blocked-phase-is-stranded-when-the-storage-sheet-closes-mid-wait.md` (medium, modo-nube/settings/groups). Hallazgo de la review adversarial de #323 (`detach-saves-the-personal-graph-outside-the-quiescence-window`, ya mergeado). Riesgo real de usuario: tras «Desasociar» + cerrar la hoja de Almacenamiento a mitad de la espera, un `.blocked` sin pantalla que lo enseñe deja `CloudSessionSignOut.phase` en `.blocked`; «Cerrar sesión» no hace nada y un nuevo desasociar dice «Estás cerrando sesión» (falso). Solo sale matando la app.

Hermano de copy/low `detach-quiescence-timeout-says-group-changes-are-pending` (no lo abras en esta sesión salvo que el arreglo lo deje inseparable). Relacionado: `signout-alert-fires-on-detach-blocks-it-did-not-cause` (misma fase compartida — léelo para decidir el camino; no ensanches el alcance a ese ticket salvo inseparabilidad).

Base fresca desde `origin/2.1`. MODO AUTÓNOMO hasta el final: al cumplir el criterio, abre PR a `2.1`, encola auto-merge (ADR-054: `gh pr merge --auto --merge`, no esperes CI) y cierra solo con `/cerrar-total`. No despiertes a Jürgen por preferencias reversibles; elige Recommended en Paso 0 y sigue. Solo para si hace falta su dispositivo, secretos o algo irreversible/prod.

Pipeline serial en Mini (si build/tests): (1) limpiar sims muertos/basura (2) `xcodebuild -jobs 2` SIN simulador arrancado (3) boot 1 sim (4) tests (5) apagar/limpiar ese sim. Norma: 1 simulador a la vez. No solapes swift-frontend + SpringBoard + app + UITests.

## Qué se pide
1. Lee el ticket entero y el código vivo: `GroupsAssociationSection.apply`, `CloudSessionSignOut.phase` / `acknowledgeBlocked`, `ProfileView` (los `case` que ignoran motivos de desasociar), y el camino de #323 (`writeDetachUnderQuiescence`).
2. Mide el hueco ANTES de arreglar: reproduce (o fija en test) el strand — hoja cerrada mid-wait → `.blocked` sin `acknowledgeBlocked` → «Cerrar sesión» mudo / desasociar `.busy` con copy falso.
3. Arregla para que un `.blocked` del desasociar sin pantalla que lo enseñe no deje el coordinador cogido. Recommended (elige en Paso 0 y documenta): o la sección relee al reaparecer y enseña su aviso, o el bloqueo no se queda en la fase compartida cuando nadie lo va a reconocer. Coordina mentalmente con `signout-alert-fires-on-detach-blocks-it-did-not-cause` sin abrirlo.
4. Tests rojo→verde que fijen el strand (fase + aviso / reset). No aflojes guards vecinos del detach/sign-out (#321/#323 y suite detach).
5. Al terminar: mueve el ticket, PR a `2.1` con parte en el cuerpo, auto-merge, y **`/cerrar-total` de forma autónoma** (sin esperar a nadie).

## Qué NO hay que tocar
- No es carril adaptativo: no uses simuladores `YalaLane-Adapt-*` ni abras tickets de layout/iPhone/iPad/multiwindow.
- No abras Cola B (rediseño UI) ni Cola C / diferidos post-2.1.
- No reabras #319/#321/#323/#324; no toques marketing/, store copy, schema CloudKit de Production, ni Supabase prod.
- No limpies worktrees ajenos ni relances otros encargos. No toques clinicas.
- No pidas OK a Jürgen por el camino Recommended del Paso 0.
- No notifiques a Dan.

## Cómo se sabe que está bien
- Medición previa documentada del strand (fase `.blocked` huérfana tras cerrar la hoja).
- Tras el arreglo: cerrar Almacenamiento mid-wait ya no deja «Cerrar sesión» mudo ni el copy falso de «Estás cerrando sesión»; tests nuevos o ampliados en rojo→verde.
- PR abierto contra `2.1` con parte; auto-merge armado; sesión cierra limpia con `/cerrar-total` sin intervención.

## Cierre obligatorio — `/cerrar-total` autónomo
Cuando termines (PR listo o bloqueo real documentado), ejecuta **`/cerrar-total` tú solo**. Deja la Mini limpia:
1. Apaga el simulador de esta sesión.
2. Erase / limpia los datos de ese device (no dejes 2–5 GB colgando).
3. Si el PR mergeó o el worktree ya no sirve → quita worktree + `.ddp`.
4. No acumules Devices apagados ni worktrees viejos.
No dejes la sesión colgada. No mates un cierre que Jürgen ya haya arrancado.

## Paso 0 (auto-contestado, MODO AUTÓNOMO)

- **Camino:** el bloqueo del desasociar NO se queda en la fase compartida. `detachGroupsAccount` devuelve el motivo
  por el retorno (`.blockedBeforeWriting(reason:)`) y deja `phase = .idle` en el mismo turno; la sección enseña su
  aviso con el motivo devuelto y su cierre ya no toca la fase. Descartado «releer al reaparecer»: la sección no puede
  distinguir un `.blocked` suyo de uno de un cierre, y si nadie reabre Almacenamiento «Cerrar sesión» sigue mudo.
- **Coste aceptado:** si la hoja se cerró a mitad de la espera, el aviso de ESE intento no se enseña (nadie lo mira);
  la sección vuelve a ofrecer «Desasociar» y reintentar dice el motivo.
- **Spinner al reabrir a mitad de espera:** lo decide el coordinador (`isDetaching`), no un `@State` de la vista que
  murió con la hoja; sin eso, tocar «Desasociar» en la hoja reabierta daba `.busy` con «Estás cerrando sesión».
- **Hermano `signout-alert-fires-on-detach-blocks-it-did-not-cause`:** no se abre; el arreglo le quita la fase que
  Perfil leía (se anota en su ticket lo medido, sin moverlo).
- Ficheros: `CloudSessionSignOut.swift`, `GroupsAssociationSection.swift`, tests (nuevo + scans), ticket, coverage-index.
