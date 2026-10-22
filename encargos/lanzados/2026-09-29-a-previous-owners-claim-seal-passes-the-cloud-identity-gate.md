# Si otra cuenta ya usó la nube en este teléfono, puede subir mis movimientos pendientes a la suya

---
ticket: a-previous-owners-claim-seal-passes-the-cloud-identity-gate
modo: autonomo
cola: A
---

## Contexto
Cola A (riesgo real nube/sync), turno alternado tras el cierre limpio del carril adaptativo paso 4 (PR #297 mergeado a 2.1). Hallazgo de la review adversarial de `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit` (lente 2): el sello de claim de una cuenta previa sobrevive al sign-out y, con el motor sin dueño en memoria, puede hacer pasar la puerta de identidad con el corpus de otra persona.

Jürgen ordenó (2026-09-28): una sola sesión Yala a la vez, alternando Cola A y carril adaptativo. Esta es Cola A. No toques simuladores `YalaLane-Adapt-*`. MODO AUTÓNOMO nocturno (Lima ~02:13): elige la opción robusta / Recommended sin preguntar; no despiertes a Jürgen por preferencias reversibles. Device-QA opcional no frena merge ni `/cerrar-total`.

## Que se pide
Cierra el ticket `tickets/backlog/a-previous-owners-claim-seal-passes-the-cloud-identity-gate.md`.

1. **Medir primero** (el ticket está INFERIDO): confirma o desmiente el hueco con pruebas. En concreto:
   - Si alguna puerta de entrada en la nube (Welcome, «Nuevo grupo», «Dónde viven tus datos») deja entrar a B con el corpus de A sin el camino de la sesión secundaria.
   - Si con B dentro y el motor sin dueño, `start()` o el paso 1 de un cierre suben el outbox de A con el JWT de B.
2. Si el hueco es real: arreglarlo de forma robusta (el outbox personal no lleva dueño por fila; el sello de claim sobrevive a sign-out a propósito para el mismo usuario). No subas movimientos de A a la cuenta de B ni bajes lo de B sobre el corpus de A.
3. Gate completo, mutantes donde toque, review adversarial, PR a `2.1`, merge y `/cerrar-total` en autónomo.

## Que NO hay que tocar
- Carril adaptativo / iPad / simuladores `YalaLane-Adapt-*`.
- Producción / deploy.
- Cola B (UI/UX redesign).
- Abrir otra sesión Yala en paralelo.

## Como se sabe que esta bien
- Premisa medida (confirmada o ticket descartado/reescrito con evidencia).
- Si hay fix: con B reentrando tras A, los pendientes de A no suben a B y el corpus de A no se mezcla con el de B.
- Tests + CI verdes; PR mergeado a `2.1`; cierre limpio.

## Paso 0 (auto-contestado, MODO AUTÓNOMO)

- **Premisa medida: el hueco es real.** Ningún borrado olvida el sello de claim (`CloudClaimActionStore`): ni el del
  cierre de sesión (`performSignOutWipeIfArmed`) ni «Empezar desde cero». `removeUserPreferenceKeys` excluye `cloudSync.*`.
  Con el motor sin dueño en memoria, las tres anclas —`start()` (P6), `sessionBelongsToAnotherAccount` (paso 1 del cierre,
  cadencia) y `SyncSignInBannerLogic.afterSignIn` («Dónde viven tus datos»)— y el guard del Welcome aceptan a B por su sello
  viejo, con el corpus y el outbox de A. Se fija con un test que falla en `2.1`.
- **Dónde se arregla: la raíz, no cada puerta.** El sello significa «el corpus local es de esta cuenta», y deja de ser
  cierto cuando el teléfono cambia de persona. Se olvida en `CloudSessionRetirement.arm`, el escritor común de todas esas
  fronteras (borrado del cierre de sesión, los caminos de «Empezar desde cero», el cierre tras borrar la cuenta). Siempre
  corre DESPUÉS de borrar el corpus, así que un borrado que falla no se lleva el sello del dueño.
- **Se mantiene** que `signOut()` a secas (cerrar la sesión SIN borrar) no toca el sello: el dueño que vuelve a entrar sobre
  su corpus sigue pasando.
- **Con el sello se va la marca del claim de «Migrar» sin respuesta**, por coherencia: su cabecera dice «sobrevive igual que
  el sello», y describe una migración de un corpus que ya no está.
- **Descartado**: dueño por fila en `SyncOutbox` (migración de schema + backfill sin dato fiable) y un ancla nueva de «dueño
  del corpus» (más escritores y un fail-closed permanente si alguno se olvida). **Residual**: los sellos escritos ANTES de
  esta versión que ya sobrevivieron a un cierre siguen hasta el siguiente cierre o relevo; no hay forma de saber cuál es el
  del corpus.
