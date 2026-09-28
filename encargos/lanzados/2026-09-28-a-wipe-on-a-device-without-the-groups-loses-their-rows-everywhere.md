# «Vaciar datos» en un iPad sin Grupos ya no deja al iPhone sin los gastos de grupo

## Contexto
Cola A autónoma (riesgo real de sync/nube). Residual del cierre de `late-remote-wipe-signal-also-wipes-rows-created-after-it` (PR #289, 2026-09-28). El ticket está en `tickets/backlog/a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere.md`. Arrancas en contexto limpio.

Síntoma: el usuario usa Grupos en el iPhone. En un iPad que nunca entró en Grupos pulsa «Vaciar datos». En el iPhone desaparecen de las cuentas los gastos y liquidaciones de grupo, y no vuelven.

Medido: el origen sin store local de Grupos converge sobre nada; su borrado viaja por el espejo; el receptor con grupos, si procesa la señal en el orden normal (sin filas de grupo posteriores), no pide su convergencia y da por repuesto lo que el origen no va a reponer. El orden tardío sí queda cubierto desde el 27-sep (mantenido el 28-sep). Es el espejo de `late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows` (receptor sin grupos).

Pedir siempre ya se descartó el 27-sep (dos convergencias cruzadas duplican). Salida recomendada en el ticket: el origen escribe en la señal si su convergencia puede reponer (tiene grupos y canal vivo), y el receptor con grupos pide la suya cuando el origen dice que no.

Feedback fresco del 28-sep (léelo): `feedback_el_motivo_que_cae_no_retira_el_mecanismo` — si un arreglo deja un mecanismo «sin motivo», no lo retires hasta enumerar qué otros casos cubre hoy.

## Que se pide
Cierra el ticket de punta a punta en MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge a 2.1 y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs o decisiones nuevas → ticket propio antes de cerrar. No sync al Kanban del panel.

Opción robusta recomendada (elige tú sin preguntar salvo acceso/device/secrets o decisión demasiado grave para asumir): señal que declare si el origen puede reponer; el receptor con grupos pide convergencia cuando el origen no puede. Mantén lo que ya cubre el orden tardío y la petición de convergencia donde siga cubriendo casos reales (no retires mecanismos por premisa caída sin medir).

Hora Lima diurna: si hace falta una decisión de producto o acceso de Jürgen, usa AskUserQuestion vía el aviso al bot; si es preferencia reversible, toma la recomendada y sigue.

## Que NO hay que tocar
- marketing/
- Simuladores de la cola adaptativa (prefijo `YalaLane-Adapt-`); usa solo los de Cola A / destino normal del encargo
- clinicas-dentales-bi / datos de salud
- Retirar a ciegas el mecanismo de declaraciones del 27-sep (`late-remote-wipe-return-has-no-producer-left` es otro ticket, low); aquí no lo metas salvo que el fix lo exija y lo documentes
- No paralices por device-QA pendiente de otros tickets

## Como se sabe que esta bien
- Con un origen sin Grupos (o canal parado) que vacía, un receptor con grupos conserva / repone sus gastos y liquidaciones de grupo; no se pierden en el parque
- No reaparecen duplicados por pedir convergencia siempre
- Tests (unit / wiring) cubren el hueco del orden normal; gate verde o residual documentado
- Ticket movido, `docs/TICKETS.md` al día, PR mergeado a 2.1, `/cerrar-total`

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 (Frank, 2026-09-28, auto-contestado en MODO AUTÓNOMO)

**Decisión: el origen no declara un sí/no, declara QUÉ repone; el receptor repone el resto.** Se aparta de la
recomendación del encargo (un booleano) por tres casos medidos leyendo código que el booleano no cubre:

1. **Origen con una parte de los grupos** (otra cuenta de grupos, o el canal atrasado): diría «sí puedo» y lo que le falta
   se perdería; o diría «no» y los dos repondrían lo que tiene, que es el duplicado del 27-sep.
2. **Un gasto de grupo que el origen aún no conocía al vaciar** (creado en el iPhone segundos antes): el corte del receptor
   lo borra (es anterior a la señal) y nadie lo repone, tenga el origen grupos o no.
3. Un booleano en la señal no dice nada de ids, y el receptor no puede calcular qué le falta al origen.

**Receta.**
- **Origen** («Vaciar datos» que avisa al parque): antes de la señal, escribe en el iCloud-KV el REPARTO: la hora de la
  señal y los ids que su convergencia repondrá (gastos locales y liquidaciones confirmadas fuera de grupos ocultos, los
  mismos filtros de la convergencia). Sin grupos, el reparto va vacío. La misma hora que la señal.
- **Receptor, orden normal**: antes de su borrado apunta en local «espero el reparto de la señal T». En el arranque
  (`retryPendingBridges`, antes de la convergencia) lo resuelve: con el reparto de T, pide su convergencia EXCLUYENDO los
  ids del origen, con las liquidaciones. Sin reparto, espera; a los 30 días lo suelta (el origen es un build anterior).
- **Receptor, orden tardío**: sin cambios. Pide la convergencia entera (#284/#289), que ya cubría este caso.
- **Una petición entera gana a una con exclusión**, y una con exclusión nueva sustituye a la vieja (el corte nuevo ya se
  llevó lo que repuso el origen viejo). La primera versión las intersecaba; lo cambió la review (lente de grupos).
- Por qué no duplica: origen y receptor reponen conjuntos disjuntos. Solo solapa lo que el origen recibe DESPUÉS de vaciar
  por su canal, que su sync de grupos puentea igual hoy (residual ya conocido de «cada dispositivo con grupos puentea lo
  que le llega»).

**Asumido (defaults reversibles):**
- Reparto por ids y no por filas: el receptor ya se llevó con su corte todo lo anterior a la señal, así que no hay borrado
  pendiente del espejo que esperar.
- Clave nueva del KV (`groupsWipeDivision`), una sola, sobrescrita en cada vaciado. Se escribe sin `synchronize` propio:
  sube con el de la señal, que va detrás.
- Si el ALCANCE local de la petición no se puede leer, cuenta como petición entera (repone todo): un duplicado se cura en
  el siguiente re-puente del gasto; una pérdida no. El REPARTO del KV que no se deja leer, en cambio, se trata como uno
  que no llegó (espera y suelta): viene de otro dispositivo y reponer todo arriesgaría el duplicado. Corregido tras la
  review (lente de sync): la primera redacción los mezclaba.
- El mecanismo de declaraciones del 27-sep (`GroupsRemoteWipeReturn`) NO se toca: su ticket
  (`late-remote-wipe-return-has-no-producer-left`) sigue abierto.
- Tres o más dispositivos con dos receptores con grupos: los dos reponen lo que no está en el reparto. Duplica solo si
  convergen antes de cruzarse por el espejo (mismo residual documentado del 27-sep). Va al ticket, no se arregla aquí.

**Ficheros (nota, no pregunta):** `GroupsRemoteWipeDivision.swift` (nuevo), `GroupsBridgeRestoreConvergence.swift`,
`DataWipeService.swift`, `PreferenceSyncService.swift`, `AppBootstrapper.swift`, tests, `.claude/rules/swiftdata-cloudkit.md`,
`qa/coverage-index.json`, ticket y `docs/TICKETS.md`.
