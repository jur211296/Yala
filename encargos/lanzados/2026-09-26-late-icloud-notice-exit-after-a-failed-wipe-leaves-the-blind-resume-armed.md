# Salir del aviso del espejo tardío tras un borrado fallido no debe reanudar el borrado a ciegas

## Contexto
Ticket `tickets/backlog/late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed.md` (léelo entero). Cola A de Yala (riesgo real: wipe inesperado). Residual de `fresh-start-wipe-kills-unsent-group-writes-silently` / «Empezar de cero».

En `LateICloudMirrorNoticeView`, la fase `.failed` sale con «Dejarlo por ahora» (`dismiss()`) o con «Cerrar» (`onKeep()` + `dismiss()`). Ninguna retira el arm (`StorageModePersistence.armICloudCorpusWipe`). En el arranque siguiente, `ContentView.runLateICloudMirrorCheck` ve el arm y reanuda `performICloudCorpusWipe(.handover)` a ciegas, sin pantalla: borra la zona de iCloud, las filas personales y el dominio de Grupos, aunque la persona dijo «déjalo así». El comentario de la fase promete lo contrario («el aviso vuelve en el próximo arranque»).

La fase nueva `.groupsPending` (del ticket del wipe con pendientes) ya desarma con seguridad porque aún no se había borrado nada. En `.failed` NO: el fallo puede llegar después de borrar la zona, y el arm es lo que termina un borrado a medias.

## Que se pide
1. Distinguir el fallo **antes** de borrar la zona del fallo **después**.
2. Solo desarmar (y dejar que el aviso vuelva / salga limpio) cuando el fallo fue antes de tocar la zona.
3. Si el fallo fue después de borrar la zona: no reanudar a ciegas en el siguiente arranque; decirle a la persona que el borrado quedó a medias (copy claro, opción robusta/Recommended) y ofrecerle el camino seguro para terminarlo o quedarse, sin wipe silencioso.
4. Tests que cubran: salir en `.failed` pre-zona desarma; salir post-zona no reanuda a ciegas; mutante que vuelva a reanudar a ciegas pone el test en rojo.
5. Si la review saca bugs o decisiones nuevas → ticket propio antes de cerrar.

## Que NO hay que tocar
- El comportamiento de `.groupsPending` ya arreglado (desarmar ahí está bien).
- `mcp/`, staging/prod de Supabase, marketing, otros proyectos.
- No abras el ticket diferido `sign-out-exits-do-not-verify-the-cloud-session-closed` (sigue «sin prisa»).
- Cola B (rediseño UI).

## Como se sabe que esta bien
- Gate verde (unit + lo del área); mutantes del caso a ciegas muertos.
- Review adversarial del diff antes del merge.
- PR a `2.1` mergeado; ticket a `qa` o `done` con guion si hace falta device; `docs/TICKETS.md` al día; `/cerrar-total`.

## MODO AUTÓNOMO
La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo. Implementa hasta gate/PR/merge y cierra con `/cerrar-total` sin pedir continuar. Solo AskUserQuestion real de producto/acceso (es de día Lima). Decisiones de techos/copy/salidas: elige la opción robusta/Recommended tú.

## Paso 0 (Frank, 2026-09-26 — auto-contestado, MODO AUTÓNOMO)

Medido en el árbol: el único fallo DESPUÉS de la zona hoy es `localWipeFailed` (cinturón de grupos o `wipeAllUserData`);
el resto (`cancelled`, `importNotQuiescent`, grupos pendientes, `signOutBusy`, el propio fallo de la zona) llega antes de
tocar nada. Y el cuerpo de `.failed` dice «Tus datos siguen en iCloud, intactos» — **falso** tras borrar la zona.

1. **Cómo se distingue antes/después.** Una marca durable que escribe QUIEN cruza la zona (`performICloudCorpusWipe`,
   justo tras borrarla), sub-estado del arm: `cloudSync.icloudCorpusWipeZoneDone`, se va con `clearICloudCorpusWipeArm`.
   No clasificar el string del motivo: un motivo nuevo tras la zona caería en «nada se tocó». *Asumido.*
2. **Cuándo cambia el estado.** Al ENTRAR en el fallo, no al salir: un kill mirando `.failed` queda igual de cubierto.
   Antes de la zona → se desarma (el testigo sigue, el aviso vuelve a preguntar). Después → marca
   `cloudSync.icloudCorpusWipeLeftHalfway` y se desarma. *Asumido.*
3. **Pantalla nueva `.leftHalfway`** («El borrado quedó a medias»), no el `.failed` con su copy falso. Botón principal
   «Terminar de borrar» (la persona ya confirmó dos veces; el cuerpo dice qué se va). Salida «Déjalo así» =
   se queda con lo del teléfono, retira las dos marcas y el testigo. Cerrar/deslizar = «luego»: vuelve al arrancar.
4. **Arranque.** Arm primero (un kill a mitad sigue reanudando, eso no cambia). Si la reanudación falla y la zona ya se
   había borrado → a medias + pantalla, no otro intento a ciegas. Sin arm y con «a medias» → la pantalla.
5. **«Cerrar» en `.failed`** pasa a hacer lo mismo que «Dejarlo por ahora» (el aviso vuelve), como ya se hizo en
   `.groupsPending`: dos controles al mismo sitio con efectos distintos era la incoherencia. *Asumido.*
6. **La marca «a medias» muere con la sesión** (hook de sign-out, junto al testigo), por la misma razón que él.
7. Sin re-confirmación en «Terminar de borrar»: sigue el molde de «Volver a intentarlo» de `.failed`.
