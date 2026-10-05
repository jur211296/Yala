# Avisar o bloquear la migración a la nube si hay un borrado de iCloud pendiente

## Contexto
Tarjeta: `tablero-decidir-borrado-de-icloud-pendiente-al-p-3fwt` (backlog).
Ticket: `tickets/backlog/late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud.md` (origen #279; sale de docs/ESTADO.md, retirado el 30-sep).

Hoy: el usuario pide borrar datos viejos de iCloud desde «Encontramos datos tuyos». El wipe no arranca (el import del espejo sigue en vuelo → `performICloudCorpusWipe` falla `.untouched` y el arm queda para el próximo arranque vía `ContentView.runLateICloudMirrorCheck`). Si antes de eso migra a la nube desde Ajustes, ni `MigrationWorkExecutor` ni el adopt miran el arm; al arrancar en `.cloud`, `lateWipeLaunch` hace `.retireInCloud` y retira el arm sin borrar ni preguntar. Los datos viejos pueden subir a la cuenta de la nube y el borrado pedido desaparece en silencio. iCloud sigue lleno.

Decisión de Jürgen 2026-10-04 (opción A, la robusta), literal: «A. Avisar o bloquear en la migración. No tragarse el borrado de iCloud pendiente en silencio al pasar a la nube.»

Regla permanente de Jürgen: quiere la solución más robusta y de mejores prácticas; no hay prisa. En horario nocturno (21:00–6:00 Lima) decide tú la opción recomendada dentro de A (avisar vs bloquear, copy, puntos de enganche) y sigue; si algo es irreversible sobre datos, déjalo propuesto para la mañana.

## Qué se pide
1. Implementar de punta a punta la decisión A: cuando hay un borrado de iCloud pendiente (late-wipe arm) y el usuario migra a la nube, la migración avisa o bloquea — el pending wipe nunca se retira en silencio.
2. Cubrir el flujo medido en el ticket (`MigrationWorkExecutor` / adopt / `lateWipeLaunch` → `.retireInCloud`) para que quien pidió borrar su iCloud privado y pasa a la nube se entere de que ese borrado no se hizo (criterio de aceptación del ticket).
3. Tests automatizados del comportamiento (unit / integración según convención del repo).
4. Copy de usuario localizado en todos los idiomas de la app, siguiendo las convenciones del repo (español neutro LATAM como base; no inventar claves fuera del patrón existente).
5. Mover el ticket del repo a `tickets/qa/` con un guion de device-QA si el cambio necesita un iPhone real para validar el wipe / la migración; si basta con sim + unit tests, indícalo en el PR y mueve a qa solo si el criterio del repo lo pide.
6. Actualizar la tarjeta del tablero cuando el trabajo quede entregado.

## Qué NO hay que tocar
- No cambiar modelo ni proveedor de IA.
- No tocar el PR #341 / formulario de cuenta.
- No tocar tarjetas de IA de 2.2 ni otras tarjetas del tablero.
- No tocar otros tickets (incluido `private-gate-back-from-found-keeps-a-resumed-arm` salvo lectura de contexto; no reabrir regresión ya cerrada).
- Nunca tocar la sesión ajena `salud--semana-nutricion-sem74`.

## Cómo se sabe que está bien
- Con un late-wipe arm puesto, intentar migrar a la nube avisa o bloquea; el arm no se retira en silencio.
- Tests verdes que cubren el camino anterior (migración / adopt / arranque en `.cloud` con arm).
- Copy localizado en todos los idiomas de la app.
- Ticket avanzado según convención (qa + guion de device-QA si hace falta iPhone).
- PR a `2.1` con gate verde; si queda en auto-merge, cierre limpio.

Base: arranca sobre origin/2.1. GATE: justo antes del gate mira si el PR anterior sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el simulador apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya y sigue. Build y simulador después de ese rebase, una sola vez.

Pipeline serial en la Mini: limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar y borrar data del sim. Nunca solapar.

DerivedData y cachés: al lanzar y al cerrar, borra sola el DerivedData de esta sesión (no el de otra viva) y las cachés de XcodeBuildMCP de worktrees que ya no existen o cuyo PR ya se mergeó. Prohibido preguntar si se borran; si falla, dilo en el cierre.

Capturas: si el cambio se ve en pantalla, deja `capturas/antes.png` y `capturas/despues.png` en el worktree y lista las rutas en el resumen.

Horario nocturno (21:00–6:00 Lima): decide la opción recomendada y más robusta y sigue; si algo es irreversible sobre datos, déjalo propuesto para la mañana.

Si al terminar el PR queda en auto-merge a 2.1, cierra con /cerrar-total y deja la Mini limpia (apagar sim, borrar data, quitar worktree si ya mergeó).

/cerrar-total

## Paso 0

*Auto-contestado de noche (22:10 Lima, 2026-10-04), dentro de la decisión A de Jürgen.*

**Medido antes de decidir.** Cuatro puertas llevan el dispositivo a `.cloud`: «Migrar a la nube» y «Activar en este
dispositivo» (adopt) en Ajustes, el alta y el adopt del Welcome, y el alta de la activación de Yala completo. Solo las
dos de Ajustes se abren con una sesión privada ya hecha, que es donde vive el borrado pendiente del aviso tardío. El
borrado pendiente son DOS marcas: el arm (`cloudSync.icloudCorpusWipeArmed`) y «a medias»
(`cloudSync.icloudCorpusWipeLeftHalfway`); `lateWipeLaunch` retira las dos en `.cloud` sin decir nada.

1. **¿Avisar o bloquear?** → **Avisar con elección explícita, en la puerta.** Al tocar «Activar la nube» (o
   «Activar en este dispositivo») con un borrado pendiente, sale un diálogo: «Activar la nube sin borrar» o «Esperar
   al borrado». No un bloqueo duro: el borrado puede quedarse atascado días (el espejo importando, iCloud sin red), y
   un bloqueo sin salida le quita a la persona la nube por un borrado que no controla.
2. **¿Cuándo se cancela el borrado?** → **Cuando el iPhone llega de verdad a la nube.** «Sin borrar» apunta una
   renuncia durable al arrancar la migración; el borrado sigue puesto hasta el arranque en `.cloud`, que lo retira sin
   contarlo. Si el intento vuelve a iCloud, la renuncia caduca. Mientras la migración está en vuelo, el arranque en
   iCloud ni reanuda ni pregunta. *(Corregido tras la review: la primera versión retiraba al arrancar `startMigration`,
   y las salidas previas al cutover perdían el borrado en silencio.)*
3. **¿Y las otras puertas, o una carrera?** → **Red en el arranque.** En `.cloud` el borrado se sigue retirando
   (reanudarlo se llevaría los datos de la cuenta), pero ahora se le dice a la persona una vez: «No se terminó un
   borrado de iCloud». La marca del aviso se escribe ANTES de retirar y se consume cuando la hoja monta (un kill no
   lo pierde). Si la persona ya eligió en Ajustes, la red no encuentra nada que contar: no hay doble aviso.
4. **¿Dónde se enseña?** → En la hoja del aviso tardío (`LateICloudMirrorNoticeView`), con una fase informativa y
   un solo botón. Reusa su paso por el router y la matriz de readiness.
5. **Copy** → claves nuevas `storage.pendingICloudWipe.*` y `welcome.privateICloud.cancelledInCloud*`, en los 16
   locales. Nombra «Empezar de cero» (lo que la persona pidió), «Activar la nube» como el botón al que acompaña, y
   «Ahora no». No promete reintentos ni afirma qué hay en iCloud o en el teléfono: dice «puede».
6. **Device-QA** → hace falta un iPhone con iCloud real para el atasco del espejo; el diálogo y la hoja se cubren en
   sim con un seam de ENTRADA (`-uitest-pending-icloud-wipe`). El ticket va a `qa` con guion.
7. **Review adversarial** → sí: toca el arm de un borrado y la migración a la nube.

**Asumido:** el cierre de sesión en la nube retira también la marca del aviso (es de la vida que se cierra).
