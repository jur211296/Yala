# Volver desde «Encontramos datos tuyos» tras un corte ya no deja armado un borrado que la nube termina a ciegas

## Contexto
Cola A autónoma Yala (riesgo real: borrado inesperado / pérdida de datos / grupos). Acaba de mergear a 2.1 el PR #278 (`private-gate-leave-after-a-halfway-wipe-forgets-the-zone`): salir de la puerta privada tras un borrado a medias ya no olvida que iCloud quedó vacío. En el review adversarial de ese cierre salió este residual medium: `tickets/backlog/private-gate-back-from-found-keeps-a-resumed-arm.md`.

Síntoma: confirmo borrar iCloud en «Es mi primera vez → privado», la app se cierra a mitad, vuelvo y veo otra vez «Encontramos datos tuyos». Me arrepiento, toco «volver» y elijo crear cuenta en la nube. En el arranque siguiente la app termina aquel borrado sin preguntar: se lleva iCloud privado, lo del teléfono (ya de mi cuenta nube) y mis grupos.

Medido en el ticket: `leaveGate()` solo desarma desde fallos; desde `.found` / `.confirmingWipe` / `.foundDevice` / `.confirmingDeviceWipe` sale con el arm tal cual. Tras kill en `.wiping`, el arm sigue y `lateWipeLaunch` reanuda en cualquier storageMode, incluido `.cloud`, con `performICloudCorpusWipe(.handover)`.

Hora Lima ~08:55 domingo (diurno). Norma Jürgen 22-sep: tú eliges la opción robusta / good-practice (la Recommended del AskUserQuestion) y sigues sin preguntar a Jürgen por producto/techos/copy. Solo para si hace falta su device, secretos o acceso. Override autónomo: la regla del repo «¿Sigo?» / wait for approval si >3 files queda SUSPENDIDA en este encargo — implementa hasta gate/PR/merge/`/cerrar-total` sin pedir continuar.

## Que se pide
Cierra el ticket `private-gate-back-from-found-keeps-a-resumed-arm`:
1. Volver desde cualquier fase de la puerta (salvo `.wiping`, que no tiene «volver») no deja un borrado armado. Quien vuelve atrás ha retirado su petición, igual que en un fallo. Si la zona ya se había ido en el intento cortado, `disarm()` lo recuerda (mismo criterio del ticket padre).
2. Ningún arranque en modo nube termina un borrado del iCloud privado sin preguntar (cinturón: `lateWipeLaunch` deja de reanudar en `.cloud` si sigue haciendo falta tras el punto 1).
3. Tests que fijen el leave desde `.found` (y fases hermanas) + que un launch en `.cloud` con arm no dispare el wipe a ciegas.
4. Board al día: ticket a qa o done según criterio del repo; hallazgos nuevos → ticket propio en backlog antes de cerrar; actualiza `docs/TICKETS.md`.
5. Cierra con `/cerrar-total` (worktree de `lanzar-sesion`).

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- No paralelizar otro modelo semántico ni otro encargo Cola A
- No inventar alcance: el ticket hermano `activation-private-gate-leaves-a-late-notice-that-purges-groups` es otro ticket; no lo metas en este PR salvo que el mismo cambio lo cubra de verdad y lo documentes
- Device-QA opcional: no bloquees el merge esperando iPhone

## Como se sabe que esta bien
- Criterios de aceptación del ticket en verde (tests + lectura del camino leaveGate / lateWipeLaunch)
- PR mergeado a 2.1
- Board y `docs/TICKETS.md` coherentes
- `/cerrar-total` limpio

## Paso 0

Decisiones tomadas en modo autónomo (opción robusta):

1. **`leaveGate()` desarma sin condición.** La única fase que no debe desarmar es el borrado en vuelo, y ahí el «volver»
   no existe (`backAction` → `nil` en `.wiping` y `.wipingDevice`). Un test fija esas dos líneas: son ahora la única red.
2. **El cinturón de la nube va también.** No es redundante: el arranque deja el arm puesto tras un fallo `.untouched` del
   aviso tardío, y una migración a la nube lo llevaría hasta ahí. En `.cloud`, `lateWipeLaunch` → `.retireInCloud`
   (arm, zona y «a medias» fuera, sin borrar ni preguntar).
3. **El neutro durable pasa a tener dueño** (hallazgo de la review, lente de estados durables). Desarmar el borrado se
   llevaba también el neutro del cierre de sesión; con el punto 1 eso llegaba a cinco fases más. Marca nueva
   `cloudSync.icloudCorpusWipeOwnsNeutralMount`; el desarme solo retira el neutro que puso su propio arm.
4. **Ticket a `qa`**, no `done`: guion de device-QA opcional; el corte a mitad no se provoca a mano.
5. **El hermano `activation-private-gate-leaves-a-late-notice-that-purges-groups` no entra**: el cambio no lo cubre.
