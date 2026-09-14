# Implementar ticket: groups-killswitch-403-blocks-detach-forever

## Contexto
Cola autónoma bypass (Jürgen 2026-09-13). Hermano del #146 (kill de nube): con el kill de **Grupos** (403 `yala_groups_disabled`) y outbox NO vacío, desasociar es imposible y el aviso dice que el problema es «tu cuenta» (`.permanent` sin reintento). Con outbox vacío el gesto sí completa.

## Decisión de producto (Jürgen, 2026-09-13)
Opción **(a)**: distinguir el 403 de kill-switch del resto de lo `permanent`. Un canal en pausa no es «tu cuenta ya no vale»: es «vuelve en un rato». Copy propio y, si procede, reintento.
**NO** opción (b): no permitir soltar dejando lo pendiente sin subir (el orden «pendiente sube ANTES de cortar» se mantiene).

MODO AUTÓNOMO HASTA TERMINAR: review adversarial si toca sync/incidentes, gate, commit, board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear`; si es high que deba adelantarse, anótalo en el cierre. Ambigüedad NUEVA: lo más seguro alineado con (a); regístralo. Device-QA → `tickets/qa/`.

Avisos a Frank (webhook Mini): (1) bloqueo acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle — una vez. No avisar por test/build a reintentar ni CI advisory.

No lances el siguiente: Frank encadena. No marketing/.

## Que se pide
1. Leer ticket + cadena medida (`GroupsSyncClient` 403 → classify → pushAllVerdict → GroupsSignOutRetryDecision → detach).
2. Implementar (a): el 403 de kill no se clasifica como permanent-de-cuenta; copy propio; reintento si procede.
3. Tests de la clasificación/decisión; outbox vacío sigue completando; outbox con 403 no miente.
4. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Opción (b). Wipe de prod. Cambiar el orden «pendiente sube antes de cortar» salvo lo mínimo para (a).

## Como se sabe que esta bien
Con kill de Grupos + outbox: aviso correcto (canal en pausa), no «cuenta rota»; con outbox vacío el detach sigue OK; tests en verde; PR mergeado; `/cerrar-total`.

## Paso 0 — decisiones resueltas (Frank, 2026-09-13)

Medido primero, contra este árbol. **Las tres coordenadas del ticket están caducadas**:
`CloudSignOutFlowLogic.swift` tiene 255 líneas, no 279 — `classify` está en :183 (no :214),
`pushAllVerdict` en :206 (no :242) y `GroupsSignOutRetryDecision.decide` en :245 (no :279). El paso 9
retiró piezas del fichero. La CADENA que describen sigue siendo exacta.

**Hallazgo que cambia el diseño: la distinción YA existe, y se pierde una capa más abajo de donde el
ticket mira.** `GroupsSyncClient.lastStopWasChannelKill` (:174) la escriben los dos únicos sitios que
leen un 403 —el push (:1501) y el pull (:1776)— con `GatewayErrorEnvelope.isGroupsChannelDisabled`.
El loop de cadencia YA la usa (:363) para no sellar `stoppedUntilRelaunch`. Lo que no existe es el
camino de esa señal hasta `classify`, porque el flag es `private` y `CadenceOutcome` no lo lleva.

- **D1 · Dónde vive la distinción.** El flag pasa a `private(set)` y `classify`/`pushAllVerdict` reciben
  `channelKilled:` **sin default**: el compilador obliga a los 13 call-sites a pronunciarse. NO se toca
  `SyncCadencePolicy.CadenceOutcome`: es compartido con el motor personal y su semántica de parada
  (`stopUntilRelaunch` vs. re-arrancable) está medida y es delicada — un case nuevo ahí reabriría el bug
  del 2026-07-31 que `lastStopWasChannelKill` vino a cerrar.
- **D2 · El flag se resetea al entrar en `syncCycleOnce`.** Sin eso describe «el último 403 de la vida
  del proceso» y no «el de este ciclo», y hay un productor de `.accountUnavailable` que NO escribe el
  flag: el 409 `yala_account_reverting` (:1503). Con un kill previo en el proceso, una cuenta
  revirtiendo se anunciaría como «canal en pausa». El reset cubre el dominio entero; una línea extra en
  la rama del 409 solo cubriría el 409, así que no se pone.
- **D3 · Motivo nuevo `BlockReason.channelPaused`**, al FINAL del enum.
- **D4 · Sin reintento automático, y es una decisión, no un olvido.** El kill es una palanca de
  operación que se levanta con un deploy; el presupuesto de 45 s gastaría ~22 peticiones contra un 403
  seguro en pleno incidente —lo contrario de lo que quiere quien lo bajó— y retrasaría el aviso 45 s
  sobre un veredicto que no va a cambiar. `decide` lo trata como inmediato, igual que `.permanent`, y
  el copy es el que invita a volver más tarde. El gesto sigue siendo reintentable por el usuario.
- **D5 · El aplanado del motivo se corrige.** `pushGroupsForSignOut` colapsaba el motivo con un ternario
  (`reason == .sessionExpired ? .sessionExpired : .permanent`). Sin tocarlo, el motivo nuevo llegaría a
  la pantalla convertido en `.permanent` y el arreglo heredaría la forma del bug. Pasa a `reason: reason`
  — **byte-equivalente hoy** (`decide` solo devuelve `.surfacePermanent` para esos dos motivos).
- **D6 · El CIERRE DE SESIÓN entra en alcance, y no por ampliarlo.** Comparte
  `pushGroupsForSignOut`, así que sufre la misma mentira por la otra superficie, y su
  `switch` de `ProfileView.presentSignOutBlock` es exhaustivo: el compilador obliga. Su alert elegía
  mensaje con un `Bool`, que con tres estados ya no llega.
- **D7 · Fuera de alcance, con motivo.** El `guard residual == 0` post-teardown de `detachGroupsAccount`
  sigue en `.permanent`: ahí el canal ya está cortado y el motivo real es «se encoló después de cortar»,
  no el kill. Y no se toca el orden «lo pendiente sube ANTES de cortar» (opción (b), descartada).
